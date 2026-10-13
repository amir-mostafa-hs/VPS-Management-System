#!/usr/bin/env bash
# ==============================================================================
# test_runner.sh — Pure Bash TDD Testing Framework
# ==============================================================================

set -euo pipefail

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Color formatting
if [[ -t 1 ]]; then
    readonly T_RESET='\033[0m'
    readonly T_BOLD='\033[1m'
    readonly T_GREEN='\033[0;32m'
    readonly T_RED='\033[0;31m'
    readonly T_YELLOW='\033[0;33m'
    readonly T_CYAN='\033[0;36m'
else
    readonly T_RESET=''
    readonly T_BOLD=''
    readonly T_GREEN=''
    readonly T_RED=''
    readonly T_YELLOW=''
    readonly T_CYAN=''
fi

suite_header() {
    local suite_name="$1"
    printf "\n${T_CYAN}${T_BOLD}=== Running Suite: %s ===${T_RESET}\n" "${suite_name}"
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local desc="$3"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [[ "${expected}" == "${actual}" ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        printf "  ${T_GREEN}✓ PASS:${T_RESET} %s\n" "${desc}"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        printf "  ${T_RED}✗ FAIL:${T_RESET} %s\n" "${desc}"
        printf "    Expected: '%s'\n" "${expected}"
        printf "    Actual:   '%s'\n" "${actual}"
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local actual_code="$2"
    local desc="$3"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [[ "${expected_code}" -eq "${actual_code}" ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        printf "  ${T_GREEN}✓ PASS:${T_RESET} %s (exit code %d)\n" "${desc}" "${actual_code}"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        printf "  ${T_RED}✗ FAIL:${T_RESET} %s\n" "${desc}"
        printf "    Expected exit code: %d\n" "${expected_code}"
        printf "    Actual exit code:   %d\n" "${actual_code}"
    fi
}

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local desc="$3"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [[ "${haystack}" == *"${needle}"* ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        printf "  ${T_GREEN}✓ PASS:${T_RESET} %s\n" "${desc}"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        printf "  ${T_RED}✗ FAIL:${T_RESET} %s\n" "${desc}"
        printf "    Expected output to contain: '%s'\n" "${needle}"
        printf "    Output snippet: '%.100s...'\n" "${haystack}"
    fi
}

assert_file_exists() {
    local filepath="$1"
    local desc="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [[ -f "${filepath}" ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        printf "  ${T_GREEN}✓ PASS:${T_RESET} %s (found %s)\n" "${desc}" "${filepath}"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        printf "  ${T_RED}✗ FAIL:${T_RESET} %s (missing %s)\n" "${desc}" "${filepath}"
    fi
}

assert_file_executable() {
    local filepath="$1"
    local desc="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [[ -x "${filepath}" ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        printf "  ${T_GREEN}✓ PASS:${T_RESET} %s (executable: %s)\n" "${desc}" "${filepath}"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        printf "  ${T_RED}✗ FAIL:${T_RESET} %s (not executable: %s)\n" "${desc}" "${filepath}"
    fi
}

finish_suite() {
    printf "\n${T_BOLD}----------------------------------------${T_RESET}\n"
    printf "Tests: %d total, ${T_GREEN}%d passed${T_RESET}, ${T_RED}%d failed${T_RESET}\n" \
        "${TOTAL_TESTS}" "${PASSED_TESTS}" "${FAILED_TESTS}"

    if [[ "${FAILED_TESTS}" -gt 0 ]]; then
        printf "${T_RED}${T_BOLD}RESULT: FAILED${T_RESET}\n\n"
        return 1
    fi

    printf "${T_GREEN}${T_BOLD}RESULT: ALL PASSED${T_RESET}\n\n"
    return 0
}
