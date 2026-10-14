# Troubleshooting & Emergency Recovery Runbook

This runbook provides actionable diagnostics and recovery steps for common operational emergencies, including SSH lockouts, Coolify crashes, Docker daemon issues, disk exhaustion, and backup failures.

> [!NOTE]
> **In Plain English:**  
> When something goes wrong on a server, do not panic. 99% of emergencies fall into three categories:  
> 1. You locked yourself out (use your hosting provider's web emergency console to unblock port 22 or unban your IP in fail2ban).  
> 2. The disk is 100% full (clean Docker dangling caches and vacuum systemd logs).  
> 3. Coolify is stuck (restart the Coolify stack with docker compose).

---

## 1. Emergency SSH Lockout Recovery

If you cannot connect via SSH after applying firewall rules or hardening:

### Accessing the Server Console
1. Log in to your VPS hosting provider dashboard (Hetzner Cloud Console, DigitalOcean Droplet Console, Linode Lish, etc.).
2. Launch the **Emergency Web Console / VNC / Serial Terminal**.
3. Log in with your root credentials or operator account.

### Lockout Diagnostics & Fixes
- **Check UFW Firewall Rules:**
  ```bash
  sudo ufw status verbose
  # If SSH (port 22) is blocked or missing:
  sudo ufw allow 22/tcp
  sudo ufw reload
  ```
- **Check Fail2ban Bans:**
  ```bash
  # Check if your client IP was banned by fail2ban
  sudo fail2ban-client status sshd
  # Unban your IP:
  sudo fail2ban-client set sshd unbanip <YOUR_CLIENT_IP>
  ```
- **Check SSH Daemon Status & Permissions:**
  ```bash
  sudo systemctl status sshd
  # Ensure permissions on authorized_keys are correct
  chmod 700 /home/deployer/.ssh
  chmod 600 /home/deployer/.ssh/authorized_keys
  chown -R deployer:deployer /home/deployer/.ssh
  ```
- **Temporarily Disable UFW in Severe Emergencies:**
  ```bash
  sudo ufw disable
  ```
  Once SSH connectivity is restored, identify the misconfiguration, fix `config/allowed_ports.conf`, and re-enable UFW (`make harden`).

---

## 2. Coolify Dashboard Unreachable or Crashing

### Check Container Status
```bash
docker ps -a --filter "name=coolify"
```

### Common Symptoms & Fixes:
1. **Coolify Container in Restart Loop:**
   Check container logs for error traces:
   ```bash
   docker logs --tail 100 coolify
   ```
2. **Missing or Corrupted `APP_KEY`:**
   If logs say `No application encryption key has been specified`:
   - Inspect `/data/coolify/source/.env`.
   - Restore your saved `APP_KEY` or recover it from the latest Tier 1 backup:
     ```bash
     sudo nano /data/coolify/source/.env
     # Ensure APP_KEY=base64:... is present and matches the original key
     ```
3. **Hard Restart of Coolify Stack:**
   ```bash
   cd /data/coolify/source
   docker compose down
   docker compose up -d
   ```
4. **Traefik Proxy Stopped:**
   If Coolify is running but web pages return 502/Connection Refused:
   ```bash
   docker restart coolify-proxy
   docker logs --tail 50 coolify-proxy
   ```

---

## 3. Docker Daemon Failures & Hanging Containers

- **Restart Docker Service:**
  ```bash
  sudo systemctl restart docker
  ```
- **Kill Stuck or Hanging Containers:**
  ```bash
  docker kill <container_id_or_name>
  ```
- **Inspect Docker Daemon Logs:**
  ```bash
  sudo journalctl -u docker.service -n 100 --no-pager
  ```

---

## 4. Disk Exhaustion Emergencies (100% Disk Full)

When disk space reaches 100%, services like Docker and PostgreSQL cannot write temporary files and crash.

### Step 1: Check Disk & Inode Usage
```bash
df -h
df -i
```

### Step 2: Clean Docker Build Cache & Dangling Images
```bash
# Safely remove unused build cache, stopped containers, and untagged images
docker system prune -af
```

### Step 3: Vacuum Systemd Journal Logs
Systemd logs can grow large over time if unconstrained:
```bash
# Vacuum logs to keep at most 200MB
sudo journalctl --vacuum-size=200M
```

### Step 4: Clean APT Package Cache
```bash
sudo apt-get clean
sudo apt-get autoremove -y
```

### Step 5: Clean Local Backup Staging Directory
```bash
# Check if old local staging archives are accumulating
du -sh /var/backups/vps-snapshots/*
# Retention script should clean files older than 7 days, or prune manually if urgent
```

---

## 5. Backup & Rclone Upload Failures

If `make backup-now` or the daily systemd timer fails:

1. **Inspect Systemd Timer & Service Logs:**
   ```bash
   sudo systemctl status vps-backup.timer
   sudo journalctl -u vps-backup.service -n 50 --no-pager
   ```
2. **Test Rclone Connection:**
   ```bash
   rclone lsd gdrive:
   ```
3. **Google Drive Token Expired:**
   If rclone reports `invalid_grant` or token expired:
   ```bash
   rclone config reconnect gdrive:
   ```
4. **Inspect Backup Files Locally:**
   Check whether the local dump succeeded prior to upload:
   ```bash
   ls -la /var/backups/vps-snapshots/
   ```
   For step-by-step restoration instructions, refer to [docs/backup-recovery/restore-and-disaster-recovery.md](../backup-recovery/restore-and-disaster-recovery.md).
