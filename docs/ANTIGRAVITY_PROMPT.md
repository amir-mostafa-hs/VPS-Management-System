# Antigravity Agent Prompt — VPS Infrastructure Repository

You are the implementation agent for a new repository named `vps-infrastructure`.

## Mission

Prepare the repository completely for safely provisioning and operating a Linux VPS with:

- Coolify as the self-hosted PaaS/control panel.
- GitHub Actions for CI and Docker image builds.
- GitHub Container Registry (GHCR) as the image registry.
- Production deployment by pulling prebuilt images, so the production VPS does **not** build application images.
- Automated, encrypted backups to Google Drive using `rclone`.
- Lightweight host/container health checks, logs, and restore/disaster-recovery documentation.

Your task in this phase is to **prepare and validate the repository**, not to connect to or modify the user's VPS. Do not perform remote provisioning. Do not request or handle real credentials.

## First actions

1. Inspect the repository and all existing files before changing anything.
2. Preserve useful existing work. Do not overwrite user-authored content blindly.
3. Read `AGENTS.md` and any existing project instructions. If none exist, create a concise root `AGENTS.md`.
4. Read `PROJECT_BRIEF.md` in this kit (the user will place it in the repository or provide its contents). Treat it as the source of truth.
5. Verify current installation and configuration details against official documentation, especially Coolify, Docker Engine, GitHub Actions/GHCR, and rclone. Do not rely on memory for version-sensitive commands. Record official references and access dates in the docs.
6. Before making major scope changes, ask the user instead of silently expanding scope.

## Non-negotiable constraints

- Keep this project focused on VPS provisioning and operations; do not turn it into a generic platform or application project.
- The production VPS must not build application images. Preferred flow:
  `Git push -> GitHub Actions -> tests/build -> GHCR -> Coolify pulls and deploys image`.
- Do not install a self-hosted GitHub Actions runner on the production VPS in the default design. Use GitHub-hosted runners unless the user later explicitly chooses otherwise.
- Never commit secrets, private keys, real `.env` files, OAuth tokens, Google Drive credentials, database passwords, or Coolify's `APP_KEY`.
- Do not put secret values in logs, command output, examples, screenshots, or test fixtures.
- Never disable SSH password authentication or root SSH login until key-based access has been verified and the user has explicitly approved the change during the manual VPS phase.
- Never enable a firewall or alter SSH/network rules remotely without a recovery plan and explicit user confirmation.
- Never run destructive actions, delete volumes, prune Docker resources, rotate encryption keys, overwrite backups, or restore data automatically.
- Do not run commands against a real VPS in this phase.
- Scripts must not assume the VPS OS, SSH port, domain, email address, username, or architecture without validating it.
- Avoid unbounded resource usage. Build work belongs on GitHub-hosted Actions by default. Monitoring and backup tasks must be lightweight and scheduled.
- Use supported, documented tools rather than implementing bespoke infrastructure components unnecessarily.
- Keep the implementation understandable, modular, testable, and suitable for a single VPS.
- Do not claim a backup is valid merely because a file exists or upload succeeded; document and implement verification and restore tests.
- Do not promise that Google Drive is an immutable backup. Document account compromise/deletion risks and recommend a separate recovery path for critical data.

## Required repository deliverables

Create or update the repository so that it includes, as appropriate:

- `README.md` — project purpose, supported platforms, quick overview, safe usage warning, phased workflow.
- `AGENTS.md` — repository-specific instructions for future coding agents.
- `docs/PROJECT_BRIEF.md` — copy the supplied project brief into the repository as the authoritative specification.
- `docs/architecture.md` — architecture, data flow, trust boundaries, ports, secrets, and build/deploy flow.
- `docs/prerequisites.md` — supported OS/CPU/RAM/disk/network requirements and preflight checks.
- `docs/initial-server-setup.md` — operator-led, step-by-step first access and provisioning procedure.
- `docs/security.md` — SSH, firewall, updates, least privilege, exposed ports, secrets, and recovery precautions.
- `docs/coolify.md` — official installation route, first-login checklist, domain/TLS, update/rollback considerations.
- `docs/github-actions-ghcr.md` — sample reusable workflow for test/build/push, image naming/tagging, least-privilege permissions, GHCR auth and Coolify deployment trigger options.
- `docs/backups.md` — backup scope, schedule, retention, encryption, verification, failure handling.
- `docs/google-drive.md` — rclone setup, OAuth handling, crypt remote design, upload/list/check workflow, recovery of encryption configuration.
- `docs/monitoring.md` — lightweight host/container/service checks, logs, disk alerts and resource limits.
- `docs/restore-and-disaster-recovery.md` — restore sequence and clean-VPS recovery drill.
- `docs/troubleshooting.md` — common failures and safe diagnostics.
- `config/server.example.env` and `config/backup.example.env` — placeholders only; no secrets.
- `.gitignore` — exclude local environment files, tokens, credentials, backup archives, private keys, and generated state.
- `scripts/` — safe, modular scripts for preflight, bootstrap, hardening, Docker/Coolify installation, backup, verification, restore preparation, and health checks.
- `systemd/` — service/timer examples for scheduled backup, if systemd scheduling is appropriate.
- `backup/README.md` — backup conventions and restore requirements.
- `tests/` — shell lint/static checks and tests for validation, configuration parsing, and safe failure paths.
- `Makefile` or an equivalent simple command interface, with commands such as `make check`, `make lint`, `make test`, and `make help`.
- A license only if appropriate and selected transparently; do not invent ownership or copyright details.

The exact tree may be adjusted if there is a clear reason. Document any deviations. Do not create empty placeholder files that pretend a feature is implemented.

## Script design and safety requirements

- Prefer Bash with strict mode and clear error messages for shell automation; use a shell linter such as ShellCheck when available.
- Validate dependencies, OS, permissions, disk space, network access, configuration, and required variables before making changes.
- Make scripts idempotent where practical. Re-running a script must not duplicate firewall rules, users, scheduled jobs, or configuration blocks.
- Separate read-only preflight/check commands from mutating commands.
- Provide `--help` and, where practical, `--dry-run` for scripts that modify the host.
- Require an explicit confirmation flag or interactive confirmation for risky actions.
- Print the exact planned changes before a mutating step where feasible.
- Back up existing configuration before editing it, use restrictive file permissions, and fail closed when uncertain.
- Never put secrets directly in command-line arguments when a safer file/stdin/environment approach is available.
- Do not use `curl | sh` or equivalent blind remote execution unless it is the officially documented installation method and the script first explains the source, verifies the source where possible, and requires the appropriate user confirmation. Prefer downloading/reviewing official scripts or clearly documenting the official installer.
- Do not automatically open public ports for arbitrary application containers. Explain the required ports and let the operator confirm.
- Do not automatically install a self-hosted Actions runner, public monitoring dashboard, or extra heavyweight observability stack.
- Do not run Docker cleanup/prune commands as part of normal backup or deployment.
- Do not back up live database files by copying their raw data directories. Use database-native dump/snapshot methods appropriate to each database.
- Backup artifacts must have timestamps, clear naming, checksums where useful, encryption before remote upload, retention policy, and logs that do not expose secrets.
- Do not delete local backup copies until remote upload and verification have succeeded and retention rules have been evaluated.
- Restoration must be a separate, explicit operation. No automatic destructive restore.
- Treat Docker volumes and bind mounts as data requiring explicit inventory; do not assume every volume is disposable or that every volume should be archived blindly.
- Preserve Coolify's required encryption key securely; document that losing it can make stored secrets unrecoverable.
- For rclone Google Drive setup, do not store OAuth tokens in Git. Explain interactive setup and a secure way to transfer/store rclone configuration. If using `rclone crypt`, document that both the crypt configuration and passwords are recovery-critical secrets.
- Ensure scripts work with paths containing spaces where reasonable and quote shell variables.

## GitHub Actions / GHCR requirements

- Use GitHub-hosted runners by default.
- Build and push images to GHCR with least-privilege workflow permissions (`contents: read`, and `packages: write` only where required).
- Pin third-party actions to full commit SHAs where feasible and document update policy.
- Support immutable commit-SHA tags and optionally a human-readable release tag. Avoid deploying a mutable `latest` tag as the only production reference.
- Include a sample workflow that can be adapted by each application repository; do not assume the infrastructure repository itself is an application image.
- Explain how Coolify obtains permission to pull private GHCR images without committing a Personal Access Token.
- Prefer a protected deployment trigger/webhook or a documented manual promotion step. Do not expose deployment secrets to untrusted pull-request workflows.
- Explain how to configure health checks and rollback to a known image tag.
- Include a validation checklist for the complete push-to-deploy flow.

## Backup requirements

Design a documented backup plan for:
1. Coolify's supported backup/export mechanisms and critical configuration/secrets needed for recovery.
2. Each application's persistent files and Docker volumes, identified explicitly.
3. Databases using their native backup tools and appropriate consistency guarantees.
4. Infrastructure configuration and non-secret manifests.
5. The encrypted off-site copy in Google Drive.

Include configurable schedule and retention, an upload/verification stage, failure reporting, and a restore drill. Clearly separate what is implemented in scripts from what requires per-application configuration. Do not claim full application backups until each database and persistent volume has been inventoried.

## Validation before reporting completion

Run all checks that are possible without a real VPS or secrets, such as:

- Shell syntax checks (`bash -n`).
- ShellCheck, if installed.
- Markdown/link or formatting checks, if practical.
- Unit tests and config validation.
- Check for accidental secrets and unsafe patterns.
- Confirm scripts have executable permissions where needed.
- Confirm example configs contain placeholders only.
- Review that all commands and ports match current official documentation.
- Review idempotency and safe-failure behavior.
- Confirm no tests connect to a real server or Google account.

Do not say the repository is complete if checks failed or if critical tasks remain. Provide the exact command run, result, and any unavailable dependency.

## Working method

1. Inspect and report the current repository state briefly.
2. Draft/update the project brief and architecture documentation.
3. Implement scripts and examples in small, coherent pieces.
4. Test each piece locally without touching a live VPS.
5. Review security-sensitive code separately.
6. Update README with the actual commands supported by the repository.
7. Produce a final report with:
   - Files created/changed.
   - Implemented features vs. documented future/manual steps.
   - Commands/tests run and results.
   - Security risks or limitations.
   - Exact manual actions the user must perform later.
   - Any decisions that require user approval.
8. Stop after repository preparation and local validation. Wait for the user to review and approve before any manual VPS setup begins.

Do not expand the project scope without asking. Do not silently change agreed architecture or priorities.
