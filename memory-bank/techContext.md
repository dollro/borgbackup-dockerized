# Technical Context: Dockerized BorgBackup

## Technology Stack

### Core Technologies

| Technology | Version | Purpose |
|------------|---------|---------|
| Python | 3.13.7 | Base Docker image (slim-trixie) |
| BorgBackup | 1.4.1 | Deduplicating backup tool |
| s3fs-fuse | 1.95-1 | FUSE filesystem for S3 |
| llfuse | Latest | FUSE bindings for Python |
| Docker | Latest | Container runtime |
| Docker Compose | Latest | Container orchestration |

### Storage Backend Technologies

| Backend | Technology | Purpose |
|---------|------------|---------|
| S3 | s3fs-fuse | FUSE mount for AWS S3 buckets |
| USB | blkid + mount | UUID-based device detection and mounting |
| Local | bind mount | Direct filesystem access via Docker volumes |

### AWS Services (S3 Backend)

| Service | Purpose |
|---------|---------|
| S3 | Backup storage backend |
| IAM | Access control for S3 bucket |

## Project Structure

```
borgbackup/
├── .env.example          # Environment variable template (all backends)
├── .env                  # Actual configuration (gitignored)
├── .gitignore            # Git ignore rules
├── Dockerfile            # Container build instructions
├── docker-compose.yml    # Service configuration with profiles
├── entrypoint            # Multi-backend mount and initialization
├── start                 # (Empty placeholder script)
├── backup.sh             # Backend-aware backup automation
├── run-backup.sh         # Host wrapper for backup execution
├── README.md             # Documentation for all backends
└── memory-bank/          # Project documentation
    ├── activeContext.md
    ├── productContext.md
    ├── progress.md
    ├── projectbrief.md
    ├── systemPatterns.md
    └── techContext.md
```

## Dependencies

### Dockerfile Build Dependencies

```dockerfile
# For s3fs (S3 backend)
s3fs=1.95-1
glib-networking
curl
gnupg
gzip
zip
unzip

# For borgbackup compilation
python3-dev
libacl1-dev
libssl-dev
liblz4-dev
libzstd-dev
libxxhash-dev
build-essential
pkg-config
libfuse-dev
fuse

# For USB backend (filesystem tools)
util-linux          # blkid for UUID detection
ntfs-3g             # NTFS filesystem support
e2fsprogs           # ext2/ext3/ext4 tools
xfsprogs            # XFS filesystem support
btrfs-progs         # Btrfs filesystem support
dosfstools          # FAT/FAT32 filesystem support
```

### Python Dependencies

```
borgbackup==1.4.1
llfuse
```

## Environment Variables

### Backend Selection

| Variable | Description | Values | Default |
|----------|-------------|--------|---------|
| `BACKUP_STORAGE_TYPE` | Storage backend to use | `s3`, `usb`, `local` | `s3` |

### Common Variables (All Backends)

| Variable | Description | Example |
|----------|-------------|---------|
| `BORG_REPO_PATH` | Repository path relative to storage mount | `borgbackup` or `server1/backups` |
| `BORG_PASSPHRASE` | Encryption passphrase | `secure-passphrase` |
| `LOGGING` | Log verbosity | `INFO` or `DEBUG` |
| `SHOW_PROGRESS` | Show real-time progress during backup | `true` or `false` (default: `false`) |
| `BORG_AUTO_BREAK_LOCK` | Handle stale locks | `false` (default), `manual`, or `auto` |

### S3 Backend Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `S3_BUCKET_NAME` | S3 bucket name | Yes | - |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key | Yes | - |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key | Yes | - |
| `AWS_DEFAULT_REGION` | AWS region | No | `us-east-1` |

### USB Backend Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `USB_DEVICE_UUID` | UUID of USB device | Yes | `1234-5678-90AB-CDEF` |

### Local Backend Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `LOCAL_BACKUP_PATH` | Path on host filesystem | Yes | `/mnt/nas/backups` |

## Container Configuration

### Docker Compose Services

```yaml
services:
  # Main service for S3 and USB backends
  borgbackup:
    privileged: true
    environment:
      - BACKUP_STORAGE_TYPE=${BACKUP_STORAGE_TYPE:-s3}
      # ... backend-specific vars
    volumes:
      - /:/mnt/target              # Host filesystem
      - /dev:/dev                  # Device access (USB)
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

  # Local backend service (uses profile)
  borgbackup-local:
    profiles:
      - local
    volumes:
      - /:/mnt/target
      - ${LOCAL_BACKUP_PATH}:/mnt/backup  # Bind mount
```

### Volume Mounts

| Host Path | Container Path | Purpose | Backends |
|-----------|----------------|---------|----------|
| `/` | `/mnt/target` | Host filesystem access | All |
| `/dev` | `/dev` | Block device access | S3, USB |
| `/etc/passwd` | `/etc/passwd:ro` | User mapping | All |
| `/etc/group` | `/etc/group:ro` | Group mapping | All |
| `${LOCAL_BACKUP_PATH}` | `/mnt/backup` | Backup destination | Local |

## Backend-Specific Technical Details

### S3 Backend (s3fs)

#### IAM Policy Required
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::<BUCKET-NAME>"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::<BUCKET-NAME>/*"
        }
    ]
}
```

#### s3fs Mount Options
```bash
s3fs "${S3_BUCKET_NAME}" /mnt/backup \
    -o passwd_file=/etc/passwd-s3fs \
    -o url="https://s3-${AWS_DEFAULT_REGION}.amazonaws.com" \
    -o endpoint="${AWS_DEFAULT_REGION}" \
    -o use_path_request_style \
    -o allow_other \
    -o uid=0 -o gid=0 \
    -o mp_umask=002 -o umask=002 \
    -o kernel_cache \
    -o max_stat_cache_size=100000
```

### USB Backend

#### UUID Detection
```bash
# Find device by UUID
USB_DEVICE=$(blkid -U "$USB_DEVICE_UUID")

# Get filesystem type
USB_FSTYPE=$(blkid -s TYPE -o value "$USB_DEVICE")
```

#### Supported Filesystems
| Filesystem | Mount Options | Notes |
|------------|---------------|-------|
| ext4/ext3/ext2 | `rw` | Recommended |
| xfs | `rw` | Good performance |
| btrfs | `rw` | Supports snapshots |
| ntfs | `rw,uid=0,gid=0` | Via ntfs-3g |
| vfat/FAT32 | `rw,uid=0,gid=0,umask=002` | Limited (no symlinks) |

### Local Backend

#### Docker Compose Profile
```bash
# Run with local profile
sudo docker compose --profile local run --rm borgbackup-local <command>
```

#### Bind Mount
The `LOCAL_BACKUP_PATH` host directory is directly mounted to `/mnt/backup` in the container.

## Borg Backup Configuration

### Default Exclusions in backup.sh

```bash
--exclude 'backup/snapshots/*'
--exclude 'backup/log/*'
--exclude 'home/*/.cache/*'
--exclude 'var/cache/*'
--exclude 'var/tmp/*'
--exclude 'dev/*'
--exclude 'proc/*'
--exclude 'sys/*'
--exclude 'tmp/*'
--exclude 'run/*'
--exclude 'mnt/*'
--exclude 'media/*'
--exclude 'lost+found'
```

### Default Retention Policy

```bash
--keep-daily 7
--keep-weekly 4
--keep-monthly 6
```

## Development Setup

### Building the Image

```bash
sudo docker compose build
```

### Testing Interactive Mode

```bash
# S3 or USB backend
sudo docker compose run --rm borgbackup bash

# Local backend
sudo docker compose --profile local run --rm borgbackup-local bash
```

### Running Backups

```bash
# Using wrapper script
./run-backup.sh

# Direct execution (S3/USB)
sudo docker compose run --rm borgbackup /usr/sbin/backup.sh

# Direct execution (Local)
sudo docker compose --profile local run --rm borgbackup-local /usr/sbin/backup.sh
```

## Debugging

### Enable Debug Mode

Set in `.env`:
```bash
LOGGING=DEBUG
```

### Debug Output Includes
- Backend selection information
- S3/USB/Local configuration details
- Mount verification details
- Process details and logs
- Detailed error messages

### USB Debugging
```bash
# List all block devices
sudo blkid

# Check connected devices
lsblk

# Check device details
sudo blkid /dev/sdb1
```

## Technical Constraints

### S3 Backend
1. **Privileged Container**: Required for FUSE mounts
2. **AppArmor Disabled**: Required on some systems for FUSE
3. **S3 Latency**: s3fs introduces latency compared to local
4. **FUSE Overhead**: Minor performance impact

### USB Backend
1. **Privileged Container**: Required for device access
2. **Device Must Be Connected**: Before container starts
3. **UUID Required**: Device paths can change
4. **Filesystem Support**: Limited by installed tools

### Local Backend
1. **Path Must Exist**: On host before container starts
2. **Permissions**: Host path must be writable
3. **Uses Profile**: Requires `--profile local` flag
