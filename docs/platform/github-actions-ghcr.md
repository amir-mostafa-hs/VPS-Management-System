# GitHub Actions & GHCR Deployment Runbook

This guide explains how to offload Docker builds to GitHub Actions, store container images on GitHub Container Registry (GHCR), and trigger instant zero-downtime deployments via Coolify webhooks.

> [!NOTE]
> **In Plain English:**  
> When you build an application on a small VPS, compiling code can consume 100% of the CPU and memory for 10 minutes, freezing existing websites and databases.  
> With this workflow, GitHub's fast cloud runners build and test your Docker container for you, upload it to a private container store (GHCR), and send a tiny notification (webhook) to Coolify: *"Hey, new version is ready!"*  
> Coolify then downloads the pre-built package in 5 seconds and starts it cleanly.

---

## 1. Overview & Data Flow

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

The template workflow is located at `.github/workflows/reusable-docker-build.yml` in this repository.

---

## 2. Setting Up GHCR Authentication in Coolify

To pull private container images from GitHub Container Registry without exposing administrative credentials:

1. **Create a GitHub Personal Access Token (PAT):**
   - Go to GitHub -> **Settings** -> **Developer settings** -> **Personal access tokens** -> **Tokens (classic)**.
   - Select scope: `read:packages`.
2. **Add Registry in Coolify Dashboard:**
   - In Coolify, navigate to **Keys & Servers** -> **Registries** -> **Add New Registry**.
   - **Type:** Docker Registry
   - **Name:** `GHCR`
   - **Registry URL:** `ghcr.io`
   - **Username:** Your GitHub username or organization name.
   - **Password / Token:** Paste the GitHub token generated above.
   - Click **Save**.

---

## 3. Configuring the Deploy Webhook

Coolify exposes a unique webhook URL for every deployed application or service:

1. In the Coolify Dashboard, open your application.
2. In the application settings, locate the **Webhooks** section.
3. Copy the **Deploy Webhook** URL (format: `https://<your-coolify-domain>/api/v1/deploy?uuid=...`).
4. In your GitHub application repository:
   - Go to **Settings** -> **Secrets and variables** -> **Actions**.
   - Create a new repository secret named `COOLIFY_DEPLOY_WEBHOOK`.
   - Paste the webhook URL as the secret value.

When the workflow completes its build and push steps, it issues an HTTP POST request to this URL, triggering Coolify to pull the latest image and restart the container seamlessly.

---

## 4. Image Tagging Strategy & Why Commit SHAs Matter

Every image built by the workflow is tagged with:
- **Immutable Commit SHA:** `ghcr.io/<org>/<app>:sha-<short-sha>` (e.g. `sha-a1b2c3d`)
- **Mutable Default Tag:** `ghcr.io/<org>/<app>:latest`
- **Semantic Release Tag (on git tags):** `ghcr.io/<org>/<app>:v1.2.3`

> [!TIP]
> **Why is tagging by commit SHA so important?**  
> The tag `latest` changes every day. If a new deployment breaks your production app, having specific commit tags (`sha-a1b2c3d`) allows you to instantly roll back to the exact code that was working yesterday in 10 seconds, without having to rebuild anything.

---

## 5. Rollback and Manual Promotion Runbook

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

---

## 6. Next Steps & Cross-References

- Review Coolify operations in [docs/platform/coolify.md](coolify.md).
- Check health status in [docs/operations/monitoring.md](../operations/monitoring.md).
- Consult emergency recovery in [docs/operations/troubleshooting.md](../operations/troubleshooting.md).
