# Specification: VPS Infrastructure Repository Preparation

## Problem Statement

Deploying and operating modern web applications on a self-hosted Virtual Private Server (VPS) is frequently plagued by fragile manual configuration, security oversights (such as open ports, weak SSH access, or committed secrets), CPU/RAM exhaustion during local image builds, and lack of verified automated backups. Operators need a safe, repeatable, and transparent entry point to bootstrap a single Linux VPS with Coolify, automated GitHub Actions CI/CD with GHCR, encrypted Google Drive backups, and disaster recovery procedures—without executing untested or destructive remote commands blindly.

Crucially, without automated test harnesses and rigorous regression testing, infrastructure scripts easily suffer regressions when edited. Future changes can break configuration parsing, accidentally bypass safety prompts, or invalidate disaster-recovery procedures.

## Solution

A fully prepared, modular, and locally validated Git repository (`vps-infrastructure`) that provides:
1. Operator-led, idempotent Bash automation scripts supporting `--dry-run`, `--help`, and strict OS/privilege validations.
2. Official setup procedures for Debian 12/13 and Ubuntu 22.04/24.04 (x86_64 and ARM64).
3. Hardened security defaults (UFW firewall with configurable `allowed_ports.conf`, SSH key verification, fail2ban).
4. An offloaded build-and-deploy workflow where GitHub Actions builds Docker images on GitHub-hosted runners and pushes them to GHCR, triggering Coolify deployments via webhooks without overloading the VPS.
5. An automated two-tiered backup system (Coolify core state + application DBs and persistent volumes) scheduled via systemd timers, encrypted locally with `rclone crypt`, and synced to Google Drive.
6. A comprehensive suite of operator documentation, troubleshooting runbooks, disaster recovery drill instructions.
7. **An automated offline TDD test suite (`make test`, `make check`)**: Every ticket and automation script is guarded by automated contract tests, boundary mocks, syntax checks, and secret scans to ensure future edits never cause regressions.

## User Stories

1. As a system operator, I want to run a read-only preflight check on my target VPS, so that I can verify OS compatibility (Debian 12/13, Ubuntu 22/24), hardware specs, and network prerequisites before making any changes.
2. As a system operator, I want to execute server bootstrapping idempotently, so that standard base utilities, repository sources, and prerequisites are cleanly installed without duplicate packages or corrupted sources.
3. As a security-conscious administrator, I want to harden the server firewall with default-deny rules while maintaining custom port flexibility via `config/allowed_ports.conf`, so that only approved services (SSH, HTTP, HTTPS, Coolify, and explicitly configured ports) are exposed.
4. As a system operator, I want SSH access hardening to enforce key-based authentication only after verifying active SSH sessions, so that I never get accidentally locked out of my server.
5. As a platform operator, I want Docker Engine and Coolify installed via official, validated distribution channels, so that the host runs a stable and maintainable self-hosted PaaS.
6. As a platform operator, I want Coolify's critical encryption key (`APP_KEY`) clearly identified and secured outside the VPS, so that configuration and stored secrets remain recoverable if the host crashes.
7. As an application developer, I want a reusable GitHub Actions workflow that builds application Docker images on GitHub-hosted runners, so that the production VPS never suffers CPU or memory starvation from building code.
8. As an application developer, I want built images tagged with immutable commit SHAs and pushed to GHCR, so that deployments are fully traceable and reproducible.
9. As an operator, I want GitHub Actions to trigger Coolify's application deployment via a webhook URL, so that new versions deploy automatically upon CI completion without exposing root server credentials to GitHub.
10. As an operator, I want a documented manual deployment promotion checklist, so that I have a reliable fallback when automatic webhooks fail or when gradual rollouts are required.
11. As an operator, I want automated daily backups of Coolify's internal state and database, so that PaaS configuration and project definitions are consistently preserved.
12. As an operator, I want native database dump support for PostgreSQL (`pg_dump`) and MySQL/MariaDB (`mysqldump`), so that databases are backed up with ACID transactional consistency rather than raw file copying.
13. As an operator, I want application Docker volumes explicitly inventoried and archived, so that persistent uploaded media and assets are protected.
14. As a privacy-focused administrator, I want all backup archives encrypted locally with `rclone crypt` before upload, so that data stored in Google Drive remains confidential and inaccessible to third parties.
15. As an operator, I want automated systemd timers managing the backup cycle, so that backups execute reliably in the background without manual intervention.
16. As an operator, I want a non-destructive backup verification tool, so that I can verify remote backup availability and checksum integrity without overwriting local state.
17. As an operator, I want an interactive, operator-supervised restore utility, so that I can recover selected backups onto a clean VPS following a guided disaster-recovery drill.
18. As an operator, I want lightweight health-check scripts monitoring disk, memory, and container status, so that I can detect resource exhaustion before services fail.
19. As a developer maintaining this repository, I want a comprehensive automated test harness (`make test`) verifying script contracts, dry-run safety, and mock boundaries, so that future changes can never break existing functionality without failing tests.

## Implementation Decisions

### Architectural Seams and Core Boundary
- The codebase is structured as an operator toolkit and documentation repository. The production VPS does not execute Git-driven continuous synchronization; rather, the operator uses the repository to bootstrap and configure host-level services.
- The boundary between CI and Production is strictly GHCR: GitHub Actions builds artifacts; the VPS only pulls and runs them.
- All mutating scripts must implement strict flags: `--dry-run`, `--help`, root privilege enforcement, and explicit confirmation prompts when performing stateful modifications.

### Platform Support Matrix
- Explicitly verified distributions: Debian 12 (Bookworm), Debian 13 (Trixie), Ubuntu 22.04 LTS, Ubuntu 24.04 LTS.
- Architectures: x86_64 (amd64) and ARM64 (aarch64).
- Kernel and virtualization: Standard Linux kernels; systemd required as PID 1.

### Security and Network Architecture
- Default inbound UFW policy: Deny all incoming traffic.
- Static open ports: SSH (port 22 or `SSH_PORT`), HTTP (80), HTTPS (443), Coolify Dashboard (8000).
- Dynamic open ports: Defined in `config/allowed_ports.conf` (one port/protocol per line with comments) and parsed during firewall configuration.
- Reverse proxy: Managed natively by Coolify's bundled Traefik instance, handling Let's Encrypt certificates and container routing automatically.

### Backup and Disaster Recovery Architecture
- Staging directory: `/var/backups/vps/` (permissions `0700`, owned by root).
- Tier 1: Coolify core configuration, SQLite/PostgreSQL database, and environment files (`APP_KEY`).
- Tier 2: Database native dumps (PostgreSQL via `pg_dump`, MySQL via `mysqldump`) and targeted Docker named volumes/bind mounts.
- Off-site synchronization: `rclone sync` / `copy` using an encrypted remote (`rclone crypt`) pointing to Google Drive.
- Checksum integrity verification: Non-destructive verification tool (`scripts/verify-backups.sh`) verifies remote archive existence and cryptographic checksums (MD5/SHA1).
- Automation: Systemd service `vps-backup.service` triggered by `vps-backup.timer` with randomized daily execution.

### Zero-Secrets and Local Safety Posture
- No actual credentials, API tokens, encryption passwords, or `.env` files with secrets are committed.
- All configuration files in Git are sample templates (`.example.env`, `.conf` templates).
- Git ignore rules aggressively filter private keys, certificates, archives, and runtime credentials.

### Unified Makefile Command Interface
- The project provides a single, self-documenting operator command interface via `Makefile` with a formatted `make help` command.
- Quality commands: `make check`, `make lint`, `make test`, `make clean`.
- Host operation commands: `make preflight`, `make bootstrap`, `make harden`, `make install-docker`, `make install-coolify`, `make backup-setup`, `make backup-now`, `make backup-verify`, `make backup-restore`, `make health`.
- Operators do not need to hunt for individual script paths; every operational script has a direct make target supporting argument passing (e.g. `ARGS="--dry-run"`).

## Testing & Quality Assurance Decisions (TDD Seam)

Following the principles of `/tdd`, the project establishes rigorous testing seams to guarantee safety and prevent regressions:

### 1. Seams Under Test
- **Syntax & Linter Seam (`make check`):** Validates bash syntax across all scripts via `bash -n` and audits for zero committed secrets.
- **CLI Contract Seam (`make test`):** Executes every script with `--help` and `--dry-run`. Asserts:
  - Return code `0` on help and dry run.
  - Zero filesystem modifications or side effects during dry run.
  - Informative usage output on `--help`.
- **Safe Failure & Input Validation Seam:** Tests that scripts fail closed (exit non-zero) when given invalid parameters, missing mandatory configs, or executed on unsupported simulated operating systems.
- **Config Parser Seam:** Unit tests verify parsing of `config/allowed_ports.conf` against valid ports, comments, whitespace variations, and malformed inputs.
- **Boundary Mock Seam:** External system commands (`apt-get`, `ufw`, `docker`, `rclone`, `systemctl`) are mockable through temporary sandbox PATH injection, allowing end-to-end command sequence verification in tests without touching live host services.

### 2. Definition of Done per Ticket
A ticket is marked complete **only** when:
1. All acceptance criteria in the ticket are met.
2. An automated test script covering the ticket's functionality is added or updated in `tests/`.
3. `make check` and `make test` run green with 100% pass rate.
4. No secrets or credentials are introduced.

## Out of Scope

- Remote provisioning, SSH connection to a live server, or automated cloud infrastructure spin-up (Terraform/Pulumi).
- Providing real Google Drive OAuth credentials or creating live rclone configurations.
- Custom application build steps inside the production VPS.
- Deploying heavy monitoring stacks (Prometheus, Grafana, ELK) by default.
- Modifying DNS records or registering external domains.

## Further Notes

- The project uses the local markdown issue tracker in `.scratch/vps-infrastructure/`.
- All operational runbooks live in `docs/` and serve as operator-led reference manuals, accompanied by a comprehensive Persian guide in `docs/fa/README.md`.
