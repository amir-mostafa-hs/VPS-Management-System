# Host & Container Monitoring Guide

This guide explains lightweight monitoring, alert thresholds, Docker health check definitions, and resource preservation.

> [!NOTE]
> **In Plain English:**  
> Many monitoring tools (like Prometheus, Grafana, Datadog) are heavy beasts that consume 1GB to 2GB of RAM just to monitor a server. On a 2GB VPS, they can crash the very websites you are trying to keep alive!  
> Instead, our script (`make health`) is a pure lightweight check that runs in 1 second, checks CPU, RAM, disk space, and Docker container statuses, and reports green or red without using up background memory.

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

## 2. Exit Codes & Simple Automated Alerting

`scripts/health-check.sh` returns standard Unix exit codes:
- **`0` (OK):** All metrics within healthy thresholds (disk < 80%, RAM healthy, all containers up).
- **`1` (WARNING):** Resource usage exceeds 80% (e.g. disk or memory > 80%).
- **`2` (CRITICAL):** Resource usage exceeds 90%, Docker daemon is unresponsive, or containers are unhealthy.

### Example: Automated Alert via Healthchecks.io or Telegram
You can add a simple cron job (`crontab -e`) to ping an external heartbeat service or send a message if an error occurs:

```bash
# Run every 10 minutes: ping healthchecks.io on success, alert on failure
*/10 * * * * cd /opt/vps-infrastructure && make health > /tmp/health.log 2>&1 && curl -fsS -m 10 --retry 3 https://hc-ping.com/your-uuid || curl -fsS -m 10 -d @/tmp/health.log https://hc-ping.com/your-uuid/fail
```

---

## 3. Best Practices for Application Dockerfiles

Ensure your application `Dockerfile` specifies an internal `HEALTHCHECK` directive so Docker and Coolify know whether your web server is actually responding:

```dockerfile
# Example for a Node/Python/Go web application
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1
```

Coolify and `scripts/health-check.sh` will automatically detect when a container reports `unhealthy`.

---

## 4. Next Steps & Cross-References

- If a metric reports WARNING or CRITICAL, consult [docs/operations/troubleshooting.md](troubleshooting.md).
- To back up your data prior to maintenance, see [docs/backup-recovery/backups.md](../backup-recovery/backups.md).
