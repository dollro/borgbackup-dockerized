# System Patterns: Dockerized BorgBackup

## System Architecture

### High-Level Architecture (Multi-Backend)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              HOST SYSTEM                                │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │                      DOCKER CONTAINER                              │ │
│  │                                                                    │ │
│  │  ┌─────────────┐    ┌─────────────────────────────────────────┐   │ │
│  │  │  entrypoint │───►│     STORAGE BACKEND SELECTION           │   │ │
│  │  │  (bash)     │    │     (BACKUP_STORAGE_TYPE)               │   │ │
│  │  └─────────────┘    └──────────────┬──────────────────────────┘   │ │
│  │                                     │                              │ │
│  │         ┌───────────────────────────┼───────────────────────────┐ │ │
│  │         │                           │                           │ │ │
│  │         ▼                           ▼                           ▼ │ │
│  │  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐│
│  │  │  S3 Backend │           │ USB Backend │           │Local Backend││
│  │  │  (s3fs)     │           │ (blkid+mount│           │ (bind mount)││
│  │  └──────┬──────┘           └──────┬──────┘           └──────┬──────┘│
│  │         │                         │                         │      │ │
│  │         └─────────────────────────┼─────────────────────────┘      │ │
│  │                                   ▼                                │ │
│  │                          ┌─────────────┐                           │ │
│  │                          │ /mnt/backup │◄── Common mount point     │ │
│  │                          └──────┬──────┘                           │ │
│  │                                 │                                  │ │
│  │  ┌─────────────┐         ┌──────┴──────┐         ┌─────────────┐  │ │
│  │  │  Command    │────────►│  BorgBackup │────────►│  Repository │  │ │
│  │  │  (backup.sh)│         │  (borg)     │         │  (encrypted)│  │ │
│  │  └─────────────┘         └──────┬──────┘         └─────────────┘  │ │
│  │                                 │                                  │ │
│  │                                 ▼                                  │ │
│  │                          ┌─────────────┐                           │ │
│  │                          │ /mnt/target │◄── Host filesystem        │ │
│  │                          └─────────────┘                           │ │
│  └───────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
   ┌───────────┐          ┌───────────┐          ┌───────────┐
   │  AWS S3   │          │ USB Drive │          │ Local/NAS │
   │ (HTTPS)   │          │ (block)   │          │ (path)    │
   └───────────┘          └───────────┘          └───────────┘
```

## Component Relationships

### Container Lifecycle (Multi-Backend)

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   docker     │────►│  entrypoint  │────►│   command    │────►│   cleanup    │
│   run        │     │  (backend    │     │  (borg/bash) │     │  (backend    │
│              │     │   setup)     │     │              │     │   cleanup)   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                            │                     │                     │
                            ▼                     ▼                     ▼
                     Select backend        Execute backup         Cleanup backend
                     Setup mount           or user command        Unmount storage
                     Verify access                                Clean temp files
```

### Backend Selection Flow

```
BACKUP_STORAGE_TYPE
        │
        ├── "s3"  ──────► setup_s3_backend()
        │                      │
        │                      ├── Create credentials file
        │                      ├── Mount with s3fs
        │                      └── Verify S3 mount
        │
        ├── "usb" ──────► setup_usb_backend()
        │                      │
        │                      ├── Find device by UUID (blkid -U)
        │                      ├── Detect filesystem type
        │                      └── Mount device to /mnt/backup
        │
        └── "local" ────► setup_local_backend()
                               │
                               ├── Verify path exists
                               └── Verify write access
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
                    │       ├── Select backend (BACKUP_STORAGE_TYPE)
                    │       ├── Setup backend (setup_*_backend())
                    │       ├── Verify mount (verify_*_mount())
                    │       └── Set up signal handlers
                    │
                    └── backup.sh (main logic)
                            │
                            ├── verify_storage_backend()
                            ├── perform_dumps()
                            │       └── perform_dumps_mailcow()
                            │
                            ├── borg create (backup)
                            │
                            └── borg prune (cleanup)
```

## Design Patterns

### 1. Storage Backend Pattern (New)
Modular backend selection with consistent interface:

```bash
# Pattern: Backend Selection → Setup → Verify → Execute → Cleanup
case "$BACKUP_STORAGE_TYPE" in
    s3)
        setup_s3_backend
        ;;
    usb)
        setup_usb_backend
        ;;
    local)
        setup_local_backend
        ;;
esac
```

Each backend implements:
- `setup_*_backend()` - Initialize and mount storage
- `verify_*_mount()` - Verify access and permissions
- `cleanup_*_backend()` - Unmount and clean up

### 2. Entrypoint Pattern
The entrypoint script handles all initialization before the main command:

```bash
# Pattern: Initialize → Execute → Cleanup
setup_storage_backend         # Setup chosen backend
exec "$@"                     # Execute command
cleanup                       # Teardown (via trap)
```

### 3. Environment-Based Configuration
All configuration via environment variables:

```yaml
environment:
  - BACKUP_STORAGE_TYPE=${BACKUP_STORAGE_TYPE:-s3}
  - S3_BUCKET_NAME=${S3_BUCKET_NAME}
  - USB_DEVICE_UUID=${USB_DEVICE_UUID}
  - LOCAL_BACKUP_PATH=${LOCAL_BACKUP_PATH}
  - BORG_REPO_PATH=${BORG_REPO_PATH:-borgbackup}
  - LOGGING=${LOGGING:-INFO}
```

### 4. Interactive vs Non-Interactive Detection
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

### 5. Modular Dump System
Extensible pre-backup dump functions:

```bash
perform_dumps() {
    mkdir -p "${DUMP_DIR}"
    
    # Call service-specific dumps
    perform_dumps_mailcow     # Implemented
    # perform_dumps_mysql     # Placeholder
    # perform_dumps_postgresql # Placeholder
}
```

### 6. Graceful Cleanup Pattern
Multi-step cleanup with fallbacks:

```bash
cleanup_*_backend() {
    # Step 1: Normal unmount with timeout
    timeout 10s umount /mnt/backup || \
    # Step 2: Lazy unmount
    umount -l /mnt/backup || \
    # Step 3: Force unmount
    umount -f /mnt/backup
    
    # Clean temp files
    # (backend-specific cleanup)
}
```

### 7. Debug/Production Logging Pattern
Conditional verbosity based on environment:

```bash
if [ "$LOGGING" = "DEBUG" ]; then
    # Full debug output
    echo "Detailed information..."
else
    # Minimal output
fi
```

## Critical Implementation Paths

### Backend Setup Paths

#### S3 Backend Path
```
1. Validate environment (S3_BUCKET_NAME, AWS_*)
2. Create credentials file (/etc/passwd-s3fs)
3. Create mount point (/mnt/backup)
4. Execute s3fs with mount options
5. Wait for initialization (sleep 3)
6. Verify mount (mount | grep, ls test)
7. Report success/failure
```

#### USB Backend Path
```
1. Validate environment (USB_DEVICE_UUID)
2. Find device by UUID (blkid -U)
3. Detect filesystem type (blkid -s TYPE)
4. Create mount point (/mnt/backup)
5. Mount with appropriate options
6. Verify mount and write access
7. Report success/failure
```

#### Local Backend Path
```
1. Validate environment (LOCAL_BACKUP_PATH)
2. Verify /mnt/backup exists (bind mounted by Docker)
3. Test write access
4. Report success/failure
```

### Backup Execution Path

```
1. Verify storage backend is accessible
2. Perform pre-backup dumps (Mailcow, etc.)
3. Change to /mnt/target (host root)
4. Execute borg create with exclusions
5. Execute borg prune with retention policy
6. Log results and exit codes
```

### Cleanup Paths

#### S3 Cleanup
```
1. Catch SIGINT/SIGTERM
2. Attempt unmount with timeout
3. Fall back to lazy/force unmount
4. Remove /etc/passwd-s3fs
5. Remove /tmp/s3fs_cache
```

#### USB Cleanup
```
1. Catch SIGINT/SIGTERM
2. Sync filesystem
3. Attempt unmount
4. Fall back to lazy unmount
```

#### Local Cleanup
```
1. Sync filesystem
2. (No unmount needed - bind mount)
```

## File System Layout in Container

```
/
├── mnt/
│   ├── backup/              ← Storage mount point (all backends)
│   │   └── borgbackup/      ← Borg repository (BORG_REPO)
│   └── target/              ← Host filesystem (bind mount)
│       ├── home/
│       ├── etc/
│       ├── var/
│       └── ...
├── dev/                     ← Device access (for USB backend)
│   ├── sda, sdb, ...
│   └── fuse
├── tmp/
│   └── s3fs_cache/          ← s3fs cache (S3 backend only)
├── etc/
│   └── passwd-s3fs          ← S3 credentials (S3 backend only)
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
log_info() { echo "[INFO] $1"; }
log_debug() { [ "$LOGGING" = "DEBUG" ] && echo "[DEBUG] $1"; }
log_error() { echo "[ERROR] $1" >&2; }
log_success() { echo "[SUCCESS] $1"; }
```

### Backend-Aware Error Messages

```bash
verify_storage_backend() {
    case "$BACKUP_STORAGE_TYPE" in
        s3)    error "S3 bucket is not mounted..." ;;
        usb)   error "USB device is not mounted..." ;;
        local) error "Local path does not exist..." ;;
    esac
}
```

## Docker Compose Patterns

### Service Profiles
```yaml
services:
  # Default service (S3, USB)
  borgbackup:
    # ... configuration

  # Profile-based service (Local)
  borgbackup-local:
    profiles:
      - local
    volumes:
      - ${LOCAL_BACKUP_PATH}:/mnt/backup
```

Usage:
```bash
# S3 or USB (default)
docker compose run --rm borgbackup ...

# Local (with profile)
docker compose --profile local run --rm borgbackup-local ...
```
