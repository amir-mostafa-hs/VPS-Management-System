# 09: Complete Operator Runbooks & Repository Finalization

**What to build:** Complete operator runbooks (`docs/architecture.md`, `docs/prerequisites.md`, `docs/initial-server-setup.md`, `docs/security.md`, `docs/coolify.md`, `docs/troubleshooting.md`), finalize root `README.md` and `AGENTS.md`, and verify zero-secrets posture and full test suite passing.

**Blocked by:** 05: GitHub Actions CI/CD Template & GHCR Deploy Webhook, 07: Backup Verification and Explicit Cold-Start Restore Drill, 08: Lightweight Host & Container Health Monitoring

**Status:** resolved

## Acceptance Criteria

- [x] `docs/architecture.md` created: diagrams, trust boundaries, port mappings, secret lifecycle.
- [x] `docs/prerequisites.md` created: hardware, network, OS matrix (Debian 12/13, Ubuntu 22/24).
- [x] `docs/initial-server-setup.md` created: first-login runbook, SSH key verification, timezone.
- [x] `docs/security.md` created: SSH hardening, UFW firewall rules, fail2ban, secret storage rules.
- [x] `docs/coolify.md` created: installation walkthrough, Traefik setup, `APP_KEY` safety.
- [x] `docs/troubleshooting.md` created: diagnostics for SSH lockout, Docker container failures, rclone errors.
- [x] Root `README.md` updated with comprehensive overview, architecture, quickstart, and make targets.
- [x] `AGENTS.md` updated with coding guidelines while strictly preserving the `## Agent skills` section.

## Quality & Test Criteria (TDD Seam)

- **Test File:** `tests/test_docs_and_repo_integrity.sh`.
- **Verified Behaviors:**
  - Zero-Secrets Guarantee: Automated recursive scan over entire repository confirms zero private keys, active tokens, passwords, or live `.env` files.
  - Markdown Link & Path Integrity: Verifies all internal Markdown links point to existing files.
  - Comprehensive Test Gate:
    - `make check` executes syntax checks on 100% of shell scripts without errors.
    - `make test` executes all test files across tickets 01 through 08 and confirms 100% pass rate.
    - `make help` prints clear operator documentation for available targets.

## Resolution
Created comprehensive operations documentation suite in `docs/` (`architecture.md`, `prerequisites.md`, `initial-server-setup.md`, `security.md`, `coolify.md`, `troubleshooting.md`), updated root `README.md` with complete architecture and Makefile command tables, updated `AGENTS.md` preserving the `## Agent skills` block, and verified full repository integrity and link resolution with 37 tests in `tests/test_docs_and_repo_integrity.sh`. Both `make check` and `make test` pass 100% green.
