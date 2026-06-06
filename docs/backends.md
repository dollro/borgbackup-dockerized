# Storage Backends

## S3 Backend

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

## USB Backend

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

## Local Backend

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
