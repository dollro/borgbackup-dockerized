# CLAUDE.md - Coding Agent Instructions

## Project Overview

Dockerized BorgBackup solution with multiple storage backends: AWS S3, USB devices, and local storage.

## Architecture

- `/mnt/backup`: Backup storage mount point (S3 bucket, USB device, or local path)
- `/mnt/target`: Host's root filesystem, mounted read-only (backup source)

**Execution chain** (the work is split across three files):

```
run-backup.sh   [host]      flock, build image, `docker compose run` the container
  └─ entrypoint [container]  mount storage at /mnt/backup, exec the command, unmount on exit
       └─ backup.sh [container]  borg create → borg prune
```

## Key Files

| File | Purpose |
|-|-|
| `run-backup.sh` | Host launcher (what you/cron call): flock, builds image, runs the container |
| `entrypoint` | Container ENTRYPOINT: mounts/unmounts storage, then `exec`s the given command |
| `backup.sh` | Borg logic (`create` + `prune`); baked into image at `/usr/sbin/backup.sh` |
| `docker-compose.yml` | Container orchestration (`environment:` block must list any var the scripts read) |
| `Dockerfile` | Container image definition |
| `.env` | Configuration (copy from `.env.example`) |
| `mkdocs.yml`, `Taskfile.yml` | Docs site config + tasks (`task docs-serve` to preview) |

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
- `BORG_TIMEOUT`: seconds for borg create/prune (default: `14400` = 4h)

**Gotcha:** a variable only reaches the container if it's listed in `docker-compose.yml`'s `environment:` block (there is no `env_file:`). Setting a var in `.env` alone is silently ignored.

## Tech Stack

- Base Image: python:3.13.7-slim-trixie
- BorgBackup: 1.4.1
- s3fs: 1.95-1

## Container Requirements

- `privileged: true` (FUSE/S3 mounts, USB block devices, mounting over Docker bind mounts)
- `SYS_ADMIN` capability (FUSE mounts)
- Access to `/dev` (USB block devices, FUSE)

## Documentation

Full docs are a MkDocs (Material) site under `docs/`, split from the README. Preview with `task docs-serve` (http://127.0.0.1:8888) or build with `task docs` (strict). Implementation plans live in `plans/`; design specs in `docs/superpowers/specs/`.
