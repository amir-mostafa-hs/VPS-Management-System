# GitHub Actions & GHCR Deployment Runbook

## Overview

In this infrastructure design, the production VPS **never builds Docker images**. Building applications locally on a single VPS risks CPU saturation, OOM (Out Of Memory) kills of running databases, and unpredictable downtime.

Instead, all build workloads are offloaded to GitHub-hosted Actions runners:

```
[ Developer Git Push ]
         │
         ▼
[ GitHub Actions (ubuntu-latest) ] ── (Builds image, runs tests)
         │
         ▼
[ GitHub Container Registry (GHCR) ] ── (Pushes sha-<commit> & latest)
         │
         ▼ (Calls Deploy Webhook)
[ Coolify on Production VPS ] ── (Pulls prebuilt image from GHCR & restarts container)
```

---

## 1. Setting Up GHCR Authentication in Coolify

To pull private container images from GitHub Container Registry without exposing administrative credentials:

1. **Create a GitHub Personal Access Token (PAT):**
   - Go to GitHub -> **Settings** -> **Developer settings** -> **Personal access tokens** -> **Fine-grained tokens** (or Classic Tokens).
   - If using Classic Tokens, select scope: `read:packages`.
   - If using Fine-grained Tokens, grant `Packages: Read-only` access to your application repository.
2. **Add Registry in Coolify Dashboard:**
   - In Coolify, navigate to **Keys & Tokens** -> **Docker Registries** -> **Add New**.
   - **Registry URL:** `ghcr.io`
   - **Username:** Your GitHub username or organization name.
   - **Password / Token:** Paste the GitHub token generated above.
   - Save the registry.

---

## 2. Configuring the Deploy Webhook

Coolify exposes a unique webhook URL for every deployed application or service:

1. In the Coolify Dashboard, open your application.
2. In the application settings, locate the **Webhooks** section.
3. Copy the **Deploy Webhook** URL (format: `https://<your-coolify-domain>/api/v1/deploy?uuid=...`).
4. In your GitHub application repository:
   - Go to **Settings** -> **Secrets and variables** -> **Actions**.
   - Create a new repository secret named `COOLIFY_DEPLOY_WEBHOOK`.
   - Paste the webhook URL as the secret value.

When the workflow completes its build and push steps, it issues a POST request to this URL, triggering Coolify to pull the latest image and restart the container seamlessly.

---

## 3. Image Tagging Strategy

Every image built by the workflow is tagged with:
- **Immutable Commit SHA:** `ghcr.io/<org>/<app>:sha-<short-sha>` (e.g. `sha-a1b2c3d`)
- **Mutable Default Tag:** `ghcr.io/<org>/<app>:latest`
- **Semantic Release Tag (on git tags):** `ghcr.io/<org>/<app>:v1.2.3`

> [!IMPORTANT]
> Always configure Coolify with explicit image tags or commit SHAs for production critical services, rather than relying solely on mutable `latest` tags.

---

## 4. Rollback and Manual Promotion Runbook

If a newly deployed image introduces an issue or fails runtime health checks, perform an instant rollback:

### Immediate Rollback Procedure:
1. Open Coolify Dashboard -> Navigate to your Application.
2. In the **Docker Image** field, change the image reference from `latest` to the previous known-good commit SHA tag:
   ```
   ghcr.io/my-org/my-app:sha-9f8e7d6
   ```
3. Click **Deploy**. Coolify pulls the exact immutable image and starts the container in seconds without rebuilding.
4. Verify the container health check status in Coolify logs.

### Manual Promotion Procedure:
To promote a tested staging build to production without automatic webhooks:
1. Trigger the GitHub Actions workflow manually via **Run workflow** (`workflow_dispatch`).
2. Inspect the GitHub Actions run output to get the generated `sha-<commit>` tag.
3. In Coolify, manually update the image tag to that SHA and click **Deploy**.
