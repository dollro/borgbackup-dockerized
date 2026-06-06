# Troubleshooting

## Enable Debug Mode

Set `LOGGING=DEBUG` in your `.env` file for verbose output:

```bash
LOGGING=DEBUG
```

## Common Issues

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

See [Automatic Lock Handling](features.md#automatic-lock-handling) or manually break the lock:
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
