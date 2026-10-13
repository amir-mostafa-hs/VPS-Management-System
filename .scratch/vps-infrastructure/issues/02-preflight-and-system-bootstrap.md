# 02: Platform Preflight Diagnostics and System Bootstrap

**What to build:** A read-only diagnostic script that inspects and validates the host against supported platforms (Debian 12/13, Ubuntu 22.04/24.04 on x86_64/ARM64) and hardware requirements, and an idempotent bootstrap script that updates the OS and installs core dependencies safely.

**Blocked by:** 01: Testing harness, Makefile, and Repository Scaffolding

**Status:** ready-for-agent

## Acceptance Criteria

- [ ] `scripts/preflight.sh` created with read-only inspection of OS distro/version, kernel, CPU cores, RAM, free disk space, open ports, and virtualization.
- [ ] `scripts/preflight.sh` enforces supported matrix (Debian 12/13, Ubuntu 22.04/24.04, x86_64/ARM64) and fails with clear advice on unsupported platforms.
- [ ] `scripts/bootstrap.sh` created to update APT package index and install essential dependencies (`curl`, `git`, `ufw`, `fail2ban`, `jq`, `rclone`, `ca-certificates`) idempotently.
- [ ] `scripts/bootstrap.sh` supports `--dry-run` and `--help` flags.

## Quality & Test Criteria (TDD Seam)

- **Test File:** `tests/test_preflight_and_bootstrap.sh`.
- **Verified Behaviors:**
  - Mock OS Detection: Simulating `/etc/os-release` as Ubuntu 22.04, 24.04, Debian 12, and Debian 13 passes preflight with exit code 0.
  - Unsupported OS Detection: Simulating unsupported distributions (e.g., CentOS, Arch Linux, Ubuntu 18.04) causes `preflight.sh` to exit non-zero with a clear descriptive error.
  - CLI Contracts: Running `scripts/preflight.sh --help` and `scripts/bootstrap.sh --help` prints usage and exits 0.
  - Dry-run Safety: Running `scripts/bootstrap.sh --dry-run` outputs planned APT commands without executing package modifications.
  - Regression: `make test` runs and passes.
