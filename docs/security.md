# Host Hardening & Security Runbook

This runbook covers host hardening, SSH configuration, the UFW firewall baseline, custom port extension via `config/allowed_ports.conf`, fail2ban intrusion prevention, unattended security upgrades, and strict secrets management policies.

---

## 1. Automated Security Hardening (`make harden`)

The automated hardening script (`scripts/harden-server.sh`) performs the complete hardening checklist in a single command.

You can preview planned actions first:
```bash
make harden ARGS="--dry-run"
```

Apply hardening to the server:
```bash
make harden
```

---

## 2. SSH Daemon Hardening

The SSH daemon configuration (`/etc/ssh/sshd_config.d/99-vps-hardening.conf` or `/etc/ssh/sshd_config`) enforces strict authentication policies:

| Directive | Configured Value | Security Purpose |
|---|---|---|
| `PasswordAuthentication` | `no` | Prevents credential brute-forcing; requires public key authentication. |
| `PermitRootLogin` | `prohibit-password` | Prevents remote root password attacks. Key access can be allowed or disabled. |
| `PubkeyAuthentication` | `yes` | Enforces Ed25519 / RSA public key authentication. |
| `MaxAuthTries` | `3` | Closes connection after 3 failed attempts to throttle scanners. |
| `X11Forwarding` | `no` | Disables unused graphical forwarding attack surface. |

> [!CAUTION]
> Always keep your existing SSH terminal open until you have opened a second terminal and successfully logged in with your private key!

---

## 3. UFW Firewall Baseline & Custom Ports

The firewall is configured with a **Default Deny Incoming** posture.

### Baseline Allowed Ports
- `22/tcp` — SSH access
- `80/tcp` — HTTP (Traefik web ingress & ACME challenges)
- `443/tcp` — HTTPS (Traefik TLS encrypted traffic)
- `8000/tcp` — Coolify control panel UI

### Dynamic Custom Ports via `config/allowed_ports.conf`
If an application or service requires additional public ports (e.g. staging proxies, VPNs, DNS, or custom game servers), add them to `config/allowed_ports.conf`:

```conf
# Format: <port>[/<protocol>]
# Comments and blank lines are ignored. Default protocol is tcp.
8080/tcp
9000
53/udp
```

Running `make harden` automatically parses `config/allowed_ports.conf` and adds UFW firewall rules for every valid port entry.

---

## 4. Docker vs. UFW Security Considerations

By default, Docker manipulates Linux `iptables` directly. When you publish a port with `docker run -p 8080:80` or `ports: - "8080:80"` in docker compose, Docker inserts NAT rules **before** UFW chains, potentially exposing a container port to the internet even if UFW blocks it.

### Defense-in-Depth Best Practices:
1. **Bind to Localhost for Internal Services:**
   In Docker Compose or Coolify, always bind internal services to `127.0.0.1`:
   ```yaml
   ports:
     - "127.0.0.1:5432:5432"  # PostgreSQL accessible only to host/local
   ```
2. **Route Public Traffic Through Traefik:**
   Do not expose application containers directly. Attach them to the `coolify` Docker network and let Traefik handle reverse proxying on ports 80/443.
3. **Coolify Network Isolation:**
   Coolify isolates each project/environment into its own private Docker bridge network, preventing lateral movement between tenant containers.

---

## 5. Fail2ban Intrusion Prevention

Fail2ban monitors system authentication logs and automatically blacklists IP addresses exhibiting malicious behavior.

- Configuration file: `/etc/fail2ban/jail.local`
- Jail: `[sshd]`
- `maxretry = 3` (bans after 3 failed authentication attempts)
- `findtime = 600` (window of 10 minutes)
- `bantime = 3600` (1 hour initial ban time)

Useful commands:
```bash
# Check jail status and banned IPs
sudo fail2ban-client status sshd

# Unban an accidental lockout
sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
```

---

## 6. Unattended Security Upgrades

To ensure the Linux kernel and core libraries receive critical CVE security patches:

```bash
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

Configured in `/etc/apt/apt.conf.d/50unattended-upgrades` to automatically install security updates and clean obsolete packages.

---

## 7. Secrets Management & Hygiene Rules

1. **Zero Secrets in Version Control:**
   - Never commit `.env` files, API keys, private certificates, or tokens.
   - Verified automatically via `make check` (`tests/test_secrets_scan.sh`).
2. **File Permissions:**
   - Any local configuration file containing secrets (e.g. `config/server.env`, `config/backup.env`, `~/.config/rclone/rclone.conf`) MUST have permissions `0600` (`chmod 600 <file>`).
3. **Coolify Environment Variables:**
   - Store application production secrets in Coolify's encrypted dashboard. Coolify encrypts these at rest using its `APP_KEY`.
4. **Deploy Webhook Protection:**
   - Coolify deploy webhooks contain unique UUID tokens. Treat these URLs as secrets and store them only in GitHub Repository Secrets (`COOLIFY_DEPLOY_WEBHOOK`).

---

## 8. Next Steps

- Now that the server is secured, proceed to [docs/coolify.md](coolify.md) to set up Docker Engine CE and Coolify.
