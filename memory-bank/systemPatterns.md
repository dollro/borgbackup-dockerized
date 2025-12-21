# System Patterns: Dockerized BorgBackup

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              HOST SYSTEM                                │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                      DOCKER CONTAINER                              │ │
│  │                                                                    │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐           │ │
│  │  │  entrypoint │───►│   s3fs      │───►│  /mnt/backup│           │ │
│  │  │  (bash)     │    │  (FUSE)     │    │  (S3 mount) │           │ │
│  │  └─────────────┘    └─────────────┘    └──────┬──────┘           │ │
│  │         │                                      │                   │ │
│  │         ▼                                      ▼                   │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐           │ │
│  │  │  Command    │───►│  BorgBackup │───►│  Repository │           │ │
│  │  │  (backup.sh)│    │  (borg)     │    │  (encrypted)│           │ │
│  │  └─────────────┘    └──────┬──────┘    └─────────────┘           │ │
│  │                            │                                       │ │
│  │                            ▼                                       │ │
│  │                     ┌─────────────┐                               │ │
│  │                     │ /mnt/target │◄──── Host filesystem          │ │
│  │                     │  (bind)     │                               │ │
│  │                     └─────────────┘                               │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│  / ─────────────────────────────────────────────────────────────────►  │
│  (bind mounted to container)                                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                          ┌─────────────────┐
                          │    AWS S3       │
                          │  (via HTTPS)    │
                          └─────────────────┘
```

## Component Relationships

### Container Lifecycle

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   docker     │────►│  entrypoint  │────►│   command    │────►│   cleanup    │
│   run        │     │  (mount s3)  │     │  (borg/bash) │     │  (unmount)   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                            │                     │                     │
                            ▼                     ▼                     ▼
                      Mount S3 bucket      Execute backup         Unmount S3
                      Verify mount         or user command        Clean temp files
                      Set up cleanup                              Exit gracefully
```

### Script Dependency Chain

```
run-backup.sh (host)
       │
       ├── docker compose build
       │
       └── docker compose run --rm borgbackup /usr/sbin/backup.sh
                    │
                    ├── entrypoint (initialization)
                    │       │
                    │       ├── Mount S3 bucket
                    │       ├── Verify mount
                    │       └── Set up signal handlers
                    │
                    └── backup.sh (main logic)
                            │
                            ├── perform_dumps()
                            │       └── perform_dumps_mailcow()
                            │
                            ├── borg create (backup)
                            │
                            └── borg prune (cleanup)
```

## Design Patterns

### 1. Entrypoint Pattern
The entrypoint script handles all initialization before the main command runs:

```bash
# Pattern: Initialize → Execute → Cleanup
mkdir -p /mnt/backup              # Setup
s3fs ... /mnt/backup              # Mount
exec "$@"                          # Execute command
cleanup                            # Teardown (via trap)
```

### 2. Environment-Based Configuration
All configuration via environment variables:

```yaml
environment:
  - S3_BUCKET_NAME=${S3_BUCKET_NAME}
  - BORG_REPO=${BORG_REPO}
  - LOGGING=${LOGGING:-INFO}       # With defaults
```

### 3. Interactive vs Non-Interactive Detection
Different behavior based on terminal attachment:

```bash
if [ -t 0 ] && [ -t 1 ]; then
    # Interactive: exec directly, no cleanup trap
    exec "$@"
else
    # Non-interactive: background process, cleanup trap
    exec "$@" &
    wait $MAIN_PID
    cleanup
fi
```

### 4. Modular Dump System
Extensible pre-backup dump functions:

```bash
perform_dumps() {
    # Create dump directory
    mkdir -p "${DUMP_DIR}"
    
    # Call service-specific dumps
    perform_dumps_mailcow     # Implemented
    # perform_dumps_mysql     # Placeholder
    # perform_dumps_postgresql # Placeholder
}
```

### 5. Graceful Cleanup Pattern
Multi-step cleanup with fallbacks:

```bash
cleanup() {
    # Step 1: Normal unmount with timeout
    timeout 10s umount /mnt/backup || \
    # Step 2: Lazy unmount
    umount -l /mnt/backup || \
    # Step 3: Force unmount
    umount -f /mnt/backup
    
    # Clean temp files
    rm -f /etc/passwd-s3fs
    rm -rf /tmp/s3fs_cache
}
```

### 6. Debug/Production Logging Pattern
Conditional verbosity based on environment:

```bash
if [ "$LOGGING" = "DEBUG" ]; then
    # Full debug output with curl tests, stats, etc.
    s3fs ... -o dbglevel=info -o curldbg
else
    # Minimal output
    s3fs ... >/dev/null 2>&1
fi
```

## Critical Implementation Paths

### S3 Mount Path

```
1. Validate environment (S3_BUCKET_NAME, AWS_*)
2. Create credentials file (/etc/passwd-s3fs)
3. Create mount point (/mnt/backup)
4. Execute s3fs with mount options
5. Wait for initialization (sleep 3)
6. Verify mount (mount | grep, ls test)
7. Report success/failure
```

### Backup Execution Path

```
1. Verify S3 mount is active
2. Perform pre-backup dumps (Mailcow, etc.)
3. Change to /mnt/target (host root)
4. Execute borg create with exclusions
5. Execute borg prune with retention policy
6. Log results and exit codes
```

### Cleanup Path

```
1. Catch SIGINT/SIGTERM (non-interactive only)
2. Attempt normal unmount with 10s timeout
3. Fall back to lazy unmount (-l)
4. Fall back to force unmount (-f)
5. Remove credentials file
6. Remove cache directory
7. Exit with appropriate code
```

## File System Layout in Container

```
/
├── mnt/
│   ├── backup/              ← S3 bucket (s3fs)
│   │   └── borgbackup/      ← Borg repository (BORG_REPO)
│   └── target/              ← Host filesystem (bind mount)
│       ├── home/
│       ├── etc/
│       ├── var/
│       └── ...
├── tmp/
│   └── s3fs_cache/          ← s3fs cache directory
├── etc/
│   └── passwd-s3fs          ← S3 credentials (runtime)
├── var/
│   └── log/
│       └── borgbackup/      ← Backup logs
└── usr/
    └── sbin/
        └── backup.sh        ← Main backup script
```

## Error Handling Patterns

### Exit Code Propagation

```bash
backup_exit=${PIPESTATUS[0]}
prune_exit=${PIPESTATUS[0]}
global_exit=$(( backup_exit > prune_exit ? backup_exit : prune_exit ))
exit ${global_exit}
```

### Exit Code Meanings

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Warning (Borg completed with warnings) |
| 2+ | Error |

### Logging Functions

```bash
log() { echo "[$(date)] [$1] $2" | tee -a "$LOG_FILE"; }
info() { log "INFO" "$@"; }
error() { log "ERROR" "$@"; }
success() { log "SUCCESS" "$@"; }
```
