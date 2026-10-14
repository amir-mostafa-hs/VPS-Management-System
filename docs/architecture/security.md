# Host Hardening & Security Runbook

This runbook covers host hardening, SSH configuration, the UFW firewall baseline, custom port extension via `config/allowed_ports.conf`, fail2ban intrusion prevention, unattended security upgrades, and strict secrets management policies.

> [!NOTE]
> **In Plain English:**  
> Securing a VPS is like locking down a house:  
> 1. We replace easily pickable password locks on the front door with high-security biometric keys (SSH keys only).  
> 2. We brick up every unused window and doorway (UFW default-deny firewall).  
> 3. We hire a guard who spots anyone repeatedly trying to pick the lock and throws them in detention for an hour (fail2ban).  
> 4. We make sure internal workrooms don't accidentally knock open secret back doors to the public street (Docker vs. UFW port binding discipline).

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

> [!TIP]
> **Why disable passwords?**  
> Public IP addresses on the internet receive thousands of automated password guesses per hour from botnets. By disabling password authentication entirely and requiring an Ed25519 cryptographic key, brute-force password guessing becomes mathematically impossible.

The SSH daemon configuration (`/etc/ssh/sshd_config.d/99-vps-hardening.conf` or `/etc/ssh/sshd_config`) enforces strict authentication policies:

| Directive | Configured Value | Security Purpose & Meaning |
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

The firewall is configured with a **Default Deny Incoming** posture. Any packet arriving at the server that does not match an explicitly allowed rule is silently dropped.

### Baseline Allowed Ports
- `22/tcp` — SSH management access
- `80/tcp` — HTTP (Traefik web ingress & ACME Let's Encrypt challenges)
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

> [!IMPORTANT]
> **The Docker iptables Gotcha Explained Simply:**  
> By default in Linux, Docker manipulates firewall rules (`iptables`) directly. When you publish a port in Docker like `ports: - "5432:5432"`, Docker injects a routing rule *before* UFW evaluates traffic. This means Docker can bypass UFW and expose your database container directly to the internet!

### Defense-in-Depth Best Practices:
1. **Bind to Localhost for Internal Services:**
   In Docker Compose or Coolify, always bind internal services to `127.0.0.1`:
   ```yaml
   ports:
     - "127.0.0.1:5432:5432"  # PostgreSQL accessible ONLY from this host, not from the public internet
   ```
2. **Route Public Traffic Through Traefik:**
   Do not expose application containers directly. Attach them to the `coolify` Docker network and let Traefik handle reverse proxying on ports 80/443.
3. **Coolify Network Isolation:**
   Coolify isolates each project/environment into its own private Docker bridge network, preventing lateral movement between tenant containers.

---

## 5. Fail2ban Intrusion Prevention

Fail2ban monitors system authentication logs (`/var/log/auth.log`) and automatically blacklists IP addresses exhibiting malicious behavior.

- Configuration file: `/etc/fail2ban/jail.local`
- Jail: `[sshd]`
- `maxretry = 3` (bans after 3 failed authentication attempts)
- `findtime = 600` (within a window of 10 minutes)
- `bantime = 3600` (1 hour initial ban time)

Useful commands:
```bash
# Check jail status and banned IPs
sudo fail2ban-client status sshd

# Unban an accidental lockout (e.g. if you misconfigured your client)
sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
```

---

## 6. Unattended Security Upgrades

To ensure the Linux kernel and core packages automatically receive critical CVE security patches without requiring manual intervention:

```bash
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

Configured in `/etc/apt/apt.conf.d/50unattended-upgrades` to automatically install security updates and clean obsolete packages.

---

## 7. Secrets Management & Hygiene Rules

> [!TIP]
> **What does permission `0600` mean?**  
> `chmod 600 <file>` means "Read and write for the owner only; completely forbidden for everyone else on the machine." This prevents other users or background processes from reading sensitive tokens.

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

- Now that the server is secured, proceed to [docs/platform/coolify.md](../platform/coolify.md) to set up Docker Engine CE and Coolify.
