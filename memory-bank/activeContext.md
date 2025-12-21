# Active Context: Dockerized BorgBackup

## Current Work Focus

The project is in a **stable, production-ready state**. The core functionality for dockerized backups with S3 storage is complete and documented.

## Recent Changes

Based on the latest commit (`7fa77b9a6578f59330952ef17eafda240ad0d540`):

- Project structure is established
- All core scripts are implemented
- README documentation is comprehensive
- Memory Bank initialized

## Current State

### What's Working
- ✅ Docker container builds successfully
- ✅ S3 mounting via s3fs works with proper credentials
- ✅ BorgBackup operations (create, list, prune) functional
- ✅ Interactive mode for manual operations
- ✅ Automated backup script (`backup.sh`)
- ✅ Wrapper script (`run-backup.sh`) for easy execution
- ✅ Mailcow backup integration
- ✅ Debug/INFO logging modes
- ✅ Graceful cleanup and unmounting

### Active Components
| Component | Status | Notes |
|-----------|--------|-------|
| Dockerfile | Stable | Python 3.13.7, BorgBackup 1.4.1, s3fs 1.95-1 |
| docker-compose.yml | Stable | Privileged mode for FUSE |
| entrypoint | Stable | S3 mount, cleanup handlers |
| backup.sh | Stable | Full system backup with exclusions |
| run-backup.sh | Stable | Host-side wrapper |

## Next Steps

### Potential Enhancements
1. **Additional Dump Functions**: MySQL, PostgreSQL dump support (placeholders exist)
2. **Notification System**: Email/Slack alerts on backup completion/failure
3. **Health Checks**: Docker health check for monitoring
4. **Restore Script**: Automated restoration helper
5. **Multi-Repository**: Support for multiple backup destinations

### Technical Debt
- `start` script is empty (placeholder)
- License not specified in README

## Important Patterns & Preferences

### Command Execution
Always use Docker Compose to run backup commands:
```bash
# Correct
sudo docker compose run --rm borgbackup <command>

# Incorrect (never run directly on host)
borg <command>
```

### Environment Configuration
- Always copy `.env.example` to `.env`
- Never commit `.env` (contains secrets)
- Use DEBUG logging for troubleshooting only

### Backup Best Practices
1. Initialize repository before first backup: `borg init --encryption=repokey`
2. Save repository key in secure location
3. Test restoration periodically
4. Monitor backup logs

## Learnings & Project Insights

### s3fs Considerations
- Requires privileged Docker container for FUSE
- AppArmor must be disabled/unconfined
- 3-second sleep needed after mount for initialization
- Kernel cache improves performance significantly

### Borg on S3
- s3fs latency acceptable for backup operations
- Deduplication still effective despite FUSE layer
- Repository locking works correctly

### Interactive vs Non-Interactive
- Interactive mode (`-t` flag): No cleanup trap, direct exec
- Non-interactive: Background process, signal handlers, cleanup on exit
- This distinction prevents cleanup issues in interactive shells

## Configuration Quick Reference

### Environment Variables
```bash
# Required
S3_BUCKET_NAME=your-bucket
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=secret...
BORG_PASSPHRASE=secure-phrase

# Optional (with defaults)
AWS_DEFAULT_REGION=us-east-1
LOGGING=INFO
BORG_REPO=/mnt/backup/borgbackup
```

### Common Commands
```bash
# Build container
sudo docker compose build

# Interactive shell
sudo docker compose run --rm borgbackup bash

# Run backup
./run-backup.sh

# List archives
sudo docker compose run --rm borgbackup borg list

# Check repository
sudo docker compose run --rm borgbackup borg check
```
