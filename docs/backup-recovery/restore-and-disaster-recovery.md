# Cold-Start Disaster Recovery Runbook & Restore Drill

This runbook documents the exact sequence for recovering all services, configurations, and application data onto a **Clean VPS** in the event of catastrophic server loss or migration.

> [!NOTE]
> **In Plain English:**  
> A disaster recovery plan is like a fire drill. Don't wait until your server actually crashes to figure out how to restore your data!  
> Follow this guide to simulate a "cold-start" recovery: renting a brand-new blank server, typing 5 commands, pulling your encrypted backup from Google Drive, and having all your websites and databases running again in 20 minutes.

---

## 1. Overview & Recovery Flow

```
[ Catastrophic Event ]
         │
         ▼
[ Step 1: Provision Clean VPS ] ── (Debian 12/13 or Ubuntu 22/24)
         │
         ▼
[ Step 2: Bootstrap & Hardening ] ── (make bootstrap, make harden)
         │
         ▼
[ Step 3: Install Docker & Coolify ] ── (make install-docker, make install-coolify)
         │
         ▼
[ Step 4: Configure rclone crypt ] ── (Enter saved crypt password & salt)
         │
         ▼
[ Step 5: Restore Data & DBs ] ── (make backup-restore)
         │
         ▼
[ Step 6: Verify Health ] ── (make health)
```

---

## 2. Prerequisites for Recovery

Ensure you have stored these two critical items in an offline password manager beforehand:
1. **Coolify `APP_KEY`** (string from `/data/coolify/source/.env`).
2. **`rclone crypt` Password and Salt** (from `~/.config/rclone/rclone.conf`).

---

## 3. Phase 1: Clean VPS Provisioning

1. Provision a fresh virtual server running a supported operating system (Ubuntu 24.04 LTS recommended).
2. SSH into the new server using your operator key:
   ```bash
   ssh root@<new-vps-ip>
   ```
3. Clone the infrastructure repository:
   ```bash
   git clone https://github.com/amir-mostafa-hs/VPS-Management-System.git /opt/vps-infrastructure
   cd /opt/vps-infrastructure
   ```
4. Run preflight, bootstrap, and security hardening:
   ```bash
   make preflight
   make bootstrap
   make harden
   ```

---

## 4. Phase 2: Installing Base Services

Install Docker Engine CE and Coolify:
```bash
make install-docker
make install-coolify
```

Stop the default clean Coolify instance temporarily so its state can be replaced:
```bash
docker stop coolify coolify-db coolify-proxy 2>/dev/null || true
```

---

## 5. Phase 3: Configuring Rclone Crypt

1. Set up the Google Drive remote and the encrypted crypt overlay following [docs/backup-recovery/google-drive.md](google-drive.md):
   ```bash
   rclone config
   ```
2. Verify remote connectivity to your backups:
   ```bash
   make backup-verify
   ```

---

## 6. Phase 4: Restoring Backups

1. Launch the interactive restore tool to extract your chosen archive:
   ```bash
   make backup-restore ARGS="--archive vps-backup-<TIMESTAMP>.tar.gz"
   ```
2. **Restore Coolify Core State:**
   ```bash
   tar -xzf /tmp/vps-restore/coolify-core.tar.gz -C /data/
   ```
3. **Verify `APP_KEY`:**
   Inspect `/data/coolify/source/.env` and confirm `APP_KEY` matches your saved offline key:
   ```bash
   grep '^APP_KEY=' /data/coolify/source/.env
   ```
4. **Restore PostgreSQL Database:**
   ```bash
   docker start coolify-db
   sleep 5
   # Restore logical dump
   cat /tmp/vps-restore/postgres-coolify-db.sql | docker exec -i coolify-db psql -U postgres
   ```
5. **Restore Application Volumes & Databases:**
   - Extract targeted volume tarballs to their designated directories.
   - For application PostgreSQL databases, execute `pg_restore` or `psql`:
     ```bash
     cat /tmp/vps-restore/postgres-<app-container>.sql | docker exec -i <app-container> psql -U <user> <dbname>
     ```

---

## 7. Phase 5: Verification & Resumption

1. Restart Coolify core containers:
   ```bash
   docker restart coolify coolify-db coolify-proxy
   ```
2. Open the Coolify dashboard at `http://<new-vps-ip>:8000` or your domain.
3. Verify that all projects, environments, and applications are listed.
4. Redeploy applications from Coolify or trigger your GitHub Actions deploy webhooks.
5. Run the health check suite to confirm all services are stable:
   ```bash
   make health
   ```

---

## 8. Next Steps & Cross-References

- Back to main backup guide: [docs/backup-recovery/backups.md](backups.md).
- Troubleshooting common restore issues: [docs/operations/troubleshooting.md](../operations/troubleshooting.md).
