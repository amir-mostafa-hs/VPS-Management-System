#!/usr/bin/env bash
# ==============================================================================
# bootstrap.sh — System Package Bootstrapping and Repository Update
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

DRY_RUN=false
FORCE_YES=false

show_help() {
    cat << EOF
Usage: sudo $(basename "$0") [OPTIONS]

Idempotent host bootstrapping script for Debian and Ubuntu.
Installs base utilities, network tools, and security packages required
by the VPS infrastructure automation.

Packages Installed:
  curl, git, ufw, fail2ban, jq, rclone, ca-certificates, tar, gzip, unzip

Options:
  --dry-run       Print planned actions without modifying host or packages
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

log_step "Bootstrapping Host System Packages"

readonly PACKAGES=(
    curl
    git
    ufw
    fail2ban
    jq
    rclone
    ca-certificates
    tar
    gzip
    unzip
)

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Planned execution steps:"
    printf "  1. apt-get update\n"
    printf "  2. apt-get install -y %s\n" "${PACKAGES[*]}"
    log_success "[DRY-RUN] Completed without modifying system."
    exit 0
fi

# Step 1: Preflight validation (for mutating run)
log_info "Verifying host compatibility..."
if ! bash "${SCRIPT_DIR}/preflight.sh" --check-only; then
    log_err "Preflight compatibility checks failed. Halting bootstrap."
    exit 1
fi
log_success "Host compatibility confirmed."

# Mutating execution requires root
require_root

if ! confirm_action "Update package index and install essential dependencies?" "Y"; then
    log_warn "Bootstrap cancelled by operator."
    exit 0
fi

log_info "Updating APT package index..."
DEBIAN_FRONTEND=noninteractive apt-get update -y

log_info "Installing packages: ${PACKAGES[*]}..."
DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGES[@]}"

log_success "Host system bootstrap completed successfully."
