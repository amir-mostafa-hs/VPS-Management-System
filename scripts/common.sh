#!/usr/bin/env bash
# ==============================================================================
# common.sh — Shared Helper Library for VPS Infrastructure Scripts
# ==============================================================================

set -euo pipefail

# Text styling and color codes (disabled if stdout is not a terminal)
if [[ -t 1 ]]; then
    readonly C_RESET='\033[0m'
    readonly C_BOLD='\033[1m'
    readonly C_RED='\033[0;31m'
    readonly C_GREEN='\033[0;32m'
    readonly C_YELLOW='\033[0;33m'
    readonly C_BLUE='\033[0;34m'
    readonly C_CYAN='\033[0;36m'
else
    readonly C_RESET=''
    readonly C_BOLD=''
    readonly C_RED=''
    readonly C_GREEN=''
    readonly C_YELLOW=''
    readonly C_BLUE=''
    readonly C_CYAN=''
fi

# Logging functions
log_info() {
    printf "${C_BLUE}${C_BOLD}[INFO]${C_RESET} %s\n" "$*" >&2
}

log_success() {
    printf "${C_GREEN}${C_BOLD}[OK]${C_RESET} %s\n" "$*" >&2
}

log_warn() {
    printf "${C_YELLOW}${C_BOLD}[WARN]${C_RESET} %s\n" "$*" >&2
}

log_error() {
    printf "${C_RED}${C_BOLD}[ERROR]${C_RESET} %s\n" "$*" >&2
}

log_err() {
    log_error "$@"
}

log_step() {
    printf "\n${C_CYAN}${C_BOLD}===> %s${C_RESET}\n" "$*" >&2
}

# Privilege assertion
require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_error "This command requires administrative (root) privileges."
        log_error "Please run again using: sudo $0 $*"
        exit 1
    fi
}

# Command existence assertion
assert_cmd_exists() {
    local cmd="$1"
    local hint="${2:-Please install it before proceeding.}"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        log_error "Required command '${cmd}' is not found in PATH."
        log_error "${hint}"
        return 1
    fi
    return 0
}

# Hardware probing helpers
get_total_ram_mb() {
    if [[ -f /proc/meminfo ]]; then
        local ram_kb
        ram_kb=$(grep -E '^MemTotal:' /proc/meminfo | awk '{print $2}')
        echo "$((ram_kb / 1024))"
    elif command -v sysctl >/dev/null 2>&1; then
        local ram_bytes
        ram_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
        echo "$((ram_bytes / 1024 / 1024))"
    else
        echo "0"
    fi
}

get_cpu_cores() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
    elif command -v sysctl >/dev/null 2>&1; then
        sysctl -n hw.ncpu 2>/dev/null || echo "1"
    elif [[ -f /proc/cpuinfo ]]; then
        grep -c '^processor' /proc/cpuinfo || echo "1"
    else
        echo "1"
    fi
}

# Operator confirmation helper
confirm_action() {
    local prompt_msg="$1"
    local default_ans="${2:-N}"
    local force_flag="${FORCE_YES:-false}"

    if [[ "${force_flag}" == "true" ]]; then
        log_info "Automatic confirmation enabled (--yes)."
        return 0
    fi

    local prompt_suffix="[y/N]"
    if [[ "${default_ans}" =~ ^[Yy]$ ]]; then
        prompt_suffix="[Y/n]"
    fi

    printf "${C_YELLOW}${C_BOLD}%s %s: ${C_RESET}" "${prompt_msg}" "${prompt_suffix}"
    read -r response
    response="${response:-${default_ans}}"

    if [[ "${response}" =~ ^[Yy]$ ]]; then
        return 0
    fi
    return 1
}

# Trap error handler
error_handler() {
    local exit_code="$1"
    local line_no="$2"
    log_error "Script terminated with exit code ${exit_code} on line ${line_no}."
}

trap 'error_handler $? $LINENO' ERR
