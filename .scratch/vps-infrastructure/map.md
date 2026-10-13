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
- [Supported OS and Architectures](issues/02-preflight-and-system-bootstrap.md): Debian 12 (Bookworm), Debian 13 (Trixie), Ubuntu 22.04 LTS, Ubuntu 24.04 LTS on x86_64 and ARM64.
- [Deploy Trigger via Coolify Webhook](issues/05-ghcr-cicd-pipeline-and-deploy-webhook.md): GitHub Actions builds/pushes to GHCR and calls Coolify application Deploy Webhooks; production VPS does not build images.
- [Two-Tiered Backup with rclone crypt](issues/06-automated-encrypted-backup-system.md): Tier 1 (Coolify core & APP_KEY) and Tier 2 (Postgres/MySQL dumps & app volumes), encrypted locally and uploaded to Google Drive.
- [Automated Backup Scheduling](issues/06-automated-encrypted-backup-system.md): Automated daily execution via systemd timer (`vps-backup.timer`).
- [Configurable Firewall Ports](issues/03-server-hardening-and-firewall.md): Base ports (SSH, 80, 443, 8000) plus custom rules via `config/allowed_ports.conf`.
- [Traefik Reverse Proxy](issues/04-docker-and-coolify-installation.md): Rely natively on Coolify's built-in Traefik for Let's Encrypt SSL and domain routing.
- [Automated Testing & Quality Gates](issues/01-testing-and-repo-scaffolding.md): TDD regression harness (`make check`, `make test`) guarding every ticket.
- [Unified Makefile Command Interface](issues/01-testing-and-repo-scaffolding.md): Centralized, self-documenting commands (`make help`) for all testing and host operations.

## Not yet specified

<!-- In-scope fog that will crystallize as tickets are worked -->
- Specific per-application database restore drill scenarios beyond PostgreSQL and MySQL.
- Advanced monitoring alerting webhooks (e.g., Discord or Telegram bot notification script integration).

## Out of scope

- Live remote VPS execution, SSH provisioning, or live network changes during repository preparation.
- Supplying real cloud tokens, private keys, or actual Google Drive credentials.
- Deploying heavy monitoring stacks (Prometheus, Grafana, ELK) by default.
- Building application code inside the production VPS.
