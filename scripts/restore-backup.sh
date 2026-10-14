#!/usr/bin/env bash
# ==============================================================================
# restore-backup.sh — Interactive Operator-Led Disaster Recovery Restoration
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIG_FILE="${BACKUP_CONFIG_PATH:-${REPO_ROOT}/config/backup.env}"
ARCHIVE_NAME=""
TARGET_DIR="/tmp/vps-restore"
DRY_RUN=false
FORCE_YES=false

RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive-crypt:vps-backups}"

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

show_help() {
    cat << EOF
Usage: sudo $(basename "$0") --archive <archive-name> [OPTIONS]

Interactive, safe restore utility that downloads a specified backup archive
from remote storage and extracts its components into a local review staging directory
(/tmp/vps-restore) for operator inspection and selective database/state restoration.

Options:
  --archive <name>     Target backup archive filename (e.g. vps-backup-20261014_030000.tar.gz)
  --target-dir <path>  Local extraction staging directory (default: /tmp/vps-restore)
  --dry-run            Display planned restore commands without downloading or extracting
  -y, --yes            Bypass interactive confirmation
  -h, --help           Display this help message and exit

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --archive)
            ARCHIVE_NAME="${2:-}"
            shift 2 || true
            ;;
        --target-dir)
            TARGET_DIR="${2:-/tmp/vps-restore}"
            shift 2 || true
            ;;
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

# Safety Guardrail: Archive name is mandatory
if [[ -z "${ARCHIVE_NAME}" ]]; then
    log_err "Missing mandatory argument: --archive <archive-name>"
    log_info "Run 'make backup-verify' to see available remote backup archives."
    exit 1
fi

log_step "Backup Restoration Preparation: ${ARCHIVE_NAME}"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Planned restore operations for ${ARCHIVE_NAME}:"
    printf "  1. Download: rclone copy %s/%s %s/\n" "${RCLONE_REMOTE}" "${ARCHIVE_NAME}" "${TARGET_DIR}"
    printf "  2. Extract archive: tar -xzf %s/%s -C %s/\n" "${TARGET_DIR}" "${ARCHIVE_NAME}" "${TARGET_DIR}"
    printf "  3. Staged contents ready for operator review in %s/\n" "${TARGET_DIR}"
    printf "  4. Follow 'docs/backup-recovery/restore-and-disaster-recovery.md' for DB restoration.\n"
    log_success "[DRY-RUN] Restore plan validated successfully."
    exit 0
fi

# Mutating execution requires root
require_root
assert_cmd_exists "rclone" "Please install rclone using 'make bootstrap'."

log_warn "This operation will download and extract: ${ARCHIVE_NAME}"
log_warn "Target staging directory: ${TARGET_DIR}"

if ! confirm_action "Proceed with downloading and staging backup archive?" "Y"; then
    log_warn "Restoration aborted by operator."
    exit 0
fi

mkdir -p "${TARGET_DIR}"
chmod 0700 "${TARGET_DIR}"

log_info "Downloading ${ARCHIVE_NAME} from ${RCLONE_REMOTE}..."
rclone copy "${RCLONE_REMOTE}/${ARCHIVE_NAME}" "${TARGET_DIR}/" --stats-one-line

log_info "Extracting ${ARCHIVE_NAME}..."
tar -xzf "${TARGET_DIR}/${ARCHIVE_NAME}" -C "${TARGET_DIR}/"

log_success "Backup archive downloaded and extracted to: ${TARGET_DIR}"
printf "\n${C_BOLD}${C_GREEN}Extracted Artifacts:${C_RESET}\n"
find "${TARGET_DIR}" -maxdepth 2 | sed 's/^/  - /'

printf "\n${C_BOLD}Next Steps (Refer to docs/backup-recovery/restore-and-disaster-recovery.md):${C_RESET}\n"
printf "  1. Review extracted SQL dumps and Coolify core state.\n"
printf "  2. Verify APP_KEY: grep '^APP_KEY=' %s/*/coolify-core.tar.gz (or extracted files)\n" "${TARGET_DIR}"
printf "  3. Import databases into target containers via docker exec.\n"
printf "  4. Restart services and verify health checks.\n\n"

