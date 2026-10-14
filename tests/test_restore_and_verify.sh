#!/usr/bin/env bash
# ==============================================================================
# test_restore_and_verify.sh — Test Backup Verification and Restore Tooling
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/tests/test_runner.sh"

suite_header "Backup Verification and Cold-Start Disaster Recovery"

# Test 1: Scripts and docs exist
assert_file_exists "${REPO_ROOT}/scripts/verify-backups.sh" "scripts/verify-backups.sh exists"
assert_file_executable "${REPO_ROOT}/scripts/verify-backups.sh" "scripts/verify-backups.sh is executable"
assert_file_exists "${REPO_ROOT}/scripts/restore-backup.sh" "scripts/restore-backup.sh exists"
assert_file_executable "${REPO_ROOT}/scripts/restore-backup.sh" "scripts/restore-backup.sh is executable"
assert_file_exists "${REPO_ROOT}/docs/backup-recovery/restore-and-disaster-recovery.md" "docs/backup-recovery/restore-and-disaster-recovery.md exists"

# Test 2: CLI --help contracts
verify_help=$(bash "${REPO_ROOT}/scripts/verify-backups.sh" --help 2>&1 || true)
assert_contains "Usage:" "${verify_help}" "verify-backups.sh --help displays usage"

restore_help=$(bash "${REPO_ROOT}/scripts/restore-backup.sh" --help 2>&1 || true)
assert_contains "Usage:" "${restore_help}" "restore-backup.sh --help displays usage"

# Test 3: verify-backups.sh dry-run non-destructiveness
verify_dry_run=$(RCLONE_REMOTE="gdrive-crypt:vps-backups" bash "${REPO_ROOT}/scripts/verify-backups.sh" --dry-run 2>&1)
assert_exit_code 0 $? "verify-backups.sh --dry-run exits with 0"
assert_contains "rclone lsf" "${verify_dry_run}" "verify-backups plans non-destructive rclone lsf"

# Test 4: restore-backup.sh safety guardrail (fails without archive specified)
if bash "${REPO_ROOT}/scripts/restore-backup.sh" >/dev/null 2>&1; then
    assert_eq 1 0 "restore-backup refuses execution without archive specified"
else
    assert_eq 1 1 "restore-backup refuses execution without archive specified"
fi

# Test 5: restore-backup.sh dry-run with archive specified
restore_dry_run=$(bash "${REPO_ROOT}/scripts/restore-backup.sh" --archive "vps-backup-20261014_030000.tar.gz" --dry-run 2>&1)
assert_exit_code 0 $? "restore-backup.sh --dry-run exits with 0"
assert_contains "vps-backup-20261014_030000.tar.gz" "${restore_dry_run}" "restore-backup targets requested archive"
assert_contains "Extract" "${restore_dry_run}" "restore-backup plans extraction"

# Test 6: Disaster recovery runbook verification
dr_doc=$(cat "${REPO_ROOT}/docs/backup-recovery/restore-and-disaster-recovery.md")
assert_contains "Clean VPS" "${dr_doc}" "Documentation covers clean VPS recovery drill"
assert_contains "APP_KEY" "${dr_doc}" "Documentation specifies APP_KEY restoration"
assert_contains "pg_restore" "${dr_doc}" "Documentation explains database restoration"

finish_suite

