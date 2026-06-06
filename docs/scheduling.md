# Scheduling Backups

## Automated Backups with Cron

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

## Multiple Storage Backends

You can maintain multiple `.env` files for different backends:

```bash
# S3 backups
sudo docker compose --env-file .env.s3 run --rm borgbackup borg list

# USB backups
sudo docker compose --env-file .env.usb run --rm borgbackup borg list
```
