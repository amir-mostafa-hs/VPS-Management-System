#!/usr/bin/env bash
# ==============================================================================
# test_health_check.sh — Test Lightweight Health Monitoring Script
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/tests/test_runner.sh"

suite_header "Lightweight Host and Container Health Monitoring"

# Test 1: Files exist
assert_file_exists "${REPO_ROOT}/scripts/health-check.sh" "scripts/health-check.sh exists"
assert_file_executable "${REPO_ROOT}/scripts/health-check.sh" "scripts/health-check.sh is executable"
assert_file_exists "${REPO_ROOT}/docs/operations/monitoring.md" "docs/operations/monitoring.md exists"
assert_file_exists "${REPO_ROOT}/monitoring/README.md" "monitoring/README.md exists"

# Test 2: CLI --help contract
health_help=$(bash "${REPO_ROOT}/scripts/health-check.sh" --help 2>&1 || true)
assert_contains "Usage:" "${health_help}" "health-check.sh --help displays usage"

# Test 3: Simulation threshold testing
# Normal disk (50% full) -> OK (exit 0)
out_ok=$(SIMULATED_DISK_PCT=50 SIMULATED_MEM_PCT=40 SKIP_DOCKER_CHECK=true bash "${REPO_ROOT}/scripts/health-check.sh" 2>&1)
assert_exit_code 0 $? "health-check returns 0 for healthy resource usage (50%)"
assert_contains "Disk Usage" "${out_ok}" "health-check outputs disk usage metric"

# High disk (85% full) -> WARNING (exit 1)
if SIMULATED_DISK_PCT=85 SIMULATED_MEM_PCT=40 SKIP_DOCKER_CHECK=true bash "${REPO_ROOT}/scripts/health-check.sh" >/dev/null 2>&1; then
    assert_eq 1 0 "health-check flags 85% disk usage as warning"
else
    assert_eq 1 1 "health-check flags 85% disk usage as warning"
fi

# Critical disk (95% full) -> CRITICAL (exit 2)
set +e
SIMULATED_DISK_PCT=95 SIMULATED_MEM_PCT=40 SKIP_DOCKER_CHECK=true bash "${REPO_ROOT}/scripts/health-check.sh" >/dev/null 2>&1
crit_exit=$?
set -e
assert_exit_code 2 "${crit_exit}" "health-check returns exit code 2 on critical disk usage (95%)"

# Test 4: JSON Output mode
json_out=$(SIMULATED_DISK_PCT=50 SIMULATED_MEM_PCT=40 SKIP_DOCKER_CHECK=true bash "${REPO_ROOT}/scripts/health-check.sh" --json 2>&1)
assert_contains "\"status\":" "${json_out}" "health-check --json contains status field"
assert_contains "\"disk\":" "${json_out}" "health-check --json contains disk field"
assert_contains "\"memory\":" "${json_out}" "health-check --json contains memory field"

# Test 5: Dry-run mode
dry_run_out=$(SIMULATED_DISK_PCT=50 SIMULATED_MEM_PCT=40 SKIP_DOCKER_CHECK=true bash "${REPO_ROOT}/scripts/health-check.sh" --dry-run 2>&1)
assert_exit_code 0 $? "health-check.sh --dry-run exits with 0"
assert_contains "[DRY-RUN]" "${dry_run_out}" "health-check.sh --dry-run reports dry-run mode"

finish_suite

