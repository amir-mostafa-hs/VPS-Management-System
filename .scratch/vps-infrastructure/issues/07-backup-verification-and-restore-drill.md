# 07: Backup Verification and Explicit Cold-Start Restore Drill

**What to build:** Tools and documented runbooks for non-destructive remote backup verification (`scripts/verify-backups.sh`), interactive operator-led restoration (`scripts/restore-backup.sh`), and a cold-start disaster-recovery drill runbook.

**Blocked by:** 06: Two-Tier Automated Backup System with rclone crypt

**Status:** ready-for-agent

## Acceptance Criteria

- [ ] `scripts/verify-backups.sh` created to list remote backups in Google Drive, verify archive size/presence, and check integrity without making local or remote modifications.
- [ ] `scripts/restore-backup.sh` created to provide an interactive restore utility that:
  - Fetches and lists available remote backups.
  - Requires explicit operator confirmation and target path confirmation before extracting anything.
  - Never automatically overwrites existing live databases without separate explicit flags.
  - Supports `--dry-run` and `--help`.
- [ ] `docs/restore-and-disaster-recovery.md` created with step-by-step clean-VPS recovery drill:
  - Phase 1: Provisioning clean OS and basic packages.
  - Phase 2: Restoring Coolify state and `APP_KEY`.
  - Phase 3: Restoring application database dumps and Docker volumes.
  - Phase 4: Starting containers and verifying health checks.

## Quality & Test Criteria (TDD Seam)

- **Test File:** `tests/test_restore_and_verify.sh`.
- **Verified Behaviors:**
  - CLI Contracts: Running `scripts/verify-backups.sh --help` and `scripts/restore-backup.sh --help` prints usage and exits 0.
  - Verification Non-destructiveness: Confirms `verify-backups.sh` only issues read/list commands and creates no local or remote artifacts.
  - Restore Guardrail Seam: Running `restore-backup.sh` without target arguments or without explicit confirmation (`--yes` or prompt) refuses execution and exits with an error.
  - Restore Dry-run: When run with `--dry-run`, logs planned decryption, tar extraction, and DB restore commands without modifying local disk.
  - Regression: `make test` runs and passes.
