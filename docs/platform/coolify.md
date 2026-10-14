# Coolify PaaS Setup & Operations Guide

This guide walks you through deploying Docker Engine CE and Coolify v4, securing the critical `APP_KEY`, accessing the web dashboard, configuring custom domains with Traefik SSL, and connecting GitHub Container Registry (GHCR) for offloaded CI/CD deployments.

> [!NOTE]
> **In Plain English:**  
> Coolify gives you a clean web control panel (similar to Heroku, Vercel, or Netlify) directly on your own private VPS. It manages domains, SSL certificates, environment variables, databases, and container restarts with a few clicks.

---

## 1. Automated Installation

Coolify is installed in two clean automated steps:

### Step 1: Install Docker Engine CE
```bash
# Preview planned installation
make install-docker ARGS="--dry-run"

# Install Docker CE from official download.docker.com repositories
make install-docker
```
This script adds the official Docker repository, installs `docker-ce`, `docker-compose-plugin`, configures log rotation (`max-size: 50m`, `max-file: 3`), and enables the Docker systemd service.

### Step 2: Install Coolify v4
```bash
# Preview planned installation
make install-coolify ARGS="--dry-run"

# Install Coolify PaaS
make install-coolify
```
The script pulls and boots the official Coolify stack into `/data/coolify`.

---

## 2. CRITICAL: Back Up Your `APP_KEY` Immediately

> [!CAUTION]
> **What is `APP_KEY` and why is it so important?**  
> Coolify stores all your application database passwords, secrets, and private deploy tokens in its internal database. To keep them safe, it encrypts all of them using a master key called `APP_KEY` located in `/data/coolify/source/.env`.  
> 
> **If you lose `APP_KEY`, your Coolify database and application credentials CANNOT be decrypted or recovered!** Even if you have a full backup of the database, without this key, the data is unreadable random garbage.

### Retrieve and save your `APP_KEY`:
```bash
sudo grep '^APP_KEY=' /data/coolify/source/.env
```
Store this string in your offline password manager (1Password, Bitwarden, KeePass) immediately. This key is also automatically included in Tier 1 automated backups (`scripts/backup-now.sh`).

---

## 3. Initial Dashboard Setup

1. **Access Web Interface:**
   Open your browser to:
   ```
   http://<YOUR_VPS_PUBLIC_IP>:8000
   ```
2. **Register First Administrator:**
   - Follow the prompt to create the root admin account (Name, Email, Strong Password).
   - This first registered user becomes the root instance administrator.

3. **Configure Instance Domain:**
   - Navigate to **Settings** > **Instance Settings** > **General**.
   - Set **Instance Domain** to `https://coolify.example.com` (ensure your DNS `A` record points to the VPS).
   - Coolify's built-in Traefik proxy automatically requests a free Let's Encrypt TLS certificate via HTTP-01 challenge.
   - Once issued, you can access Coolify securely via `https://coolify.example.com`.

---

## 4. Connecting GitHub Container Registry (GHCR)

Because images are built off-server in GitHub Actions runners and pushed to GHCR, Coolify needs read access to your private images.

1. **Generate a GitHub Personal Access Token (PAT):**
   - In GitHub: **Settings** > **Developer Settings** > **Personal Access Tokens** > **Tokens (classic)**.
   - Grant scopes: `read:packages`.
2. **Add Registry in Coolify:**
   - In Coolify, go to **Keys & Servers** > **Registries** > **Add New Registry**.
   - **Type:** Docker Registry
   - **Name:** `GHCR`
   - **Registry URL:** `ghcr.io`
   - **Username:** Your GitHub username or organization name
   - **Password:** The GitHub PAT created above
   - Click **Save**.

---

## 5. Deploying an Application from GHCR

1. In Coolify, click **Projects** > **Select or Create Project** > **New Resource**.
2. Select **Docker Image**.
3. Choose the **GHCR** registry added in Step 4.
4. Set the image path: `ghcr.io/<your-org>/<image-name>:latest`.
5. Specify the public domain (e.g. `https://app.example.com`). Traefik will automatically handle SSL.
6. Under **Webhooks**, locate the **Deploy Webhook** URL.
7. Copy this URL and save it in your GitHub repository's secrets as `COOLIFY_DEPLOY_WEBHOOK`.
8. When your GitHub Actions workflow runs, it calls this webhook, triggering Coolify to pull the latest image and restart the container seamlessly!

---

## 6. Coolify Maintenance & Restarts

- **Restart Coolify Containers:**
  ```bash
  cd /data/coolify/source
  docker compose down && docker compose up -d
  ```
- **View Coolify Logs:**
  ```bash
  docker logs -f coolify
  ```
- **Update Coolify:**
  Updates can be triggered directly from the Coolify web interface under **Settings** > **Update**, or by pulling the latest compose stack in `/data/coolify/source`.

---

## 7. Next Steps

- Set up automated CI/CD builds with [docs/platform/github-actions-ghcr.md](github-actions-ghcr.md).
- Configure automated offsite backups with [docs/backup-recovery/backups.md](../backup-recovery/backups.md).
