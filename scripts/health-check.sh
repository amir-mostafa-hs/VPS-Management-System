#!/usr/bin/env bash
# ==============================================================================
# health-check.sh — Lightweight Host and Container Health Monitoring
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

JSON_MODE=false
SKIP_DOCKER_CHECK="${SKIP_DOCKER_CHECK:-false}"

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Lightweight host and container health inspection utility.
Evaluates disk space, memory pressure, Docker daemon responsiveness,
and running container health status.

Exit Codes:
  0 - OK (All metrics healthy)
  1 - WARNING (Resource usage > 80%)
  2 - CRITICAL (Resource usage > 90% or service down)

Options:
  --json          Output diagnostic report in parseable JSON
  -h, --help      Display this help message and exit

EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            JSON_MODE=true
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

# Metric 1: Disk usage percentage
disk_pct=0
if [[ -n "${SIMULATED_DISK_PCT:-}" ]]; then
    disk_pct="${SIMULATED_DISK_PCT}"
else
    # Best-effort root or current mount disk pct
    disk_pct=$(df -k . | awk 'NR==2 {gsub("%","",$5); print $5}')
fi

# Metric 2: Memory usage percentage
mem_pct=0
if [[ -n "${SIMULATED_MEM_PCT:-}" ]]; then
    mem_pct="${SIMULATED_MEM_PCT}"
elif [[ -f /proc/meminfo ]]; then
    total_mem=$(grep -E '^MemTotal:' /proc/meminfo | awk '{print $2}')
    avail_mem=$(grep -E '^MemAvailable:' /proc/meminfo | awk '{print $2}')
    if [[ "${total_mem}" -gt 0 ]]; then
        used_mem=$((total_mem - avail_mem))
        mem_pct=$(( (used_mem * 100) / total_mem ))
    fi
fi

# Metric 3: Docker daemon and container status
docker_status="ok"
unhealthy_containers=""
if [[ "${SKIP_DOCKER_CHECK}" != "true" ]]; then
    if command -v docker >/dev/null 2>&1; then
        if ! docker info >/dev/null 2>&1; then
            docker_status="unresponsive"
        else
            unhealthy_containers=$(docker ps --filter "health=unhealthy" --format '{{.Names}}' 2>/dev/null || true)
            restarting_containers=$(docker ps --filter "status=restarting" --format '{{.Names}}' 2>/dev/null || true)
            if [[ -n "${restarting_containers}" ]]; then
                unhealthy_containers="${unhealthy_containers} ${restarting_containers}"
            fi
        fi
    else
        docker_status="not_installed"
    fi
fi

# Determine Overall Status & Exit Code
status="OK"
exit_code=0

if [[ "${disk_pct}" -ge 90 || "${mem_pct}" -ge 90 || "${docker_status}" == "unresponsive" || -n "${unhealthy_containers}" ]]; then
    status="CRITICAL"
    exit_code=2
elif [[ "${disk_pct}" -ge 80 || "${mem_pct}" -ge 80 ]]; then
    status="WARNING"
    exit_code=1
fi

if [[ "${JSON_MODE}" == "true" ]]; then
    cat << EOF
{
  "status": "${status}",
  "exit_code": ${exit_code},
  "disk": {
    "usage_pct": ${disk_pct}
  },
  "memory": {
    "usage_pct": ${mem_pct}
  },
  "docker": {
    "daemon": "${docker_status}",
    "unhealthy_containers": "${unhealthy_containers}"
  }
}
EOF
    exit "${exit_code}"
fi

# Visual report
log_step "Host & Container Health Inspection"

printf "  %-22s : %s%%\n" "Disk Usage" "${disk_pct}"
if [[ "${disk_pct}" -ge 90 ]]; then
    log_err "Disk usage is CRITICAL (> 90%). Clean old logs or expand storage."
elif [[ "${disk_pct}" -ge 80 ]]; then
    log_warn "Disk usage is high (> 80%)."
else
    log_success "Disk usage healthy."
fi

printf "  %-22s : %s%%\n" "Memory Usage" "${mem_pct}"
if [[ "${mem_pct}" -ge 90 ]]; then
    log_err "Memory usage is CRITICAL (> 90%). Investigate runaway processes."
elif [[ "${mem_pct}" -ge 80 ]]; then
    log_warn "Memory usage is elevated (> 80%)."
else
    log_success "Memory usage healthy."
fi

printf "  %-22s : %s\n" "Docker Daemon" "${docker_status}"
if [[ "${docker_status}" == "ok" ]]; then
    log_success "Docker daemon responsive."
    if [[ -n "${unhealthy_containers}" ]]; then
        log_err "Unhealthy containers detected: ${unhealthy_containers}"
    else
        log_success "All container health checks passing."
    fi
elif [[ "${docker_status}" == "unresponsive" ]]; then
    log_err "Docker daemon is unresponsive or stopped!"
fi

printf "\n${C_BOLD}Overall Health Status: ${C_RESET}"
case "${status}" in
    OK)
        printf "${C_GREEN}${C_BOLD}OK${C_RESET}\n\n"
        ;;
    WARNING)
        printf "${C_YELLOW}${C_BOLD}WARNING${C_RESET}\n\n"
        ;;
    CRITICAL)
        printf "${C_RED}${C_BOLD}CRITICAL${C_RESET}\n\n"
        ;;
esac

exit "${exit_code}"
