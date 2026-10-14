#!/usr/bin/env bash
# ==============================================================================
# preflight.sh — Read-Only Host Diagnostics and Compatibility Verification
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

OS_RELEASE_PATH="${OS_RELEASE_PATH:-/etc/os-release}"
ARCH_OVERRIDE="${ARCH_OVERRIDE:-$(uname -m)}"
CHECK_ONLY=false
JSON_MODE=false
DRY_RUN=false

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Read-only preflight diagnostic utility for validating VPS compatibility
against supported platforms and hardware requirements.

Supported Platforms:
  - Ubuntu 22.04 LTS, Ubuntu 24.04 LTS
  - Debian 12 (Bookworm), Debian 13 (Trixie)
  - Architectures: x86_64, aarch64 (ARM64)

Options:
  --check-only    Perform compatibility assertions and exit (0=supported, 1=unsupported)
  --json          Output diagnostic report in JSON format
  --dry-run       Acknowledge non-destructive dry-run mode (script is inherently read-only)
  -h, --help      Display this help message and exit

EOF
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --json)
            JSON_MODE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY-RUN] Preflight diagnostics is non-destructive and read-only."
fi

# Step 1: Detect and validate OS
is_supported_os=false
os_id="unknown"
os_version="unknown"
os_name="Unknown"

if [[ -f "${OS_RELEASE_PATH}" ]]; then
    # Parse os-release safely
    os_id=$(grep -E '^ID=' "${OS_RELEASE_PATH}" | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "unknown")
    os_version=$(grep -E '^VERSION_ID=' "${OS_RELEASE_PATH}" | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "unknown")
    os_name=$(grep -E '^NAME=' "${OS_RELEASE_PATH}" | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "Unknown")
fi

case "${os_id}" in
    ubuntu)
        if [[ "${os_version}" == "22.04"* || "${os_version}" == "24.04"* ]]; then
            is_supported_os=true
        fi
        ;;
    debian)
        if [[ "${os_version}" == "12"* || "${os_version}" == "13"* ]]; then
            is_supported_os=true
        fi
        ;;
esac

# Step 2: Validate Architecture
is_supported_arch=false
case "${ARCH_OVERRIDE}" in
    x86_64|amd64|aarch64|arm64)
        is_supported_arch=true
        ;;
esac

# Step 3: Gather hardware metrics using common helpers
cpu_cores=$(get_cpu_cores)
total_ram_mb=$(get_total_ram_mb)
disk_avail_human=$(df -h . | awk 'NR==2 {print $4}')

# If JSON mode requested
if [[ "${JSON_MODE}" == "true" ]]; then
    cat << EOF
{
  "os": {
    "id": "${os_id}",
    "name": "${os_name}",
    "version": "${os_version}",
    "supported": ${is_supported_os}
  },
  "arch": {
    "detected": "${ARCH_OVERRIDE}",
    "supported": ${is_supported_arch}
  },
  "hardware": {
    "cpu_cores": ${cpu_cores},
    "ram_mb": ${total_ram_mb},
    "disk_available": "${disk_avail_human}"
  }
}
EOF
    if [[ "${is_supported_os}" == "true" && "${is_supported_arch}" == "true" ]]; then
        exit 0
    else
        exit 1
    fi
fi

# Visual report
log_step "VPS Infrastructure Preflight Diagnostic Report"

printf "  %-22s : %s (%s)\n" "Operating System" "${os_name}" "${os_version}"
if [[ "${is_supported_os}" == "true" ]]; then
    log_success "OS distribution is officially supported."
else
    log_error "OS distribution '${os_id} ${os_version}' is NOT in the supported matrix."
    log_error "Supported OS: Ubuntu 22.04 LTS, Ubuntu 24.04 LTS, Debian 12, Debian 13."
fi

printf "  %-22s : %s\n" "CPU Architecture" "${ARCH_OVERRIDE}"
if [[ "${is_supported_arch}" == "true" ]]; then
    log_success "Architecture is supported (x86_64 / ARM64)."
else
    log_error "Architecture '${ARCH_OVERRIDE}' is NOT supported."
fi

printf "  %-22s : %s cores\n" "CPU Cores" "${cpu_cores}"
printf "  %-22s : %s MB\n" "Total Memory" "${total_ram_mb}"
printf "  %-22s : %s\n" "Disk Space Available" "${disk_avail_human}"

if [[ "${total_ram_mb}" -gt 0 && "${total_ram_mb}" -lt 2000 ]]; then
    log_warn "Host has less than 2GB of RAM (${total_ram_mb} MB). Coolify recommends >= 2GB."
fi

if [[ "${is_supported_os}" == "true" && "${is_supported_arch}" == "true" ]]; then
    log_success "Preflight validation PASSED. Host is ready for bootstrapping."
    exit 0
else
    log_error "Preflight validation FAILED. Host does not meet platform requirements."
    exit 1
fi
