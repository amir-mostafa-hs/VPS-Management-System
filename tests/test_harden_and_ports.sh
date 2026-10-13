#!/usr/bin/env bash
# ==============================================================================
# test_harden_and_ports.sh — Test Server Hardening and Dynamic Port Configuration
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/tests/test_runner.sh"

suite_header "Host Hardening and Configurable Firewall"

# Test 1: Configuration files exist
assert_file_exists "${REPO_ROOT}/config/server.example.env" "config/server.example.env exists"
assert_file_exists "${REPO_ROOT}/config/allowed_ports.conf" "config/allowed_ports.conf exists"

# Test 2: harden-server.sh exists and is executable
assert_file_exists "${REPO_ROOT}/scripts/harden-server.sh" "scripts/harden-server.sh exists"
assert_file_executable "${REPO_ROOT}/scripts/harden-server.sh" "scripts/harden-server.sh is executable"

# Test 3: CLI --help contract
harden_help=$(bash "${REPO_ROOT}/scripts/harden-server.sh" --help 2>&1 || true)
assert_contains "Usage:" "${harden_help}" "harden-server.sh --help displays usage"

# Test 4: Dynamic port parser testing with mock file
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "${MOCK_DIR}"' EXIT

cat << 'EOF' > "${MOCK_DIR}/mock_ports.conf"
# This is a comment
8080/tcp     Web service
53/udp       DNS lookup
9000         Defaults to tcp
   # Indented comment
  3000/tcp   Node app
EOF

parsed_ports=$(PORTS_CONFIG_PATH="${MOCK_DIR}/mock_ports.conf" bash "${REPO_ROOT}/scripts/harden-server.sh" --parse-ports-only 2>&1)
assert_contains "8080/tcp" "${parsed_ports}" "Parser extracted 8080/tcp"
assert_contains "53/udp" "${parsed_ports}" "Parser extracted 53/udp"
assert_contains "9000/tcp" "${parsed_ports}" "Parser added default /tcp to port 9000"
assert_contains "3000/tcp" "${parsed_ports}" "Parser extracted indented 3000/tcp"

# Test 5: Dry-run execution generates planned UFW allow rules for base and custom ports
dry_run_out=$(PORTS_CONFIG_PATH="${MOCK_DIR}/mock_ports.conf" SSH_PORT="22" bash "${REPO_ROOT}/scripts/harden-server.sh" --dry-run 2>&1)
assert_exit_code 0 $? "harden-server.sh --dry-run exits with 0"
assert_contains "ufw default deny incoming" "${dry_run_out}" "Dry-run plans default deny incoming"
assert_contains "ufw default allow outgoing" "${dry_run_out}" "Dry-run plans default allow outgoing"
assert_contains "ufw allow 22/tcp" "${dry_run_out}" "Dry-run plans allowing SSH (22/tcp)"
assert_contains "ufw allow 80/tcp" "${dry_run_out}" "Dry-run plans allowing HTTP (80/tcp)"
assert_contains "ufw allow 443/tcp" "${dry_run_out}" "Dry-run plans allowing HTTPS (443/tcp)"
assert_contains "ufw allow 8000/tcp" "${dry_run_out}" "Dry-run plans allowing Coolify UI (8000/tcp)"
assert_contains "ufw allow 8080/tcp" "${dry_run_out}" "Dry-run plans allowing custom port 8080/tcp"
assert_contains "ufw allow 53/udp" "${dry_run_out}" "Dry-run plans allowing custom port 53/udp"

finish_suite
