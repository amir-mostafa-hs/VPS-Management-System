#!/usr/bin/env bash
# ==============================================================================
# test_makefile.sh — Validate Makefile Targets and Help Output
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/tests/test_runner.sh"

suite_header "Makefile Targets and Interface Verification"

# Test 1: Makefile exists
assert_file_exists "${REPO_ROOT}/Makefile" "Makefile exists at repository root"

# Test 2: make help returns 0 and displays documented targets
help_output=$(make -C "${REPO_ROOT}" help 2>&1)
assert_exit_code 0 $? "make help command exits with code 0"

# Test 3: check presence of quality targets in help output
assert_contains "check" "${help_output}" "make help documents 'check' target"
assert_contains "test" "${help_output}" "make help documents 'test' target"
assert_contains "lint" "${help_output}" "make help documents 'lint' target"

# Test 4: check presence of operational targets in help output
assert_contains "preflight" "${help_output}" "make help documents 'preflight' target"
assert_contains "bootstrap" "${help_output}" "make help documents 'bootstrap' target"
assert_contains "harden" "${help_output}" "make help documents 'harden' target"
assert_contains "install-docker" "${help_output}" "make help documents 'install-docker' target"
assert_contains "install-coolify" "${help_output}" "make help documents 'install-coolify' target"
assert_contains "backup-setup" "${help_output}" "make help documents 'backup-setup' target"
assert_contains "backup-now" "${help_output}" "make help documents 'backup-now' target"
assert_contains "backup-verify" "${help_output}" "make help documents 'backup-verify' target"
assert_contains "backup-restore" "${help_output}" "make help documents 'backup-restore' target"
assert_contains "health" "${help_output}" "make help documents 'health' target"

finish_suite

