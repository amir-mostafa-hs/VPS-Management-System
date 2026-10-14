# Backup Architecture & Operator Policies

This document explains the two-tier backup architecture, daily systemd automation, retention policies, and disaster recovery readiness.

> [!NOTE]
> **In Plain English:**  
> If the physical server hosting your VPS catches fire tonight, can you restore everything tomorrow on a completely fresh server?  
> With this backup system, yes. Every night at 03:00 UTC, the server packages your Coolify configurations (Tier 1) and your application databases and files (Tier 2), encrypts them on the fly so only you can read them, and uploads them to Google Drive.

---

## 1. Scope and Strategy

The backup system implements the industry-standard **3-2-1 backup principle**:
- **3 copies** of critical data (production runtime, local staging archive, remote cloud copy).
- **2 different media** (local SSD, cloud object storage).
- **1 off-site location** (Google Drive accessed via `rclone crypt`).

```
[ Production Host ]
       │
       ├─► Tier 1: Coolify Core Config & SQLite/Postgres DB
       │           (/data/coolify tarball + logical DB dump)
       │
       └─► Tier 2: Application Databases & Named Docker Volumes
                   (Native pg_dump / mysqldump + volume tarballs)
                          │
                          ▼
            [ Staged in /var/backups/vps/ ] ── (permissions 0700)
                          │
                          ▼
            [ Local Encryption via rclone crypt (AES-256) ]
                          │
                          ▼
            [ Remote Sync: Google Drive (Encrypted) ]
```

---

## 2. Backup Tiers Detail

### Tier 1: Coolify Core System
- Coolify stores application configurations, server credentials, Traefik routes, and SSL details in `/data/coolify`.
- A daily tar archive `coolify-core-<timestamp>.tar.gz` captures this state.
- Internal database state is dumped using logical database dump commands.
- **Critical Recovery Factor:** The Coolify `APP_KEY` in `/data/coolify/source/.env` is backed up as part of the core files. Ensure this key is also stored offline in your master password vault.

### Tier 2: Application Databases & Volumes
- **PostgreSQL:** Backed up via `docker exec <container> pg_dump -U <user> <dbname>`.
- **MySQL / MariaDB:** Backed up via `docker exec <container> mysqldump -u <user> -p<pass> <dbname>`.
- **Docker Volumes:** Named volumes and bind mounts configured in `APPLICATION_DATA_PATHS` are compressed into individual tarballs.

---

## 3. Automation via Systemd

Backups are executed daily without manual operator intervention:
- **Service:** `/etc/systemd/system/vps-backup.service` executes `/opt/vps-infrastructure/scripts/backup-now.sh`.
- **Timer:** `/etc/systemd/system/vps-backup.timer` triggers daily at 03:00 UTC with a 15-minute randomized delay (`RandomizedDelaySec=900`) to avoid recurring cloud API rate limits.

### Checking Backup Status:
```bash
# View timer status
systemctl status vps-backup.timer

# View execution logs from recent backup runs
journalctl -u vps-backup.service -n 50 --no-pager
```

---

## 4. Retention Policy

- **Local Retention (`LOCAL_RETENTION_DAYS`, default 7):** Local archives are retained in `/var/backups/vps` for 7 days for fast local rollbacks, then automatically purged after verified cloud upload.
- **Remote Retention (`REMOTE_RETENTION_DAYS`, default 30):** Archives older than 30 days are automatically purged from Google Drive to avoid storage bloat.

---

## 5. Next Steps & Cross-References

- Learn how to set up Google Drive credentials in [docs/backup-recovery/google-drive.md](google-drive.md).
- Follow the disaster recovery drill in [docs/backup-recovery/restore-and-disaster-recovery.md](restore-and-disaster-recovery.md).
