# 06: Two-Tier Automated Backup System with rclone crypt

**What to build:** An automated, two-tiered backup system that archives Tier 1 (Coolify core configuration, database, and `APP_KEY`) and Tier 2 (application PostgreSQL/MySQL databases via native dumps, plus Docker volumes), encrypts archives with `rclone crypt`, uploads them to Google Drive, enforces retention, and is automated via systemd service and timer units.

**Blocked by:** 04: Docker Engine and Coolify Setup Automation

**Status:** resolved

## Acceptance Criteria

- [x] `config/backup.example.env` created containing placeholders for backup retention days, rclone remote name, target paths, and database credentials pointers (no real secrets).
- [x] `scripts/backup-now.sh` created implementing:
  - Timestamped backup staging in `/var/backups/vps/` (permissions `0700`).
  - Tier 1: Archive `/data/coolify` and Coolify DB dump.
  - Tier 2: Automated native database dumps (`pg_dump`, `mysqldump`) for specified containers and tarball of targeted Docker volumes.
  - Encryption and upload to Google Drive via `rclone copy/sync` using an `rclone crypt` destination.
  - Local and remote retention enforcement (deleting older archives according to retention policy only after verified upload).
  - Strict `--dry-run` and `--help` flags.
- [x] `systemd/vps-backup.service` and `systemd/vps-backup.timer` created to schedule automated daily backup execution with randomized delay.
- [x] `scripts/setup-backups.sh` created to verify rclone configuration, create staging paths, and enable the systemd timer.
- [x] `docs/google-drive.md` created detailing interactive `rclone config` setup for Google Drive and `rclone crypt` password safety.
- [x] `docs/backups.md` and `backup/README.md` created with backup policies, schedules, and consistency guarantees.

## Quality & Test Criteria (TDD Seam)

- **Test File:** `tests/test_backup_system.sh`.
- **Verified Behaviors:**
  - CLI Contracts: Running `scripts/backup-now.sh --help` and `scripts/setup-backups.sh --help` prints usage and exits 0.
  - Two-Tier Dry-run Validation: When executed with `--dry-run`, logs planned execution for Tier 1 (Coolify `/data/coolify` tar + DB dump), Tier 2 (`pg_dump`/`mysqldump` commands, volume tarballs), and `rclone` encryption/sync commands without touching disk.
  - Environment Validation: Fails closed when required environment variables or target remote settings are missing.
  - Systemd Unit Syntax: Verifies `systemd/vps-backup.service` and `vps-backup.timer` contain valid unit structures, execution triggers, and security directives (`ProtectSystem=strict`).
  - Regression: `make test` runs and passes.

## Resolution

All acceptance criteria completed. Two-tier backup scripts, systemd service/timer, rclone crypt guides, and configuration templates implemented with full TDD coverage in `tests/test_backup_system.sh` with 19/19 tests passing.
