# Features

## Automatic Lock Handling

BorgBackup uses exclusive locks to prevent concurrent repository access. If a backup is interrupted (container killed, system crash, etc.), a stale lock file may remain.

Configure `BORG_AUTO_BREAK_LOCK` in your `.env` file to handle this automatically:

| Value | Behavior |
|-------|----------|
| `false` | Do nothing, fail immediately on lock error (default, safest) |
| `manual` | Prompt user to confirm breaking the lock (for interactive use) |
| `auto` | Wait 60 seconds, then automatically break the lock (for cron jobs) |

Example configuration:
```bash
BORG_AUTO_BREAK_LOCK=manual  # or "auto" for unattended backups
```

With `manual` mode, the script will ask for confirmation before breaking the lock. With `auto` mode, it waits 60 seconds and automatically breaks the lock if it persists.

After breaking a lock, the script automatically verifies repository integrity before proceeding.

## Real-time Progress Display

Enable progress output during backup operations by setting:

```bash
SHOW_PROGRESS=true
```

This displays:
- Original size
- Compressed size
- Deduplicated size
- Files processed

## Pre-backup Database Dumps

The backup script automatically detects and performs dumps for:

- **Mailcow**: If detected at `/srv/mailcow`, runs the official backup script

Dumps are stored at `/backup/dump` on the host and included in the Borg archive.

## Retention Policy

The automated backup script applies the following retention policy:

| Period | Retention |
|--------|-----------|
| Daily | 7 backups |
| Weekly | 4 backups |
| Monthly | 6 backups |
