# System Architecture

This document describes the architectural layout, component boundaries, networking, CI/CD pipelines, and secret lifecycle for the single-node Linux VPS infrastructure running Coolify.

> [!NOTE]
> **In Plain English:**  
> Think of this VPS like a quiet retail storefront. Traditional setups try to manufacture goods, package them, and run the cash register all inside a tiny 2GB server—which often causes the server to crash when compiling software.  
> In our architecture, the heavy manufacturing (building Docker container images) is completely outsourced to GitHub's powerful cloud machines for free. The VPS only ever downloads finished, packaged containers and runs them, keeping memory and CPU usage whisper-quiet.

---

## 1. High-Level Architecture Overview

The system runs on a single Linux Virtual Private Server (Debian 12/13 or Ubuntu 22.04/24.04 LTS). It acts as an autonomous, self-hosted Platform-as-a-Service (PaaS) node while completely offloading compute-heavy Docker image building to GitHub Actions runners.

```
                           +----------------------------------------+
                           |             Developer Workstation      |
                           +----------------------------------------+
                                        |                |
                                    git push         make <target>
                                        v                v
+------------------------+  Docker Push  +------------------------+
| GitHub Actions Runner  |-------------> | GitHub Packages (GHCR) |
| (Offloaded Image Build)|               | (Prebuilt Images)      |
+------------------------+               +------------------------+
            | Deploy Webhook                         |
            | (POST /api/v1/deploy)                  | docker pull
            v                                        v
+===================================================================+
|                          Linux VPS Node                           |
|                                                                   |
|   +-----------------------------------------------------------+   |
|   | Host Operating System (Debian/Ubuntu LTS)                 |   |
|   | - SSH Daemon (Key-Only Auth, Port 22)                     |   |
|   | - UFW Firewall (Default Deny Incoming)                    |   |
|   | - Fail2ban (SSH Brute Force Defense)                      |   |
|   | - Systemd Timers (Automated Encrypted Backups)            |   |
|   +-----------------------------------------------------------+   |
|                                                                   |
|   +-----------------------------------------------------------+   |
|   | Docker Engine CE                                          |   |
|   |                                                           |   |
|   |  +---------------------+        +----------------------+  |   |
|   |  | Traefik Proxy       |<-------| Coolify Control      |  |   |
|   |  | (Ports 80/443, SSL) |        | Plane (Port 8000)    |  |   |
|   |  +---------------------+        +----------------------+  |   |
|   |             |                              |              |   |
|   |             | internal network             | manages      |   |
|   |             v                              v              |   |
|   |  +---------------------+        +----------------------+  |   |
|   |  | Application 1       |        | Application 2        |  |   |
|   |  | (e.g. Next.js / API)|        | (e.g. PostgreSQL DB) |  |   |
|   |  +---------------------+        +----------------------+  |   |
|   +-----------------------------------------------------------+   |
+===================================================================+
                                 |
                          rclone crypt sync
                                 v
                 +-------------------------------+
                 |  Google Drive (Remote Backup) |
                 |  - Tier 1: Coolify & APP_KEY  |
                 |  - Tier 2: DBs & Volumes      |
                 +-------------------------------+
```

---

## 2. Host vs. Container Responsibilities

| Responsibility | Handled By | Details & Plain-English Purpose |
|---|---|---|
| **OS Security & Kernel** | Host (Ubuntu/Debian) | Kernel patching, unattended security updates, user permissions. |
| **Network Perimeter** | Host (UFW) | Default deny incoming; only SSH (22), HTTP (80), HTTPS (443), and Coolify (8000) open. |
| **Intrusion Prevention** | Host (fail2ban) | Jails malicious IPs attempting repeated invalid SSH logins. |
| **Image Building** | GitHub Actions | 100% offloaded. VPS never runs `docker build` or npm/cargo compiles. |
| **Container Orchestration**| Docker Engine CE | Runs containerized workloads, isolates network bridges and volumes. |
| **Routing & Ingress SSL** | Traefik (Container) | Handles incoming HTTP/HTTPS traffic, automatically issues Let's Encrypt TLS certificates. |
| **Application Lifecycle**| Coolify (Container) | Manages webhooks, restarts containers on new GHCR image pushes, orchestrates databases. |
| **Backup Automation** | Host Systemd Timer | Dumps databases, archives Coolify configs and volumes, encrypts with `rclone`, uploads to Google Drive. |

---

## 3. Network Topology & Port Mapping

> [!NOTE]
> **In Plain English:**  
> Imagine ports like doors on a building. By default, all doors are locked shut ("Default Deny"). Only doors 22 (SSH for management), 80/443 (web visitors), and 8000 (Coolify admin panel) have keys. Your application containers (like a database) sit in private back rooms with no doors to the outside world—they can only talk to each other through private internal hallways (Docker bridge networks).

1. **Public Ingress:**
   - **Port 22/tcp (SSH):** Managed by host `sshd`, restricted to public key authentication.
   - **Port 80/tcp (HTTP):** Handled by Traefik container, automatically redirects to HTTPS.
   - **Port 443/tcp (HTTPS):** Handled by Traefik container, serves TLS certificates with automatic renewal.
   - **Port 8000/tcp (Coolify UI):** Coolify administration dashboard. Can be accessed directly via IP:8000 or routed through a custom domain (`coolify.example.com`) via Traefik.
   - **Custom Ports:** Defined in `config/allowed_ports.conf` and loaded dynamically by `scripts/harden-server.sh`.

2. **Internal Networking:**
   - Applications communicate across isolated Docker bridges (`coolify` bridge network).
   - Databases (Postgres, MySQL, Redis) deployed through Coolify are not exposed to public ports unless explicitly enabled in Coolify UI.

---

## 4. Offloaded CI/CD Build Flow

To prevent CPU starvation, memory exhaustion (OOM), and disk bloat on low-spec VPS nodes (e.g. 2GB RAM):

1. **Trigger:** A developer pushes code or creates a release tag on GitHub (`main` or `release/*`).
2. **Build Stage:** A GitHub-hosted runner (`ubuntu-latest` with 16GB RAM and fast multi-core CPU) executes `.github/workflows/reusable-docker-build.yml`.
3. **Registry Push:** The runner logs into GitHub Container Registry (`ghcr.io`), builds the multi-platform or target Docker image, tags it with the commit SHA and `latest`, and pushes it to GHCR.
4. **Deploy Trigger:** The runner triggers Coolify via a lightweight HTTP POST request to Coolify's application deployment webhook.
5. **VPS Deployment:** Coolify receives the webhook, instructs Docker on the VPS to pull the prebuilt image from GHCR, and performs a zero-downtime rolling restart.

---

## 5. Backup Architecture & Data Paths

The backup pipeline enforces a strict two-tier architecture:

```
[Local VPS Data]
  ├── Tier 1: /data/coolify/source/.env (APP_KEY) & DB (/data/coolify/databases)
  └── Tier 2: Application DB native dumps (PostgreSQL / MySQL) & Docker volumes
         │
         ▼
[Local Staging Directory] (/var/backups/vps-snapshots/<timestamp>/)
  ├── tier1_coolify_<timestamp>.tar.gz
  ├── tier2_databases_<timestamp>.sql.gz
  └── tier2_volumes_<timestamp>.tar.gz
         │
         ▼
[rclone Engine with Client-Side Encryption (rclone crypt)]
  └── AES-256-GCM symmetric client encryption
         │
         ▼
[Remote Storage: Google Drive] (gdrive:vps-backups/enc/)
```

> [!TIP]
> **What is `rclone crypt`?**  
> `rclone crypt` is client-side encryption. Before any backup file leaves your server, it is encrypted locally with AES-256-GCM. Even if Google Drive or your Google account were ever compromised, the attacker only sees scrambled random bytes and cannot read your database records or application secrets.

- **Daily Automation:** Handled by `systemd/vps-backup.timer` triggering `scripts/backup-now.sh`.
- **Retention:** Rolling 7-day retention automatically prunes older backups both locally and remotely.

---

## 6. Trust Boundaries & Secret Handling

| Asset / Secret | Authorized Location | Prohibited Location |
|---|---|---|
| **VPS SSH Private Key** | Operator's local workstation / password manager | Never on the VPS, never in Git. |
| **Coolify `APP_KEY`** | `/data/coolify/source/.env` (mode 0600) & offsite encrypted backup | Never in Git or public repositories. |
| **Backup Encryption Key** | `~/.config/rclone/rclone.conf` (mode 0600) & offline password vault | Never in Git or non-root accessible paths. |
| **GHCR Deploy Token / Secret** | GitHub Actions Repository Secrets & Coolify Registry Config | Never committed to repo scripts or Dockerfiles. |
| **Application Passwords & API Keys** | Injected via Coolify Environment Variables or local `.env` (0600) | Never baked into Docker images or committed to Git. |

---

## 7. Next Steps & Cross-References

- Review hardware and network requisites in [docs/getting-started/prerequisites.md](../getting-started/prerequisites.md).
- Follow initial setup in [docs/getting-started/initial-server-setup.md](../getting-started/initial-server-setup.md).
- Review firewall and security rules in [docs/architecture/security.md](security.md).
- Inspect CI/CD workflows in [docs/platform/github-actions-ghcr.md](../platform/github-actions-ghcr.md).
- Read backup and restore procedures in [docs/backup-recovery/backups.md](../backup-recovery/backups.md) and [docs/backup-recovery/restore-and-disaster-recovery.md](../backup-recovery/restore-and-disaster-recovery.md).
