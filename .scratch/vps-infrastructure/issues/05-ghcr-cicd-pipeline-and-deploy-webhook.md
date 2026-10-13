# 05: GitHub Actions CI/CD Template & GHCR Deploy Webhook

**What to build:** A reusable GitHub Actions CI/CD workflow template that builds application Docker images on GitHub-hosted runners, tags them with immutable commit SHAs, publishes them to GHCR with least-privilege permissions, and triggers Coolify application deployment via webhooks, with comprehensive documentation on manual promotion and private registry authentication.

**Blocked by:** 04: Docker Engine and Coolify Setup Automation

**Status:** resolved

## Acceptance Criteria

- [x] `.github/workflows/reusable-docker-build.yml` created demonstrating:
  - Triggering on push to main and tags.
  - Building Docker images using GitHub-hosted runners (no production VPS build).
  - Scoped GitHub token permissions (`packages: write`, `contents: read`).
  - Tagging images with commit SHA (`sha-${{ github.sha }}`) and `latest`.
  - Triggering Coolify's application Deploy Webhook safely.
- [x] `docs/github-actions-ghcr.md` created with:
  - Step-by-step instructions for generating GHCR pull credentials in Coolify without leaking tokens.
  - Instructions for configuring the Deploy Webhook secret.
  - Step-by-step runbook for manual image promotion and instant rollbacks to a previous commit SHA.

## Quality & Test Criteria (TDD Seam)

- **Test File:** `tests/test_ci_cd_workflow.sh`.
- **Verified Behaviors:**
  - YAML Syntax & Schema: Validates `.github/workflows/reusable-docker-build.yml` is valid YAML.
  - Security Audit: Asserts least-privilege permissions are explicitly declared (`packages: write`, `contents: read`), and no hardcoded secrets or tokens exist in workflow files.
  - Offloaded Build Rule: Confirms the workflow uses `runs-on: ubuntu-latest` (GitHub-hosted runner) and contains zero self-hosted runner directives.
  - Webhook URL Safety: Verifies webhook calls use GitHub Secrets references rather than exposed URLs.
  - Regression: `make test` runs and passes.

## Resolution

All acceptance criteria completed. Reusable workflow created with GHCR authentication, commit SHA tagging, Deploy Webhook triggers, and comprehensive documentation in `docs/github-actions-ghcr.md` with 11/11 tests passing.
