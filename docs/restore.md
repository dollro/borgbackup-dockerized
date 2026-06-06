# Restoring from Backup

Borg extracts files relative to the **current working directory** inside the container. Because this project mounts the host filesystem (`/mnt/target`) **read-only**, restores must go to a separate writable location — typically a temporary directory on the host that you bind-mount into the container.

**Important:**
- Paths inside borg archives are stored **without** a leading slash (e.g., `etc/hosts`, not `/etc/hosts`).
- Always restore to a temp dir first, inspect the result, then move files to their final location with `sudo cp -a`.
- Use `--dry-run --list` to preview before extracting large directories.

## Finding the Archive

```bash
# List all archives in the repository
sudo docker compose run --rm borgbackup borg list

# List contents of a specific archive
sudo docker compose run --rm borgbackup borg list ::archive-name

# Search for a specific path inside an archive
sudo docker compose run --rm borgbackup borg list ::archive-name | grep etc/nginx
```

## Restore a Single File or Directory

Extract one path from an archive into `/tmp/restore` on the host:

```bash
mkdir -p /tmp/restore

sudo docker compose run --rm \
    -v /tmp/restore:/restore \
    -w /restore \
    borgbackup borg extract --list ::archive-name etc/hosts
```

Result: the file appears at `/tmp/restore/etc/hosts` on the host (borg preserves the archived path structure relative to CWD).

For a whole directory, just pass the directory path:

```bash
sudo docker compose run --rm \
    -v /tmp/restore:/restore \
    -w /restore \
    borgbackup borg extract --progress ::archive-name home/user/Documents
```

Useful flags:

| Flag | Purpose |
|-|-|
| `--list` | Print each extracted path |
| `--dry-run` | Preview without writing files (combine with `--list`) |
| `--progress` | Real-time progress for large extracts |
| `--strip-components N` | Strip N leading path components from extracted paths |
| `--pattern '...'` / `--patterns-from FILE` | Fine-grained include/exclude rules |

## Restore a File to stdout

Useful for diffing a backed-up version against the current one without writing to disk:

```bash
# Compare current /etc/nginx/nginx.conf to the archived version
sudo docker compose run --rm borgbackup \
    borg extract --stdout ::archive-name etc/nginx/nginx.conf | diff - /etc/nginx/nginx.conf
```

## Full Archive Restore

To restore the entire contents of an archive into a temp directory:

```bash
mkdir -p /tmp/restore

sudo docker compose run --rm \
    -v /tmp/restore:/restore \
    -w /restore \
    borgbackup borg extract --progress ::archive-name
```

After extraction, `/tmp/restore/` will contain the full archived tree (`etc/`, `home/`, `var/`, etc.). Be aware this can be very large — make sure `/tmp` (or wherever you mount) has enough free space.

## Browse the Archive with FUSE

For exploratory restores, mount the archive as a filesystem and copy what you want interactively:

```bash
mkdir -p /tmp/restore

sudo docker compose run --rm \
    -v /tmp/restore:/restore \
    borgbackup bash

# Inside the container:
mkdir /mnt/archive
borg mount ::archive-name /mnt/archive

# Browse and copy selectively
ls /mnt/archive/etc/
cp -a /mnt/archive/etc/nginx /restore/
cp -a /mnt/archive/home/user/.ssh /restore/

# Always unmount before exiting
borg umount /mnt/archive
exit
```

Restored files appear at `/tmp/restore/` on the host.

> **Tip:** `borg mount` is read-only and lazy — you can browse a multi-terabyte archive instantly without extracting it all. Ideal when you're not sure exactly which file you need.

## Disaster Recovery (Bare-Metal Restore)

Restoring directly over `/` is **not supported** by this container because `/mnt/target` is mounted read-only (intentionally — to protect the host during normal operation).

For full bare-metal recovery:

1. Boot the target system from a Linux rescue/live USB.
2. Install borg in the live environment:
   ```bash
   apt install borgbackup     # Debian/Ubuntu
   # or use a borg-linux64 standalone binary
   ```
3. Mount your backup storage:
   - **USB:** `mount /dev/sdX1 /mnt/backup`
   - **S3:** install `s3fs` and mount the bucket
   - **Local/NAS:** mount the share normally
4. Set the passphrase and extract directly to the target filesystem:
   ```bash
   export BORG_PASSPHRASE='your-passphrase'
   mount /dev/sda1 /mnt/target          # your new root partition
   cd /mnt/target
   borg extract /mnt/backup/borgbackup::archive-name
   ```
5. Reinstall the bootloader (`grub-install`, `update-grub`) and reboot.

> **Test your restore procedure regularly** — a backup you've never restored from is just hope, not insurance.
