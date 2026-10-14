# Prerequisites and System Requirements

This document outlines the hardware specifications, network and DNS setup, supported operating systems, and workstation tools required prior to provisioning the VPS.

> [!NOTE]
> **In Plain English:**  
> Before running setup commands, you need four simple ingredients:  
> 1. A virtual server running Debian or Ubuntu with at least 2GB of RAM.  
> 2. A domain name (e.g. `example.com`) where you can create `A` records pointing to your server's IP.  
> 3. An SSH key on your personal computer to securely log in without passwords.  
> 4. Free GitHub and Google Drive accounts to handle automated builds and offsite backups.

---

## 1. Operating System Support Matrix

The automation scripts and provisioning targets have been designed, tested, and validated for the following distributions:

| Distribution | Version | Codename | Status | Architectures |
|---|---|---|---|---|
| **Ubuntu Server** | 24.04 LTS | Noble Numbat | Supported & Recommended | `x86_64` (amd64), `aarch64` (arm64) |
| **Ubuntu Server** | 22.04 LTS | Jammy Jellyfish | Supported | `x86_64` (amd64), `aarch64` (arm64) |
| **Debian GNU/Linux**| 12 | Bookworm | Supported & Recommended | `x86_64` (amd64), `aarch64` (arm64) |
| **Debian GNU/Linux**| 13 | Trixie | Supported | `x86_64` (amd64), `aarch64` (arm64) |

> [!NOTE]
> All scripts include automatic OS detection via `/etc/os-release`. RedHat/CentOS/Fedora and Arch distributions are explicitly rejected by `scripts/preflight.sh` to prevent package manager collisions.

---

## 2. Hardware Sizing Recommendations

Because container image builds are 100% offloaded to GitHub Actions, the VPS only handles runtime execution and proxying:

| Resource | Minimum (Testing / Hobby) | Recommended (Production / Multiple Apps) |
|---|---|---|
| **vCPU** | 1 vCPU (x86_64 or ARM64) | 2 to 4 vCPUs |
| **RAM** | 2 GB RAM (Coolify requires ≥ 1 GB) | 4 GB to 8 GB RAM |
| **Storage** | 20 GB SSD / NVMe | 40 GB to 80 GB SSD / NVMe |
| **Architecture** | `x86_64` (amd64) or `arm64` | `x86_64` or `arm64` |
| **Virtualization** | KVM, Proxmox, or Cloud VPS (Hetzner, DigitalOcean, Linode, AWS EC2, etc.) | Standard KVM / Dedicated instance |

> [!WARNING]
> **Why KVM and not OpenVZ or shared containers?**  
> OpenVZ or shared containers share the host machine's Linux kernel and do not allow full Docker network routing (`iptables` and bridge manipulation). Full KVM virtualization gives your VPS its own independent kernel, allowing Docker and Traefik to run without restrictions.

---

## 3. Network & DNS Prerequisites

1. **Static Public IPv4 Address:**
   - A dedicated static IPv4 address assigned to the VPS.
   - (Optional) Public IPv6 address if dual-stack networking is desired.

2. **DNS Records (at your domain registrar or Cloudflare):**
   Prior to setting up Coolify and SSL certificates, configure the following DNS records pointing to your VPS public IP:

   | Record Type | Host / Name | Value / Target | Plain-English Purpose |
   |---|---|---|---|
   | `A` | `coolify.example.com` | `<VPS_PUBLIC_IP>` | Coolify management dashboard URL |
   | `A` | `*.example.com` (Wildcard) | `<VPS_PUBLIC_IP>` | Automatically points any subdomains (e.g. `api.example.com`, `app.example.com`) to your server without needing new DNS entries each time |
   | `A` | `example.com` (Apex) | `<VPS_PUBLIC_IP>` | (Optional) Primary root domain |

> [!TIP]
> **Cloudflare Users Note:**  
> Start with **DNS only (Gray Cloud)** during initial Let's Encrypt certificate issuance. If Cloudflare's orange cloud (proxy) is enabled initially, Let's Encrypt cannot verify the ACME challenge directly on Traefik, which causes SSL issuance to fail.

---

## 4. Access & Credentials Prerequisites

1. **Root Access on Fresh VPS:**
   - Initial root credentials or provider-injected SSH public key.
2. **Local SSH Keypair:**
   - A modern Ed25519 key generated on your local workstation:
     ```bash
     ssh-keygen -t ed25519 -C "admin@vps-infrastructure"
     ```
3. **GitHub Account & Repository:**
   - Permissions to create repository secrets and push images to GitHub Packages / Container Registry (`ghcr.io`).
4. **Google Account (for Remote Backups):**
   - Access to Google Drive and Google Cloud Console to create an OAuth Client ID for `rclone` (see [docs/backup-recovery/google-drive.md](../backup-recovery/google-drive.md)).

---

## 5. Workstation Tools

Ensure the following tools are installed on your local computer or operator terminal:

- **Git** (v2.30+)
- **Make** (GNU Make)
- **Bash** (v4.0+)
- **OpenSSH Client** (`ssh`, `scp`)
- **cURL**

---

## 6. Next Steps

Once the VPS is launched and DNS records are configured:
- Proceed to [docs/getting-started/initial-server-setup.md](initial-server-setup.md) to perform the initial login, configure the operator user, and run preflight checks.
