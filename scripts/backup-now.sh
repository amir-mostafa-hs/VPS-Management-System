#!/usr/bin/env bash
# ==============================================================================
# backup-now.sh — Immediate Two-Tier Encrypted Backup Execution
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"

CONFIG_FILE="${BACKUP_CONFIG_PATH:-${REPO_ROOT}/config/backup.env}"
DRY_RUN=false
FORCE_YES=false

# Default settings (can be overridden by backup.env)
RCLONE_REMOTE="${RCLONE_REMOTE:-gdrive-crypt:vps-backups}"
BACKUP_STAGING_DIR="${BACKUP_STAGING_DIR:-/var/backups/vps}"
LOCAL_RETENTION_DAYS="${LOCAL_RETENTION_DAYS:-7}"
REMOTE_RETENTION_DAYS="${REMOTE_RETENTION_DAYS:-30}"
BACKUP_COOLIFY_ENABLED="${BACKUP_COOLIFY_ENABLED:-true}"
COOLIFY_DATA_DIR="${COOLIFY_DATA_DIR:-/data/coolify}"
POSTGRES_CONTAINERS="${POSTGRES_CONTAINERS:-coolify-db}"
MYSQL_CONTAINERS="${MYSQL_CONTAINERS:-}"
APPLICATION_DATA_PATHS="${APPLICATION_DATA_PATHS:-}"

if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

show_help() {
    cat << EOF
Usage: sudo $(basename "$0") [OPTIONS]

Executes an immediate two-tier backup:
  Tier 1: Coolify core state, configuration, and internal DB
  Tier 2: Application databases (PostgreSQL/MySQL native dumps) and Docker volumes
Encrypts archives and uploads them to the remote Google Drive destination via rclone crypt.

Options:
  --dry-run       Display planned backup staging, dumping, and upload steps without executing
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

TIMESTAMP="$(date +"%Y%m%d_%H%M%S")"
ARCHIVE_NAME="vps-backup-${TIMESTAMP}.tar.gz"

log_step "VPS Two-Tier Automated Backup (${TIMESTAMP})"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Planned backup operations:"
    printf "  1. Stage directory: %s/%s\n" "${BACKUP_STAGING_DIR}" "${TIMESTAMP}"
    if [[ "${BACKUP_COOLIFY_ENABLED}" == "true" ]]; then
        printf "  2. Tier 1: Coolify core backup of %s\n" "${COOLIFY_DATA_DIR}"
    fi
    printf "  3. Tier 2: Application databases & volumes:\n"
    if [[ -n "${POSTGRES_CONTAINERS}" ]]; then
        printf "     - Native pg_dump for PostgreSQL containers: %s\n" "${POSTGRES_CONTAINERS}"
    fi
    if [[ -n "${MYSQL_CONTAINERS}" ]]; then
        printf "     - Native mysqldump for MySQL containers: %s\n" "${MYSQL_CONTAINERS}"
    fi
    if [[ -n "${APPLICATION_DATA_PATHS}" ]]; then
        printf "     - Tar archive for persistent data paths: %s\n" "${APPLICATION_DATA_PATHS}"
    fi
    printf "  4. Compress all staged data into: %s/%s\n" "${BACKUP_STAGING_DIR}" "${ARCHIVE_NAME}"
    printf "  5. Execute rclone encrypted upload: rclone copy %s/%s %s\n" \
        "${BACKUP_STAGING_DIR}" "${ARCHIVE_NAME}" "${RCLONE_REMOTE}"
    printf "  6. Enforce local retention: delete archives in %s older than %s days\n" \
        "${BACKUP_STAGING_DIR}" "${LOCAL_RETENTION_DAYS}"
    printf "  7. Enforce remote retention: rclone delete --min-age %sd %s\n" \
        "${REMOTE_RETENTION_DAYS}" "${RCLONE_REMOTE}"
    log_success "[DRY-RUN] Completed without modifying system."
    exit 0
fi

# Mutating execution requires root
require_root

assert_cmd_exists "rclone" "Please install rclone using 'make bootstrap'."
assert_cmd_exists "tar" "tar utility is required."
assert_cmd_exists "gzip" "gzip utility is required."

STAGE_PATH="${BACKUP_STAGING_DIR}/${TIMESTAMP}"
mkdir -p "${STAGE_PATH}"
chmod 0700 "${BACKUP_STAGING_DIR}" "${STAGE_PATH}"

log_info "Staging backup in: ${STAGE_PATH}"

# Tier 1: Coolify core backup
if [[ "${BACKUP_COOLIFY_ENABLED}" == "true" && -d "${COOLIFY_DATA_DIR}" ]]; then
    log_info "Creating Tier 1 Coolify core archive..."
    tar -czf "${STAGE_PATH}/coolify-core.tar.gz" -C "$(dirname "${COOLIFY_DATA_DIR}")" "$(basename "${COOLIFY_DATA_DIR}")" 2>/dev/null || {
        log_warn "Coolify data directory partially read or locked. Check permissions."
    }
fi

# Tier 2: Database native dumps
if command -v docker >/dev/null 2>&1; then
    # PostgreSQL dumps
    if [[ -n "${POSTGRES_CONTAINERS}" ]]; then
        for container in ${POSTGRES_CONTAINERS}; do
            if docker ps --format '{{.Names}}' | grep -Eq "^${container}$"; then
                log_info "Dumping PostgreSQL database from container: ${container}..."
                docker exec "${container}" pg_dumpall -U postgres > "${STAGE_PATH}/postgres-${container}.sql" 2>/dev/null || {
                    log_warn "pg_dumpall failed for ${container}. Trying pg_dump on default db..."
                    docker exec "${container}" pg_dump -U postgres postgres > "${STAGE_PATH}/postgres-${container}.sql" 2>/dev/null || true
                }
            fi
        done
    fi

    # MySQL / MariaDB dumps
    if [[ -n "${MYSQL_CONTAINERS}" ]]; then
        for container in ${MYSQL_CONTAINERS}; do
            if docker ps --format '{{.Names}}' | grep -Eq "^${container}$"; then
                log_info "Dumping MySQL database from container: ${container}..."
                docker exec "${container}" mysqldump --all-databases -u root > "${STAGE_PATH}/mysql-${container}.sql" 2>/dev/null || true
            fi
        done
    fi
fi

# Tier 2: Persistent paths
if [[ -n "${APPLICATION_DATA_PATHS}" ]]; then
    for path in ${APPLICATION_DATA_PATHS}; do
        if [[ -d "${path}" ]]; then
            log_info "Archiving persistent application path: ${path}..."
            base_p=$(basename "${path}")
            tar -czf "${STAGE_PATH}/app-${base_p}.tar.gz" -C "$(dirname "${path}")" "${base_p}" 2>/dev/null || true
        fi
    done
fi

# Package master archive
FINAL_ARCHIVE="${BACKUP_STAGING_DIR}/${ARCHIVE_NAME}"
log_info "Compressing master backup archive: ${FINAL_ARCHIVE}..."
tar -czf "${FINAL_ARCHIVE}" -C "${BACKUP_STAGING_DIR}" "${TIMESTAMP}"

# Upload to encrypted remote
log_info "Uploading to remote ${RCLONE_REMOTE}..."
rclone copy "${FINAL_ARCHIVE}" "${RCLONE_REMOTE}" --stats-one-line --stats 5s

# Verify upload succeeded before local cleanup
if rclone ls "${RCLONE_REMOTE}/${ARCHIVE_NAME}" >/dev/null 2>&1; then
    log_success "Remote upload verified in Google Drive."
    # Clean up stage directory
    rm -rf "${STAGE_PATH}"
else
    log_err "Could not verify uploaded archive in remote. Keeping local stage copy!"
    exit 1
fi

# Enforce local retention
log_info "Enforcing local retention (${LOCAL_RETENTION_DAYS} days)..."
find "${BACKUP_STAGING_DIR}" -maxdepth 1 -name "vps-backup-*.tar.gz" -mtime +"${LOCAL_RETENTION_DAYS}" -delete 2>/dev/null || true

# Enforce remote retention
log_info "Enforcing remote retention (${REMOTE_RETENTION_DAYS} days)..."
rclone delete --min-age "${REMOTE_RETENTION_DAYS}d" "${RCLONE_REMOTE}" 2>/dev/null || true

log_success "Backup ${ARCHIVE_NAME} completed and synced successfully."

