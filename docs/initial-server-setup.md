# Initial Server Setup Runbook

This step-by-step guide walks you through connecting to a newly provisioned Linux VPS, provisioning a dedicated non-root operator user, configuring timezone and locale, and executing automated preflight diagnostics.

---

## 1. Initial Connection as Root

Upon receiving your server credentials from your VPS provider (Hetzner, DigitalOcean, Linode, OVH, etc.), log in as `root`:

```bash
ssh root@<SERVER_IP>
```

If you receive a host key verification warning, verify the fingerprint and accept with `yes`.

---

## 2. Create Dedicated Operator User

Never operate daily tasks directly as `root`. Create a dedicated administrative user (for example `deployer` or `admin`):

```bash
# 1. Create the user with home directory and bash shell
adduser --gecos "" deployer

# 2. Add user to sudoers group
usermod -aG sudo deployer

# 3. Configure passwordless sudo for automation scripts (optional but recommended)
echo "deployer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/deployer
chmod 0440 /etc/sudoers.d/deployer
```

---

## 3. Install SSH Public Key for Operator User

Authorize your local workstation's SSH key on the new operator account:

```bash
# Create SSH directory with strict permissions
mkdir -p /home/deployer/.ssh
chmod 700 /home/deployer/.ssh

# Copy root's authorized_keys or paste your public key
cp /root/.ssh/authorized_keys /home/deployer/.ssh/authorized_keys
chmod 600 /home/deployer/.ssh/authorized_keys

# Fix ownership
chown -R deployer:deployer /home/deployer/.ssh
```

---

## 4. Test SSH Connection Before Disconnecting Root

> [!CAUTION]
> **DO NOT** disconnect your current `root` terminal session yet! Open a new terminal window on your local machine and verify login:

```bash
ssh deployer@<SERVER_IP>
```

Verify that you can run `sudo` commands without error:

```bash
sudo whoami
# Expected output: root
```

---

## 5. System Clock & Timezone Configuration

Set system timezone to UTC to ensure consistent logging across distributed systems, cron jobs, and backups:

```bash
sudo timedatectl set-timezone UTC
sudo timedatectl set-ntp on
timedatectl status
```

---

## 6. Clone Infrastructure Repository

As the `deployer` user on the VPS:

```bash
# Install git if missing
sudo apt-get update && sudo apt-get install -y git make

# Clone the repository
git clone https://github.com/<your-org>/vps-infrastructure.git
cd vps-infrastructure
```

---

## 7. Run Preflight Diagnostics & Bootstrapping

Before applying changes or installing services, execute the preflight diagnostic suite:

```bash
# Run preflight check
make preflight
```

The preflight script checks:
- OS distribution (Debian 12/13, Ubuntu 22.04/24.04)
- CPU cores, RAM (minimum 1GB required for Coolify), available disk space
- Essential package readiness

Once preflight checks pass green, bootstrap system dependencies:

```bash
# Bootstrap system packages (curl, ufw, fail2ban, rclone, jq)
make bootstrap
```

---

## 8. Next Steps

With basic dependencies bootstrapped:
- Proceed to [docs/security.md](security.md) to apply SSH hardening, firewall rules, and intrusion protection.
- Then install Docker and Coolify using [docs/coolify.md](coolify.md).
