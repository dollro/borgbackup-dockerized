# Configuration

## Environment Variables

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

For backend-specific setup (IAM policy, UUID detection, NAS mounts), see [Storage Backends](backends.md).
