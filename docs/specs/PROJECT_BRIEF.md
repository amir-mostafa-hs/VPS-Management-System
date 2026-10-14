# Project Brief — VPS Infrastructure

**Repository name:** `vps-infrastructure`  
**Status:** Specification / repository preparation  
**Primary operator:** Repository owner  
**Primary goal:** Safely provision and operate a single Linux VPS using a self-hosted PaaS, repeatable scripts, documented CI/CD, encrypted off-site backups, monitoring, and a tested recovery procedure.

## 1. Goals

Create one Git repository that the operator can clone onto a new VPS and use as a guided, auditable entry point for:

- Preflight checks and initial server preparation.
- Baseline server security hardening.
- Docker Engine setup.
- Coolify installation and safe initial configuration.
- A CI/CD pattern that builds application images on GitHub-hosted Actions, publishes them to GHCR, and has Coolify deploy the already-built images.
- Backups of Coolify recovery-critical data, application databases, persistent files/volumes, and infrastructure configuration.
- Encrypted off-site backup copies in Google Drive using `rclone`.
- Lightweight health checks and resource monitoring.
- Documented restoration and disaster recovery.

The repository is not intended to be a full configuration-management platform. Prefer a small set of understandable, tested scripts and official tools.

## 2. Architecture decisions

### PaaS
Use **Coolify** as the primary self-hosted PaaS.

### Build and deploy
Use this default path:

`Application repository -> GitHub-hosted Actions -> tests/build -> GHCR -> Coolify pulls image -> runtime container`

The production VPS must not build application images by default. Do not install a self-hosted GitHub Actions runner on the production VPS in the initial design. A future exception requires explicit approval.

Use commit-SHA image tags and/or release tags for traceability. Do not rely only on mutable `latest` tags. Each application may need its own workflow and configuration; the infrastructure repository should provide safe, documented templates rather than assume all applications share the same build process.

### Backup destination
Use **Google Drive**, accessed through `rclone`. Sensitive backup data should be encrypted before upload, for example with an `rclone crypt` remote. Do not commit rclone config, OAuth tokens, crypt passwords, or recovery keys. Document how to store and recover these securely.

### Monitoring
Start with lightweight checks for host resources, disk usage, Docker/container health, Coolify availability, backup outcomes, and logs. Do not install a large observability stack by default. Optional additions must be justified by measured need.

### Security
Scripts must be safe by default, transparent about planned changes, and suitable for operator-led execution. No remote VPS changes are authorized during repository preparation.

## 3. Scope

### In scope
- Supported Linux OS preflight and documented support matrix.
- SSH/access checks and a cautious hardening procedure.
- Firewall guidance and port inventory.
- Security updates and least-privilege recommendations.
- Docker installation using current official instructions.
- Coolify installation using current official instructions.
- Example GitHub Actions workflows for GHCR.
- Secure GHCR pull/deploy guidance for Coolify.
- Backup planning, scripts, scheduling, encryption, upload verification, retention, and restore documentation.
- `rclone` Google Drive setup guidance.
- Lightweight health checks and systemd timers where appropriate.
- Tests, linting, sample configuration, `.gitignore`, documentation, and a clear operator workflow.
- Recovery documentation and a restore drill checklist.

### Out of scope unless separately approved
- Running any command against the real VPS during this phase.
- Connecting to the user's GitHub account or Google Drive.
- Storing actual credentials in the repository.
- Building or deploying the user's application code.
- Installing a self-hosted GitHub Actions runner on the production VPS.
- Automatic destructive restoration, Docker prune/cleanup, or deletion of backup data.
- Installing a heavyweight monitoring stack by default.
- Supporting every Linux distribution without testing.
- Claiming a complete backup for an application before its database and persistent data have been inventoried.

## 4. Safety requirements

1. Never commit secrets, private keys, real `.env` files, OAuth tokens, rclone configuration, database credentials, or Coolify `APP_KEY`.
2. Keep secrets in restricted local files or a suitable secret store, with documented permissions and recovery requirements.
3. Before changing SSH settings, prove key-based access works in a second session and require explicit operator approval.
4. Before enabling a firewall or changing network rules, show the intended rules and confirm the current SSH port and required inbound ports.
5. Take a provider snapshot or document another recovery path before risky initial changes where available.
6. Make scripts idempotent where practical and validate prerequisites before mutation.
7. Separate check-only commands from mutating commands.
8. Provide help text and dry-run behavior where practical.
9. Never delete local backups until the off-site upload has been verified and retention has been evaluated.
10. Keep restore separate from backup; restore must require explicit operator action.
11. Use database-native backup tools rather than copying live database data directories.
12. Avoid unbounded Build/monitoring/backup workloads on the production VPS.
13. Document all exposed ports and do not automatically expose arbitrary application ports.
14. Do not assume Docker volumes are disposable. Inventory persistent data explicitly.
15. Record official references for version-sensitive setup commands.

## 5. Backup design requirements

The design must cover these categories separately:

- **Coolify recovery:** use its supported backup/export mechanisms where available and preserve recovery-critical configuration, including `APP_KEY`, securely outside the VPS.
- **Application databases:** native consistent backups appropriate to the actual database engine.
- **Application persistent data:** explicitly inventoried Docker volumes and bind mounts.
- **Infrastructure configuration:** scripts, manifests, and non-secret configuration tracked in Git; runtime secrets handled separately.
- **Off-site copy:** encrypted artifacts uploaded to Google Drive through rclone.

For every backup class, specify:
- What is included and excluded.
- How it is generated.
- Schedule and retention.
- Encryption and key recovery.
- Verification and error reporting.
- Restore procedure.
- Known consistency limitations.

A successful archive or upload is not enough to prove recoverability. Include checksum/remote verification where applicable and a documented restore drill. Backups stored in one Google account are not immutable and may be deleted or compromised; document a separate recovery option for critical data.

## 6. CI/CD requirements

Provide a template for application repositories that:
- Runs relevant checks/tests.
- Builds a Docker image on GitHub-hosted Actions.
- Logs in to GHCR using the workflow's scoped `GITHUB_TOKEN` where supported.
- Pushes an immutable commit-SHA tag and optional release tag.
- Uses least-privilege permissions.
- Avoids exposing secrets to untrusted pull-request workflows.
- Provides a safe method for Coolify to pull private images.
- Documents the deployment trigger/promotion process, health checks, and rollback to a known image tag.

Do not put application-specific assumptions into the infrastructure repository without making them configurable.

## 7. Suggested repository layout

The agent may adjust this layout with a clear rationale:

```text
vps-infrastructure/
├── README.md
├── AGENTS.md
├── .gitignore
├── Makefile
├── docs/
│   ├── PROJECT_BRIEF.md
│   ├── architecture.md
│   ├── prerequisites.md
│   ├── initial-server-setup.md
│   ├── security.md
│   ├── coolify.md
│   ├── github-actions-ghcr.md
│   ├── backups.md
│   ├── google-drive.md
│   ├── monitoring.md
│   ├── restore-and-disaster-recovery.md
│   └── troubleshooting.md
├── config/
│   ├── server.example.env
│   └── backup.example.env
├── scripts/
│   ├── preflight.sh
│   ├── bootstrap.sh
│   ├── harden-server.sh
│   ├── install-docker.sh
│   ├── install-coolify.sh
│   ├── setup-backups.sh
│   ├── backup-now.sh
│   ├── verify-backups.sh
│   ├── restore-backup.sh
│   └── health-check.sh
├── backup/
│   └── README.md
├── monitoring/
│   └── README.md
├── systemd/
│   ├── vps-backup.service
│   └── vps-backup.timer
└── tests/
```

Do not leave misleading empty files or claim functionality that is only described in documentation.

## 8. Initial platform support

The operator has not yet confirmed the VPS operating system, CPU architecture, RAM, disk, SSH port, or domain. Therefore:

- Start with discovery/preflight and do not assume these values.
- Propose a small support matrix based on current Coolify/Docker official requirements.
- Implement only OS versions the agent can validate against current documentation.
- Fail clearly on unsupported platforms instead of attempting a risky install.
- Ask the operator to confirm any server-specific values during the later manual setup phase.

## 9. Definition of Done for repository preparation

Repository preparation is complete only when:

- [ ] Existing repository contents and instructions were inspected and preserved.
- [ ] `README.md`, `AGENTS.md`, and `docs/PROJECT_BRIEF.md` agree on scope and workflow.
- [ ] Architecture and trust boundaries are documented.
- [ ] Secrets are excluded by `.gitignore`, and examples contain placeholders only.
- [ ] Scripts validate the OS, privileges, required configuration, and dependencies before making changes.
- [ ] Mutating operations are clearly identified and have safe confirmation/dry-run behavior where practical.
- [ ] No script connects to or modifies a real VPS during this phase.
- [ ] CI/CD template builds on GitHub-hosted runners and publishes to GHCR without requiring production VPS builds.
- [ ] Backup documentation clearly identifies coverage, limitations, encryption, retention, verification, and restoration.
- [ ] Google Drive/rclone setup and recovery of crypt configuration are documented without committing credentials.
- [ ] Health checks are lightweight and avoid exposing sensitive endpoints.
- [ ] Restore/disaster-recovery steps are documented and distinguish tested behavior from untested guidance.
- [ ] Shell syntax checks and available tests/lints have been run; results are reported honestly.
- [ ] Unsafe patterns and accidental secrets have been checked for.
- [ ] Final report lists implemented items, remaining manual tasks, test results, risks, and required user decisions.
- [ ] The agent stops and waits for user approval before any real VPS setup begins.

## 10. Required final report from the agent

The agent must finish with:
1. Summary of repository changes.
2. Final file tree.
3. Features implemented vs. documentation-only/manual steps.
4. Tests and exact results.
5. Security review findings.
6. Any unresolved assumptions or decisions.
7. A clearly ordered manual VPS checklist for the next phase.
8. Explicit confirmation that no real VPS, GitHub account, or Google Drive was accessed during repository preparation.
