# Changelog

All notable changes to the `vps-infrastructure` repository will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> [!IMPORTANT]
> **Agent & Developer Rule:**
> Every completed decision, architectural modification, bug fix, or feature added to this repository MUST append a concise entry to this file under `[Unreleased]` or the corresponding release version header.

---

## [Unreleased]

### Added
- Comprehensive Persian operator guide (`docs/fa/README.md`) covering architecture, step-by-step VPS setup, automated builds, and disaster recovery.
- "In Plain English" callouts and jargon glossaries across all English documentation.
- Mandatory `CHANGELOG.md` logging rule added to `AGENTS.md` developer guidelines.

### Changed
- Reorganized `docs/` hierarchy into structured subdirectories:
  - `docs/getting-started/`: `prerequisites.md`, `initial-server-setup.md`
  - `docs/architecture/`: `architecture.md`, `security.md`
  - `docs/platform/`: `coolify.md`, `github-actions-ghcr.md`
  - `docs/backup-recovery/`: `backups.md`, `google-drive.md`, `restore-and-disaster-recovery.md`
  - `docs/operations/`: `monitoring.md`, `troubleshooting.md`
  - `docs/specs/`: `PROJECT_BRIEF.md`, `ANTIGRAVITY_PROMPT.md`
- Updated all relative cross-links in documentation, scripts, tests, and root `README.md`.

---

## [1.0.0] - 2026-10-14

### Added
- **Repository Scaffolding & Unified CLI:**
  - Standard `.gitignore` enforcing zero secrets.
  - Common shell library `scripts/common.sh` with colorized logging and `--dry-run` seam.
  - Root `Makefile` with self-documenting targets (`make help`, `make test`, `make preflight`, etc.).
  - Offline Pure-Bash TDD test runner `tests/test_runner.sh`.
- **Preflight & Bootstrapping:**
  - `scripts/preflight.sh`: Diagnostic checking Debian 12/13, Ubuntu 22.04/24.04 on x86_64/ARM64.
  - `scripts/bootstrap.sh`: Non-interactive APT dependencies setup (`curl`, `ufw`, `fail2ban`, `rclone`, `jq`).
- **Host Hardening & Firewall:**
  - `scripts/harden-server.sh`: Enforces SSH key-only authentication and UFW default-deny incoming.
  - `config/allowed_ports.conf`: Configurable custom port registry loaded dynamically by UFW.
- **Docker CE & Coolify PaaS:**
  - `scripts/install-docker.sh`: Official Docker CE repository setup and container log rotation (50MB/3 files).
  - `scripts/install-coolify.sh`: Safe installation of Coolify v4 with memory validation and `APP_KEY` safety warnings.
- **Offloaded CI/CD Pipeline:**
  - `.github/workflows/reusable-docker-build.yml`: Reusable GitHub Actions workflow for building on `ubuntu-latest`, pushing to GHCR, and triggering Coolify webhooks without VPS build compute.
- **Two-Tier Automated Encrypted Backup System:**
  - `scripts/backup-now.sh`: Creates Tier 1 (Coolify core & `APP_KEY`) and Tier 2 (DB dumps & volumes), encrypts locally with `rclone crypt` (AES-256), and uploads to Google Drive.
  - `systemd/vps-backup.service` and `systemd/vps-backup.timer`: Automated daily backup scheduling.
  - `scripts/verify-backups.sh`: Non-destructive remote backup inspection.
  - `scripts/restore-backup.sh`: Cold-start archive extraction and restoration wizard.
- **Lightweight Monitoring:**
  - `scripts/health-check.sh`: Sub-second resource inspection (CPU, RAM, swap, disk, inode, unhealthy containers) supporting visual and parseable JSON output.
- **Testing & Quality Assurance:**
  - Complete TDD test suite covering syntax, secrets scanning, CLI contracts, and doc integrity (210 passing tests).

### Security
- Default deny incoming firewall posture.
- SSH password authentication disabled.
- Client-side AES-256 encryption (`rclone crypt`) before uploading backups off-site.
- Automated zero-secrets scanning gate in `make check`.
