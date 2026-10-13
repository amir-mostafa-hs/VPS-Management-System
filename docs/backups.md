# Backup Architecture & Operator Policies

## 1. Scope and Strategy

The backup system implements the **3-2-1 backup principle**:
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
            [ Local Encryption via rclone crypt ]
                          │
                          ▼
            [ Remote Sync: Google Drive (Encrypted) ]
```

---

## 2. Backup Tiers Detail

### Tier 1: Coolify Core System
- Coolify stores application configurations, server credentials, Traefik routes, and SSL details in `/data/coolify`.
- A daily tar archive `coolify-core-<timestamp>.tar.gz` captures this state.
- Internal SQLite or PostgreSQL state is dumped using logical database dump commands.
- **Critical Recovery Factor:** The Coolify `APP_KEY` is backed up as part of the core files. Ensure this key is also stored offline in your master credentials vault.

### Tier 2: Application Databases
- **PostgreSQL:** Backed up via `docker exec <container> pg_dump -U <user> <dbname>`.
- **MySQL / MariaDB:** Backed up via `docker exec <container> mysqldump -u <user> -p<pass> <dbname>`.
- **Docker Volumes:** Named volumes and bind mounts configured in `APPLICATION_DATA_PATHS` are compressed into individual tarballs.

---

## 3. Automation via Systemd

Backups are executed daily without manual operator intervention:
- **Service:** `/etc/systemd/system/vps-backup.service` executes `/opt/vps-infrastructure/scripts/backup-now.sh`.
- **Timer:** `/etc/systemd/system/vps-backup.timer` triggers daily at 03:00 UTC with a 15-minute randomized delay (`RandomizedDelaySec=900`) to avoid recurring cloud throttling.

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
- **Remote Retention (`REMOTE_RETENTION_DAYS`, default 30):** Archives older than 30 days are purged from Google Drive.
