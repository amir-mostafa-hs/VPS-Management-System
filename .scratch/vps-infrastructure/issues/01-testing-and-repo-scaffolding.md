# 01: Testing harness, Makefile, and Repository Scaffolding

**What to build:** A complete offline testing and linting harness (`Makefile`, test runner in `tests/`), a shared helper library for bash scripts (`scripts/common.sh`), and strict secret exclusion via `.gitignore`. This establishes the primary testing seam for all future automation scripts without requiring a live VPS.

**Blocked by:** None (can start immediately)

**Status:** resolved

## Acceptance Criteria

- [x] `.gitignore` configured to exclude `.env`, `*.key`, `*.pem`, `*.tar.gz`, `*.bak`, `rclone.conf`, local temporary backup directories, and IDE state.
- [x] `scripts/common.sh` created with strict bash mode (`set -euo pipefail`), colorized logging functions (`log_info`, `log_warn`, `log_err`), privilege checks (`require_root`), and error trapping.
- [x] `tests/test_runner.sh` created as an automated pure-Bash test runner with assertions (`assert_eq`, `assert_exit_code`, `assert_output_contains`) and test summary report.
- [x] `tests/test_scripts_syntax.sh` created to validate all `.sh` files with `bash -n` and verify executable permissions.
- [x] `tests/test_secrets_scan.sh` created to scan the repository for accidental committed secrets, tokens, and private keys.
- [x] `Makefile` created providing a complete, self-documenting unified operator interface with `make help`:
  - **Quality & Verification Targets:**
    - `make check`: Syntax checks (`bash -n`) and secret audits.
    - `make lint`: ShellCheck linting and formatting.
    - `make test`: Automated test suite execution across all components.
    - `make clean`: Clean temporary test artifacts and local caches.
  - **Operational & Provisioning Targets (supporting `ARGS`):**
    - `make preflight`: Run read-only preflight diagnostics (`scripts/preflight.sh`).
    - `make bootstrap`: Run base package & APT bootstrapping (`scripts/bootstrap.sh`).
    - `make harden`: Run firewall and SSH hardening (`scripts/harden-server.sh`).
    - `make install-docker`: Install Docker CE (`scripts/install-docker.sh`).
    - `make install-coolify`: Install Coolify v4 PaaS safely (`scripts/install-coolify.sh`).
    - `make backup-setup`: Setup backup directories and systemd timer (`scripts/setup-backups.sh`).
    - `make backup-now`: Execute immediate two-tier backup (`scripts/backup-now.sh`).
    - `make backup-verify`: Non-destructive remote backup check (`scripts/verify-backups.sh`).
    - `make backup-restore`: Interactive backup restore wizard (`scripts/restore-backup.sh`).
    - `make health`: Host resource and container health inspection (`scripts/health-check.sh`).

## Quality & Test Criteria (TDD Seam)

- **Test Files:** `tests/test_runner.sh`, `tests/test_scripts_syntax.sh`, `tests/test_secrets_scan.sh`, `tests/test_makefile.sh`.
- **Verified Behaviors:**
  - `bash -n` passes on all shell scripts.
  - Test runner correctly reports passed and failed assertions.
  - Secret scanner flags known dummy credential patterns and passes on clean repo.
  - `make help` prints formatted, readable descriptions for 100% of defined targets.
  - `make check`, `make lint`, and `make test` return exit code 0.

## Resolution

All acceptance criteria completed. The TDD testing framework, secret scanner, syntax validator, `common.sh` helper library, `.gitignore`, and `Makefile` are fully implemented and verified with 15/15 tests passing.
