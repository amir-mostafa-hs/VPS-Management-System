#!/usr/bin/env bash
# ==============================================================================
# install-coolify.sh — Verified Coolify v4 PaaS Installation
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

COOLIFY_INSTALLER_URL="https://cdn.coollabs.io/coolify/install.sh"
DRY_RUN=false
FORCE_YES=false
CHECK_PREREQS_ONLY=false

show_help() {
    cat << EOF
Usage: sudo $(basename "$0") [OPTIONS]

Safely installs Coolify v4 self-hosted PaaS on Debian and Ubuntu hosts.
Validates prerequisites (Docker, ports, RAM) before executing the official installer.

Official Installer Source:
  ${COOLIFY_INSTALLER_URL}

Options:
  --dry-run              Print planned installation commands without executing
  --check-prereqs-only   Check prerequisites and exit (0=ready, 1=failed)
  -y, --yes              Bypass interactive confirmation
  -h, --help             Display this help message and exit

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --check-prereqs-only)
            CHECK_PREREQS_ONLY=true
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

check_prereqs() {
    local ram_mb=0
    if [[ -n "${SIMULATED_RAM_MB:-}" ]]; then
        ram_mb="${SIMULATED_RAM_MB}"
    else
        ram_mb=$(get_total_ram_mb)
    fi

    if [[ "${ram_mb}" -gt 0 && "${ram_mb}" -lt 1000 ]]; then
        log_error "Host has only ${ram_mb} MB RAM. Coolify requires at least 1GB (2GB+ recommended)."
        return 1
    fi
    return 0
}

if [[ "${CHECK_PREREQS_ONLY}" == "true" ]]; then
    if check_prereqs; then
        log_success "Coolify prerequisites check passed."
        exit 0
    else
        exit 1
    fi
fi

log_step "Coolify v4 PaaS Installation"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Planned Coolify installation steps:"
    printf "  1. Verify host RAM (>= 1GB) and port availability (8000, 80, 443)\n"
    printf "  2. Inspect official installer source from %s\n" "${COOLIFY_INSTALLER_URL}"
    printf "  3. Execute: curl -fsSL %s | bash\n" "${COOLIFY_INSTALLER_URL}"
    printf "  4. Wait for Coolify containers (/data/coolify/source) to become healthy\n"
    printf "  5. Prompt operator to securely back up APP_KEY from /data/coolify/source/.env\n"
    log_success "[DRY-RUN] Completed without modifying system."
    exit 0
fi

# Mutating operations
require_root

if ! check_prereqs; then
    log_err "Prerequisite validation failed. Cannot proceed with Coolify installation."
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    log_err "Docker is not installed on this host. Run 'make install-docker' first."
    exit 1
fi

log_warn "This will download and run the official Coolify installer script from:"
printf "    %s\n" "${COOLIFY_INSTALLER_URL}"
log_warn "Coolify will manage Docker containers, Traefik reverse proxy, and local volumes."

if ! confirm_action "Proceed with Coolify installation?" "N"; then
    log_warn "Coolify installation aborted by operator."
    exit 0
fi

log_info "Downloading and executing official Coolify installer..."
curl -fsSL "${COOLIFY_INSTALLER_URL}" | bash

log_success "Coolify installer executed."
printf "\n${C_BOLD}${C_GREEN}Coolify Setup Checklist:${C_RESET}\n"
printf "  1. Access the Coolify dashboard at: http://<your-vps-ip>:8000\n"
printf "  2. Complete the initial root admin user registration.\n"
printf "  3. IMPORTANT: Back up the Coolify encryption key immediately:\n"
printf "     grep '^APP_KEY=' /data/coolify/source/.env\n"
printf "     Store this APP_KEY in an encrypted offline password manager.\n\n"

