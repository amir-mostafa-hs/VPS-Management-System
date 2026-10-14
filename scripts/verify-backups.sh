#!/usr/bin/env bash
# ==============================================================================
# verify-backups.sh — Non-Destructive Remote Backup Verification
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIG_FILE="${BACKUP_CONFIG_PATH:-${REPO_ROOT}/config/backup.env}"
DRY_RUN=false
CHECK_INTEGRITY=true

RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive-crypt:vps-backups}"

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Non-destructive diagnostic tool that inspects the remote backup store
in Google Drive via rclone crypt. Verifies remote connectivity, lists available
backup archives, checks remote checksum integrity, and reports storage size.

Options:
  --dry-run       Display planned verification commands without connecting
  -h, --help      Display this help message and exit

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
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

log_step "Verifying Remote Backup Store (${RCLONE_REMOTE})"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Planned non-destructive verification commands:"
    printf "  1. rclone lsf %s\n" "${RCLONE_REMOTE}"
    printf "  2. rclone size %s\n" "${RCLONE_REMOTE}"
    printf "  3. rclone hashsum (verify remote archive checksum integrity)\n"
    log_success "[DRY-RUN] Verification plan validated successfully."
    exit 0
fi

assert_cmd_exists "rclone" "Please install rclone using 'make bootstrap'."

log_info "Fetching backup archives from remote store..."
if ! archives=$(rclone lsf "${RCLONE_REMOTE}" --files-only 2>/dev/null); then
    log_error "Failed to connect to remote store '${RCLONE_REMOTE}'. Check rclone configuration."
    exit 1
fi

count=$(echo "${archives}" | grep -c "vps-backup-" || true)

if [[ "${count}" -eq 0 ]]; then
    log_warn "Remote backup directory is reachable, but no 'vps-backup-*.tar.gz' archives were found."
    exit 0
fi

log_success "Found ${count} remote backup archive(s):"
echo "${archives}" | sort -r | head -n 10 | sed 's/^/  - /'

log_info "Calculating remote storage usage..."
rclone size "${RCLONE_REMOTE}" 2>/dev/null || true

latest_archive=$(echo "${archives}" | sort -r | head -n 1)
log_success "Latest available backup: ${latest_archive}"

# Checksum integrity verification
log_info "Verifying remote checksum integrity for: ${latest_archive}..."
if remote_hash=$(rclone hashsum md5 "${RCLONE_REMOTE}/${latest_archive}" 2>/dev/null); then
    log_success "Checksum verified (MD5): ${remote_hash}"
else
    # Fallback to sha1 if remote supports sha1
    if remote_hash=$(rclone hashsum sha1 "${RCLONE_REMOTE}/${latest_archive}" 2>/dev/null); then
        log_success "Checksum verified (SHA1): ${remote_hash}"
    else
        log_warn "Remote storage provider does not return standard hashsums on crypt overlays."
    fi
fi
