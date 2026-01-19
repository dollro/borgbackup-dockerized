# Project Brief: Dockerized BorgBackup with S3 Storage

## Project Overview

A containerized solution for running BorgBackup operations with AWS S3 as the backup storage backend. This Docker container provides a secure, isolated environment for performing backup operations while mounting both an S3 bucket and the host filesystem.

## Core Requirements

### Primary Goals
1. **Containerized Backup Environment**: Run BorgBackup in an isolated Docker container
2. **S3 Integration**: Use AWS S3 as the backup storage destination via s3fs-fuse
3. **Host Filesystem Access**: Full access to host filesystem for backing up any directory
4. **Flexible Configuration**: Environment-based configuration for easy deployment
5. **Extensible Dump System**: Support for service-specific pre-backup dumps (e.g., Mailcow)

### Non-Functional Requirements
- **Security**: Encrypted backups with Borg's repokey encryption
- **Reliability**: Graceful cleanup and unmounting on exit
- **Observability**: Configurable logging levels (INFO/DEBUG)
- **Automation**: Support for cron-based scheduled backups

## Target Audience

- System administrators managing server backups
- DevOps engineers needing automated backup solutions
- Users with Mailcow installations requiring integrated backup

## Project Scope

### In Scope
- Docker container for BorgBackup with s3fs
- Automated backup script with pruning
- Mailcow-specific backup integration
- Interactive and non-interactive modes
- AWS S3 bucket mounting and cleanup

### Out of Scope
- GUI/Web interface
- Backup restoration automation (manual via borg commands)
- Additional cloud providers beyond S3 (Azure, GCP, etc.)

## Success Criteria

1. Container successfully mounts S3 bucket via s3fs
2. Backups are created and stored in S3
3. Pruning policies are applied correctly
4. Graceful cleanup on container exit
5. Works in both interactive shell and automated script modes

## Repository

- **Origin**: `git@git.dolltons.com:server/borgbackup.git`
- **License**: To be specified
