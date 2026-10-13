#!/usr/bin/env bash
# ==============================================================================
# test_scripts_syntax.sh — Validate Bash Syntax and Executable Permissions
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/tests/test_runner.sh"

suite_header "Shell Scripts Syntax and Permissions"

while IFS= read -r script_file; do
    rel_path="${script_file#"${REPO_ROOT}/"}"

    # Verify syntax with bash -n
    if bash -n "${script_file}"; then
        assert_exit_code 0 0 "bash -n syntax validation for ${rel_path}"
    else
        assert_exit_code 0 1 "bash -n syntax validation for ${rel_path}"
    fi

    # Verify executable bit
    assert_file_executable "${script_file}" "Executable bit set for ${rel_path}"
done < <(find "${REPO_ROOT}/scripts" "${REPO_ROOT}/tests" -name "*.sh" -type f 2>/dev/null | sort)

finish_suite
