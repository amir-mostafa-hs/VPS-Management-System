#!/usr/bin/env bash
# ==============================================================================
# test_backup_system.sh — Test Two-Tier Backup Scripts and Systemd Automation
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/tests/test_runner.sh"

suite_header "Two-Tier Backup System and Systemd Automation"

# Test 1: Configuration template and units exist
assert_file_exists "${REPO_ROOT}/config/backup.example.env" "config/backup.example.env exists"
assert_file_exists "${REPO_ROOT}/systemd/vps-backup.service" "systemd/vps-backup.service exists"
assert_file_exists "${REPO_ROOT}/systemd/vps-backup.timer" "systemd/vps-backup.timer exists"

# Test 2: Systemd security directives
service_content=$(cat "${REPO_ROOT}/systemd/vps-backup.service")
assert_contains "ProtectSystem=strict" "${service_content}" "vps-backup.service has ProtectSystem=strict"
assert_contains "PrivateTmp=true" "${service_content}" "vps-backup.service has PrivateTmp=true"

timer_content=$(cat "${REPO_ROOT}/systemd/vps-backup.timer")
assert_contains "OnCalendar" "${timer_content}" "vps-backup.timer defines OnCalendar schedule"
assert_contains "RandomizedDelaySec" "${timer_content}" "vps-backup.timer defines RandomizedDelaySec"

# Test 3: Scripts exist and are executable
assert_file_exists "${REPO_ROOT}/scripts/backup-now.sh" "scripts/backup-now.sh exists"
assert_file_executable "${REPO_ROOT}/scripts/backup-now.sh" "scripts/backup-now.sh is executable"
assert_file_exists "${REPO_ROOT}/scripts/setup-backups.sh" "scripts/setup-backups.sh exists"
assert_file_executable "${REPO_ROOT}/scripts/setup-backups.sh" "scripts/setup-backups.sh is executable"

# Test 4: CLI --help contracts
backup_help=$(bash "${REPO_ROOT}/scripts/backup-now.sh" --help 2>&1 || true)
assert_contains "Usage:" "${backup_help}" "backup-now.sh --help displays usage"

setup_help=$(bash "${REPO_ROOT}/scripts/setup-backups.sh" --help 2>&1 || true)
assert_contains "Usage:" "${setup_help}" "setup-backups.sh --help displays usage"

# Test 5: backup-now.sh --dry-run validation
backup_dry_run=$(RCLONE_REMOTE="gdrive-crypt:vps-backups" bash "${REPO_ROOT}/scripts/backup-now.sh" --dry-run 2>&1)
assert_exit_code 0 $? "backup-now.sh --dry-run exits with 0"
assert_contains "Tier 1: Coolify core" "${backup_dry_run}" "backup-now plans Tier 1 Coolify backup"
assert_contains "Tier 2" "${backup_dry_run}" "backup-now plans Tier 2 application databases & volumes"
assert_contains "rclone" "${backup_dry_run}" "backup-now plans rclone upload and retention sync"

# Test 6: setup-backups.sh --dry-run validation
setup_dry_run=$(bash "${REPO_ROOT}/scripts/setup-backups.sh" --dry-run 2>&1)
assert_exit_code 0 $? "setup-backups.sh --dry-run exits with 0"
assert_contains "systemctl enable --now vps-backup.timer" "${setup_dry_run}" "setup-backups plans enabling systemd timer"

finish_suite
