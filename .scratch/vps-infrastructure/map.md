# Wayfinder Map: VPS Infrastructure Repository Preparation

## Destination

A fully prepared, modular, and locally validated `vps-infrastructure` repository containing operator documentation, hardened configuration templates, idempotent shell automation scripts, systemd backup timers, and an offline test harness ready for operator deployment.

## Notes

- **Domain:** VPS provisioning, Linux hardening, Coolify PaaS, GitHub Actions CI/CD with GHCR, rclone crypt off-site backups to Google Drive.
- **Reference Specification:** `.scratch/vps-infrastructure/spec.md`
- **Skills to consult:** `tdd`, `code-review`, `codebase-design`.
- **Standing preferences:**
  - Zero secrets in repository.
  - Strict bash scripts (`set -euo pipefail`), supporting `--dry-run` and `--help`.
  - Non-destructive execution; all mutating actions require explicit operator confirmation.
  - **TDD & Quality Gate:** No ticket is marked resolved without corresponding automated tests in `tests/` and a passing `make test` run.
  - **Testing Seams:** CLI Contract Seam (`--help`, `--dry-run`), Input Validation Seam (fail-closed behavior), Config Parser Seam, and Boundary Mock Seam (mock binaries in sandbox PATH).

## Decisions so far

- [01: Testing harness, Makefile, and Repository Scaffolding](issues/01-testing-and-repo-scaffolding.md): Implemented pure-Bash test runner, syntax validator, secret scanner, common.sh, .gitignore, and comprehensive Makefile.
- [02: Preflight diagnostics and System Bootstrap](issues/02-preflight-and-system-bootstrap.md): Implemented OS detector (Debian 12/13, Ubuntu 22/24 on x86_64/ARM64) and system package bootstrap.
- [03: Server Hardening and Configurable Firewall](issues/03-server-hardening-and-firewall.md): SSH hardening, default-deny UFW baseline, and dynamic custom port parsing via `config/allowed_ports.conf`.
- [04: Docker Engine and Coolify Setup Automation](issues/04-docker-and-coolify-installation.md): Official Docker CE repo setup with daemon log rotation, plus Coolify v4 installer with APP_KEY safety warnings.
- [05: GitHub Actions CI/CD Template & GHCR Deploy Webhook](issues/05-ghcr-cicd-pipeline-and-deploy-webhook.md): GitHub Actions builds/pushes to GHCR and calls Coolify application Deploy Webhooks; production VPS does not build images.
- [06: Two-Tier Automated Encrypted Backup System](issues/06-automated-encrypted-backup-system.md): Tier 1 (Coolify core & APP_KEY) and Tier 2 (Postgres/MySQL dumps & app volumes), encrypted locally via `rclone crypt` and uploaded to Google Drive with systemd timers.
- [07: Backup Verification and Explicit Cold-Start Restore Drill](issues/07-backup-verification-and-restore-drills.md): Remote listing/verification tool (`verify-backups.sh`) and cold-start interactive restore wizard (`restore-backup.sh`).
- [08: Lightweight Host & Container Health Monitoring](issues/08-lightweight-monitoring-and-health-checks.md): Metric evaluation (CPU, RAM, swap, disk, inode, unhealthy containers) with JSON output mode (`health-check.sh`).
- [09: Complete Operator Runbooks & Repository Finalization](issues/09-comprehensive-operations-documentation.md): Comprehensive operator documentation suite in `docs/`, root `README.md`, preserved `AGENTS.md` guidelines, and doc integrity tests.


## Not yet specified

<!-- In-scope fog that will crystallize as tickets are worked -->
- Specific per-application database restore drill scenarios beyond PostgreSQL and MySQL.
- Advanced monitoring alerting webhooks (e.g., Discord or Telegram bot notification script integration).

## Out of scope

- Live remote VPS execution, SSH provisioning, or live network changes during repository preparation.
- Supplying real cloud tokens, private keys, or actual Google Drive credentials.
- Deploying heavy monitoring stacks (Prometheus, Grafana, ELK) by default.
- Building application code inside the production VPS.
