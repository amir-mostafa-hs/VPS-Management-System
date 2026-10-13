# Google Drive & rclone Crypt Setup Guide

## Overview

Backups in this infrastructure are synced to Google Drive using `rclone`. To protect user data and sensitive database dumps from unauthorized access in the cloud, all files are encrypted locally on the VPS using an `rclone crypt` overlay remote before uploading.

---

## Step 1: Configuring Google Drive Remote

On your local workstation or the VPS, run:

```bash
rclone config
```

1. Select `n` for **New remote**.
2. **Name:** `gdrive`
3. **Storage type:** Select `drive` (Google Drive).
4. **Client ID & Secret:** It is strongly recommended to generate your own Google Cloud OAuth Client ID and Secret (see [rclone Google Drive documentation](https://rclone.org/drive/#making-your-own-client-id)).
5. **Scope:** Select `1` (Full access to all files).
6. **Service Account Credentials:** Leave blank unless using a GCP service account.
7. **Advanced Config:** Select `n`.
8. **Auto Config:**
   - If configuring directly on a headless VPS without a browser, select `n` and follow the headless authorization instructions using `rclone authorize "drive" "..."` on your local machine.
9. Verify the remote and save.

---

## Step 2: Creating the Encrypted Remote (`rclone crypt`)

An `rclone crypt` remote wraps around the standard `gdrive` remote, encrypting filenames, directory names, and file contents with a master password and salt.

Run `rclone config`:
1. Select `n` for **New remote**.
2. **Name:** `gdrive-crypt`
3. **Storage type:** Select `crypt` (Encrypt/Decrypt a remote).
4. **Remote to encrypt/decrypt:** `gdrive:vps-backups`
5. **Filename encryption:** Select `standard` (encrypts directory and filenames).
6. **Directory name encryption:** Select `true`.
7. **Password:** Generate a strong random password (e.g. 32 characters) using a password manager.
8. **Password salt:** Generate a strong random salt.
9. Save the remote.

> [!CAUTION]
> **CRITICAL RECOVERY REQUIREMENT:**
> The `rclone crypt` password and salt are essential for disaster recovery! If your VPS is completely destroyed, you CANNOT decrypt your backups from Google Drive without this password and salt.
> Save the exact `~/.config/rclone/rclone.conf` or the password and salt in an encrypted offline password manager (1Password, Bitwarden, KeePass).

---

## Step 3: Verifying Remote Connectivity

Test that your crypt remote works without errors:

```bash
# Test creating a test file
rclone mkdir gdrive-crypt:test

# List the test directory
rclone lsd gdrive-crypt:

# Clean up
rclone rmdir gdrive-crypt:test
```
