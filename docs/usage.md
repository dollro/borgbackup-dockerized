# Usage

## Running Backups

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

## Interactive Mode

For manual backup operations and exploration:

```bash
sudo docker compose run --rm borgbackup bash
```

Once inside the container:
- Backup storage is available at: `/mnt/backup`
- Host filesystem is available at: `/mnt/target`
- Borg environment variables are pre-configured

## Common Borg Commands

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

# Extract/restore files (see the Restoring from Backup guide: restore.md)
sudo docker compose run --rm -v /tmp/restore:/restore -w /restore borgbackup \
    borg extract ::archive-name etc/hosts

# Check repository integrity
sudo docker compose run --rm borgbackup borg check

# Prune old backups
sudo docker compose run --rm borgbackup \
    borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6
```
