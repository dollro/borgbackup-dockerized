# Security & Robustness Fixes Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all HIGH, MEDIUM, and LOW severity issues from code review — harden container security, prevent data loss edge cases, and improve error handling robustness.

**Architecture:** Changes span 5 files. No new files created. Each task is a self-contained fix that can be committed independently. Order matters only where noted.

**Tech Stack:** Docker Compose, Bash, BorgBackup, s3fs-fuse

---

## Chunk 1: Docker Compose Hardening

### Task 1: Remove privileged mode and AppArmor disable

**Files:**
- Modify: `docker-compose.yml:9` (remove `privileged: true`)
- Modify: `docker-compose.yml:50-51` (remove `apparmor:unconfined`)

The container already has `cap_add: SYS_ADMIN` which is sufficient for FUSE mounts. `privileged: true` grants ALL capabilities and bypasses ALL security (AppArmor, SELinux, seccomp). Removing it restores container isolation. The `apparmor:unconfined` is also unnecessary with just `SYS_ADMIN`.

- [ ] **Step 1: Remove `privileged: true` (line 9)**

Delete the entire line `privileged: true` from `docker-compose.yml`.

- [ ] **Step 2: Remove `security_opt` block (lines 50-51)**

Delete both lines:
```yaml
    security_opt:
      - apparmor:unconfined
```

- [ ] **Step 3: Verify compose file is valid**

Run: `cd /home/rodo/Coding/borgbackup && docker compose config --quiet`
Expected: exits 0, no output (valid config)

- [ ] **Step 4: Commit**

```bash
git add docker-compose.yml
git commit -m "security: remove privileged mode and apparmor:unconfined

SYS_ADMIN capability is sufficient for FUSE mounts. privileged:true
grants all capabilities and disables all security restrictions."
```

---

### Task 2: Restrict /dev mount to necessary devices only

**Files:**
- Modify: `docker-compose.yml:41` (replace `/dev:/dev` with specific devices)

Full `/dev` mount exposes raw disks, serial ports, memory, and kernel interfaces. The container only needs USB device detection (for `blkid`) and FUSE.

- [ ] **Step 1: Replace the /dev volume mount**

Replace line 41:
```yaml
      - /dev:/dev
```
with:
```yaml
      # FUSE device (required for s3fs)
      - /dev/fuse:/dev/fuse
      # USB device detection (required for blkid UUID lookups)
      - /dev/disk:/dev/disk:ro
```

Note: `/dev/fuse` is needed for s3fs FUSE mounts. `/dev/disk` (read-only) is needed for `blkid -U` UUID lookups in USB backend. The actual USB block device (e.g. `/dev/sdb1`) is resolved by blkid at runtime — if USB backend is needed, users must add their specific device. Add a comment explaining this.

- [ ] **Step 2: Add a comment for USB users**

After the `/dev/disk` line, add:
```yaml
      # NOTE: For USB backend, you may also need to mount your specific
      # block device, e.g.: /dev/sdb1:/dev/sdb1
```

- [ ] **Step 3: Verify compose file is valid**

Run: `docker compose config --quiet`
Expected: exits 0

- [ ] **Step 4: Commit**

```bash
git add docker-compose.yml
git commit -m "security: restrict /dev mount to /dev/fuse and /dev/disk

Full /dev mount exposed raw disks and kernel interfaces. Only FUSE
device and disk-by-uuid (for blkid) are needed."
```

---

### Task 3: Remove LOCAL_BACKUP_PATH silent fallback to /tmp

**Files:**
- Modify: `docker-compose.yml:47`

When `LOCAL_BACKUP_PATH` is unset and `BACKUP_STORAGE_TYPE=local`, the compose file silently maps `/tmp/backup` as the backup destination. Backups written there are lost on reboot. For S3/USB backends the mount is overwritten by FUSE/device mount anyway, so we need a safe default that won't break those backends.

- [ ] **Step 1: Replace the fallback with a required variable approach**

Replace line 47:
```yaml
      - ${LOCAL_BACKUP_PATH:-/tmp/backup}:/mnt/backup
```
with:
```yaml
      - ${LOCAL_BACKUP_PATH:-/mnt/backup-unused}:/mnt/backup
```

Rationale: For S3/USB, the entrypoint overwrites `/mnt/backup` with a FUSE/device mount, so this bind mount is irrelevant. For local backend, the entrypoint already validates `LOCAL_BACKUP_PATH` is set (entrypoint:384-386) and exits if empty. Using `/mnt/backup-unused` (a path that doesn't exist on the host) instead of `/tmp/backup` means: if someone runs local backend without setting `LOCAL_BACKUP_PATH`, Docker creates an empty dir rather than silently using `/tmp`.

- [ ] **Step 2: Update the comment above the line**

Replace lines 45-46:
```yaml
      # Local backup destination (bind mount from host)
      # Used when BACKUP_STORAGE_TYPE=local, ignored for S3/USB (overwritten by FUSE/device mount)
```
with:
```yaml
      # Local backup destination (bind mount from host)
      # For BACKUP_STORAGE_TYPE=local: set LOCAL_BACKUP_PATH in .env (required)
      # For S3/USB: this mount is overwritten by FUSE/device mount in entrypoint
```

- [ ] **Step 3: Verify compose file is valid**

Run: `docker compose config --quiet`
Expected: exits 0

- [ ] **Step 4: Commit**

```bash
git add docker-compose.yml
git commit -m "fix: remove silent /tmp/backup fallback for LOCAL_BACKUP_PATH

Previously, unset LOCAL_BACKUP_PATH silently fell back to /tmp/backup,
causing backups to be lost on reboot. Now uses a dummy path that forces
explicit configuration for local backend."
```

---

### Task 4: Align AWS region default between .env.example and docker-compose.yml

**Files:**
- Modify: `docker-compose.yml:29`

`.env.example` shows `eu-central-1` as the example region, but `docker-compose.yml` defaults to `us-east-1`. This mismatch causes confusion. Since `.env.example` is what users copy, the compose default should match what they'd expect if they don't set the variable.

- [ ] **Step 1: Remove the default from docker-compose.yml**

Replace line 29:
```yaml
      - AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
```
with:
```yaml
      - AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
```

Rationale: The `.env` file (copied from `.env.example`) always has this value set. Removing the compose-level default means if it's somehow unset, the entrypoint's S3 connectivity check will fail with a clear error rather than silently using the wrong region.

- [ ] **Step 2: Commit**

```bash
git add docker-compose.yml
git commit -m "fix: remove AWS_DEFAULT_REGION fallback from docker-compose

Avoids silent mismatch with .env.example (eu-central-1 vs us-east-1).
Region must now be explicitly set in .env file."
```

---

## Chunk 2: run-backup.sh Robustness

### Task 5: Add concurrent execution protection with flock

**Files:**
- Modify: `run-backup.sh` (add flock near top, after directory check)

Two cron invocations running simultaneously can corrupt the borg repository. Use `flock` to ensure only one instance runs.

- [ ] **Step 1: Add lockfile mechanism after the .env check (after line 30)**

Insert after line 30 (`fi` closing the .env check):
```bash

# Prevent concurrent execution (protects borg repo from corruption)
LOCK_FILE="/tmp/borgbackup.lock"
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    echo -e "${RED}Error: Another backup is already running${NC}"
    echo "Lock file: $LOCK_FILE"
    exit 1
fi
```

- [ ] **Step 2: Verify script syntax**

Run: `bash -n run-backup.sh`
Expected: exits 0, no output

- [ ] **Step 3: Commit**

```bash
git add run-backup.sh
git commit -m "fix: add flock to prevent concurrent backup execution

Simultaneous runs can corrupt the borg repository. Uses flock with
/tmp/borgbackup.lock to ensure single-instance execution."
```

---

### Task 6: Add build error handling and sudo check

**Files:**
- Modify: `run-backup.sh` (lines 33-38)

If `docker compose build` fails, the script continues to run the backup with a stale image. Also, the script assumes passwordless sudo without checking.

- [ ] **Step 1: Add sudo check before the build (insert before line 33)**

Insert before line 33 (`# Rebuild the image`):
```bash
# Verify sudo access (needed for docker compose run)
if ! sudo -n true 2>/dev/null; then
    echo -e "${RED}Error: Passwordless sudo required but not available${NC}"
    echo "Configure sudoers or run as root"
    exit 1
fi

```

- [ ] **Step 2: Add error handling to build command**

Replace lines 33-34:
```bash
# Rebuild the image if needed (in case backup.sh was updated)
echo -e "${YELLOW}Building/updating Docker image...${NC}"
docker compose build
```
with:
```bash
# Rebuild the image if needed (in case backup.sh was updated)
echo -e "${YELLOW}Building/updating Docker image...${NC}"
if ! docker compose build --quiet; then
    echo -e "${RED}Error: Docker image build failed${NC}"
    exit 1
fi
```

- [ ] **Step 3: Add signal handling for clean container shutdown**

Insert after line 6 (`set -e`):
```bash

# Cleanup on interruption
cleanup() {
    echo -e "\n${YELLOW}Interrupted, stopping container...${NC}"
    sudo docker compose down --remove-orphans 2>/dev/null
    exit 130
}
trap cleanup INT TERM
```

- [ ] **Step 4: Verify script syntax**

Run: `bash -n run-backup.sh`
Expected: exits 0

- [ ] **Step 5: Commit**

```bash
git add run-backup.sh
git commit -m "fix: add sudo check, build error handling, and signal trap

- Fail fast if passwordless sudo unavailable
- Stop if docker compose build fails instead of running stale image
- Trap SIGINT/SIGTERM to cleanly stop containers on interruption"
```

---

## Chunk 3: backup.sh Error Handling

### Task 7: Add signal trap and dump directory cleanup

**Files:**
- Modify: `backup.sh` (add trap after line 18, add cleanup function)

If backup is interrupted (Ctrl+C, SIGTERM), dump directories are orphaned and never cleaned up. They accumulate on every failed run.

- [ ] **Step 1: Add cleanup function and trap after the variable declarations (after line 18)**

Insert after line 18 (`DUMP_DIR="${DUMP_BASE_DIR}"`):
```bash

# Cleanup handler for interruptions and failures
cleanup_on_exit() {
    local exit_code=$?
    if [ -d "${DUMP_DIR}" ] && [ "${DUMP_DIR}" != "/" ] && [ "${DUMP_DIR}" != "/mnt/target" ]; then
        info "Cleaning up dump directory: ${DUMP_DIR}" 2>/dev/null || true
        rm -rf "${DUMP_DIR}"
    fi
    exit ${exit_code}
}
trap cleanup_on_exit EXIT
```

Note: Using `EXIT` trap (not just SIGINT/SIGTERM) ensures cleanup runs on any exit — normal, error, or signal. The `set -e` on line 8 means any unhandled error will also trigger cleanup.

- [ ] **Step 2: Remove the explicit dump cleanup in perform_dumps (lines 84-86)**

The trap now handles cleanup. But the `perform_dumps` function still needs to create a fresh dump dir. Keep lines 84-86 (the `rm -rf` of old dumps) as-is because that removes *previous* run's dumps before creating new ones. The trap handles *current* run's dumps on failure.

No change needed — the existing cleanup in `perform_dumps` and the new trap serve different purposes.

- [ ] **Step 3: Verify script syntax**

Run: `bash -n backup.sh`
Expected: exits 0

- [ ] **Step 4: Commit**

```bash
git add backup.sh
git commit -m "fix: add EXIT trap to clean up dump directory on failure

Interrupted or failed backups left orphaned dump directories that
accumulated over time. Trap ensures cleanup on any exit path."
```

---

### Task 8: Validate BORG_REPO and BORG_PASSPHRASE early

**Files:**
- Modify: `backup.sh:269` (add validation at start of `main()`)

`BORG_REPO` is set by the entrypoint. If entrypoint fails to export it, backup.sh silently misbehaves. `BORG_PASSPHRASE` is also used without checking in this script.

- [ ] **Step 1: Add validation at the start of main() (after line 270)**

Insert after line 270 (`local storage_desc=$(get_storage_description)`):
```bash

    # Validate required environment variables
    if [ -z "${BORG_REPO}" ]; then
        error "BORG_REPO is not set (should be exported by entrypoint)"
        exit 1
    fi
    if [ -z "${BORG_PASSPHRASE}" ]; then
        error "BORG_PASSPHRASE is not set"
        exit 1
    fi
```

- [ ] **Step 2: Verify script syntax**

Run: `bash -n backup.sh`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add backup.sh
git commit -m "fix: validate BORG_REPO and BORG_PASSPHRASE at backup start

Fail fast with clear error if entrypoint didn't export BORG_REPO or
if BORG_PASSPHRASE is missing, instead of cryptic borg errors."
```

---

### Task 9: Fix pipe exit code capture (PIPESTATUS issue)

**Files:**
- Modify: `backup.sh:324-349` (backup pipe)
- Modify: `backup.sh:384-393` (prune pipe)

`set -o pipefail` is already set on line 9, which means the pipe's exit code IS the leftmost non-zero exit. So `PIPESTATUS[0]` should work correctly here because pipefail propagates borg's exit code. However, `set -e` (line 8) combined with `pipefail` means the script will EXIT immediately if borg fails — before reaching the `PIPESTATUS` check.

The real fix: disable `set -e` around the borg commands so we can capture the exit code.

- [ ] **Step 1: Wrap the backup borg create command to capture exit code**

Replace lines 324-349:
```bash
        borg create \
            --verbose \
            ${PROGRESS_OPT} \
            --stats \
            --show-rc \
            --exclude-caches \
            --compression lz4 \
            --one-file-system \
            --exclude 'backup/snapshots/*' \
            --exclude 'backup/log/*' \
            --exclude 'home/*/.cache/*' \
            --exclude 'var/cache/*' \
            --exclude 'var/tmp/*' \
            --exclude 'dev/*' \
            --exclude 'proc/*' \
            --exclude 'sys/*' \
            --exclude 'tmp/*' \
            --exclude 'run/*' \
            --exclude 'mnt/*' \
            --exclude 'media/*' \
            --exclude 'lost+found' \
            "${LOCAL_PATH_EXCLUDE[@]}" \
            ::'{hostname}-{now}' \
            . 2>&1 | tee -a "${LOG_FILE}"

        backup_exit=${PIPESTATUS[0]}
```
with:
```bash
        set +e
        borg create \
            --verbose \
            ${PROGRESS_OPT} \
            --stats \
            --show-rc \
            --exclude-caches \
            --compression lz4 \
            --one-file-system \
            --exclude 'backup/snapshots/*' \
            --exclude 'backup/log/*' \
            --exclude 'home/*/.cache/*' \
            --exclude 'var/cache/*' \
            --exclude 'var/tmp/*' \
            --exclude 'dev/*' \
            --exclude 'proc/*' \
            --exclude 'sys/*' \
            --exclude 'tmp/*' \
            --exclude 'run/*' \
            --exclude 'mnt/*' \
            --exclude 'media/*' \
            --exclude 'lost+found' \
            "${LOCAL_PATH_EXCLUDE[@]}" \
            ::'{hostname}-{now}' \
            . 2>&1 | tee -a "${LOG_FILE}"
        backup_exit=${PIPESTATUS[0]}
        set -e
```

- [ ] **Step 2: Apply the same fix to the prune command (lines 384-393)**

Replace lines 384-393:
```bash
        borg prune \
            ${PROGRESS_OPT} \
            --list \
            --glob-archives '{hostname}-*' \
            --show-rc \
            --keep-daily 7 \
            --keep-weekly 4 \
            --keep-monthly 6 2>&1 | tee -a "${LOG_FILE}"

        prune_exit=${PIPESTATUS[0]}
```
with:
```bash
        set +e
        borg prune \
            ${PROGRESS_OPT} \
            --list \
            --glob-archives '{hostname}-*' \
            --show-rc \
            --keep-daily 7 \
            --keep-weekly 4 \
            --keep-monthly 6 2>&1 | tee -a "${LOG_FILE}"
        prune_exit=${PIPESTATUS[0]}
        set -e
```

- [ ] **Step 3: Verify script syntax**

Run: `bash -n backup.sh`
Expected: exits 0

- [ ] **Step 4: Commit**

```bash
git add backup.sh
git commit -m "fix: disable set -e around borg commands to capture exit codes

set -e + pipefail caused immediate script exit on borg failure before
PIPESTATUS could be checked. Temporarily disable for proper exit code
capture and lock-retry logic."
```

---

## Chunk 4: Entrypoint Fixes

### Task 10: Mask AWS credentials in debug logs

**Files:**
- Modify: `entrypoint:85`

Debug logging shows first 10 characters of `AWS_ACCESS_KEY_ID`. This is enough to identify the key in AWS CloudTrail logs and narrows brute-force space.

- [ ] **Step 1: Change credential masking to show last 4 characters only**

Replace line 85:
```bash
        echo "AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:0:10}..."
```
with:
```bash
        echo "AWS_ACCESS_KEY_ID: ...${AWS_ACCESS_KEY_ID: -4}"
```

- [ ] **Step 2: Commit**

```bash
git add entrypoint
git commit -m "security: mask AWS access key in debug logs to last 4 chars

Previously showed first 10 chars which is enough to identify the key
in CloudTrail. Now shows only trailing 4 characters."
```

---

### Task 11: Replace s3fs sleep with polling loop

**Files:**
- Modify: `entrypoint:136-149` (replace `sleep 3` + `kill -0` check)

Fixed `sleep 3` is fragile — on slow networks s3fs may not be ready, on fast networks it wastes time. Replace with a polling loop that checks for actual mount readiness.

- [ ] **Step 1: Replace the sleep-based check with a polling loop**

Replace lines 135-149:
```bash
    # Give s3fs time to initialize
    log_debug "Waiting for s3fs to initialize..."
    sleep 3

    # Check if s3fs is still running
    if kill -0 $S3FS_PID 2>/dev/null; then
        log_debug "s3fs process is running (PID: $S3FS_PID)"
    else
        log_error "s3fs process died during initialization"
        if [ "$LOGGING" = "DEBUG" ] && [ -f /tmp/s3fs_debug.log ]; then
            echo "Last 20 lines of debug log:"
            tail -20 /tmp/s3fs_debug.log
        fi
        exit 1
    fi
```
with:
```bash
    # Wait for s3fs to initialize (poll instead of fixed sleep)
    log_debug "Waiting for s3fs to initialize..."
    for i in $(seq 1 30); do
        # Check if process died
        if ! kill -0 $S3FS_PID 2>/dev/null; then
            log_error "s3fs process died during initialization"
            if [ "$LOGGING" = "DEBUG" ] && [ -f /tmp/s3fs_debug.log ]; then
                echo "Last 20 lines of debug log:"
                tail -20 /tmp/s3fs_debug.log
            fi
            exit 1
        fi
        # Check if mount is ready
        if mountpoint -q /mnt/backup 2>/dev/null; then
            log_debug "s3fs mount detected after ${i}s (PID: $S3FS_PID)"
            break
        fi
        if [ "$i" -eq 30 ]; then
            log_error "s3fs mount timeout after 30 seconds"
            kill $S3FS_PID 2>/dev/null
            exit 1
        fi
        sleep 1
    done
```

- [ ] **Step 2: Verify script syntax**

Run: `bash -n entrypoint`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add entrypoint
git commit -m "fix: replace s3fs sleep with polling loop for mount readiness

Fixed 3s sleep was fragile on slow networks and wasteful on fast ones.
Now polls mountpoint every 1s with 30s timeout, failing fast if s3fs
process dies during initialization."
```

---

## Chunk 5: Low Priority — Dockerfile Improvements

### Task 12: Add HEALTHCHECK to Dockerfile

**Files:**
- Modify: `Dockerfile` (add HEALTHCHECK before ENTRYPOINT)

If s3fs hangs or `/mnt/backup` becomes inaccessible, the container appears healthy to Docker but backup will fail silently. A healthcheck lets orchestrators detect and restart stuck containers.

- [ ] **Step 1: Add HEALTHCHECK directive before ENTRYPOINT (before line 27)**

Insert before line 27 (`ENTRYPOINT ["/entrypoint"]`):
```dockerfile
# Health check: verify backup mount is accessible (only meaningful during backup runs)
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=3 \
    CMD test -d /mnt/backup || exit 1
```

Note: We use `test -d` rather than a write test because the mount may be read-only during prune or between operations. The `start-period=30s` allows time for s3fs to mount.

- [ ] **Step 2: Verify Dockerfile syntax**

Run: `cd /home/rodo/Coding/borgbackup && docker compose config --quiet`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "feat: add HEALTHCHECK to detect hung s3fs mounts

Checks /mnt/backup accessibility every 60s with 30s start grace
period. Allows orchestrators to detect and restart stuck containers."
```

---

### Task 13: Pin base image to SHA256 digest

**Files:**
- Modify: `Dockerfile:1`

Tag-only `FROM python:3.13.7-slim-trixie` means rebuilds may pull different content if the tag is updated. Pinning to digest ensures reproducible builds.

- [ ] **Step 1: Get the current digest**

Run: `docker pull python:3.13.7-slim-trixie && docker inspect --format='{{index .RepoDigests 0}}' python:3.13.7-slim-trixie`

This will output something like: `python@sha256:abcdef123...`

- [ ] **Step 2: Update the FROM line with the digest**

Replace line 1:
```dockerfile
FROM python:3.13.7-slim-trixie
```
with (using the actual digest from step 1):
```dockerfile
FROM python:3.13.7-slim-trixie@sha256:<digest-from-step-1>
```

Keep the tag for readability — Docker uses the digest for resolution when both are present.

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "build: pin base image to SHA256 digest for reproducibility

Tag-only FROM means rebuilds can pull different content. Digest pin
ensures bit-for-bit reproducible builds."
```

---

### Task 14: Remove build-only dependency libfuse-dev

**Files:**
- Modify: `Dockerfile:7` (split build deps from runtime deps)

`libfuse-dev` is a build-time dependency for compiling llfuse. It remains in the final image, wasting ~10MB. The runtime only needs `libfuse3-3` (or `libfuse2`) which is already pulled in by `fuse`.

- [ ] **Step 1: Move libfuse-dev to a separate install + purge**

Replace line 7:
```dockerfile
  && apt-get install -y python3-dev libacl1-dev libssl-dev liblz4-dev libzstd-dev libxxhash-dev build-essential pkg-config libfuse-dev fuse \
```
with:
```dockerfile
  && apt-get install -y python3-dev libacl1-dev libssl-dev liblz4-dev libzstd-dev libxxhash-dev build-essential pkg-config libfuse-dev fuse \
```

Actually, the `purge --auto-remove` on line 11 already removes auto-installed deps, but `libfuse-dev` was explicitly installed so it won't be auto-removed. The fix is to purge build-only packages after pip install. This requires restructuring.

Replace lines 3-15 (the entire build section):
```dockerfile
RUN --mount=type=cache,id=apt-cache,target=/var/cache/apt apt-get update \
  # dependencies for s3fs (latest version with cache management)
  && apt-get install -y s3fs=1.95-1 glib-networking curl gnupg gzip zip unzip \
  # build dependencies for borgbackup (removed after pip install)
  && apt-get install -y python3-dev libacl1-dev libssl-dev liblz4-dev libzstd-dev libxxhash-dev build-essential pkg-config libfuse-dev fuse \
  # dependencies for USB storage backend (blkid, ntfs support)
  && apt-get install -y util-linux ntfs-3g e2fsprogs xfsprogs btrfs-progs dosfstools \
  # cleaning up unused files
  && rm -rf /var/lib/apt/lists/*
# Requirements are installed here to ensure they will be cached.
RUN python -m pip install --upgrade pip
RUN --mount=type=cache,id=pip-cache,target=/root/.cache/pip pip install borgbackup==1.4.1 llfuse
# Remove build-only dependencies to reduce image size
RUN apt-get purge -y --auto-remove python3-dev libacl1-dev libssl-dev liblz4-dev libzstd-dev libxxhash-dev build-essential pkg-config libfuse-dev \
  && rm -rf /var/lib/apt/lists/*
```

Key change: moved `purge --auto-remove` to AFTER `pip install` and explicitly listed the build-only packages. Removed the old `purge` from the apt-get RUN since it ran before pip install (too early).

- [ ] **Step 2: Verify the image builds**

Run: `cd /home/rodo/Coding/borgbackup && docker compose build`
Expected: build completes successfully

- [ ] **Step 3: Verify borg and s3fs are present in the built image**

Run: `docker compose run --rm borgbackup bash -c "borg --version && s3fs --version && python -c 'import llfuse; print(\"llfuse OK\")'"`
Expected: shows borgbackup 1.4.1, s3fs version, and "llfuse OK"

- [ ] **Step 4: Commit**

```bash
git add Dockerfile
git commit -m "build: purge build-only deps after pip install to reduce image size

libfuse-dev, build-essential, python3-dev etc. are only needed for
compiling borgbackup/llfuse. Removing them saves ~100MB."
```

---

## Chunk 6: Low Priority — Resource Limits & Timeouts

### Task 15: Add resource limits to docker-compose.yml

**Files:**
- Modify: `docker-compose.yml` (add deploy section)

Runaway s3fs or borg processes could exhaust all host memory. Adding limits prevents a backup job from taking down the host.

- [ ] **Step 1: Add resource limits after the security_opt section**

Since Task 1 removes `security_opt`, add the deploy block after `cap_add` section. Insert after the `cap_add` block:
```yaml
    deploy:
      resources:
        limits:
          memory: 4G
```

Note: Only memory limit — CPU limit is unnecessary for a backup job that's I/O-bound. 4GB is generous for borg + s3fs; adjust per environment.

- [ ] **Step 2: Verify compose file is valid**

Run: `docker compose config --quiet`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "fix: add memory limit to prevent runaway resource consumption

Caps container at 4GB to prevent s3fs or borg from exhausting host
memory. Adjust in docker-compose.yml per environment needs."
```

---

### Task 16: Add timeout to borg operations

**Files:**
- Modify: `backup.sh` (wrap borg create and borg prune with timeout)

A stuck s3fs mount can cause borg to hang indefinitely. Adding a timeout ensures the backup eventually fails rather than blocking forever.

- [ ] **Step 1: Add BORG_TIMEOUT variable at top of backup.sh (after line 14)**

Insert after line 14 (`BORG_AUTO_BREAK_LOCK="${BORG_AUTO_BREAK_LOCK:-false}"`):
```bash
BORG_TIMEOUT="${BORG_TIMEOUT:-14400}"  # 4 hours default
```

- [ ] **Step 2: Prefix borg create with timeout (in the modified block from Task 9)**

In the `borg create` command block (already wrapped in `set +e`/`set -e` from Task 9), prefix the command:

Change:
```bash
        set +e
        borg create \
```
to:
```bash
        set +e
        timeout "${BORG_TIMEOUT}" borg create \
```

- [ ] **Step 3: Prefix borg prune with timeout (same approach)**

Change:
```bash
        set +e
        borg prune \
```
to:
```bash
        set +e
        timeout "${BORG_TIMEOUT}" borg prune \
```

Note: `timeout` returns exit code 124 on timeout. The existing error handling (`else` branch for exit codes > 1) will catch this and report "Borg backup failed with exit code: 124".

- [ ] **Step 4: Verify script syntax**

Run: `bash -n backup.sh`
Expected: exits 0

- [ ] **Step 5: Commit**

```bash
git add backup.sh
git commit -m "fix: add configurable timeout to borg create and prune

Prevents indefinite hangs from stuck s3fs mounts. Defaults to 4 hours
(BORG_TIMEOUT env var). Exit code 124 = timeout."
```

---

### Task 17: Guard df output parsing in backup.sh

**Files:**
- Modify: `backup.sh:150-153`

`df -BG` parsing can fail silently on unusual mounts (e.g., s3fs may not report meaningful space). If `available_space` is empty, the arithmetic comparison on line 153 fails with a bash error.

- [ ] **Step 1: Add validation around the df parsing**

Replace lines 150-156:
```bash
    local available_space=$(df -BG /mnt/backup | tail -1 | awk '{print $4}' | sed 's/G//')
    info "Available space on backup storage: ${available_space}GB"

    if [ "$available_space" -lt 5 ]; then
        error "WARNING: Less than 5GB available on backup storage!"
        error "Available: ${available_space}GB - Consider freeing up space or pruning old backups"
        # Don't exit, just warn - let user decide if they want to continue
    fi
```
with:
```bash
    local available_space
    available_space=$(df -BG /mnt/backup 2>/dev/null | tail -1 | awk '{print $4}' | sed 's/G//')

    if [ -z "${available_space}" ] || ! [[ "${available_space}" =~ ^[0-9]+$ ]]; then
        info "Could not determine available space on backup storage (common with s3fs)"
    else
        info "Available space on backup storage: ${available_space}GB"
        if [ "${available_space}" -lt 5 ]; then
            error "WARNING: Less than 5GB available on backup storage!"
            error "Available: ${available_space}GB - Consider freeing up space or pruning old backups"
        fi
    fi
```

- [ ] **Step 2: Verify script syntax**

Run: `bash -n backup.sh`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add backup.sh
git commit -m "fix: guard df output parsing against empty/non-numeric values

s3fs and some FUSE mounts don't report meaningful disk space. Now
handles empty or non-numeric df output gracefully instead of crashing."
```

---

## Chunk 7: Low Priority — run-backup.sh Polish

### Task 18: Add Docker daemon availability check

**Files:**
- Modify: `run-backup.sh` (add check before build)

If the Docker daemon isn't running, the error is delayed until the build step with an unhelpful message. Check early.

- [ ] **Step 1: Add Docker daemon check after the .env check (before the flock from Task 5)**

Insert after the `.env` file check (`fi` on line 30) and before the flock block:
```bash

# Verify Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    echo "Start Docker with: sudo systemctl start docker"
    exit 1
fi
```

- [ ] **Step 2: Verify script syntax**

Run: `bash -n run-backup.sh`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add run-backup.sh
git commit -m "fix: check Docker daemon availability before build

Provides a clear error message instead of cryptic docker compose
failure when daemon isn't running."
```

---

### Task 19: Respect NO_COLOR environment variable

**Files:**
- Modify: `run-backup.sh:8-12`

The script hardcodes ANSI color codes. The `NO_COLOR` standard (https://no-color.org/) says tools should disable colors when `NO_COLOR` is set, making output cleaner for log files and CI.

- [ ] **Step 1: Add NO_COLOR support to the color definitions**

Replace lines 8-12:
```bash
# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
```
with:
```bash
# Colors for output (respect NO_COLOR standard: https://no-color.org/)
if [ -n "${NO_COLOR}" ]; then
    RED='' GREEN='' YELLOW='' NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
fi
```

- [ ] **Step 2: Verify script syntax**

Run: `bash -n run-backup.sh`
Expected: exits 0

- [ ] **Step 3: Commit**

```bash
git add run-backup.sh
git commit -m "fix: respect NO_COLOR env var for clean log output

Disables ANSI color codes when NO_COLOR is set, per no-color.org
standard. Useful for cron jobs and log file redirection."
```

---

## Summary

| Task | File | Severity | Description |
|-|-|-|-|
| 1 | docker-compose.yml | CRITICAL | Remove privileged mode + AppArmor disable |
| 2 | docker-compose.yml | CRITICAL | Restrict /dev mount |
| 3 | docker-compose.yml | HIGH | Remove /tmp/backup fallback |
| 4 | docker-compose.yml | MED | Align AWS region defaults |
| 5 | run-backup.sh | HIGH | Add flock concurrent execution protection |
| 6 | run-backup.sh | HIGH+MED | Build error handling + sudo check + signal trap |
| 7 | backup.sh | MED | Signal trap + dump cleanup |
| 8 | backup.sh | HIGH | Validate BORG_REPO + BORG_PASSPHRASE |
| 9 | backup.sh | HIGH | Fix pipe exit code capture |
| 10 | entrypoint | MED | Mask AWS credentials in debug logs |
| 11 | entrypoint | MED | Replace s3fs sleep with polling loop |
| 12 | Dockerfile | LOW | Add HEALTHCHECK |
| 13 | Dockerfile | LOW | Pin base image to digest |
| 14 | Dockerfile | LOW | Remove build-only deps after pip install |
| 15 | docker-compose.yml | LOW | Add memory resource limit |
| 16 | backup.sh | LOW | Add configurable timeout to borg operations |
| 17 | backup.sh | LOW | Guard df output parsing |
| 18 | run-backup.sh | LOW | Docker daemon availability check |
| 19 | run-backup.sh | LOW | Respect NO_COLOR env var |

**Dependency notes:**
- Tasks 1-4 (docker-compose.yml) are independent of each other; Task 15 depends on Task 1 (removes security_opt first)
- Tasks 5-6 (run-backup.sh) are independent; Tasks 18-19 are independent of each other but should come after 5-6
- Tasks 7-9 (backup.sh): Task 7 before 9 (trap must exist before disabling set -e); Task 16 depends on 9; Task 17 is independent
- Tasks 10-11 (entrypoint) are independent of each other
- Tasks 12-14 (Dockerfile) are independent of each other
- All file groups are independent — can be parallelized across files
