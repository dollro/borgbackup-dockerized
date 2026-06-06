# Deploying on a VPS

This runbook covers deploying the container on a real server and verifying the
first backup by hand. It deliberately stops short of the cron cutover — see
[Scheduling](scheduling.md) for the cron line once you're confident the manual
run is healthy.

## How the pieces fit

The work that a single bare-metal script used to do is split across three files:

| Role | File | Runs on |
|-|-|-|
| What you / cron call | `run-backup.sh` | host |
| Mount/unmount storage | `entrypoint` | container |
| `borg create` + `borg prune` | `backup.sh` (baked to `/usr/sbin/backup.sh`) | container |

`run-backup.sh` is the host-side launcher: it takes a `flock`, builds the image,
then `docker compose run --rm borgbackup /usr/sbin/backup.sh`. The container's
`entrypoint` mounts your storage at `/mnt/backup`, exec's the command it was
given, and unmounts on exit.

## Prerequisites

- Docker and Docker Compose installed on the VPS
- root / sudo access
- `git`
- Your storage backend ready: for S3, the bucket plus IAM credentials (see
  [Storage Backends](backends.md))
- **If migrating from an existing Borg repository:** the original
  `BORG_PASSPHRASE`. Without the exact passphrase you cannot read or append to
  an existing repo.

## 1. Get the code

```bash
sudo git clone <repository-url> /srv/borgbackup-dockerized
cd /srv/borgbackup-dockerized
```

(Any path works; `/srv/borgbackup-dockerized` matches the layout referenced
elsewhere in these docs.)

## 2. Configure `.env`

```bash
sudo cp .env.example .env
sudo nano .env
sudo chmod 600 .env
```

Key values (full list in [Configuration](configuration.md)):

- `BACKUP_STORAGE_TYPE=s3` (or `usb` / `local`)
- S3: `S3_BUCKET_NAME`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`
- `BORG_REPO_PATH` — path **inside** the bucket/device. When migrating, set this
  to the existing repo's path so the container points at it.
- `BORG_PASSPHRASE` — must match the existing repo's passphrase when migrating.
- `BORG_AUTO_BREAK_LOCK=auto` — recommended for unattended/cron operation.

## 3. Build the image

```bash
sudo docker compose build
```

## 4. Check for an existing repository — do NOT blindly init

The container exposes the repository as `BORG_REPO=/mnt/backup/<BORG_REPO_PATH>`,
so `borg` subcommands work without naming the repo. Probe it:

```bash
sudo docker compose run --rm borgbackup borg info
```

Interpret the result:

- **Prints repository stats** → a repo already exists and your passphrase is
  correct. **Skip `borg init`.** Optionally list archives to confirm history:
  ```bash
  sudo docker compose run --rm borgbackup borg list
  ```
- **`Repository ... does not exist`** → this is a fresh location. Initialize it:
  ```bash
  sudo docker compose run --rm borgbackup borg init --encryption=repokey
  ```
- **`passphrase supplied ... is incorrect` / `Could not decrypt`** → the repo
  exists but `BORG_PASSPHRASE` is wrong. Fix `.env` before going further — do
  **not** init (that would try to create a second repo alongside the real one).

> Running `borg init` against a location that already holds a repository fails
> safely (it won't overwrite), but the check above keeps the intent explicit and
> avoids confusing errors.

## 5. First backup — run it by hand

Run the wrapper interactively and watch it end-to-end:

```bash
sudo ./run-backup.sh
```

Expect the storage to mount, `borg create` to run, then `borg prune`, then a
final banner: `Backup completed successfully!` (or `completed with warnings`,
which is borg exit code 1 and non-fatal — e.g. a file changed mid-read).

`run-backup.sh` keeps the Docker TTY for interactive runs like this, so a
`BORG_AUTO_BREAK_LOCK=manual` prompt would work here if you use that mode.

## 6. Verify the result

```bash
# The new archive should appear at the top
sudo docker compose run --rm borgbackup borg list

# Optional integrity check (can be slow on large repos)
sudo docker compose run --rm borgbackup borg check
```

Confirm the newest archive's timestamp matches the run you just did, and spot
-check its contents:

```bash
sudo docker compose run --rm borgbackup borg list ::<archive-name> | head
```

## 7. Hand off to cron (you)

Once the manual run verifies cleanly, schedule it. `run-backup.sh` already
handles the two things that bite unattended runs:

- **No TTY under cron:** it detects a non-terminal and adds `docker compose run -T`
  automatically, avoiding `the input device is not a TTY`.
- **Overlapping runs:** a `flock` on `/tmp/borgbackup.lock` makes a second run
  exit rather than corrupt the repo.

Recommended root crontab entry (daily at 02:00):

```bash
0 2 * * * cd /srv/borgbackup-dockerized && NO_COLOR=1 ./run-backup.sh >> /var/log/borgbackup-cron.log 2>&1
```

Pair this with `BORG_AUTO_BREAK_LOCK=auto` in `.env` so a stale lock from an
interrupted run is cleared automatically. See [Scheduling](scheduling.md) for
multiple-backend variations.

## Troubleshooting first runs

- Mount failures (S3 credentials, USB UUID, local permissions) →
  [Troubleshooting](troubleshooting.md).
- Stale lock errors → [Features → Automatic Lock Handling](features.md#automatic-lock-handling).
- Set `LOGGING=DEBUG` in `.env` for verbose mount/borg output.
