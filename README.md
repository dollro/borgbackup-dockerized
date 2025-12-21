# Dockerized BorgBackup with S3 Storage

A containerized solution for running BorgBackup operations with AWS S3 as the backup storage backend. This Docker container provides a secure, isolated environment for performing backup operations while mounting both your S3 bucket and host filesystem.

## 🎯 Key Features

- **Containerized BorgBackup**: Run Borg backup operations in an isolated Docker environment
- **S3 Integration**: Automatic mounting of AWS S3 bucket as backup storage via s3fs
- **Host Filesystem Access**: Full access to host filesystem for backing up any directory
- **Flexible Configuration**: Environment-based configuration for easy deployment
- **Debug Support**: Built-in debug logging for troubleshooting
- **Interactive & Non-interactive Modes**: Run one-off commands or interactive shell sessions

## 📋 Prerequisites

- Docker and Docker Compose installed on your system
- AWS account with S3 access
- Basic understanding of [BorgBackup](https://www.borgbackup.org/)
- Root/sudo access for mounting operations

## 🏗️ Architecture

The container provides two main mount points:
- `/mnt/backup`: Your S3 bucket (automatically mounted via s3fs)
- `/mnt/target`: Your host's root filesystem (for backup source)

This allows Borg to read files from your host system and store encrypted backups directly to S3.

## 🚀 Setup Instructions

### Step 1: AWS S3 Bucket Setup

#### 1.1 Create S3 Bucket

Create a new S3 bucket via AWS Management Console:

```
<HOSTNAME>-backup
```

Replace `<HOSTNAME>` with a unique identifier for your server (e.g., `webserver01-backup`, `database-prod-backup`).

#### 1.2 Create IAM User

Create an IAM user for exclusive backup access:

```
<HOSTNAME>-backup-access
```

#### 1.3 Attach IAM Policy

Create and attach the following IAM policy to the user. Replace `<HOSTNAME>-backup` with your actual bucket name:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListBucketPermission",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::<HOSTNAME>-backup"
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
            "Resource": "arn:aws:s3:::<HOSTNAME>-backup/*"
        }
    ]
}
```

#### 1.4 Generate Access Keys

Generate access keys for the IAM user and save them securely. You'll need:
- Access Key ID
- Secret Access Key

### Step 2: Local Configuration

#### 2.1 Clone or Download the Repository

```bash
git clone <repository-url>
cd borgbackup
```

#### 2.2 Configure Environment Variables

Copy the example environment file and edit it with your values:

```bash
cp .env.example .env
nano .env  # or use your preferred editor
```

Edit `.env` with your configuration:

```bash
# S3 Bucket Configuration
S3_BUCKET_NAME=your-hostname-backup

# AWS Credentials (from Step 1.4)
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# AWS Region
AWS_DEFAULT_REGION=us-east-1

# Logging Level (INFO for normal use, DEBUG for troubleshooting)
LOGGING=INFO

# Borg Repository Configuration
BORG_REPO=/mnt/backup/borgbackup
BORG_PASSPHRASE=your-secure-passphrase-here
```

### Step 3: Build and Test

#### 3.1 Build the Docker Image

```bash
sudo docker compose build
```

#### 3.2 Test the Container

Run an interactive session to verify everything works:

```bash
sudo docker compose run --rm borgbackup bash
```

Inside the container, verify the mounts:

```bash
# Check S3 mount
ls -la /mnt/backup/

# Check host filesystem mount
ls -la /mnt/target/

# Test Borg installation
borg --version
```

Type `exit` to leave the container.

## 📖 Usage Guide

### Interactive Mode

For manual backup operations and exploration:

```bash
sudo docker compose run --rm --remove-orphans borgbackup bash
```

Once inside the container:
- S3 bucket is available at: `/mnt/backup`
- Host filesystem is available at: `/mnt/target`
- Borg environment variables (`BORG_REPO` and `BORG_PASSPHRASE`) are pre-configured

### Direct Command Mode

Run Borg commands directly without entering the container:

```bash
# Check Borg version
sudo docker compose run --rm borgbackup borg --version

# Initialize a new repository (first time only)
sudo docker compose run --rm borgbackup borg init --encryption=repokey

# Create a backup
sudo docker compose run --rm borgbackup borg create ::backup-{now} /mnt/target/home /mnt/target/etc

# List archives
sudo docker compose run --rm borgbackup borg list

# Show archive info
sudo docker compose run --rm borgbackup borg info ::backup-2025-01-24T12:00:00
```

### Automated Backup Script

The container includes a pre-configured backup script at `/usr/sbin/backup.sh` that automates the entire backup process:

#### Quick Start - Using the Wrapper Script

```bash
# Run backup using the wrapper script (recommended)
./run-backup.sh
```

#### Manual Execution

```bash
# Run the automated backup script directly
sudo docker compose run --rm borgbackup /usr/sbin/backup.sh
```

The script performs:
1. **Pre-backup dumps**: Creates local dumps of databases and critical directories
2. **Mailcow backup**: Automatically detects and backs up Mailcow if present
3. **Full system backup**: Backs up the entire host filesystem with intelligent exclusions
4. **Repository pruning**: Maintains 7 daily, 4 weekly, and 6 monthly backups
5. **Comprehensive logging**: Logs all operations to `/var/log/borgbackup/backup-<timestamp>.log`

View logs from outside the container:
```bash
# List available backup logs
sudo docker compose run --rm borgbackup ls -la /var/log/borgbackup/

# View the latest log
sudo docker compose run --rm borgbackup tail -f /var/log/borgbackup/backup-*.log
```

### Common Borg Operations

#### Initialize Repository (First Time Setup)

```bash
sudo docker compose run --rm borgbackup borg init --encryption=repokey
```

**Important**: Save the repository key in a secure location!

#### Create Backups

Basic backup of home directories and configuration:

```bash
sudo docker compose run --rm borgbackup \
    borg create --stats --progress \
    ::'{hostname}-{now}' \
    /mnt/target/home \
    /mnt/target/etc \
    /mnt/target/var/www \
    --exclude '*.cache' \
    --exclude '*.tmp'
```

#### List Archives

```bash
sudo docker compose run --rm borgbackup borg list
```

#### Extract/Restore Files

```bash
# Extract entire archive
sudo docker compose run --rm borgbackup \
    borg extract ::archive-name

# Extract specific files/directories
sudo docker compose run --rm borgbackup \
    borg extract ::archive-name /mnt/target/home/user/documents
```

#### Prune Old Backups

Keep backups according to retention policy:

```bash
sudo docker compose run --rm borgbackup \
    borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6
```

## ⚙️ Configuration Reference

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `S3_BUCKET_NAME` | Name of your S3 bucket | - | Yes |
| `AWS_ACCESS_KEY_ID` | AWS access key ID | - | Yes |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key | - | Yes |
| `AWS_DEFAULT_REGION` | AWS region for S3 bucket | us-east-1 | No |
| `LOGGING` | Logging verbosity (INFO/DEBUG) | INFO | No |
| `BORG_REPO` | Path to Borg repository | /mnt/backup/borgbackup | No |
| `BORG_PASSPHRASE` | Encryption passphrase for Borg | - | Yes |

### Logging Levels

- **INFO**: Minimal output, suitable for production use
- **DEBUG**: Verbose output including S3 mount details, useful for troubleshooting

## 🔧 Troubleshooting

### Enable Debug Mode

Set `LOGGING=DEBUG` in your `.env` file to see detailed output:

```bash
LOGGING=DEBUG
```

Then run the container to see verbose logs:

```bash
sudo docker compose run --rm borgbackup bash
```

### Common Issues

#### S3 Mount Fails

1. Check AWS credentials are correct
2. Verify IAM policy is properly attached
3. Ensure bucket name and region are correct
4. Check network connectivity to AWS

#### Permission Denied Errors

Ensure the container is run with proper privileges:
- Use `sudo` when running docker compose commands
- The container needs `SYS_ADMIN` capability for FUSE mounts

#### Backup Performance

For large backups, consider:
- Using compression: `borg create --compression lz4 ...`
- Excluding unnecessary files with `--exclude` patterns
- Running backups during off-peak hours

## 🔒 Security Considerations

### Credential Management

1. **Never commit `.env` file to version control**
2. Use strong, unique passwords for `BORG_PASSPHRASE`
3. Rotate AWS access keys regularly
4. Consider using AWS IAM roles if running on EC2

### Borg Encryption

- Always use encryption when initializing repositories
- Store repository keys in multiple secure locations
- Test restore procedures regularly

### Container Security

- The container runs with elevated privileges for mounting
- Only run trusted images and review Dockerfile contents
- Keep the base image updated regularly

## 📚 Advanced Usage

### Automated Backups with Cron

Create a backup script (`backup.sh`):

```bash
#!/bin/bash
cd /path/to/borgbackup
sudo docker compose run --rm borgbackup \
    borg create --stats \
    ::'{hostname}-{now}' \
    /mnt/target/home \
    /mnt/target/etc \
    /mnt/target/var/www \
    --exclude '*.cache'

# Prune old backups
sudo docker compose run --rm borgbackup \
    borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6
```

Add to crontab:

```bash
# Daily backup at 2 AM
0 2 * * * /path/to/backup.sh >> /var/log/borgbackup.log 2>&1
```

### Multiple Repositories

To manage multiple backup repositories, create separate `.env` files:

```bash
# Production backups
sudo docker compose --env-file .env.prod run --rm borgbackup borg list

# Development backups
sudo docker compose --env-file .env.dev run --rm borgbackup borg list
```

### Backup Verification

Regularly verify backup integrity:

```bash
# Check repository consistency
sudo docker compose run --rm borgbackup borg check

# Verify specific archive
sudo docker compose run --rm borgbackup borg check ::archive-name
```

## 📝 Example Backup Script

Here's a complete example script for automated backups:

```bash
#!/bin/bash
set -e

# Configuration
COMPOSE_FILE="/path/to/borgbackup/docker-compose.yml"
LOG_FILE="/var/log/borgbackup/backup-$(date +%Y%m%d).log"

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start backup
log "Starting backup process..."

# Create backup with progress
sudo docker compose -f "$COMPOSE_FILE" run --rm borgbackup \
    borg create \
    --verbose \
    --stats \
    --progress \
    --compression lz4 \
    ::'{hostname}-{now:%Y-%m-%d_%H:%M}' \
    /mnt/target/home \
    /mnt/target/etc \
    /mnt/target/var \
    --exclude '*/cache/*' \
    --exclude '*/tmp/*' \
    --exclude '*.log' \
    2>&1 | tee -a "$LOG_FILE"

# Prune old backups
log "Pruning old backups..."
sudo docker compose -f "$COMPOSE_FILE" run --rm borgbackup \
    borg prune \
    --list \
    --keep-daily=7 \
    --keep-weekly=4 \
    --keep-monthly=6 \
    --keep-yearly=1 \
    2>&1 | tee -a "$LOG_FILE"

# Verify repository
log "Verifying repository..."
sudo docker compose -f "$COMPOSE_FILE" run --rm borgbackup \
    borg check --last 1 \
    2>&1 | tee -a "$LOG_FILE"

log "Backup process completed successfully!"
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

[Specify your license here]

## 🔗 Resources

- [BorgBackup Documentation](https://borgbackup.readthedocs.io/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Docker Documentation](https://docs.docker.com/)
- [s3fs-fuse Project](https://github.com/s3fs-fuse/s3fs-fuse)
