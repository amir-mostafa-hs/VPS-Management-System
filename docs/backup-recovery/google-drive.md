# Google Drive & rclone Crypt Setup Guide

This guide walks you through configuring Google Drive and client-side encryption (`rclone crypt`) so automated backups are securely stored offsite.

> [!NOTE]
> **In Plain English:**  
> `rclone` is like a supercharged file copy tool for cloud drives.  
> To protect your privacy, we set up two layers:  
> 1. `gdrive`: Connects your VPS to your Google Drive account.  
> 2. `gdrive-crypt`: Acts as a digital encryption wrapper. Every file sent through `gdrive-crypt` is scrambled with AES-256 before leaving the server. Anyone peeking at Google Drive only sees gibberish filenames and encrypted data.

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
8. **Auto Config (Headless VPS Notice):**
   - Because a server does not have a web browser, select `n` when asked `Use web browser to automatically authenticate?`.
   - On your local computer (where you have a web browser and `rclone` installed), run:
     ```bash
     rclone authorize "drive" "<your-client-id>" "<your-client-secret>"
     ```
   - Log in via your browser, approve access, and paste the generated JSON token back into your VPS terminal.
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
# Test creating a test folder
rclone mkdir gdrive-crypt:test

# List the test directory
rclone lsd gdrive-crypt:

# Clean up
rclone rmdir gdrive-crypt:test
```

---

## Step 4: Next Steps

- Set up automated daily backup timers with [docs/backup-recovery/backups.md](backups.md).
- Practice disaster recovery with [docs/backup-recovery/restore-and-disaster-recovery.md](restore-and-disaster-recovery.md).
