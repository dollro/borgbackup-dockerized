# Dockerized BorgBackup with Multiple Storage Backends

A containerized solution for running BorgBackup operations with support for multiple storage backends: AWS S3, USB devices, and local storage. This Docker container provides a secure, isolated environment for performing backup operations.

## Key Features

- **Containerized BorgBackup**: Run Borg backup operations in an isolated Docker environment
- **Multiple Storage Backends**: Support for S3, USB devices, and local/NAS storage
- **USB Auto-Detection**: Automatically detects USB devices by UUID
- **Host Filesystem Access**: Full access to host filesystem for backing up any directory
- **Flexible Configuration**: Environment-based configuration for easy deployment
- **Automatic Lock Handling**: Configurable handling of stale repository locks
- **Debug Support**: Built-in debug logging for troubleshooting
- **Interactive & Non-interactive Modes**: Run one-off commands or interactive shell sessions

## Architecture

The container provides two main mount points:

- `/mnt/backup`: Your backup storage (S3 bucket, USB device, or local path)
- `/mnt/target`: Your host's root filesystem (for backup source)

This allows Borg to read files from your host system and store encrypted backups to your chosen storage backend.

## Documentation

- [Getting Started](getting-started.md) — requirements and first backup
- [Configuration](configuration.md) — environment variables
- [Storage Backends](backends.md) — S3, USB, and local setup
- [Usage](usage.md) — running backups and common commands
- [Restoring from Backup](restore.md) — single-file, full, FUSE, and bare-metal restores
- [Features](features.md) — lock handling, progress, dumps, retention
- [Scheduling](scheduling.md) — cron and multiple backends
- [Troubleshooting](troubleshooting.md)
- [Security Considerations](security.md)
- [Technical Reference](reference.md)
