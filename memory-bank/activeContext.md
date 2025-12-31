# Active Context: Dockerized BorgBackup

## Current Work Focus

The project is in a **stable, production-ready state** with **multi-backend storage support**. The system now supports three storage backends: AWS S3, USB devices, and local/NAS storage.

## Recent Changes

Latest implementation (December 2025):

### Lock Handling Feature (Dec 31, 2025)
- ✅ **Automatic Lock Handling** implemented
  - New `BORG_AUTO_BREAK_LOCK` environment variable
  - Three modes: `false` (default), `manual` (user prompt), `auto` (60s timeout)
  - Handles stale locks from interrupted backups
  - Retry logic for both backup and prune operations
- ✅ Updated README with stale lock troubleshooting section
- ✅ Updated `.env.example` with new configuration option
- ✅ Enhanced `backup.sh` with lock detection and break-lock logic

### Multi-Backend Storage Support
- ✅ **Multi-Backend Storage Support** implemented
  - S3 backend (existing, refactored)
  - USB backend with UUID auto-detection
  - Local/NAS backend with bind mount
- ✅ New environment variable `BACKUP_STORAGE_TYPE` for backend selection
- ✅ Dockerfile updated with USB filesystem tools (ntfs-3g, util-linux, etc.)
- ✅ docker-compose.yml with profiles for local storage
- ✅ Comprehensive documentation for all backends

## Current State

### What's Working
- ✅ Docker container builds successfully
- ✅ **S3 backend** - S3 mounting via s3fs with proper credentials
- ✅ **USB backend** - Auto-detection by UUID, supports ext4/ntfs/xfs/btrfs
- ✅ **Local backend** - Bind mount for NAS/network shares
- ✅ BorgBackup operations (create, list, prune) functional on all backends
- ✅ Interactive mode for manual operations
- ✅ Automated backup script (`backup.sh`) with backend-aware verification
- ✅ Wrapper script (`run-backup.sh`) for easy execution
- ✅ Mailcow backup integration
- ✅ Debug/INFO logging modes
- ✅ Graceful cleanup and unmounting for all backends

### Active Components
| Component | Status | Notes |
|-----------|--------|-------|
| Dockerfile | Stable | Python 3.13.7, BorgBackup 1.4.1, s3fs 1.95-1, USB tools |
| docker-compose.yml | Stable | Multi-backend env vars, local profile |
| entrypoint | Stable | Backend selection, S3/USB/Local setup & cleanup |
| backup.sh | Stable | Backend-aware verification and logging |
| run-backup.sh | Stable | Host-side wrapper |

## Storage Backend Quick Reference

### Environment Variable: `BACKUP_STORAGE_TYPE`

| Value | Backend | Required Config |
|-------|---------|-----------------|
| `s3` (default) | AWS S3 via s3fs | `S3_BUCKET_NAME`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| `usb` | USB device | `USB_DEVICE_UUID` |
| `local` | Local/NAS path | `LOCAL_BACKUP_PATH` (use `--profile local` service) |

### Usage Examples
```bash
# S3 Backend (default)
BACKUP_STORAGE_TYPE=s3
sudo docker compose run --rm borgbackup /usr/sbin/backup.sh

# USB Backend
BACKUP_STORAGE_TYPE=usb
sudo docker compose run --rm borgbackup /usr/sbin/backup.sh

# Local/NAS Backend
BACKUP_STORAGE_TYPE=local
sudo docker compose --profile local run --rm borgbackup-local /usr/sbin/backup.sh
```

## Next Steps

### Potential Enhancements
1. **SSH Backend**: Direct backup to remote Linux server (Borg native SSH support)
2. **Database Dumps**: MySQL, PostgreSQL dump support (placeholders exist)
3. **Notification System**: Email/Slack alerts on backup completion/failure
4. **Health Checks**: Docker health check for monitoring
5. **Restore Script**: Automated restoration helper

### Technical Debt
- `start` script is empty (placeholder)
- License not specified in README

## Important Patterns & Preferences

### Command Execution
Always use Docker Compose to run backup commands:
```bash
# S3 or USB backend
sudo docker compose run --rm borgbackup <command>

# Local backend (use profile)
sudo docker compose --profile local run --rm borgbackup-local <command>
```

### Environment Configuration
- Always copy `.env.example` to `.env`
- Never commit `.env` (contains secrets)
- Set `BACKUP_STORAGE_TYPE` based on your storage choice
- Use DEBUG logging for troubleshooting only

### Backup Best Practices
1. Initialize repository before first backup: `borg init --encryption=repokey`
2. Save repository key in secure location
3. Test restoration periodically
4. Monitor backup logs

## Learnings & Project Insights

### Multi-Backend Architecture
- Entrypoint script uses case/switch for backend selection
- Each backend has setup/verify/cleanup functions
- Common mount point `/mnt/backup` for all backends
- Backend-specific environment variable validation

### USB Backend Insights
- `blkid -U` for UUID-based device lookup
- Supports multiple filesystems (ext4, ntfs, xfs, btrfs, vfat)
- Container needs `/dev` mount for device access
- Filesystem type auto-detected via `blkid -s TYPE`

### Local Backend Insights
- Uses Docker Compose profiles (`--profile local`)
- Bind mount from host to `/mnt/backup`
- Separate service `borgbackup-local` in docker-compose.yml
- No privileged mode needed for local backend

### s3fs Considerations (S3 Backend)
- Requires privileged Docker container for FUSE
- AppArmor must be disabled/unconfined
- 3-second sleep needed after mount for initialization
- Kernel cache improves performance significantly

## Configuration Quick Reference

### Common Environment Variables
```bash
# Storage Backend (s3 | usb | local)
BACKUP_STORAGE_TYPE=s3

# Borg Configuration
BORG_REPO_PATH=borgbackup
BORG_PASSPHRASE=secure-phrase
LOGGING=INFO
```

### S3 Backend Variables
```bash
S3_BUCKET_NAME=your-bucket
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=secret...
AWS_DEFAULT_REGION=us-east-1
```

### USB Backend Variables
```bash
USB_DEVICE_UUID=1234-5678-90AB-CDEF
```

### Local Backend Variables
```bash
LOCAL_BACKUP_PATH=/mnt/nas/backups
```

### Common Commands
```bash
# Build container
sudo docker compose build

# Interactive shell (S3/USB)
sudo docker compose run --rm borgbackup bash

# Interactive shell (Local)
sudo docker compose --profile local run --rm borgbackup-local bash

# Run backup
./run-backup.sh

# List archives
sudo docker compose run --rm borgbackup borg list

# Check repository
sudo docker compose run --rm borgbackup borg check
```
