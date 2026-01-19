# Progress: Dockerized BorgBackup

## Project Status: ✅ Production Ready with Multi-Backend Support

The backup solution is complete with support for multiple storage backends: AWS S3, USB devices, and local/NAS storage.

## What Works

### Core Features
| Feature | Status | Description |
|---------|--------|-------------|
| Docker Container | ✅ Complete | Python 3.13.7 slim with all dependencies |
| **Multi-Backend Storage** | ✅ Complete | S3, USB, and Local storage support |
| **Automatic Lock Handling** | ✅ Complete | Three modes: false/manual/auto for stale locks |
| **Real-time Progress Display** | ✅ Complete | SHOW_PROGRESS env var for live backup monitoring |
| S3 Integration | ✅ Complete | s3fs-fuse mounts S3 bucket as filesystem |
| USB Integration | ✅ Complete | Auto-detect by UUID, multiple filesystems |
| Local/NAS Integration | ✅ Complete | Bind mount for any host path |
| BorgBackup | ✅ Complete | v1.4.1 with encryption and deduplication |
| Interactive Mode | ✅ Complete | Shell access for manual operations |
| Automated Backup | ✅ Complete | Full system backup with `backup.sh` |
| Mailcow Support | ✅ Complete | Auto-detects and backs up Mailcow |
| Retention Policy | ✅ Complete | 7 daily, 4 weekly, 6 monthly |
| Graceful Cleanup | ✅ Complete | Multi-stage unmount with fallbacks |
| Debug Logging | ✅ Complete | INFO/DEBUG log levels |
| Documentation | ✅ Complete | Comprehensive README for all backends |

### Storage Backends
| Backend | Status | Configuration |
|---------|--------|---------------|
| AWS S3 | ✅ Complete | `BACKUP_STORAGE_TYPE=s3` + S3 credentials |
| USB Device | ✅ Complete | `BACKUP_STORAGE_TYPE=usb` + `USB_DEVICE_UUID` |
| Local/NAS | ✅ Complete | `BACKUP_STORAGE_TYPE=local` + `LOCAL_BACKUP_PATH` |

### Scripts
| Script | Status | Purpose |
|--------|--------|---------|
| `Dockerfile` | ✅ | Container build with USB filesystem tools |
| `docker-compose.yml` | ✅ | Multi-backend service orchestration |
| `entrypoint` | ✅ | Backend selection, setup, and cleanup |
| `backup.sh` | ✅ | Backend-aware backup automation |
| `run-backup.sh` | ✅ | Host-side wrapper |
| `.env.example` | ✅ | Configuration template for all backends |

## What's Left to Build

### Planned Enhancements (Not Started)

#### SSH Backend (Future)
- [ ] Direct backup to remote Linux server via SSH
- [ ] Borg native SSH support (no FUSE mount needed)

#### Database Dump Support
- [ ] MySQL/MariaDB dump function
- [ ] PostgreSQL dump function
- [ ] MongoDB dump function

#### Notifications
- [ ] Email notifications on completion/failure
- [ ] Slack/Discord webhook integration
- [ ] Healthcheck endpoint for monitoring

#### Restoration Helpers
- [ ] Interactive restore wizard
- [ ] Point-in-time recovery script
- [ ] File search across archives

### Technical Improvements (Nice to Have)
- [ ] Docker health check configuration
- [ ] Prometheus metrics endpoint
- [ ] Backup verification automation
- [ ] Incremental restore optimization

## Current Limitations

### Known Constraints
1. **Privileged Container**: Required for FUSE (S3) and device access (USB)
2. **Single Repository**: One backup destination per container instance
3. **No Web UI**: Command-line only interface
4. **Manual Restore**: No automated restoration scripts

### Edge Cases Not Handled
1. Very large files (>5GB) may have s3fs multipart upload issues
2. High-frequency backups may hit S3 API rate limits
3. Network interruption during backup leaves partial archive
4. USB device must be connected before container starts

## Evolution of Project Decisions

### Architecture Choices

#### Why Multi-Backend Support?
- **Decision**: Support S3, USB, and Local storage backends
- **Rationale**: Different use cases require different storage (cloud vs local vs portable)
- **Implementation**: Entrypoint script with case/switch for backend selection

#### Why UUID for USB Detection?
- **Decision**: Auto-detect USB devices by UUID instead of device path
- **Rationale**: Device paths (/dev/sdb1) can change; UUIDs are stable
- **Implementation**: `blkid -U` for lookup, automatic mount

#### Why Docker Compose Profiles for Local?
- **Decision**: Use `--profile local` for local backend service
- **Rationale**: Local backend needs different volume mounts (bind mount vs internal)
- **Implementation**: Separate `borgbackup-local` service in docker-compose.yml

#### Why Docker?
- **Decision**: Containerize BorgBackup instead of bare-metal installation
- **Rationale**: Isolation, reproducibility, easy deployment across servers
- **Trade-off**: Added complexity, privileged container requirement

#### Why s3fs over rclone mount?
- **Decision**: Use s3fs-fuse for S3 mounting
- **Rationale**: More stable, better Borg compatibility, well-tested
- **Trade-off**: Debian package version may lag behind

#### Why not Borg 2.x?
- **Decision**: Stick with BorgBackup 1.4.1
- **Rationale**: 1.x is stable and widely tested; 2.x was still in beta
- **Future**: Consider upgrade path when 2.x is stable

### Script Design Decisions

#### Storage Backend Pattern
- **Decision**: Each backend has setup/verify/cleanup functions
- **Rationale**: Clean separation, easy to add new backends
- **Pattern**: `setup_*_backend()`, `verify_*_mount()`, `cleanup_*_backend()`

#### Interactive vs Non-Interactive Detection
- **Decision**: Different cleanup behavior based on terminal attachment
- **Rationale**: Interactive sessions shouldn't auto-cleanup on exit
- **Implementation**: Check `-t 0 && -t 1` for TTY detection

#### Modular Dump System
- **Decision**: Separate functions for each service backup
- **Rationale**: Easy to add new services without modifying core logic
- **Pattern**: `perform_dumps_<service>()` function naming

## Milestones

### Completed ✅
1. ~~Initial Docker setup~~
2. ~~S3 mounting via s3fs~~
3. ~~BorgBackup integration~~
4. ~~Entrypoint script with cleanup~~
5. ~~Backup automation script~~
6. ~~Mailcow integration~~
7. ~~Debug logging support~~
8. ~~README documentation~~
9. ~~Memory Bank initialization~~
10. ~~**Multi-Backend Storage Support**~~ (December 2025)
    - S3 backend (refactored)
    - USB backend with UUID auto-detection
    - Local/NAS backend with bind mount
11. ~~**Dockerfile USB tools**~~ (util-linux, ntfs-3g, etc.)
12. ~~**docker-compose.yml profiles**~~
13. ~~**Backend-aware backup.sh**~~
14. ~~**Automatic Lock Handling**~~ (December 31, 2025)
    - `BORG_AUTO_BREAK_LOCK` environment variable
    - Three modes: false (default), manual (prompt), auto (60s timeout)
    - Retry logic for backup and prune operations
    - Comprehensive troubleshooting documentation

### Future Milestones
1. SSH backend support
2. Database dump support
3. Notification system
4. Restore automation

## Testing Status

### Manual Testing Completed
- [x] Container builds without errors
- [x] S3 mount works with valid credentials
- [x] USB mount works with valid UUID
- [x] Local mount works with valid path
- [x] Borg init creates encrypted repository
- [x] Borg create backup completes
- [x] Borg prune applies retention policy
- [x] Interactive shell works
- [x] Cleanup unmounts properly (all backends)
- [x] Debug mode shows verbose output
- [x] Backend selection via `BACKUP_STORAGE_TYPE`

### Automated Testing (Not Implemented)
- [ ] Unit tests
- [ ] Integration tests
- [ ] CI/CD pipeline
