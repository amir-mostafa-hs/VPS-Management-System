# VPS Infrastructure (`vps-infrastructure`)

A production-ready, security-hardened infrastructure toolkit for managing a single Linux Virtual Private Server (Debian 12/13, Ubuntu 22.04/24.04 LTS) running **Coolify PaaS**.

> 📖 **[🇮🇷 برای مطالعه راهنمای جامع فارسی اینجا کلیک کنید (Persian Documentation)](docs/fa/README.md)** | **[Changelog](CHANGELOG.md)**

This repository offloads Docker image builds completely to **GitHub Actions** and **GitHub Packages (GHCR)**, keeps host memory and CPU consumption low, enforces host-level hardening (UFW default-deny, SSH public key auth, fail2ban), and provides automated two-tier client-side encrypted backups (`rclone crypt`) to **Google Drive**.

---

## Architecture Overview

```
 [Developer] --- git push ---> [GitHub Actions Runner]
                                     |
                                     | 1. Build & Push Image
                                     v
                        [GitHub Container Registry (GHCR)]
                                     |
  [GitHub Actions Runner]            |
        |                            |
        | 2. Deploy Webhook          | 3. docker pull
        v                            v
 +=======================================================+
 |                      Linux VPS                        |
 |  +-------------------------------------------------+  |
 |  | Host OS (Debian / Ubuntu LTS)                   |  |
 |  | - UFW Firewall (80, 443, 8000, SSH)             |  |
 |  | - Fail2ban (SSH Brute Force Defense)            |  |
 |  | - Systemd Timer (Encrypted Backups)             |  |
 |  +-------------------------------------------------+  |
 |  | Docker Engine CE                                |  |
 |  | - Traefik Reverse Proxy (Automatic SSL / ACME)  |  |
 |  | - Coolify v4 PaaS Dashboard (Port 8000)         |  |
 |  | - Application Containers & Isolated DBs         |  |
 |  +-------------------------------------------------+  |
 +=======================================================+
                             |
                      rclone crypt sync (AES-256)
                             v
               [Google Drive Remote Storage]
```

---

## Quickstart Provisioning Sequence

To provision a fresh Linux VPS, follow this sequence:

```bash
# 1. Connect to VPS and clone repository
git clone https://github.com/<your-org>/vps-infrastructure.git
cd vps-infrastructure

# 2. Verify environment readiness (read-only diagnostic)
make preflight

# 3. Bootstrap essential system packages
make bootstrap

# 4. Apply SSH hardening & UFW firewall rules
make harden

# 5. Install Docker Engine CE from official repository
make install-docker

# 6. Install Coolify PaaS v4
make install-coolify

# 7. Configure encrypted Google Drive backups and enable daily timer
make backup-setup

# 8. Run health diagnostics
make health
```

---

## Makefile Command Reference

All quality gates, provisioning tasks, and operational maintenance procedures are accessible via `make`:

| Command | Description |
|---|---|
| `make help` | Display available targets and descriptions. |
| `make check` | Run shell syntax checks (`bash -n`) and recursive zero-secrets audit. |
| `make lint` | Run ShellCheck static analysis if installed. |
| `make test` | Execute complete offline TDD test suite across all subsystems. |
| `make preflight` | Run read-only diagnostics on OS, CPU, RAM, disk, and dependencies. |
| `make bootstrap` | Install base packages (`curl`, `ufw`, `fail2ban`, `rclone`, `jq`). |
| `make harden` | Configure SSH hardening, UFW firewall (base + custom ports), and fail2ban. |
| `make install-docker` | Install Docker CE with official repos, log rotation, and systemd service. |
| `make install-coolify`| Deploy Coolify v4 PaaS and display initial login instructions. |
| `make backup-setup` | Set up backup directories, environment configs, and systemd timers. |
| `make backup-now` | Execute an immediate two-tier client-encrypted backup to Google Drive. |
| `make backup-verify`| Non-destructive remote inspection of encrypted backup archives. |
| `make backup-restore`| Interactive disaster-recovery restore wizard. |
| `make health` | Evaluate host CPU, memory, disk, inode thresholds, and Docker container states. |
| `make clean` | Remove temporary test fixtures and scratch artifacts. |

> [!TIP]
> You can preview any operational script without applying changes using `ARGS="--dry-run"`.  
> Example: `make harden ARGS="--dry-run"`

---

## Directory Layout

```
.
├── .github/
│   └── workflows/
│       └── reusable-docker-build.yml   # Offloaded GHCR build & Coolify deploy workflow
├── config/
│   ├── allowed_ports.conf              # Dynamic custom firewall ports (e.g., 8080/tcp)
│   ├── backup.example.env              # Environment template for automated backups
│   └── server.example.env              # Host configuration template
├── docs/
│   ├── fa/
│   │   └── README.md                   # راهنمای جامع فارسی (Persian Operator Guide)
│   ├── getting-started/
│   │   ├── prerequisites.md            # Hardware, network, DNS, and OS support matrix
│   │   └── initial-server-setup.md     # First-login runbook, non-root user, timezone
│   ├── architecture/
│   │   ├── architecture.md             # System architecture, boundaries, and secrets
│   │   └── security.md                 # SSH hardening, UFW, fail2ban, Docker firewalling
│   ├── platform/
│   │   ├── coolify.md                  # Coolify installation, Traefik, GHCR integration
│   │   └── github-actions-ghcr.md      # Offloaded CI/CD pipeline and deploy webhooks
│   ├── backup-recovery/
│   │   ├── backups.md                  # Two-tier backup architecture and lifecycle
│   │   ├── google-drive.md             # Google Drive & rclone crypt setup guide
│   │   └── restore-and-disaster-recovery.md # Disaster recovery drill and restoration
│   ├── operations/
│   │   ├── monitoring.md               # Host thresholds, container health checks, alerting
│   │   └── troubleshooting.md          # Diagnostics for lockouts, crashes, disk exhaustion
│   └── specs/
│       ├── PROJECT_BRIEF.md            # Authoritative project requirements
│       └── ANTIGRAVITY_PROMPT.md       # Implementation prompt
├── scripts/
│   ├── common.sh                       # Shared logging, error handling, dry-run utilities
│   ├── preflight.sh                    # System validation and OS compatibility check
│   ├── bootstrap.sh                    # Base APT packages and tools installation
│   ├── harden-server.sh                # SSH and UFW firewall enforcement
│   ├── install-docker.sh               # Official Docker CE installation and daemon config
│   ├── install-coolify.sh              # Coolify PaaS installation
│   ├── setup-backups.sh                # Backup directories and systemd timer installation
│   ├── backup-now.sh                   # Two-tier backup creation, encryption, and upload
│   ├── verify-backups.sh               # Backup verification and remote listing
│   ├── restore-backup.sh               # Cold-start archive extraction and restoration
│   └── health-check.sh                 # Lightweight host and container health monitoring
├── systemd/
│   ├── vps-backup.service              # Systemd one-shot service for backup-now.sh
│   └── vps-backup.timer                # Daily systemd timer for automated backups
├── tests/                              # Complete offline TDD test suite
│   ├── test_runner.sh                  # Pure bash test framework
│   ├── test_scripts_syntax.sh          # Syntax validation (bash -n)
│   ├── test_secrets_scan.sh            # Zero-secrets detection scanner
│   ├── test_makefile.sh                # Makefile target contract tests
│   ├── test_preflight_and_bootstrap.sh # OS detection and bootstrap tests
│   ├── test_harden_and_ports.sh        # Firewall parsing and SSH hardening tests
│   ├── test_docker_and_coolify_install.sh # Docker and Coolify installation tests
│   ├── test_ci_cd_workflow.sh          # CI/CD workflow contract tests
│   ├── test_backup_system.sh           # Backup pipeline and rclone command tests
│   ├── test_restore_and_verify.sh      # Disaster recovery and restore tests
│   ├── test_health_check.sh            # Health check thresholds and JSON format tests
│   └── test_docs_and_repo_integrity.sh # Documentation presence and link integrity tests
├── Makefile                            # Unified operator and test CLI interface
├── CHANGELOG.md                        # Formal history of changes and decisions
└── AGENTS.md                           # Developer guidelines and agent skills
```

---

## Documentation Index

### 🇮🇷 مستندات فارسی
- [راهنمای جامع فارسی](docs/fa/README.md)

### 🚀 Getting Started
- [Prerequisites & OS Support](docs/getting-started/prerequisites.md)
- [Initial Server Setup Runbook](docs/getting-started/initial-server-setup.md)

### 🏛 Architecture & Security
- [System Architecture](docs/architecture/architecture.md)
- [Host Security & Firewall Guide](docs/architecture/security.md)

### 📦 Platform & CI/CD
- [Coolify Setup & Operations](docs/platform/coolify.md)
- [GitHub Actions & GHCR CI/CD](docs/platform/github-actions-ghcr.md)

### 💾 Backup & Disaster Recovery
- [Backup System Architecture](docs/backup-recovery/backups.md)
- [Google Drive & Rclone Crypt Setup](docs/backup-recovery/google-drive.md)
- [Disaster Recovery & Restore Runbook](docs/backup-recovery/restore-and-disaster-recovery.md)

### 🛠 Operations & Observability
- [Host & Container Monitoring](docs/operations/monitoring.md)
- [Troubleshooting & Emergency Recovery](docs/operations/troubleshooting.md)

### 📜 Project History
- [Changelog](CHANGELOG.md)

---

## Security & Zero-Secrets Posture

This repository enforces strict security guidelines:
- **No Committed Secrets:** Credentials, private keys, API tokens, and `.env` files are ignored via `.gitignore` and enforced via `make check`.
- **Encryption at Rest & In Transit:** All backups are encrypted locally using `rclone crypt` (AES-256-GCM) before uploading to Google Drive.
- **Offloaded Builds:** The VPS never builds untrusted code or handles build secrets; images are compiled in isolated GitHub runners.
