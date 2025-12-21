# Dockerized BorgBackup with Multiple Storage Backends

A containerized solution for running BorgBackup operations with support for multiple storage backends: AWS S3, USB devices, and local storage. This Docker container provides a secure, isolated environment for performing backup operations.

## 🎯 Key Features

- **Containerized BorgBackup**: Run Borg backup operations in an isolated Docker environment
- **Multiple Storage Backends**: Support for S3, USB devices, and local/NAS storage
- **USB Auto-Detection**: Automatically detects USB devices by UUID
- **Host Filesystem Access**: Full access to host filesystem for backing up any directory
- **Flexible Configuration**: Environment-based configuration for easy deployment
- **Debug Support**: Built-in debug logging for troubleshooting
- **Interactive & Non-interactive Modes**: Run one-off commands or interactive shell sessions

## 📋 Prerequisites

- Docker and Docker Compose installed on your system
- Root/sudo access for mounting operations
- **For S3**: AWS account with S3 access
- **For USB**: A USB storage device formatted with a supported filesystem
- **For Local**: A local directory or mounted network share
- Basic understanding of [BorgBackup](https://www.borgbackup.org/)

## 🏗️ Architecture

The container provides two main mount points:
- `/mnt/backup`: Your backup storage (S3 bucket, USB device, or local path)
- `/mnt/target`: Your host's root filesystem (for backup source)

This allows Borg to read files from your host system and store encrypted backups to your chosen storage backend.

## 🚀 Quick Start

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

## 📦 Storage Backend Configuration

### Backend 1: AWS S3 (Default)

Store backups in an AWS S3 bucket using s3fs FUSE mount.

#### S3 Setup

1. **Create S3 Bucket** in AWS Console with name like `<hostname>-backup`

2. **Create IAM User** with the following policy:
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

3. **Configure `.env`**:
```bash
BACKUP_STORAGE_TYPE=s3
S3_BUCKET_NAME=your-hostname-backup
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=eu-central-1

BORG_REPO=/mnt/backup/borgbackup
BORG_PASSPHRASE=your-secure-passphrase
```

4. **Run backup**:
```bash
sudo docker compose run --rm borgbackup /usr/sbin/backup.sh
```

---

### Backend 2: USB Device

Store backups on a USB-connected storage device, auto-detected by UUID.

#### USB Setup

1. **Connect your USB device** and find its UUID:
```bash
sudo blkid
```
Example output:
```
/dev/sdb1: UUID="1234-5678-90AB-CDEF" TYPE="ext4" PARTUUID="..."
```

2. **Configure `.env`**:
```bash
BACKUP_STORAGE_TYPE=usb
USB_DEVICE_UUID=1234-5678-90AB-CDEF

BORG_REPO=/mnt/backup/borgbackup
BORG_PASSPHRASE=your-secure-passphrase
```

3. **Run backup**:
```bash
sudo docker compose run --rm borgbackup /usr/sbin/backup.sh
```

#### Supported USB Filesystems
- ext4, ext3, ext2 (recommended)
- xfs, btrfs
- ntfs (using ntfs-3g)
- vfat/FAT32 (not recommended for large backups)

#### USB Tips
- Use a dedicated USB drive for backups
- Format with ext4 for best performance and reliability
- Label your drive for easy identification: `sudo e2label /dev/sdb1 "BACKUP"`

---

### Backend 3: Local/NAS Storage

Store backups on a local directory, network share, or any pre-mounted path.

#### Local Setup

1. **Create or identify your backup directory**:
```bash
# Local directory
sudo mkdir -p /mnt/backup-storage

# Or use a mounted NAS share
# sudo mount -t nfs nas.local:/backups /mnt/backup-storage
```

2. **Configure `.env`**:
```bash
BACKUP_STORAGE_TYPE=local
LOCAL_BACKUP_PATH=/mnt/backup-storage

BORG_REPO=/mnt/backup/borgbackup
BORG_PASSPHRASE=your-secure-passphrase
```

3. **Run backup using the local profile**:
```bash
sudo docker compose --profile local run --rm borgbackup-local /usr/sbin/backup.sh
```

#### Local Storage Use Cases
- NAS/NFS shares
- CIFS/SMB network shares
- iSCSI volumes
- Secondary internal drives
- Any mounted filesystem

---

## 📖 Usage Guide

### Interactive Mode

For manual backup operations and exploration:

```bash
# S3 or USB backend
sudo docker compose run --rm borgbackup bash

# Local backend
sudo docker compose --profile local run --rm borgbackup-local bash
```

Once inside the container:
- Backup storage is available at: `/mnt/backup`
- Host filesystem is available at: `/mnt/target`
- Borg environment variables are pre-configured

### Automated Backup Script

The container includes a pre-configured backup script:

```bash
# Using the wrapper script (recommended)
./run-backup.sh

# Or run directly
sudo docker compose run --rm borgbackup /usr/sbin/backup.sh
```

The script performs:
1. Pre-backup dumps (databases, critical directories)
2. Mailcow backup (if detected)
3. Full system backup with intelligent exclusions
4. Repository pruning (7 daily, 4 weekly, 6 monthly)

### Common Borg Operations

```bash
# Initialize repository (first time only)
sudo docker compose run --rm borgbackup borg init --encryption=repokey

# List archives
sudo docker compose run --rm borgbackup borg list

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

## ⚙️ Configuration Reference

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| **Common** |
| `BACKUP_STORAGE_TYPE` | Storage backend: `s3`, `usb`, or `local` | `s3` | No |
| `BORG_REPO` | Path to Borg repository | `/mnt/backup/borgbackup` | No |
| `BORG_PASSPHRASE` | Encryption passphrase | - | Yes |
| `LOGGING` | Logging verbosity: `INFO` or `DEBUG` | `INFO` | No |
| **S3 Backend** |
| `S3_BUCKET_NAME` | Name of S3 bucket | - | Yes (S3) |
| `AWS_ACCESS_KEY_ID` | AWS access key | - | Yes (S3) |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | - | Yes (S3) |
| `AWS_DEFAULT_REGION` | AWS region | `us-east-1` | No |
| **USB Backend** |
| `USB_DEVICE_UUID` | UUID of USB device | - | Yes (USB) |
| **Local Backend** |
| `LOCAL_BACKUP_PATH` | Path on host to use | - | Yes (Local) |

---

## 🔧 Troubleshooting

### Enable Debug Mode

Set `LOGGING=DEBUG` in your `.env` file for verbose output:

```bash
LOGGING=DEBUG
```

### Common Issues

#### S3: Mount Fails
- Verify AWS credentials are correct
- Check IAM policy permissions
- Ensure bucket name and region match
- Test network connectivity to AWS

#### USB: Device Not Found
```bash
# List all block devices
sudo blkid

# Check if device is connected
lsblk

# Verify UUID matches .env configuration
```

#### USB: Mount Fails
- Ensure filesystem is supported (ext4 recommended)
- Check for filesystem errors: `sudo fsck /dev/sdb1`
- Verify device is not already mounted on host

#### Local: Permission Denied
- Ensure directory exists and is writable
- Check ownership: `sudo chown -R root:root /mnt/backup-storage`
- Verify NAS/network share is properly mounted

#### General: Backup Performance
- Use compression: `--compression lz4` (already enabled)
- Exclude unnecessary files with `--exclude` patterns
- For USB: Use USB 3.0 ports and devices
- For S3: Consider AWS region closest to your server

---

## 🔒 Security Considerations

### Credential Management
- Never commit `.env` to version control
- Use strong, unique `BORG_PASSPHRASE` (store securely!)
- Rotate AWS access keys regularly
- For USB: Consider filesystem encryption (LUKS)

### Borg Encryption
- Always use encryption when initializing repositories
- Store repository key in multiple secure locations
- Test restore procedures regularly

---

## 📚 Advanced Usage

### Automated Backups with Cron

```bash
# Edit crontab
sudo crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /path/to/borgbackup && ./run-backup.sh >> /var/log/borgbackup-cron.log 2>&1
```

### Multiple Storage Backends

You can maintain multiple `.env` files for different backends:

```bash
# S3 backups
sudo docker compose --env-file .env.s3 run --rm borgbackup borg list

# USB backups
sudo docker compose --env-file .env.usb run --rm borgbackup borg list
```

### Backup Verification

```bash
# Check repository consistency
sudo docker compose run --rm borgbackup borg check

# Verify specific archive
sudo docker compose run --rm borgbackup borg check ::archive-name

# List archive contents
sudo docker compose run --rm borgbackup borg list ::archive-name
```

---

## 🗺️ Future Enhancements

- **SSH Backend**: Direct backup to remote Linux server via SSH (Borg native)
- **Backblaze B2**: Support for Backblaze B2 cloud storage
- **Notifications**: Email/Slack notifications on backup completion
- **Web UI**: Simple web interface for monitoring backups

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

[Specify your license here]

## 🔗 Resources

- [BorgBackup Documentation](https://borgbackup.readthedocs.io/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Docker Documentation](https://docs.docker.com/)
- [s3fs-fuse Project](https://github.com/s3fs-fuse/s3fs-fuse)
