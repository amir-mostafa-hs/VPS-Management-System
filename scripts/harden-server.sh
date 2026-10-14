#!/usr/bin/env bash
# ==============================================================================
# harden-server.sh — Host Security Hardening, SSH & Configurable UFW Firewall
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIG_FILE="${SERVER_CONFIG_PATH:-${REPO_ROOT}/config/server.env}"
PORTS_CONFIG_PATH="${PORTS_CONFIG_PATH:-${REPO_ROOT}/config/allowed_ports.conf}"

DRY_RUN=false
FORCE_YES=false
PARSE_PORTS_ONLY=false

# Default baseline variables (can be overridden by config file)
SSH_PORT="${SSH_PORT:-22}"
FAIL2BAN_ENABLED="${FAIL2BAN_ENABLED:-true}"
CUSTOM_ALLOWED_PORTS="${CUSTOM_ALLOWED_PORTS:-}"

# Load config if present
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Applies security hardening, verifies SSH key sessions to prevent lockouts,
enforces SSH key-only authentication, configures UFW with a default-deny
inbound posture, allows baseline ports, and dynamically parses custom allowed
ports from config/allowed_ports.conf.

Baseline Ports Allowed:
  - ${SSH_PORT}/tcp (SSH management)
  - 80/tcp  (HTTP - Traefik ingress & ACME)
  - 443/tcp (HTTPS - Traefik TLS)
  - 8000/tcp (Coolify PaaS UI)

Dynamic Custom Ports:
  Configured in config/allowed_ports.conf (format: <port>[/<protocol>])

Options:
  --dry-run            Display planned firewall rules and hardening without applying
  --parse-ports-only   Parse allowed_ports.conf, output parsed list, and exit
  -y, --yes            Skip interactive confirmation prompts
  -h, --help           Display this help message and exit

EOF
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --parse-ports-only)
            PARSE_PORTS_ONLY=true
            shift
            ;;
        -y|--yes)
            FORCE_YES=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Dynamic port parser
parse_ports() {
    local config_file="$1"
    local -a parsed=()

    if [[ -f "${config_file}" ]]; then
        while IFS= read -r line || [[ -n "${line}" ]]; do
            # Strip comments
            line="${line%%#*}"
            # Extract first token (port specification)
            local port_token=""
            read -r port_token _ <<< "${line}"

            [[ -z "${port_token}" ]] && continue

            # If protocol omitted, default to /tcp
            if [[ "${port_token}" =~ ^[0-9]+$ ]]; then
                port_token="${port_token}/tcp"
            fi

            # Validate format <port>/<protocol>
            if [[ "${port_token}" =~ ^([0-9]{1,5})/(tcp|udp)$ ]]; then
                local port_num="${BASH_REMATCH[1]}"
                if (( port_num >= 1 && port_num <= 65535 )); then
                    parsed+=("${port_token}")
                fi
            fi
        done < "${config_file}"
    fi

    # Also include ports from environment variable CUSTOM_ALLOWED_PORTS if provided
    if [[ -n "${CUSTOM_ALLOWED_PORTS}" ]]; then
        for p in ${CUSTOM_ALLOWED_PORTS}; do
            if [[ "${p}" =~ ^[0-9]+$ ]]; then
                p="${p}/tcp"
            fi
            if [[ "${p}" =~ ^[0-9]+/(tcp|udp)$ ]]; then
                parsed+=("${p}")
            fi
        done
    fi

    printf "%s\n" "${parsed[@]}"
}

# If only parsing requested
if [[ "${PARSE_PORTS_ONLY}" == "true" ]]; then
    parse_ports "${PORTS_CONFIG_PATH}"
    exit 0
fi

log_step "Configuring Host Hardening and Firewall (UFW)"

# Gather all ports to allow
base_ports=("${SSH_PORT}/tcp" "80/tcp" "443/tcp" "8000/tcp")
mapfile -t custom_ports < <(parse_ports "${PORTS_CONFIG_PATH}")

log_info "Base ports: ${base_ports[*]}"
if [[ ${#custom_ports[@]} -gt 0 ]]; then
    log_info "Custom ports from config: ${custom_ports[*]}"
fi

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Planned firewall configuration commands:"
    printf "  0. Verify active SSH session and authorized_keys existence\n"
    printf "  1. ufw default deny incoming\n"
    printf "  2. ufw default allow outgoing\n"
    for port in "${base_ports[@]}"; do
        printf "  3. ufw allow %s\n" "${port}"
    done
    for port in "${custom_ports[@]}"; do
        printf "  4. ufw allow %s\n" "${port}"
    done
    printf "  5. ufw --force enable\n"
    printf "  6. Configure sshd key-only authentication (/etc/ssh/sshd_config.d/99-vps-hardening.conf)\n"
    printf "  7. sshd -t && systemctl reload sshd\n"
    if [[ "${FAIL2BAN_ENABLED}" == "true" ]]; then
        printf "  8. systemctl enable --now fail2ban\n"
    fi
    log_success "[DRY-RUN] Completed without modifying firewall."
    exit 0
fi

# Mutating operations
require_root

# Verify SSH key authentication safety
verify_ssh_safety() {
    log_info "Verifying SSH key authentication safety..."
    local keys_found=0

    # Check root authorized keys
    if [[ -f /root/.ssh/authorized_keys ]] && [[ -s /root/.ssh/authorized_keys ]]; then
        keys_found=$((keys_found + 1))
    fi

    # Check home directories for authorized keys
    for user_dir in /home/*; do
        if [[ -f "${user_dir}/.ssh/authorized_keys" ]] && [[ -s "${user_dir}/.ssh/authorized_keys" ]]; then
            keys_found=$((keys_found + 1))
        fi
    done

    if [[ "${keys_found}" -eq 0 && "${SKIP_SSH_KEY_CHECK:-false}" != "true" ]]; then
        log_warn "No non-empty authorized_keys files detected on this system."
        log_warn "Disabling password authentication now could permanently lock you out!"
        if ! confirm_action "Continue without detected SSH public keys?" "N"; then
            log_error "Hardening aborted to prevent operator lockout."
            exit 1
        fi
    else
        log_success "Verified ${keys_found} authorized_keys file(s) present."
    fi

    if [[ -n "${SSH_CONNECTION:-}" ]]; then
        log_success "Active SSH session confirmed (${SSH_CONNECTION})."
    else
        log_info "Running in local or automated session."
    fi
}

verify_ssh_safety

log_warn "Applying firewall rules will enable UFW with default-deny on all inbound ports."
log_warn "Ensure your active SSH port (${SSH_PORT}) is accessible before confirming."

if ! confirm_action "Proceed with enabling UFW firewall, SSH hardening, and fail2ban?" "N"; then
    log_warn "Hardening aborted by operator."
    exit 0
fi

# Apply UFW rules
log_info "Configuring UFW default policies..."
ufw default deny incoming
ufw default allow outgoing

log_info "Allowing base ports..."
for port in "${base_ports[@]}"; do
    ufw allow "${port}"
done

if [[ ${#custom_ports[@]} -gt 0 ]]; then
    log_info "Allowing custom configured ports..."
    for port in "${custom_ports[@]}"; do
        ufw allow "${port}"
    done
fi

log_info "Enabling UFW..."
ufw --force enable

# Apply SSH hardening configuration
configure_sshd() {
    log_info "Applying SSH daemon security hardening..."
    mkdir -p /etc/ssh/sshd_config.d
    cat << 'EOF' > /etc/ssh/sshd_config.d/99-vps-hardening.conf
# Enforce public-key authentication and disable passwords
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
MaxAuthTries 3
X11Forwarding no
EOF
    chmod 0644 /etc/ssh/sshd_config.d/99-vps-hardening.conf

    if command -v sshd >/dev/null 2>&1; then
        if sshd -t >/dev/null 2>&1; then
            if command -v systemctl >/dev/null 2>&1; then
                systemctl reload sshd 2>/dev/null || systemctl reload ssh 2>/dev/null || true
                log_success "SSH daemon reloaded with hardened configuration."
            fi
        else
            log_warn "sshd -t syntax check failed. Reverting 99-vps-hardening.conf."
            rm -f /etc/ssh/sshd_config.d/99-vps-hardening.conf
        fi
    fi
}

configure_sshd

# Configure fail2ban
if [[ "${FAIL2BAN_ENABLED}" == "true" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
        log_info "Enabling and starting fail2ban service..."
        systemctl enable --now fail2ban || log_warn "Could not enable fail2ban via systemctl."
    fi
fi

log_success "Host security hardening completed successfully."
