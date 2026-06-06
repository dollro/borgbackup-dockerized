# Getting Started

## Requirements

### General Requirements

- Docker and Docker Compose installed on your system
- Root/sudo access for mounting operations
- Basic understanding of [BorgBackup](https://www.borgbackup.org/)

### Backend-Specific Requirements

| Backend | Requirements |
|---------|-------------|
| S3 | AWS account with S3 access, IAM credentials |
| USB | USB storage device formatted with a supported filesystem |
| Local | A local directory or mounted network share |

## Quick Start

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd borgbackup
```

### Step 2: Configure Environment

```bash
cp .env.example .env
nano .env  # Edit with your configuration
```

### Step 3: Build the Docker Image

```bash
sudo docker compose build
```

### Step 4: Initialize Borg Repository

```bash
sudo docker compose run --rm borgbackup borg init --encryption=repokey
```

### Step 5: Run Your First Backup

```bash
./run-backup.sh
```

See [Configuration](configuration.md) and [Storage Backends](backends.md) to tailor the setup to your backend.
