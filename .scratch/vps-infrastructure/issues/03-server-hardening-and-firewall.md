# 03: Host Hardening and Configurable Firewall

**What to build:** Server security hardening script that configures UFW firewall with default-deny inbound rules, supports dynamic user ports via `config/allowed_ports.conf`, validates SSH active sessions before tightening rules, and sets up fail2ban.

**Blocked by:** 02: Platform Preflight Diagnostics and System Bootstrap

**Status:** ready-for-agent

## Acceptance Criteria

- [ ] `config/server.example.env` created with non-secret environment defaults (`SSH_PORT=22`, `UFW_ENABLED=true`, etc.).
- [ ] `config/allowed_ports.conf` created as a declarative, commented file for operators to specify additional inbound ports and protocols.
- [ ] `scripts/harden-server.sh` created to configure UFW: allows base ports (SSH, 80, 443, 8000) and dynamically parses `config/allowed_ports.conf`.
- [ ] `scripts/harden-server.sh` displays planned firewall changes, warns before enabling, and requires explicit user confirmation (bypassed only in `--dry-run` or with `--yes`).
- [ ] SSH verification checks included to prevent disabling password authentication or root login prematurely without confirmed key access.

## Quality & Test Criteria (TDD Seam)

- **Test File:** `tests/test_harden_and_ports.sh`.
- **Verified Behaviors:**
  - Config Parser Seam: Accurately parses valid port entries (`8080/tcp`, `53/udp`), trims whitespace, ignores comments (`# comment`) and empty lines, and rejects invalid port formats with a clear warning.
  - CLI Contracts: Running `scripts/harden-server.sh --help` prints usage and exits 0.
  - Dry-run & Boundary Mock: When executed with `--dry-run`, logs planned `ufw allow` commands matching base ports + custom ports from `allowed_ports.conf` without calling real `ufw`.
  - SSH Safety: Asserts that running hardening without confirmed SSH key access warns operator and avoids locking out remote sessions.
  - Regression: `make test` runs and passes.
