#!/usr/bin/env bash
# ==============================================================================
# tests/test_docs_and_repo_integrity.sh
# Tests documentation presence, Markdown link integrity, and repo hygiene
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source test harness
source "${REPO_ROOT}/tests/test_runner.sh"

suite_header "Documentation and Repository Integrity"

# 1. Required categorized documentation suite existence and substance
DOC_FILES=(
  "docs/architecture/architecture.md"
  "docs/architecture/security.md"
  "docs/getting-started/prerequisites.md"
  "docs/getting-started/initial-server-setup.md"
  "docs/platform/coolify.md"
  "docs/platform/github-actions-ghcr.md"
  "docs/backup-recovery/backups.md"
  "docs/backup-recovery/google-drive.md"
  "docs/backup-recovery/restore-and-disaster-recovery.md"
  "docs/operations/monitoring.md"
  "docs/operations/troubleshooting.md"
  "docs/specs/PROJECT_BRIEF.md"
  "docs/specs/ANTIGRAVITY_PROMPT.md"
  "docs/fa/README.md"
  "README.md"
  "AGENTS.md"
  "CHANGELOG.md"
)

for doc in "${DOC_FILES[@]}"; do
  assert_file_exists "${REPO_ROOT}/${doc}" "${doc} exists"
  if [[ -f "${REPO_ROOT}/${doc}" ]]; then
    file_size=$(wc -c < "${REPO_ROOT}/${doc}" | tr -d ' ')
    if [[ "$file_size" -ge 100 ]]; then
      TOTAL_TESTS=$((TOTAL_TESTS + 1))
      PASSED_TESTS=$((PASSED_TESTS + 1))
      printf "  ${T_GREEN}✓ PASS:${T_RESET} %s has substantive content (%d bytes)\n" "${doc}" "${file_size}"
    else
      TOTAL_TESTS=$((TOTAL_TESTS + 1))
      FAILED_TESTS=$((FAILED_TESTS + 1))
      printf "  ${T_RED}✗ FAIL:${T_RESET} %s is too short or empty (%d bytes)\n" "${doc}" "${file_size}"
    fi
  fi
done

# 2. README.md structure checks
README_FILE="${REPO_ROOT}/README.md"
if [[ -f "$README_FILE" ]]; then
  readme_content=$(cat "$README_FILE")
  assert_contains "Architecture" "$readme_content" "README.md references Architecture"
  assert_contains "Quickstart" "$readme_content" "README.md references Quickstart"
  assert_contains "make check" "$readme_content" "README.md documents make check"
  assert_contains "make preflight" "$readme_content" "README.md documents make preflight"
  assert_contains "make bootstrap" "$readme_content" "README.md documents make bootstrap"
  assert_contains "make harden" "$readme_content" "README.md documents make harden"
  assert_contains "Persian Documentation" "$readme_content" "README.md links to Persian guide"
  assert_contains "CHANGELOG.md" "$readme_content" "README.md links to CHANGELOG.md"
fi

# 3. AGENTS.md preserved structure & Changelog rule
AGENTS_FILE="${REPO_ROOT}/AGENTS.md"
if [[ -f "$AGENTS_FILE" ]]; then
  agents_content=$(cat "$AGENTS_FILE")
  assert_contains "## Agent skills" "$agents_content" "AGENTS.md strictly preserves ## Agent skills block"
  assert_contains "Issue tracker" "$agents_content" "AGENTS.md preserves Issue tracker description"
  assert_contains "Triage labels" "$agents_content" "AGENTS.md preserves Triage labels description"
  assert_contains "Domain docs" "$agents_content" "AGENTS.md preserves Domain docs description"
  assert_contains "Changelog Protocol" "$agents_content" "AGENTS.md includes Changelog Protocol rule"
fi

# 4. CHANGELOG.md format checks
CHANGELOG_FILE="${REPO_ROOT}/CHANGELOG.md"
if [[ -f "$CHANGELOG_FILE" ]]; then
  changelog_content=$(cat "$CHANGELOG_FILE")
  assert_contains "Keep a Changelog" "$changelog_content" "CHANGELOG.md references Keep a Changelog standard"
  assert_contains "[1.0.0]" "$changelog_content" "CHANGELOG.md contains [1.0.0] release"
  assert_contains "[Unreleased]" "$changelog_content" "CHANGELOG.md contains [Unreleased] section"
fi

# 5. Markdown link verification (checks local relative file links in docs/ and README.md)
broken_links=0
tested_links=0
while IFS= read -r md_file; do
  md_dir="$(dirname "$md_file")"
  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    clean_target="${link%%#*}"
    clean_target="${clean_target%%\?*}"
    [[ -z "$clean_target" ]] && continue

    if [[ "$clean_target" == /* ]]; then
      resolved_target="${REPO_ROOT}${clean_target}"
    else
      resolved_target="${md_dir}/${clean_target}"
    fi

    tested_links=$((tested_links + 1))
    if [[ ! -e "$resolved_target" ]]; then
      printf "  ${T_RED}✗ FAIL:${T_RESET} Broken link in %s: '%s' -> %s\n" "$(basename "$md_file")" "$link" "$resolved_target"
      broken_links=$((broken_links + 1))
    fi
  done < <(grep -o -E '\[[^]]+\]\([^)]+\)' "$md_file" | sed -E 's/.*\]\(([^)]+)\)/\1/' | grep -v -E '^(http|https|mailto:|#|file:)' || true)
done < <(find "${REPO_ROOT}/docs" -name "*.md"; echo "${REPO_ROOT}/README.md")

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if [[ "$broken_links" -eq 0 && "$tested_links" -gt 0 ]]; then
  PASSED_TESTS=$((PASSED_TESTS + 1))
  printf "  ${T_GREEN}✓ PASS:${T_RESET} Verified %d internal Markdown links, 0 broken\n" "$tested_links"
elif [[ "$broken_links" -gt 0 ]]; then
  FAILED_TESTS=$((FAILED_TESTS + 1))
  printf "  ${T_RED}✗ FAIL:${T_RESET} Found %d broken internal Markdown links\n" "$broken_links"
else
  PASSED_TESTS=$((PASSED_TESTS + 1))
  printf "  ${T_GREEN}✓ PASS:${T_RESET} No internal Markdown links found to verify\n"
fi

finish_suite
