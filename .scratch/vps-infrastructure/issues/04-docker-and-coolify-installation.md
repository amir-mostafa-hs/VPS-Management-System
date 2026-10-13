# 04: Docker Engine and Coolify Setup Automation

**What to build:** Safe, official installation scripts for Docker Engine CE (using official Docker APT repository and GPG signing keys) and Coolify v4 PaaS (with official URL inspection, prerequisites verification, and `APP_KEY` preservation instructions).

**Blocked by:** 03: Host Hardening and Configurable Firewall

**Status:** ready-for-agent

## Acceptance Criteria

- [ ] `scripts/install-docker.sh` created to set up the official Docker repository for Debian and Ubuntu, verify existing installations, configure log rotation limits for Docker daemon, and support `--dry-run`.
- [ ] `scripts/install-coolify.sh` created to inspect official Coolify v4 installer, verify hardware/port prerequisites, warn operator about `APP_KEY` criticality, and prompt for confirmation before proceeding.
- [ ] Scripts do not execute blind `curl | sh` without displaying source and requiring operator confirmation.

## Quality & Test Criteria (TDD Seam)

- **Test File:** `tests/test_docker_and_coolify_install.sh`.
- **Verified Behaviors:**
  - CLI Contracts: Running `scripts/install-docker.sh --help` and `scripts/install-coolify.sh --help` prints usage and exits 0.
  - Safe Dry-run: Running with `--dry-run` outputs the planned APT repository setup steps, GPG key paths, and Coolify installation commands without executing system changes.
  - Fail-closed Prerequisite Check: `install-coolify.sh` verifies minimum RAM and ports availability; fails closed when simulated memory is < 1GB or critical ports are in conflict.
  - Log Rotation Config: Verifies Docker `/etc/docker/daemon.json` template generation includes safe log rotation (`max-size: 10m`, `max-file: 3`).
  - Regression: `make test` runs and passes.
