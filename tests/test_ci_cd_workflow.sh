#!/usr/bin/env bash
# ==============================================================================
# test_ci_cd_workflow.sh — Test GitHub Actions Workflow and GHCR Documentation
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_ROOT}/tests/test_runner.sh"

suite_header "GitHub Actions CI/CD Pipeline & GHCR Integration"

WORKFLOW_FILE="${REPO_ROOT}/.github/workflows/reusable-docker-build.yml"
DOC_FILE="${REPO_ROOT}/docs/platform/github-actions-ghcr.md"

# Test 1: Files exist
assert_file_exists "${WORKFLOW_FILE}" ".github/workflows/reusable-docker-build.yml exists"
assert_file_exists "${DOC_FILE}" "docs/platform/github-actions-ghcr.md exists"

# Test 2: Workflow content checks
wf_content=$(cat "${WORKFLOW_FILE}" 2>/dev/null || echo "")

assert_contains "packages: write" "${wf_content}" "Workflow grants least-privilege packages: write"
assert_contains "contents: read" "${wf_content}" "Workflow grants least-privilege contents: read"
assert_contains "runs-on: ubuntu-latest" "${wf_content}" "Workflow uses GitHub-hosted runner (ubuntu-latest)"

# Ensure no self-hosted runner directives
if grep -i "self-hosted" "${WORKFLOW_FILE}" >/dev/null 2>&1; then
    assert_eq 0 1 "Workflow strictly avoids self-hosted runners"
else
    assert_eq 0 0 "Workflow strictly avoids self-hosted runners"
fi

# Test 3: Immutable tagging and webhook trigger
assert_contains "github.sha" "${wf_content}" "Workflow tags images with commit SHA"
assert_contains "COOLIFY_DEPLOY_WEBHOOK" "${wf_content}" "Workflow uses secret for Coolify deploy webhook"

# Test 4: Documentation verification
doc_content=$(cat "${DOC_FILE}" 2>/dev/null || echo "")
assert_contains "GHCR" "${doc_content}" "Documentation explains GHCR authentication"
assert_contains "Deploy Webhook" "${doc_content}" "Documentation explains Coolify deploy webhooks"
assert_contains "Rollback" "${doc_content}" "Documentation details rollback procedure to prior commit SHA"

finish_suite

