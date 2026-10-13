# Monitoring & Health Checks Overview

This directory provides operational guidance, alert thresholds, and log maintenance standards for host and container monitoring.

## Monitoring Architecture

The repository favors a **lightweight, native host monitoring** approach rather than deploying heavy observability stacks (such as Prometheus, Grafana, or ELK) that consume 1GB+ RAM on a small single-host VPS.

## Monitored Metrics & Thresholds

| Metric | Warning Threshold | Critical Threshold | Check Command |
| :--- | :---: | :---: | :--- |
| **Root Disk Usage** | > 80% | > 90% | `make health` / `df -h /` |
| **Inode Usage** | > 80% | > 90% | `df -i /` |
| **RAM Pressure** | > 85% | > 95% | `free -m` |
| **Docker Daemon** | Unresponsive | Stopped | `docker info` |
| **Containers** | Status = restarting | Status = unhealthy | `docker ps --filter health=unhealthy` |

## Routine Maintenance

- **Docker Log Rotation:** Enforced at `/etc/docker/daemon.json` (`max-size: 10m`, `max-file: 3`) to prevent unconstrained log disk filling.
- **Journalctl Log Vacuuming:** Systemd journal logs can be cleaned using `journalctl --vacuum-time=14d`.
