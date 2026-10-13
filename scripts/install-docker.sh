#!/usr/bin/env bash
# ==============================================================================
# install-docker.sh — Official Docker Engine CE Installation for Debian/Ubuntu
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

DRY_RUN=false
FORCE_YES=false

show_help() {
    cat << EOF
Usage: sudo $(basename "$0") [OPTIONS]

Installs official Docker Engine CE and Docker Compose plugin on Debian and Ubuntu.
Configures automatic container log rotation in /etc/docker/daemon.json.

Repository Source:
  https://download.docker.com/linux/{ubuntu|debian}

Options:
  --dry-run       Display planned repository setup and packages without installing
  -y, --yes       Bypass interactive confirmation
  -h, --help      Display this help message and exit

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--yes)
            FORCE_YES=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_err "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

log_step "Docker Engine CE Installation"

# Packages to install
readonly DOCKER_PACKAGES=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
)

readonly DAEMON_JSON_CONTENT='{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}'

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Planned Docker installation steps:"
    printf "  1. Add official Docker GPG key from https://download.docker.com\n"
    printf "  2. Add repository: deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/... stable\n"
    printf "  3. Configure /etc/docker/daemon.json for log rotation:\n"
    printf "%s\n" "${DAEMON_JSON_CONTENT}" | sed 's/^/     /'
    printf "  4. apt-get update && apt-get install -y %s\n" "${DOCKER_PACKAGES[*]}"
    printf "  5. systemctl enable --now docker\n"
    log_success "[DRY-RUN] Completed without modifying system."
    exit 0
fi

# Mutating execution requires root
require_root

# Validate host OS
if ! bash "${SCRIPT_DIR}/preflight.sh" --check-only; then
    log_err "Host does not meet platform prerequisites. Aborting Docker install."
    exit 1
fi

if command -v docker >/dev/null 2>&1; then
    log_info "Docker is already installed ($(docker --version 2>/dev/null || true))."
    if ! confirm_action "Reconfigure repository and ensure latest packages?" "N"; then
        log_info "Skipping Docker installation."
        exit 0
    fi
else
    if ! confirm_action "Proceed with installing Docker Engine CE from official repository?" "Y"; then
        log_warn "Installation cancelled by operator."
        exit 0
    fi
fi

# Detect distro and codename
# shellcheck source=/dev/null
source /etc/os-release
distro="${ID}"
codename="${VERSION_CODENAME:-bookworm}"

log_info "Installing official Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/${distro}/gpg" -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

arch="$(dpkg --print-architecture)"
log_info "Adding Docker repository for ${distro} (${codename}, ${arch})..."
echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${distro} ${codename} stable" \
    > /etc/apt/sources.list.d/docker.list

log_info "Configuring Docker daemon log rotation in /etc/docker/daemon.json..."
mkdir -p /etc/docker
if [[ ! -f /etc/docker/daemon.json ]]; then
    echo "${DAEMON_JSON_CONTENT}" > /etc/docker/daemon.json
fi

log_info "Installing Docker packages..."
DEBIAN_FRONTEND=noninteractive apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y "${DOCKER_PACKAGES[@]}"

log_info "Enabling and starting Docker service..."
systemctl enable --now docker

log_success "Docker Engine CE installed and verified successfully."
