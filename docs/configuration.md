# Configuration

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| **Common** |
| `BACKUP_STORAGE_TYPE` | Storage backend: `s3`, `usb`, or `local` | `s3` | No |
| `BORG_REPO_PATH` | Repository path relative to storage mount (supports subdirs like `server1/backups`) | `borgbackup` | No |
| `BORG_PASSPHRASE` | Encryption passphrase (leave empty only for repos created with `--encryption=none`) | - | Yes (encrypted repos) |
| `LOGGING` | Logging verbosity: `INFO` or `DEBUG` | `INFO` | No |
| `SHOW_PROGRESS` | Show real-time progress during backup: `true` or `false` | `false` | No |
| `BORG_AUTO_BREAK_LOCK` | Handle stale locks: `false`, `manual`, or `auto` | `false` | No |
| `BORG_TIMEOUT` | Timeout in seconds for borg create/prune operations (`0` disables) | `14400` (4h) | No |
| `BORG_SOURCE_PATHS` | Space-separated paths to back up, relative to host root (e.g. `mnt/data/shares`). When set, the system excludes (`proc`, `sys`, `mnt/*`, ...) are not applied | `.` (whole host root) | No |
| `BORG_HOSTNAME` | Archive name prefix (`{hostname}-{now}`). Must stay stable across runs to match an existing repo's archives | Host's `hostname` | No |
| **S3 Backend** |
| `S3_BUCKET_NAME` | Name of S3 bucket | - | Yes (S3) |
| `AWS_ACCESS_KEY_ID` | AWS access key | - | Yes (S3) |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | - | Yes (S3) |
| `AWS_DEFAULT_REGION` | AWS region | - | Yes (S3) |
| **USB Backend** |
| `USB_DEVICE_UUID` | UUID of USB device | - | Yes (USB) |
| **Local Backend** |
| `LOCAL_BACKUP_PATH` | Path on host to use | - | Yes (Local) |

For backend-specific setup (IAM policy, UUID detection, NAS mounts), see [Storage Backends](backends.md).
