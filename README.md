# Dockerized BorgBackup with Multiple Storage Backends

A containerized solution for running [BorgBackup](https://www.borgbackup.org/) with support for multiple storage backends: AWS S3, USB devices, and local/NAS storage. The container provides a secure, isolated environment that reads from the host filesystem and writes encrypted, deduplicated backups to your chosen backend.

## Features

- **Containerized BorgBackup** in an isolated Docker environment
- **Multiple storage backends**: S3, USB (auto-detected by UUID), and local/NAS
- **Full host filesystem access** for backing up any directory
- **Environment-based configuration** for easy deployment
- **Automatic stale-lock handling** and optional real-time progress
- **Interactive & non-interactive modes**

## Quick Start

```bash
cp .env.example .env                                                  # configure
sudo docker compose build                                             # build image
sudo docker compose run --rm borgbackup borg init --encryption=repokey  # init repo
./run-backup.sh                                                       # first backup
```

See [Getting Started](docs/getting-started.md) for prerequisites and a step-by-step walkthrough.

## Documentation

Full documentation lives in [`docs/`](docs/index.md) and is browsable as a site via MkDocs:

```bash
pip install -r requirements-docs.txt
task docs-serve   # http://127.0.0.1:8888   (or: mkdocs serve)
```

| Topic | Page |
|-|-|
| Requirements & first backup | [Getting Started](docs/getting-started.md) |
| Environment variables | [Configuration](docs/configuration.md) |
| S3 / USB / Local setup | [Storage Backends](docs/backends.md) |
| Running backups & borg commands | [Usage](docs/usage.md) |
| Restoring (file, full, FUSE, bare-metal) | [Restore](docs/restore.md) |
| Lock handling, progress, dumps, retention | [Features](docs/features.md) |
| Cron & multiple backends | [Scheduling](docs/scheduling.md) |
| Common issues | [Troubleshooting](docs/troubleshooting.md) |
| Credentials & hardening | [Security](docs/security.md) |
| Versions, capabilities, mounts | [Technical Reference](docs/reference.md) |

## License

See repository for license details.
