#!/usr/bin/env bash
# ==============================================================================
# test_docker_and_coolify_install.sh — Test Docker and Coolify Setup Scripts
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/tests/test_runner.sh"

suite_header "Docker Engine and Coolify Setup Automation"

# Test 1: Scripts exist and are executable
assert_file_exists "${REPO_ROOT}/scripts/install-docker.sh" "scripts/install-docker.sh exists"
assert_file_executable "${REPO_ROOT}/scripts/install-docker.sh" "scripts/install-docker.sh is executable"
assert_file_exists "${REPO_ROOT}/scripts/install-coolify.sh" "scripts/install-coolify.sh exists"
assert_file_executable "${REPO_ROOT}/scripts/install-coolify.sh" "scripts/install-coolify.sh is executable"

# Test 2: CLI --help contracts
docker_help=$(bash "${REPO_ROOT}/scripts/install-docker.sh" --help 2>&1 || true)
assert_contains "Usage:" "${docker_help}" "install-docker.sh --help displays usage"

coolify_help=$(bash "${REPO_ROOT}/scripts/install-coolify.sh" --help 2>&1 || true)
assert_contains "Usage:" "${coolify_help}" "install-coolify.sh --help displays usage"

# Test 3: install-docker.sh --dry-run safety
docker_dry_run=$(bash "${REPO_ROOT}/scripts/install-docker.sh" --dry-run 2>&1)
assert_exit_code 0 $? "install-docker.sh --dry-run exits with 0"
assert_contains "download.docker.com" "${docker_dry_run}" "install-docker plans official download.docker.com repo"
assert_contains "docker-ce" "${docker_dry_run}" "install-docker plans installing docker-ce"
assert_contains "daemon.json" "${docker_dry_run}" "install-docker plans log-rotation daemon.json config"
assert_contains "max-size" "${docker_dry_run}" "install-docker daemon.json specifies max-size log rotation"

# Test 4: install-coolify.sh --dry-run safety
coolify_dry_run=$(bash "${REPO_ROOT}/scripts/install-coolify.sh" --dry-run 2>&1)
assert_exit_code 0 $? "install-coolify.sh --dry-run exits with 0"
assert_contains "https://cdn.coolify.io/coolify/install.sh" "${coolify_dry_run}" "install-coolify inspects official install URL"
assert_contains "APP_KEY" "${coolify_dry_run}" "install-coolify warns about saving APP_KEY"

# Test 5: install-coolify.sh fails closed on memory < 1GB
if SIMULATED_RAM_MB=512 bash "${REPO_ROOT}/scripts/install-coolify.sh" --check-prereqs-only >/dev/null 2>&1; then
    assert_eq 1 0 "install-coolify rejects host with < 1GB RAM"
else
    assert_eq 1 1 "install-coolify rejects host with < 1GB RAM"
fi

finish_suite

