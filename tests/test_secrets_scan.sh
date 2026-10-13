#!/usr/bin/env bash
# ==============================================================================
# test_secrets_scan.sh — Verify Zero Secrets in Repository
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/tests/test_runner.sh"

suite_header "Zero Secrets Repository Audit"

# Test 1: Check for committed private key blocks
private_keys_found=0
if git -C "${REPO_ROOT}" grep -IE 'BEGIN [A-Z ]*PRIVATE KEY' -- ':!tests/' ':!.scratch/' >/dev/null 2>&1; then
    private_keys_found=1
fi
assert_eq 0 "${private_keys_found}" "No private key blocks (RSA/ED25519) committed"

# Test 2: Check for real .env files accidentally tracked in git
tracked_env_files=$(git -C "${REPO_ROOT}" ls-files '*.env' ':!*.example.env' || true)
assert_eq "" "${tracked_env_files}" "No real .env files tracked in Git"

# Test 3: Check for rclone config or credentials files
tracked_rclone_files=$(git -C "${REPO_ROOT}" ls-files 'rclone.conf' '*.rclone*' || true)
assert_eq "" "${tracked_rclone_files}" "No rclone configuration files tracked in Git"

# Test 4: Check for hardcoded password assignments in scripts (e.g., PASSWORD="actual_secret")
# Allowed: placeholder patterns like PASSWORD="" or ${PASSWORD:-}
hardcoded_passwords_found=0
if git -C "${REPO_ROOT}" grep -nIE '(PASSWORD|SECRET|API_KEY|APP_KEY)=["\x27][^"\x27]{6,}["\x27]' \
    -- 'scripts/' ':!scripts/common.sh' ':!tests/' ':!config/*.example.env' >/dev/null 2>&1; then
    hardcoded_passwords_found=1
fi
assert_eq 0 "${hardcoded_passwords_found}" "No hardcoded secrets or credentials in scripts"

finish_suite
