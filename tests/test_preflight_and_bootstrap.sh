#!/usr/bin/env bash
# ==============================================================================
# test_preflight_and_bootstrap.sh — Test Preflight and Bootstrap Scripts
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/tests/test_runner.sh"

suite_header "Preflight Diagnostics and System Bootstrap"

# Test 1: preflight.sh exists and is executable
assert_file_exists "${REPO_ROOT}/scripts/preflight.sh" "scripts/preflight.sh exists"
assert_file_executable "${REPO_ROOT}/scripts/preflight.sh" "scripts/preflight.sh is executable"

# Test 2: bootstrap.sh exists and is executable
assert_file_exists "${REPO_ROOT}/scripts/bootstrap.sh" "scripts/bootstrap.sh exists"
assert_file_executable "${REPO_ROOT}/scripts/bootstrap.sh" "scripts/bootstrap.sh is executable"

# Test 3: CLI --help contracts
preflight_help=$(bash "${REPO_ROOT}/scripts/preflight.sh" --help 2>&1 || true)
assert_contains "Usage:" "${preflight_help}" "preflight.sh --help displays usage"

bootstrap_help=$(bash "${REPO_ROOT}/scripts/bootstrap.sh" --help 2>&1 || true)
assert_contains "Usage:" "${bootstrap_help}" "bootstrap.sh --help displays usage"

# Test 4: Preflight OS validation using temporary mock os-release files
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "${MOCK_DIR}"' EXIT

# 4a: Ubuntu 24.04 (Supported)
cat << 'EOF' > "${MOCK_DIR}/os-release-ubuntu-24"
ID=ubuntu
VERSION_ID="24.04"
NAME="Ubuntu"
EOF
out_u24=$(OS_RELEASE_PATH="${MOCK_DIR}/os-release-ubuntu-24" ARCH_OVERRIDE="x86_64" bash "${REPO_ROOT}/scripts/preflight.sh" --check-only 2>&1)
assert_exit_code 0 $? "preflight detects Ubuntu 24.04 as supported"

# 4b: Debian 12 (Supported)
cat << 'EOF' > "${MOCK_DIR}/os-release-debian-12"
ID=debian
VERSION_ID="12"
NAME="Debian GNU/Linux"
EOF
out_deb12=$(OS_RELEASE_PATH="${MOCK_DIR}/os-release-debian-12" ARCH_OVERRIDE="aarch64" bash "${REPO_ROOT}/scripts/preflight.sh" --check-only 2>&1)
assert_exit_code 0 $? "preflight detects Debian 12 as supported"

# 4c: Debian 13 (Supported)
cat << 'EOF' > "${MOCK_DIR}/os-release-debian-13"
ID=debian
VERSION_ID="13"
NAME="Debian GNU/Linux"
EOF
out_deb13=$(OS_RELEASE_PATH="${MOCK_DIR}/os-release-debian-13" ARCH_OVERRIDE="x86_64" bash "${REPO_ROOT}/scripts/preflight.sh" --check-only 2>&1)
assert_exit_code 0 $? "preflight detects Debian 13 as supported"

# 4d: CentOS 7 (Unsupported - must fail closed)
cat << 'EOF' > "${MOCK_DIR}/os-release-centos"
ID=centos
VERSION_ID="7"
NAME="CentOS Linux"
EOF
if OS_RELEASE_PATH="${MOCK_DIR}/os-release-centos" ARCH_OVERRIDE="x86_64" bash "${REPO_ROOT}/scripts/preflight.sh" --check-only >/dev/null 2>&1; then
    assert_eq 1 0 "preflight correctly rejects unsupported OS (CentOS)"
else
    assert_eq 1 1 "preflight correctly rejects unsupported OS (CentOS)"
fi

# Test 5: Bootstrap --dry-run safety
bootstrap_dry_run=$(bash "${REPO_ROOT}/scripts/bootstrap.sh" --dry-run 2>&1)
assert_exit_code 0 $? "bootstrap.sh --dry-run exits with 0"
assert_contains "apt-get update" "${bootstrap_dry_run}" "bootstrap.sh --dry-run displays planned apt-get update"
assert_contains "curl" "${bootstrap_dry_run}" "bootstrap.sh --dry-run plans installation of curl"
assert_contains "ufw" "${bootstrap_dry_run}" "bootstrap.sh --dry-run plans installation of ufw"
assert_contains "rclone" "${bootstrap_dry_run}" "bootstrap.sh --dry-run plans installation of rclone"

finish_suite

