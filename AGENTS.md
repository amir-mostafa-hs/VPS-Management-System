## Agent skills

### Issue tracker

Issues and specs live as markdown files under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default triage label vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout (`GLOSSARY.md` + `docs/adr/` at the repo root). See `docs/agents/domain.md`.

---

## Developer and Agent Guidelines

### 1. Repository Purpose & Architecture
This repository (`vps-infrastructure`) manages single-node Linux Virtual Private Servers running Coolify PaaS.
Key architectural principles:
- **Offloaded Builds:** Build compute is 100% offloaded to GitHub Actions and GHCR. The VPS never runs `docker build`.
- **Zero Secrets in Git:** No private keys, active tokens, passwords, or live `.env` files are committed.
- **Two-Tier Encrypted Backups:** Client-side encryption (`rclone crypt`) before uploading to Google Drive.
- **Unified Interface:** All operator tasks and quality gates must be exposed via `Makefile`.

### 2. Bash Scripting Standards
All operational shell scripts under `scripts/` must adhere to these standards:
- Always use `#!/usr/bin/env bash` with `set -euo pipefail`.
- Always source `scripts/common.sh` for logging (`log_info`, `log_warn`, `log_error`, `log_success`).
- Always support `--help` and `--dry-run` options.
- The `--dry-run` flag must be completely non-destructive and executable without root privileges (the "dry-run seam" allows test suites to execute cleanly on local workstations and CI).
- Quote all variables to prevent word splitting: `"${VAR}"`.
- Ensure all scripts under both `scripts/` and `tests/` pass `bash -n` syntax validation and `shellcheck` (where available).

### 3. Testing Standards (TDD)
- All new features and scripts must have corresponding unit and contract tests in `tests/`.
- Use the pure bash test runner `tests/test_runner.sh` (`assert_eq`, `assert_exit_code`, `assert_contains`, `assert_file_exists`, `assert_file_executable`).
- Tests must be offline: they must never make live network calls, connect to real VPS instances, or write to root filesystems.
- Every test must pass cleanly via `make test` and `make check`.

### 4. Documentation Standards
- Keep documentation organized under `docs/` subdirectories (`getting-started/`, `architecture/`, `platform/`, `backup-recovery/`, `operations/`, `specs/`, `fa/`).
- Ensure all internal Markdown links use relative paths and resolve to valid files.
- Run `tests/test_docs_and_repo_integrity.sh` to verify documentation completeness and link integrity.

### 5. Changelog Protocol
- Whenever any decision is implemented, architectural modification is made, or feature/fix is added, developers and agents MUST record a concise summary in `CHANGELOG.md` under `[Unreleased]` or the corresponding version header.
- Maintain format according to the [Keep a Changelog](https://keepachangelog.com/) standard (`Added`, `Changed`, `Fixed`, `Security`).
