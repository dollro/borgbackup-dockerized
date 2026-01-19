# Product Context: Dockerized BorgBackup

## Why This Project Exists

### The Problem
Server administrators need reliable, secure, and cost-effective backup solutions. Traditional backup approaches face several challenges:

1. **Infrastructure Complexity**: Setting up backup storage requires dedicated infrastructure (NAS, external drives, off-site storage)
2. **Security Concerns**: Backups need encryption at rest and in transit
3. **Consistency Issues**: Running backup tools directly on hosts can cause dependency conflicts
4. **Cloud Storage Cost**: Enterprise backup solutions can be expensive

### The Solution
This project combines three powerful technologies:
- **BorgBackup**: Deduplicating, compressing, encrypting backup tool
- **AWS S3**: Cheap, durable cloud storage ($0.023/GB/month for standard)
- **Docker**: Isolated, reproducible environment

By mounting S3 as a FUSE filesystem via s3fs, BorgBackup can use S3 directly as its repository storage, treating it like a local filesystem.

## How It Should Work

### User Workflow - Multi-Backend Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Host Server                                │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              Docker Container                              │ │
│  │                                                            │ │
│  │  /mnt/target ◄──── Host filesystem (read-only)            │ │
│  │                                                            │ │
│  │  /mnt/backup ◄──── Storage Backend (selectable):          │ │
│  │       │             • S3 bucket (via s3fs)                │ │
│  │       │             • USB device (UUID auto-detected)      │ │
│  │       │             • Local/NAS path (bind mount)          │ │
│  │       │                                                    │ │
│  │       └── /borgbackup ◄── Borg repository                 │ │
│  │                                                            │ │
│  │  BorgBackup reads from /mnt/target                        │ │
│  │  BorgBackup writes to /mnt/backup/borgbackup              │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
    ┌─────────┐         ┌─────────┐         ┌─────────┐
    │  AWS S3 │         │   USB   │         │ Local/  │
    │ (cloud) │         │  Drive  │         │   NAS   │
    └─────────┘         └─────────┘         └─────────┘
```

### Usage Modes

#### 1. Interactive Mode
For manual operations, exploration, and troubleshooting:
```bash
sudo docker compose run --rm borgbackup bash
```

#### 2. Automated Backup Mode
For scheduled/cron backups:
```bash
./run-backup.sh
# or directly:
sudo docker compose run --rm borgbackup /usr/sbin/backup.sh
```

#### 3. Direct Command Mode
For specific Borg operations:
```bash
sudo docker compose run --rm borgbackup borg list
sudo docker compose run --rm borgbackup borg info ::archive-name
```

## User Experience Goals

### For First-Time Setup
1. Clone repository
2. Copy `.env.example` to `.env`
3. Configure AWS credentials and Borg passphrase
4. Build image with `docker compose build`
5. Initialize repository with `borg init --encryption=repokey`
6. Ready to backup

### For Daily Operations
- **One command backup**: `./run-backup.sh`
- **Clear logging**: Know what's happening at INFO level
- **Detailed debugging**: Switch to DEBUG for troubleshooting
- **Automatic pruning**: Retention policy applied after each backup

### For Restoration
- Enter interactive mode
- Use standard Borg commands to extract files
- Full access to all archives in S3

## Target Use Cases

### 1. Single Server Backup
- Small VPS or dedicated server
- Full system backup to S3
- Daily automated backups via cron

### 2. Mailcow Server Backup
- Automatic detection of Mailcow installation
- Uses Mailcow's native backup script
- Integrates with full system backup

### 3. Multi-Server Environment
- Deploy same container on multiple servers
- Each server gets its own S3 bucket
- Centralized backup management via S3

## What Makes This Different

| Feature | This Project | Traditional Backup |
|---------|--------------|-------------------|
| Storage | S3 (pay-per-use) | NAS/SAN (upfront cost) |
| Encryption | Borg encryption | Often optional |
| Deduplication | Built-in | Varies |
| Dependencies | Docker only | Multiple packages |
| Portability | Any Docker host | OS-specific |
| Off-site | Built-in (S3) | Requires setup |
