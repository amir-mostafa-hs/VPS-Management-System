# 08: Lightweight Host & Container Health Monitoring

**What to build:** Lightweight host and container health monitoring scripts and operational documentation to detect disk exhaustion, memory pressure, and unhealthy containers without deploying an unneeded heavyweight monitoring stack.

**Blocked by:** 04: Docker Engine and Coolify Setup Automation

**Status:** resolved

## Acceptance Criteria

- [x] `scripts/health-check.sh` created implementing:
  - System load and CPU usage check.
  - Memory usage and swap pressure check.
  - Disk usage and inode exhaustion warning (alerting if disk > 80% full).
  - Docker daemon responsiveness check.
  - Inspection of Docker containers reporting unhealthy or restarting states.
  - Colorized console output and structured JSON/exit code output suitable for automated alerting.
- [x] `docs/monitoring.md` and `monitoring/README.md` created covering alert thresholds, host metrics interpretation, Docker container health check syntax in Dockerfiles, and log retention.

## Quality & Test Criteria (TDD Seam)

- **Test File:** `tests/test_health_check.sh`.
- **Verified Behaviors:**
  - CLI Contracts: Running `scripts/health-check.sh --help` prints usage and exits 0.
  - Threshold Evaluation:
    - Simulates disk at 50% capacity -> reports OK, returns exit code 0.
    - Simulates disk at 85% capacity -> reports WARNING, returns exit code 1.
    - Simulates disk at 95% capacity -> reports CRITICAL, returns exit code 2.
  - Container Inspection: Simulates Docker reporting an unhealthy container -> correctly flags container and emits failure status.
  - JSON Output Mode: Running with `--json` outputs valid parseable JSON.
  - Regression: `make test` runs and passes.

## Resolution
Implemented `scripts/health-check.sh` with CPU, memory, disk, inode, and Docker health evaluation, supporting console, colorized, and parseable JSON formats. Created `docs/monitoring.md` and `monitoring/README.md` covering host metrics, container health checks, alerting hooks, and log retention. Verified with 12 automated unit and contract tests in `tests/test_health_check.sh`.
