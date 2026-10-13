#!/usr/bin/env bash
# ==============================================================================
# setup-backups.sh — Setup Staging Paths and Systemd Automated Backup Timer
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

DRY_RUN=false
FORCE_YES=false

show_help() {
    cat << EOF
Usage: sudo $(basename "$0") [OPTIONS]

Configures the automated backup subsystem on the VPS:
  1. Creates secure staging directory (/var/backups/vps, permissions 0700)
  2. Copies systemd service and timer units to /etc/systemd/system/
  3. Reloads systemd daemon and activates vps-backup.timer (daily at 03:00 UTC)

Options:
  --dry-run       Display planned systemd unit and directory setup without modifying host
  -y, --yes       Bypass interactive confirmation
  -h, --help      Display this help message and exit

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
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

log_step "Configuring Automated Backup System"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Planned backup system configuration:"
    printf "  1. mkdir -p -m 0700 /var/backups/vps\n"
    printf "  2. cp %s/systemd/vps-backup.service /etc/systemd/system/\n" "${REPO_ROOT}"
    printf "  3. cp %s/systemd/vps-backup.timer /etc/systemd/system/\n" "${REPO_ROOT}"
    printf "  4. systemctl daemon-reload\n"
    printf "  5. systemctl enable --now vps-backup.timer\n"
    log_success "[DRY-RUN] Completed without modifying system."
    exit 0
fi

# Mutating execution requires root
require_root

if ! confirm_action "Set up backup staging directory and enable systemd daily backup timer?" "Y"; then
    log_warn "Setup cancelled by operator."
    exit 0
fi

log_info "Creating secure backup staging directory..."
mkdir -p -m 0700 /var/backups/vps

log_info "Installing systemd units..."
cp "${REPO_ROOT}/systemd/vps-backup.service" /etc/systemd/system/
cp "${REPO_ROOT}/systemd/vps-backup.timer" /etc/systemd/system/

if command -v systemctl >/dev/null 2>&1; then
    log_info "Reloading systemd daemon..."
    systemctl daemon-reload

    log_info "Enabling and starting vps-backup.timer..."
    systemctl enable --now vps-backup.timer
fi

log_success "Automated backup subsystem configured successfully."
printf "Timer schedule: Daily at 03:00 UTC.\n"
printf "Check timer status: systemctl status vps-backup.timer\n"
