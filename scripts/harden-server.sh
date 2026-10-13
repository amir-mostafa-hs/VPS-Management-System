#!/usr/bin/env bash
# ==============================================================================
# harden-server.sh — Server Security Hardening and Configurable Firewall
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

# Default settings (can be overridden by server.env)
SSH_PORT="${SSH_PORT:-22}"
UFW_ENABLED="${UFW_ENABLED:-true}"
FAIL2BAN_ENABLED="${FAIL2BAN_ENABLED:-true}"
CUSTOM_ALLOWED_PORTS="${CUSTOM_ALLOWED_PORTS:-}"

# Load server.env if it exists
if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

show_help() {
    cat << EOF
Usage: sudo $(basename "$0") [OPTIONS]

Security hardening script that configures UFW firewall, fail2ban, and SSH access rules.
Reads base ports and dynamically parses additional allowed ports from:
  ${PORTS_CONFIG_PATH}

Base Allowed Ports:
  - SSH (port ${SSH_PORT}/tcp)
  - 80/tcp (HTTP)
  - 443/tcp (HTTPS)
  - 8000/tcp (Coolify PaaS UI)

Options:
  --dry-run             Print planned firewall and hardening rules without applying them
  --parse-ports-only    Output parsed ports from configuration and exit
  -y, --yes             Bypass interactive confirmation
  -h, --help            Display this help message and exit

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
            log_err "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Function to parse ports configuration
parse_ports() {
    local config_file="$1"
    local parsed=()

    if [[ -f "${config_file}" ]]; then
        while IFS= read -r line || [[ -n "${line}" ]]; do
            # Remove comments and trim whitespace
            line="${line%%#*}"
            line="$(echo "${line}" | xargs || true)"

            if [[ -z "${line}" ]]; then
                continue
            fi

            # Extract first token (the port definition)
            local port_def
            port_def="$(echo "${line}" | awk '{print $1}')"

            if [[ -z "${port_def}" ]]; then
                continue
            fi

            # If no protocol specified, default to /tcp
            if [[ "${port_def}" =~ ^[0-9]+$ ]]; then
                port_def="${port_def}/tcp"
            fi

            # Basic validation: digits followed by /tcp or /udp
            if [[ "${port_def}" =~ ^[0-9]+/(tcp|udp)$ ]]; then
                parsed+=("${port_def}")
            else
                log_warn "Ignoring invalid port definition: '${port_def}'"
            fi
        done < "${config_file}"
    fi

    # Also include any ports defined in CUSTOM_ALLOWED_PORTS variable
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
    printf "  1. ufw default deny incoming\n"
    printf "  2. ufw default allow outgoing\n"
    for port in "${base_ports[@]}"; do
        printf "  3. ufw allow %s\n" "${port}"
    done
    for port in "${custom_ports[@]}"; do
        printf "  4. ufw allow %s\n" "${port}"
    done
    printf "  5. ufw --force enable\n"
    if [[ "${FAIL2BAN_ENABLED}" == "true" ]]; then
        printf "  6. systemctl enable --now fail2ban\n"
    fi
    log_success "[DRY-RUN] Completed without modifying firewall."
    exit 0
fi

# Mutating operations
require_root

log_warn "Applying firewall rules will enable UFW with default-deny on all inbound ports."
log_warn "Ensure your active SSH port (${SSH_PORT}) is accessible before confirming."

if ! confirm_action "Proceed with enabling UFW firewall and fail2ban?" "N"; then
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

# Configure fail2ban
if [[ "${FAIL2BAN_ENABLED}" == "true" ]]; then
    if command -v systemctl >/dev/null 2>&1; then
        log_info "Enabling and starting fail2ban service..."
        systemctl enable --now fail2ban || log_warn "Could not enable fail2ban via systemctl."
    fi
fi

log_success "Host security hardening completed successfully."
