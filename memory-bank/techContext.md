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

### AWS Services

| Service | Purpose |
|---------|---------|
| S3 | Backup storage backend |
| IAM | Access control for S3 bucket |

## Project Structure

```
borgbackup/
├── .env.example          # Environment variable template
├── .env                  # Actual configuration (gitignored)
├── .gitignore            # Git ignore rules
├── Dockerfile            # Container build instructions
├── docker-compose.yml    # Service configuration
├── entrypoint            # S3 mount and initialization script
├── start                 # (Empty placeholder script)
├── backup.sh             # Main backup automation script
├── run-backup.sh         # Host wrapper for backup execution
└── README.md             # Documentation
```

## Dependencies

### Dockerfile Build Dependencies

```dockerfile
# For s3fs
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
```

### Python Dependencies

```
borgbackup==1.4.1
llfuse
```

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `S3_BUCKET_NAME` | S3 bucket name | `myserver-backup` |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key | `wJalr...` |
| `BORG_PASSPHRASE` | Encryption passphrase | `secure-passphrase` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_DEFAULT_REGION` | AWS region | `us-east-1` |
| `LOGGING` | Log verbosity | `INFO` |
| `BORG_REPO` | Borg repository path | `/mnt/backup/borgbackup` |

## Container Configuration

### Docker Compose Settings

```yaml
privileged: true          # Required for FUSE mounts
stdin_open: true          # Enable interactive mode
tty: true                 # Allocate pseudo-TTY
cap_add:
  - SYS_ADMIN             # Required for mount operations
security_opt:
  - apparmor:unconfined   # Disable AppArmor restrictions
```

### Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|----------------|---------|
| `/` | `/mnt/target` | Host filesystem access |
| `/dev/fuse` | `/dev/fuse` | FUSE device access |
| `/etc/passwd` | `/etc/passwd:ro` | User mapping |
| `/etc/group` | `/etc/group:ro` | Group mapping |

## AWS IAM Policy

Required IAM policy for S3 bucket access:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListBucketPermission",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::<BUCKET-NAME>"
        },
        {
            "Sid": "ObjectOperationsPermission",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:DeleteObjectVersion",
                "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::<BUCKET-NAME>/*"
        }
    ]
}
```

## s3fs Mount Options

```bash
s3fs "${S3_BUCKET_NAME}" /mnt/backup \
    -o passwd_file=/etc/passwd-s3fs \    # Credentials file
    -o url="https://s3-${AWS_DEFAULT_REGION}.amazonaws.com" \
    -o endpoint="${AWS_DEFAULT_REGION}" \
    -o use_path_request_style \           # Path-style URLs
    -o allow_other \                      # Allow other users
    -o uid=0 -o gid=0 \                   # Root ownership
    -o mp_umask=002 -o umask=002 \        # Permissions
    -o kernel_cache \                     # Enable caching
    -o max_stat_cache_size=100000         # Cache 100k stats
```

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
sudo docker compose run --rm borgbackup bash
```

### Running Backups

```bash
./run-backup.sh
# or
sudo docker compose run --rm borgbackup /usr/sbin/backup.sh
```

## Debugging

### Enable Debug Mode

Set in `.env`:
```bash
LOGGING=DEBUG
```

### Debug Output Includes
- S3 configuration details
- AWS connectivity tests
- Mount verification
- s3fs process details
- Detailed error logs

## Technical Constraints

1. **Privileged Container**: Required for FUSE mounts - security consideration
2. **Root Access**: Container runs as root for mount operations
3. **AppArmor Disabled**: Required on some systems for FUSE to work
4. **S3 Latency**: s3fs introduces latency compared to local filesystems
5. **FUSE Overhead**: Minor performance impact from FUSE layer
