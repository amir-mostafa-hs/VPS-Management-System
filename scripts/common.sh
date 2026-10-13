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

log_err() {
    printf "${C_RED}${C_BOLD}[ERROR]${C_RESET} %s\n" "$*" >&2
}

log_step() {
    printf "\n${C_CYAN}${C_BOLD}===> %s${C_RESET}\n" "$*" >&2
}

# Privilege assertion
require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        log_err "This command requires administrative (root) privileges."
        log_err "Please run again using: sudo $0 $*"
        exit 1
    fi
}

# Command existence assertion
assert_cmd_exists() {
    local cmd="$1"
    local hint="${2:-Please install it before proceeding.}"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        log_err "Required command '${cmd}' is not found in PATH."
        log_err "${hint}"
        return 1
    fi
    return 0
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
    log_err "Script terminated with exit code ${exit_code} on line ${line_no}."
}

trap 'error_handler $? $LINENO' ERR
