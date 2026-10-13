# Backup Conventions & Architecture

This directory defines the standards, structure, and retention rules for the automated backup system.

## Two-Tier Backup Strategy

1. **Tier 1 — Coolify Core System:**
   - **Scope:** Directory `/data/coolify` (Coolify state, keys, configurations, Traefik config) and Coolify internal PostgreSQL database dump.
   - **Frequency:** Daily via `vps-backup.timer`.
   - **Critical Secret:** `APP_KEY` stored in `/data/coolify/source/.env`. If lost, database passwords and encrypted application secrets inside Coolify cannot be decrypted!

2. **Tier 2 — Application Databases & Persistent Volumes:**
   - **Databases:** Consistent native logical dumps using `pg_dump` (PostgreSQL) and `mysqldump` (MySQL/MariaDB) invoked directly via container exec without stopping containers.
   - **Volumes:** Targeted tarballs of persistent asset directories and Docker named volumes.
   - **Consistency Guarantee:** Logical dumps provide point-in-time transactional consistency. Never copy live database data files directly (`/var/lib/postgresql/data`) as raw copying produces corrupted indexes and transaction logs.

## Encryption & Remote Synchronization

- Backups are compressed with `gzip` and encrypted locally using an `rclone crypt` remote before upload to Google Drive.
- The crypt remote encrypts both file contents and filenames.
- Retention is enforced locally (default 7 days) and remotely (default 30 days) only after successful verification.
