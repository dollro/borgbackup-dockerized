# Dockerized BorgBackup with Multiple Storage Backends

A containerized solution for running BorgBackup operations with support for multiple storage backends: AWS S3, USB devices, and local storage. This Docker container provides a secure, isolated environment for performing backup operations.

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
  - [Environment Variables](#environment-variables)
  - [Storage Backends](#storage-backends)
- [Usage](#usage)
  - [Running Backups](#running-backups)
  - [Interactive Mode](#interactive-mode)
  - [Common Borg Commands](#common-borg-commands)
- [Features](#features)
  - [Automatic Lock Handling](#automatic-lock-handling)
  - [Real-time Progress Display](#real-time-progress-display)
  - [Pre-backup Database Dumps](#pre-backup-database-dumps)
  - [Retention Policy](#retention-policy)
- [Scheduling Backups](#scheduling-backups)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [Technical Reference](#technical-reference)
- [Resources](#resources)

---

## Overview

### Key Features

- **Containerized BorgBackup**: Run Borg backup operations in an isolated Docker environment
- **Multiple Storage Backends**: Support for S3, USB devices, and local/NAS storage
- **USB Auto-Detection**: Automatically detects USB devices by UUID
- **Host Filesystem Access**: Full access to host filesystem for backing up any directory
- **Flexible Configuration**: Environment-based configuration for easy deployment
- **Automatic Lock Handling**: Configurable handling of stale repository locks
- **Debug Support**: Built-in debug logging for troubleshooting
- **Interactive & Non-interactive Modes**: Run one-off commands or interactive shell sessions

### Architecture

The container provides two main mount points:
- `/mnt/backup`: Your backup storage (S3 bucket, USB device, or local path)
- `/mnt/target`: Your host's root filesystem (for backup source)

This allows Borg to read files from your host system and store encrypted backups to your chosen storage backend.

---

## Requirements

### General Requirements

- Docker and Docker Compose installed on your system
- Root/sudo access for mounting operations
- Basic understanding of [BorgBackup](https://www.borgbackup.org/)

### Backend-Specific Requirements

| Backend | Requirements |
|---------|-------------|
| S3 | AWS account with S3 access, IAM credentials |
| USB | USB storage device formatted with a supported filesystem |
| Local | A local directory or mounted network share |

---

## Quick Start

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd borgbackup
```

### Step 2: Configure Environment

```bash
cp .env.example .env
nano .env  # Edit with your configuration
```

### Step 3: Build the Docker Image

```bash
sudo docker compose build
```

### Step 4: Initialize Borg Repository

```bash
sudo docker compose run --rm borgbackup borg init --encryption=repokey
```

### Step 5: Run Your First Backup

```bash
./run-backup.sh
```

---

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| **Common** |
| `BACKUP_STORAGE_TYPE` | Storage backend: `s3`, `usb`, or `local` | `s3` | No |
| `BORG_REPO_PATH` | Repository path relative to storage mount (supports subdirs like `server1/backups`) | `borgbackup` | No |
| `BORG_PASSPHRASE` | Encryption passphrase | - | Yes |
| `LOGGING` | Logging verbosity: `INFO` or `DEBUG` | `INFO` | No |
| `SHOW_PROGRESS` | Show real-time progress during backup: `true` or `false` | `false` | No |
| `BORG_AUTO_BREAK_LOCK` | Handle stale locks: `false`, `manual`, or `auto` | `false` | No |
| `BORG_TIMEOUT` | Timeout in seconds for borg create/prune operations | `14400` (4h) | No |
| **S3 Backend** |
| `S3_BUCKET_NAME` | Name of S3 bucket | - | Yes (S3) |
| `AWS_ACCESS_KEY_ID` | AWS access key | - | Yes (S3) |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | - | Yes (S3) |
| `AWS_DEFAULT_REGION` | AWS region | - | Yes (S3) |
| **USB Backend** |
| `USB_DEVICE_UUID` | UUID of USB device | - | Yes (USB) |
| **Local Backend** |
| `LOCAL_BACKUP_PATH` | Path on host to use | - | Yes (Local) |

### Storage Backends

#### S3 Backend

Store backups in an AWS S3 bucket using s3fs FUSE mount.

**Setup:**

1. Create an S3 bucket in AWS Console with a name like `<hostname>-backup`

2. Create an IAM user with the following policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::<your-bucket-name>"
        },
        {
            "Effect": "Allow",
            "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
            "Resource": "arn:aws:s3:::<your-bucket-name>/*"
        }
    ]
}
```

3. Configure `.env`:

```bash
BACKUP_STORAGE_TYPE=s3
S3_BUCKET_NAME=your-hostname-backup
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=eu-central-1

BORG_REPO_PATH=borgbackup
BORG_PASSPHRASE=your-secure-passphrase
```

#### USB Backend

Store backups on a USB-connected storage device, auto-detected by UUID.

**Setup:**

1. Connect your USB device and find its UUID:

```bash
sudo blkid
```

Example output:
```
/dev/sdb1: UUID="1234-5678-90AB-CDEF" TYPE="ext4" PARTUUID="..."
```

2. Configure `.env`:

```bash
BACKUP_STORAGE_TYPE=usb
USB_DEVICE_UUID=1234-5678-90AB-CDEF

BORG_REPO_PATH=borgbackup
BORG_PASSPHRASE=your-secure-passphrase
```

**Supported Filesystems:**
- ext4, ext3, ext2 (recommended)
- xfs, btrfs
- ntfs (using ntfs-3g)
- vfat/FAT32 (not recommended for large backups)

**Tips:**
- Use a dedicated USB drive for backups
- Format with ext4 for best performance and reliability
- Label your drive for easy identification: `sudo e2label /dev/sdb1 "BACKUP"`

#### Local Backend

Store backups on a local directory, network share, or any pre-mounted path.

**Setup:**

1. Create or identify your backup directory:

```bash
# Local directory
sudo mkdir -p /mnt/backup-storage

# Or use a mounted NAS share
# sudo mount -t nfs nas.local:/backups /mnt/backup-storage
```

2. Configure `.env`:

```bash
BACKUP_STORAGE_TYPE=local
LOCAL_BACKUP_PATH=/mnt/backup-storage

BORG_REPO_PATH=borgbackup
BORG_PASSPHRASE=your-secure-passphrase
```

**Use Cases:**
- NAS/NFS shares
- CIFS/SMB network shares
- iSCSI volumes
- Secondary internal drives
- Any mounted filesystem

---

## Usage

### Running Backups

```bash
# Using the wrapper script (recommended)
./run-backup.sh

# Or run directly
sudo docker compose run --rm borgbackup /usr/sbin/backup.sh
```

The backup script performs:
1. Pre-backup dumps (databases, critical directories)
2. Mailcow backup (if detected)
3. Full system backup with intelligent exclusions
4. Repository pruning (7 daily, 4 weekly, 6 monthly)

### Interactive Mode

For manual backup operations and exploration:

```bash
sudo docker compose run --rm borgbackup bash
```

Once inside the container:
- Backup storage is available at: `/mnt/backup`
- Host filesystem is available at: `/mnt/target`
- Borg environment variables are pre-configured

### Common Borg Commands

```bash
# Initialize repository (first time only)
sudo docker compose run --rm borgbackup borg init --encryption=repokey

# List archives
sudo docker compose run --rm borgbackup borg list

# List contents of a specific archive (with path filter)
sudo docker compose run --rm borgbackup \
    borg list ::archive-name /home/user

# Create manual backup
sudo docker compose run --rm borgbackup \
    borg create ::'{hostname}-{now}' /mnt/target/home /mnt/target/etc

# Extract/restore files
sudo docker compose run --rm borgbackup \
    borg extract ::archive-name /mnt/target/home/user/documents

# Check repository integrity
sudo docker compose run --rm borgbackup borg check

# Prune old backups
sudo docker compose run --rm borgbackup \
    borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6
```

---

## Features

### Automatic Lock Handling

BorgBackup uses exclusive locks to prevent concurrent repository access. If a backup is interrupted (container killed, system crash, etc.), a stale lock file may remain.

Configure `BORG_AUTO_BREAK_LOCK` in your `.env` file to handle this automatically:

| Value | Behavior |
|-------|----------|
| `false` | Do nothing, fail immediately on lock error (default, safest) |
| `manual` | Prompt user to confirm breaking the lock (for interactive use) |
| `auto` | Wait 60 seconds, then automatically break the lock (for cron jobs) |

Example configuration:
```bash
BORG_AUTO_BREAK_LOCK=manual  # or "auto" for unattended backups
```

With `manual` mode, the script will ask for confirmation before breaking the lock. With `auto` mode, it waits 60 seconds and automatically breaks the lock if it persists.

After breaking a lock, the script automatically verifies repository integrity before proceeding.

### Real-time Progress Display

Enable progress output during backup operations by setting:

```bash
SHOW_PROGRESS=true
```

This displays:
- Original size
- Compressed size
- Deduplicated size
- Files processed

### Pre-backup Database Dumps

The backup script automatically detects and performs dumps for:

- **Mailcow**: If detected at `/srv/mailcow`, runs the official backup script

Dumps are stored at `/backup/dump` on the host and included in the Borg archive.

### Retention Policy

The automated backup script applies the following retention policy:

| Period | Retention |
|--------|-----------|
| Daily | 7 backups |
| Weekly | 4 backups |
| Monthly | 6 backups |

---

## Scheduling Backups

### Automated Backups with Cron

```bash
# Edit crontab
sudo crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /path/to/borgbackup && ./run-backup.sh >> /var/log/borgbackup-cron.log 2>&1
```

For unattended cron backups, set `BORG_AUTO_BREAK_LOCK=auto` to handle stale locks automatically.

> **Concurrent execution protection:** `run-backup.sh` uses `flock` to prevent overlapping runs. If a backup is still in progress when cron triggers the next one, it will exit with an error instead of corrupting the repository.

To suppress color codes in cron log output, set `NO_COLOR=1`:

```bash
0 2 * * * cd /path/to/borgbackup && NO_COLOR=1 ./run-backup.sh >> /var/log/borgbackup-cron.log 2>&1
```

### Multiple Storage Backends

You can maintain multiple `.env` files for different backends:

```bash
# S3 backups
sudo docker compose --env-file .env.s3 run --rm borgbackup borg list

# USB backups
sudo docker compose --env-file .env.usb run --rm borgbackup borg list
```

---

## Troubleshooting

### Enable Debug Mode

Set `LOGGING=DEBUG` in your `.env` file for verbose output:

```bash
LOGGING=DEBUG
```

### Common Issues

**S3: Mount Fails**
- Verify AWS credentials are correct
- Check IAM policy permissions
- Ensure bucket name and region match
- Test network connectivity to AWS

**USB: Device Not Found**
```bash
# List all block devices
sudo blkid

# Check if device is connected
lsblk

# Verify UUID matches .env configuration
```

**USB: Mount Fails**
- Ensure filesystem is supported (ext4 recommended)
- Check for filesystem errors: `sudo fsck /dev/sdb1`
- Verify device is not already mounted on host

**Local: Permission Denied**
- Ensure directory exists and is writable
- Check ownership: `sudo chown -R root:root /mnt/backup-storage`
- Verify NAS/network share is properly mounted

**Borg: Stale Lock Error**

If you see:
```
Failed to create/acquire the lock /mnt/backup/.../borgbackup/lock.exclusive (timeout).
```

See [Automatic Lock Handling](#automatic-lock-handling) or manually break the lock:
```bash
sudo docker compose run --rm borgbackup bash
borg break-lock /mnt/backup/borgbackup
exit
```

**General: Backup Performance**
- Use compression: `--compression lz4` (already enabled)
- Exclude unnecessary files with `--exclude` patterns
- For USB: Use USB 3.0 ports and devices
- For S3: Consider AWS region closest to your server

---

## Security Considerations

### Credential Management

- Never commit `.env` to version control
- Restrict `.env` file permissions: `chmod 600 .env`
- Use strong, unique `BORG_PASSPHRASE` (store securely)
- Rotate AWS access keys regularly
- For USB: Consider filesystem encryption (LUKS)

### Container Hardening

- The container runs in privileged mode (required for FUSE mounts and mounting over bind mounts)
- Memory is capped at 4GB by default (adjustable in `docker-compose.yml`)
- A health check monitors `/mnt/backup` accessibility

### Borg Encryption

- Always use encryption when initializing repositories
- Store repository key in multiple secure locations
- Test restore procedures regularly

---

## Technical Reference

### Software Versions

| Component | Version |
|-----------|---------|
| Base Image | python:3.13.7-slim-trixie |
| BorgBackup | 1.4.1 |
| s3fs | 1.95-1 |

### Container Capabilities

The container requires the following capabilities for proper operation:
- `privileged`: Required for FUSE mounts (S3), block device mounts (USB), and mounting over Docker bind mounts
- `SYS_ADMIN`: Required for FUSE mounts (S3, USB)

### Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/mnt/backup` | Backup storage mount point |
| `/mnt/target` | Host filesystem |
| `/dev` | Device access for FUSE (S3) and block devices (USB) |

### Supported USB Filesystems

| Filesystem | Mount Options |
|------------|---------------|
| ext4, ext3, ext2 | `rw` |
| xfs, btrfs | `rw` |
| ntfs | `rw,uid=0,gid=0` |
| vfat | `rw,uid=0,gid=0,umask=002` |

---

## Resources

- [BorgBackup Documentation](https://borgbackup.readthedocs.io/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Docker Documentation](https://docs.docker.com/)
- [s3fs-fuse Project](https://github.com/s3fs-fuse/s3fs-fuse)
