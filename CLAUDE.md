# CLAUDE.md - Coding Agent Instructions

## Project Overview

Dockerized BorgBackup solution with multiple storage backends: AWS S3, USB devices, and local storage.

## Architecture

- `/mnt/backup`: Backup storage mount point (S3 bucket, USB device, or local path)
- `/mnt/target`: Host's root filesystem (backup source)

## Key Files

| File | Purpose |
|------|---------|
| `run-backup.sh` | Main backup wrapper script |
| `docker-compose.yml` | Container orchestration |
| `.env` | Configuration (copy from `.env.example`) |
| `Dockerfile` | Container image definition |
| `backup.sh` | Internal backup script (in container at `/usr/sbin/backup.sh`) |

## Common Commands

```bash
# Build container
sudo docker compose build

# Initialize borg repository (first time)
sudo docker compose run --rm borgbackup borg init --encryption=repokey

# Run backup
./run-backup.sh

# Interactive shell
sudo docker compose run --rm borgbackup bash

# List archives
sudo docker compose run --rm borgbackup borg list

# Use different env file
sudo docker compose --env-file .env.s3 run --rm borgbackup borg list
```

## Environment Variables

**Required:**
- `BORG_PASSPHRASE`: Encryption passphrase

**Storage Selection:**
- `BACKUP_STORAGE_TYPE`: `s3`, `usb`, or `local` (default: `s3`)
- `BORG_REPO_PATH`: Repository path relative to storage mount (default: `borgbackup`)

**Backend-specific:**
- S3: `S3_BUCKET_NAME`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`
- USB: `USB_DEVICE_UUID`
- Local: `LOCAL_BACKUP_PATH`

**Optional:**
- `LOGGING`: `INFO` or `DEBUG`
- `SHOW_PROGRESS`: `true` or `false`
- `BORG_AUTO_BREAK_LOCK`: `false`, `manual`, or `auto`

## Tech Stack

- Base Image: python:3.13.7-slim-trixie
- BorgBackup: 1.4.1
- s3fs: 1.95-1

## Container Requirements

- `SYS_ADMIN` capability (for FUSE mounts)
- Access to `/dev` (for USB detection)
