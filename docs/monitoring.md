# Host & Container Monitoring Guide

## Philosophy: Low Overhead, High Actionability

A production VPS hosting Coolify and application workloads must not exhaust its resources running monitoring overhead. A lightweight health-check script (`scripts/health-check.sh` or `make health`) executes in under 2 seconds and reports on the four critical failure modes:

1. **Storage Exhaustion:** Root partition full or inode exhaustion.
2. **Memory Pressure:** Out of physical RAM and high swap paging.
3. **Docker Daemon Deadlocks:** Docker socket unresponsive.
4. **Container Failures:** Containers caught in restart loops or failing Docker healthchecks.

---

## 1. Running the Health Check

```bash
# Run visual console report
make health

# Or directly with script
bash scripts/health-check.sh

# Run structured JSON output (ideal for cron / external webhook alerts)
bash scripts/health-check.sh --json
```

---

## 2. Exit Codes for Automated Alerting

`scripts/health-check.sh` returns standard Unix exit codes:
- **`0` (OK):** All metrics within healthy thresholds.
- **`1` (WARNING):** Resource usage exceeds 80% (e.g. disk or memory > 80%).
- **`2` (CRITICAL):** Resource usage exceeds 90% or Docker daemon is unresponsive or containers are unhealthy.

You can configure a periodic cron job or systemd timer to curl a notification webhook (such as Healthchecks.io, Telegram bot, or Discord webhook) when exit code > 0.

---

## 3. Best Practices for Application Dockerfiles

Ensure your application `Dockerfile` specifies an internal `HEALTHCHECK` directive:

```dockerfile
# Example for a Node/Python/Go web application
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1
```

Coolify and `scripts/health-check.sh` will automatically detect when a container reports `unhealthy`.
