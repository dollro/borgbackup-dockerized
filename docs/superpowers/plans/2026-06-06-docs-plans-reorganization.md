# Docs & Plans Reorganization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the 673-line monolithic `README.md` into a Material-themed MkDocs site under `docs/`, keep a slim GitHub-facing `README.md`, retire the Cline artifacts, and adopt the sidesupport `.gitignore`/plans conventions.

**Architecture:** Content is moved (not rewritten) from `README.md` into one focused page per topic under `docs/`. `mkdocs.yml` defines a Material theme + nav; `Taskfile.yml` provides `docs`/`docs-serve` tasks. `mkdocs build --strict` is the verification harness — it fails on broken internal links or pages missing from `nav`, which is exactly what catches migration mistakes. No application code or backup behavior changes.

**Tech Stack:** MkDocs, mkdocs-material, go-task (Taskfile), git.

**Spec:** `docs/superpowers/specs/2026-06-06-docs-plans-reorganization-design.md`

**Deviation from approved spec:** The spec listed 11 docs pages and said to fold mined Cline content into `reference.md`. This plan adds a 12th page, `docs/architecture.md`, because `memory-bank/systemPatterns.md` contains ~387 lines of architecture/design-pattern material that would overwhelm `reference.md`. Reviewer may drop Task 13 and fold the content into `reference.md` instead.

---

## File Structure

Created:
- `mkdocs.yml` — site config, Material theme, nav
- `requirements-docs.txt` — pins `mkdocs-material`
- `Taskfile.yml` — `docs` (build) and `docs-serve` tasks
- `docs/index.md` — overview / key features / architecture summary + links
- `docs/getting-started.md` — requirements + quick start
- `docs/configuration.md` — environment variables
- `docs/backends.md` — S3 / USB / Local setup
- `docs/usage.md` — running backups, interactive mode, common borg commands
- `docs/restore.md` — full restoring-from-backup guide
- `docs/features.md` — lock handling, progress, db dumps, retention
- `docs/scheduling.md` — cron, multiple backends
- `docs/troubleshooting.md` — debug, common issues
- `docs/security.md` — credentials, hardening, encryption
- `docs/reference.md` — versions, capabilities, mounts, filesystems, resources
- `docs/architecture.md` — design patterns, script chain, exit codes (mined from Cline)

Modified:
- `README.md` — slimmed to executive summary + doc links
- `.gitignore` — adopt sidesupport pattern

Removed:
- `memory-bank/` (6 files), `.clinerules/` (after mining)

Conventions for every page move:
- The README uses `##`/`###`/`####`. As a standalone page each becomes one level shallower: `## X` → `# X` (page H1), `### Y` → `## Y`, `#### Z` → `### Z`.
- Cross-page anchor links must be rewritten to `targetpage.md#anchor` (called out per task).

---

## Task 1: Scaffold MkDocs config and tooling

**Files:**
- Create: `requirements-docs.txt`
- Create: `mkdocs.yml`
- Create: `Taskfile.yml`
- Create: `docs/index.md` (temporary stub, replaced in Task 2)

- [ ] **Step 1: Create `requirements-docs.txt`**

```
mkdocs-material==9.5.49
```

- [ ] **Step 2: Create `mkdocs.yml`**

```yaml
site_name: Dockerized BorgBackup
site_description: Containerized BorgBackup with S3, USB, and local storage backends
docs_dir: docs
site_dir: docs-site
dev_addr: 127.0.0.1:8888

validation:
  links:
    absolute_links: relative_to_docs
    anchors: warn
    unrecognized_links: warn

theme:
  name: material
  features:
    - navigation.sections
    - navigation.expand
    - content.code.copy
  palette:
    scheme: default

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - Configuration:
    - Environment Variables: configuration.md
    - Storage Backends: backends.md
  - Usage:
    - Running Backups: usage.md
    - Restoring from Backup: restore.md
    - Scheduling: scheduling.md
  - Reference:
    - Features: features.md
    - Architecture: architecture.md
    - Troubleshooting: troubleshooting.md
    - Security: security.md
    - Technical Reference: reference.md

markdown_extensions:
  - toc:
      permalink: true
  - tables
  - attr_list
  - pymdownx.highlight
  - pymdownx.superfences
```

- [ ] **Step 3: Create `Taskfile.yml`**

```yaml
version: '3'

tasks:
  docs:
    desc: Build static docs site into docs-site/
    cmds:
      - mkdocs build

  docs-serve:
    desc: Serve docs locally at http://127.0.0.1:8888
    cmds:
      - mkdocs serve
```

- [ ] **Step 4: Create temporary `docs/index.md` stub**

```markdown
# Dockerized BorgBackup

Placeholder home page — replaced in Task 2.
```

- [ ] **Step 5: Install docs tooling**

Run: `pip install -r requirements-docs.txt`
Expected: mkdocs-material and mkdocs install successfully. (If `pip` is externally managed, use `pipx install mkdocs --include-deps` then `pipx inject mkdocs mkdocs-material`, or `uv tool install mkdocs --with mkdocs-material`.)

- [ ] **Step 6: Verify the skeleton builds**

Run: `mkdocs build --strict 2>&1 | head -40`
Expected: FAIL — strict mode reports the nav references pages that don't exist yet (`getting-started.md`, etc.). This confirms strict validation is active. Pages get created in Tasks 2–13.

- [ ] **Step 7: Commit**

```bash
git add mkdocs.yml requirements-docs.txt Taskfile.yml docs/index.md
git commit -m "docs: scaffold mkdocs site config and task runner"
```

---

## Task 2: Home page (`docs/index.md`)

**Source:** `README.md` lines 3 (intro paragraph) and 37–56 (Overview, Key Features, Architecture).

**Files:**
- Modify: `docs/index.md` (replace the Task 1 stub)

- [ ] **Step 1: Write `docs/index.md`**

Move the intro paragraph + Overview/Key Features/Architecture content. Top heading is the page title; `### Key Features` → `## Key Features`, `### Architecture` → `## Architecture`. Append a documentation index.

```markdown
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
- [Architecture](architecture.md) — internal design and script flow
- [Technical Reference](reference.md)
```

- [ ] **Step 2: Commit**

```bash
git add docs/index.md
git commit -m "docs: add home page"
```

---

## Task 3: Getting Started page (`docs/getting-started.md`)

**Source:** `README.md` lines 60–110 (Requirements + Quick Start).

**Files:**
- Create: `docs/getting-started.md`

- [ ] **Step 1: Write `docs/getting-started.md`**

Combine the Requirements and Quick Start sections into one page. `## Requirements` → `# Getting Started` is wrong — keep both as `##` under a new H1. Specifically: page H1 = `# Getting Started`, then `## Requirements` (was `## Requirements`), `### General Requirements`/`### Backend-Specific Requirements` stay `###`, then `## Quick Start`, with the five `### Step N` headings preserved.

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add docs/getting-started.md
git commit -m "docs: add getting-started page"
```

---

## Task 4: Configuration page (`docs/configuration.md`)

**Source:** `README.md` lines 116–136 (Environment Variables table).

**Files:**
- Create: `docs/configuration.md`

- [ ] **Step 1: Write `docs/configuration.md`**

Page H1 = `# Configuration`, then the env-var table verbatim. Add a pointer to backends.

```markdown
# Configuration

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| **Common** |
| `BACKUP_STORAGE_TYPE` | Storage backend: `s3`, `usb`, or `local` | `s3` | No |
| `BORG_REPO_PATH` | Repository path relative to storage mount (supports subdirs like `server1/backups`) | `borgbackup` | No |
| `BORG_PASSPHRASE` | Encryption passphrase | - | Yes |
| `LOGGING` | Logging verbosity: `INFO` or `DEBUG` | `INFO` | No |
| `SHOW_PROGRESS` | Show real-time progress during backup: `true` or `false` | `false` | No |
| `BORG_AUTO_BREAK_LOCK` | Handle stale locks: `false`, `manual`, or `auto` | `false` | No |
| `BORG_TIMEOUT` | Timeout in seconds for borg create/prune operations | `14400` (4h) | No |
| **S3 Backend** |
| `S3_BUCKET_NAME` | Name of S3 bucket | - | Yes (S3) |
| `AWS_ACCESS_KEY_ID` | AWS access key | - | Yes (S3) |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | - | Yes (S3) |
| `AWS_DEFAULT_REGION` | AWS region | - | Yes (S3) |
| **USB Backend** |
| `USB_DEVICE_UUID` | UUID of USB device | - | Yes (USB) |
| **Local Backend** |
| `LOCAL_BACKUP_PATH` | Path on host to use | - | Yes (Local) |

For backend-specific setup (IAM policy, UUID detection, NAS mounts), see [Storage Backends](backends.md).
```

- [ ] **Step 2: Commit**

```bash
git add docs/configuration.md
git commit -m "docs: add configuration page"
```

---

## Task 5: Backends page (`docs/backends.md`)

**Source:** `README.md` lines 138–250 (Storage Backends: S3, USB, Local).

**Files:**
- Create: `docs/backends.md`

- [ ] **Step 1: Write `docs/backends.md`**

Move the whole Storage Backends section verbatim, promoting headings one level: `### Storage Backends` → `# Storage Backends`, the three `#### S3/USB/Local Backend` → `## S3 Backend` / `## USB Backend` / `## Local Backend`. Keep the IAM JSON policy, blkid example, supported-filesystem list, and all `.env` snippets exactly as in `README.md` lines 140–250.

- [ ] **Step 2: Verify nothing was dropped**

Run: `grep -c '## ' docs/backends.md`
Expected: at least 3 (S3 Backend, USB Backend, Local Backend).

- [ ] **Step 3: Commit**

```bash
git add docs/backends.md
git commit -m "docs: add storage backends page"
```

---

## Task 6: Usage page (`docs/usage.md`)

**Source:** `README.md` lines 256–312 (Running Backups, Interactive Mode, Common Borg Commands).

**Files:**
- Create: `docs/usage.md`

- [ ] **Step 1: Write `docs/usage.md`**

Page H1 = `# Usage`. `### Running Backups`/`### Interactive Mode`/`### Common Borg Commands` → `##`. Keep all command blocks verbatim from lines 258–312. In the "Common Borg Commands" block, the inline comment `# Extract/restore files (see "Restoring from Backup" below for full guide)` (line 302) must change "below" to a link: `# Extract/restore files (see the Restoring from Backup guide: restore.md)`.

- [ ] **Step 2: Commit**

```bash
git add docs/usage.md
git commit -m "docs: add usage page"
```

---

## Task 7: Restore page (`docs/restore.md`)

**Source:** `README.md` lines 316–451 (Restoring from Backup, all six subsections).

**Files:**
- Create: `docs/restore.md`

- [ ] **Step 1: Write `docs/restore.md`**

Move the entire Restoring from Backup section. `## Restoring from Backup` → `# Restoring from Backup`; the six `### ` subsections (Finding the Archive, Restore a Single File or Directory, Restore a File to stdout, Full Archive Restore, Browse the Archive with FUSE, Disaster Recovery (Bare-Metal Restore)) stay `###`? No — promote to `##` so they appear in the page toc. Keep the intro paragraph (lines 318–323), all command blocks, the flag tables, and both `> Tip`/`> Test your restore` callouts verbatim.

- [ ] **Step 2: Verify the six subsections survived**

Run: `grep -c '^## ' docs/restore.md`
Expected: 6.

- [ ] **Step 3: Commit**

```bash
git add docs/restore.md
git commit -m "docs: add restore guide page"
```

---

## Task 8: Features page (`docs/features.md`)

**Source:** `README.md` lines 455–508 (Automatic Lock Handling, Real-time Progress Display, Pre-backup Database Dumps, Retention Policy).

**Files:**
- Create: `docs/features.md`

- [ ] **Step 1: Write `docs/features.md`**

Page H1 = `# Features`. The four `### ` subsections → `##`. Keep the lock-behavior table, the progress list, the dump description, and the retention table verbatim from lines 457–508.

Note: the heading `## Automatic Lock Handling` provides the anchor `#automatic-lock-handling`, which `troubleshooting.md` and `scheduling.md` link to.

- [ ] **Step 2: Commit**

```bash
git add docs/features.md
git commit -m "docs: add features page"
```

---

## Task 9: Scheduling page (`docs/scheduling.md`)

**Source:** `README.md` lines 512–544 (Automated Backups with Cron, Multiple Storage Backends).

**Files:**
- Create: `docs/scheduling.md`

- [ ] **Step 1: Write `docs/scheduling.md`**

Page H1 = `# Scheduling Backups`. `### Automated Backups with Cron`/`### Multiple Storage Backends` → `##`. Keep the crontab examples, the `flock` callout, the `NO_COLOR` example, and the multi-env-file commands verbatim from lines 514–544. The sentence at line 524 referencing `BORG_AUTO_BREAK_LOCK=auto` stays as plain text (no anchor change needed).

- [ ] **Step 2: Commit**

```bash
git add docs/scheduling.md
git commit -m "docs: add scheduling page"
```

---

## Task 10: Troubleshooting page (`docs/troubleshooting.md`)

**Source:** `README.md` lines 548–605 (Enable Debug Mode, Common Issues).

**Files:**
- Create: `docs/troubleshooting.md`

- [ ] **Step 1: Write `docs/troubleshooting.md`**

Page H1 = `# Troubleshooting`. `### Enable Debug Mode`/`### Common Issues` → `##`. Keep all the bolded issue subheadings and command blocks verbatim from lines 550–605.

**Link fix:** line 594 contains `See [Automatic Lock Handling](#automatic-lock-handling) or manually break the lock:`. The target now lives on the features page — rewrite to `See [Automatic Lock Handling](features.md#automatic-lock-handling) or manually break the lock:`.

- [ ] **Step 2: Verify the cross-page link was fixed**

Run: `grep -n 'features.md#automatic-lock-handling' docs/troubleshooting.md`
Expected: one match. (And `grep '(#automatic-lock-handling)' docs/troubleshooting.md` should return nothing.)

- [ ] **Step 3: Commit**

```bash
git add docs/troubleshooting.md
git commit -m "docs: add troubleshooting page"
```

---

## Task 11: Security page (`docs/security.md`)

**Source:** `README.md` lines 609–629 (Credential Management, Container Hardening, Borg Encryption).

**Files:**
- Create: `docs/security.md`

- [ ] **Step 1: Write `docs/security.md`**

Page H1 = `# Security Considerations`. The three `### ` subsections → `##`. Keep all bullet lists verbatim from lines 611–629.

- [ ] **Step 2: Commit**

```bash
git add docs/security.md
git commit -m "docs: add security page"
```

---

## Task 12: Reference page (`docs/reference.md`)

**Source:** `README.md` lines 633–665 (Technical Reference) and 668–673 (Resources).

**Files:**
- Create: `docs/reference.md`

- [ ] **Step 1: Write `docs/reference.md`**

Page H1 = `# Technical Reference`. `### Software Versions`/`### Container Capabilities`/`### Volume Mounts`/`### Supported USB Filesystems` → `##`. Append the Resources list (lines 668–673) under a final `## Resources` heading. Keep all four reference tables verbatim.

```markdown
# Technical Reference

## Software Versions

| Component | Version |
|-----------|---------|
| Base Image | python:3.13.7-slim-trixie |
| BorgBackup | 1.4.1 |
| s3fs | 1.95-1 |

## Container Capabilities

The container requires the following capabilities for proper operation:

- `privileged`: Required for FUSE mounts (S3), block device mounts (USB), and mounting over Docker bind mounts
- `SYS_ADMIN`: Required for FUSE mounts (S3, USB)

## Volume Mounts

| Container Path | Purpose |
|---------------|---------|
| `/mnt/backup` | Backup storage mount point |
| `/mnt/target` | Host filesystem |
| `/dev` | Device access for FUSE (S3) and block devices (USB) |

## Supported USB Filesystems

| Filesystem | Mount Options |
|------------|---------------|
| ext4, ext3, ext2 | `rw` |
| xfs, btrfs | `rw` |
| ntfs | `rw,uid=0,gid=0` |
| vfat | `rw,uid=0,gid=0,umask=002` |

## Resources

- [BorgBackup Documentation](https://borgbackup.readthedocs.io/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Docker Documentation](https://docs.docker.com/)
- [s3fs-fuse Project](https://github.com/s3fs-fuse/s3fs-fuse)
```

- [ ] **Step 2: Commit**

```bash
git add docs/reference.md
git commit -m "docs: add technical reference page"
```

---

## Task 13: Architecture page (`docs/architecture.md`) — mined from Cline

**Source:** `memory-bank/systemPatterns.md` (design patterns, script dependency chain, exit-code meanings, container filesystem layout) and the backend technical details / default exclusions from `memory-bank/techContext.md` not already covered by `backends.md` or `reference.md`.

> Reviewer: if you rejected the architecture-page deviation, skip this task and instead append the same mined content as `## Architecture` sections inside `reference.md` (Task 12), and remove the `architecture.md` line from `mkdocs.yml` nav in Task 1.

**Files:**
- Create: `docs/architecture.md`
- Read: `memory-bank/systemPatterns.md`, `memory-bank/techContext.md`

- [ ] **Step 1: Read both source files**

Run: `sed -n '120,360p' memory-bank/systemPatterns.md` and `sed -n '246,275p' memory-bank/techContext.md`
Purpose: identify the Design Patterns, Script Dependency Chain, Exit Code Meanings, Container Filesystem Layout, and Default Exclusions content to carry over.

- [ ] **Step 2: Write `docs/architecture.md`**

Compose a page with H1 `# Architecture` and these `##` sections, transcribing the corresponding content from the Cline files (drop any content already duplicated verbatim in `backends.md`/`reference.md`):

- `## Design Patterns` — the seven patterns (Storage Backend, Entrypoint, Environment-Based Configuration, Interactive vs Non-Interactive Detection, Modular Dump System, Graceful Cleanup, Debug/Production Logging) from `systemPatterns.md` lines 120–224.
- `## Script Dependency Chain` — from `systemPatterns.md` lines 93–119.
- `## Container Filesystem Layout` — from `systemPatterns.md` lines 296–322.
- `## Exit Codes` — the exit-code meanings table/list from `systemPatterns.md` lines 334–349.
- `## Default Backup Exclusions` — from `techContext.md` lines 248–264.

Preserve fenced code blocks and tables exactly; only adjust heading levels to fit under the page H1.

- [ ] **Step 3: Verify the page is non-trivial and well-formed**

Run: `grep -c '^## ' docs/architecture.md`
Expected: 5.

- [ ] **Step 4: Commit**

```bash
git add docs/architecture.md
git commit -m "docs: add architecture page (mined from memory-bank)"
```

---

## Task 14: Strict build — verify the whole site

**Files:** none (verification only)

- [ ] **Step 1: Build with strict validation**

Run: `mkdocs build --strict 2>&1 | tail -30`
Expected: PASS — `INFO - Documentation built in ...`, with no `WARNING`/`ERROR` lines about missing nav pages, broken links, or unrecognized anchors. Strict mode turns those warnings into a non-zero exit.

- [ ] **Step 2: If any warning appears, fix and rebuild**

Common causes and fixes:
- "A reference to 'X.md' is included in the 'nav' ... but not found" → the page wasn't created; revisit its task.
- "contains a link 'X.md#anchor' ... but ... not found" → a cross-page anchor is wrong; correct the link target.
Re-run Step 1 until it passes.

- [ ] **Step 3: Confirm exit code is clean**

Run: `mkdocs build --strict >/dev/null 2>&1 && echo OK || echo FAIL`
Expected: `OK`

---

## Task 15: Slim the README

**Files:**
- Modify: `README.md` (full replacement)

- [ ] **Step 1: Replace `README.md` with the executive summary**

```markdown
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
| Internal design | [Architecture](docs/architecture.md) |
| Versions, capabilities, mounts | [Technical Reference](docs/reference.md) |

## License

See repository for license details.
```

- [ ] **Step 2: Verify the README shrank substantially**

Run: `wc -l README.md`
Expected: well under 100 lines (was 673).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: slim README to executive summary linking docs site"
```

---

## Task 16: Retire Cline artifacts

**Files:**
- Remove: `memory-bank/` (6 files), `.clinerules/`

- [ ] **Step 1: Confirm nothing un-mined remains**

Run: `ls memory-bank/ .clinerules/`
Sanity check that the only files are the six `memory-bank/*.md` and `.clinerules/default-rules.md`. Architecture-relevant content was carried into `docs/architecture.md` in Task 13; `.clinerules/default-rules.md` is Cline tool config with no docs value.

- [ ] **Step 2: Remove the directories**

```bash
git rm -r memory-bank .clinerules
```

(If they are untracked rather than tracked, use `rm -r memory-bank .clinerules` instead — check with `git status` first.)

- [ ] **Step 3: Verify removal**

Run: `ls memory-bank .clinerules 2>&1`
Expected: "No such file or directory" for both.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: retire Cline memory-bank and clinerules (content moved to docs)"
```

---

## Task 17: Update `.gitignore` and track plans

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Replace `.gitignore`**

```
# Secrets
.env

# Claude Code — track shared settings, ignore local overrides
.claude/*
!.claude/settings.json

# MkDocs build output
docs-site/

# Vim swap files
[._]*.sw[a-p]
```

- [ ] **Step 2: Remove the stray vim swap file**

Run: `rm -f .backup.sh.swp`
Expected: silently removed; `git status` no longer lists it.

- [ ] **Step 3: Stage plans and verify ignore rules**

```bash
git add .gitignore plans/
git status
```
Expected: `.gitignore`, `plans/fix-security-and-robustness/plan.md`, and the `docs/superpowers/` spec+plan are staged/tracked. `.backup.sh.swp` is gone. If `.claude/settings.json` exists, it is trackable; other `.claude/` contents are ignored. `docs-site/` is ignored.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: adopt sidesupport .gitignore pattern and track plans"
```

---

## Task 18: Final verification

**Files:** none

- [ ] **Step 1: Strict build still passes after README/Cline/gitignore changes**

Run: `mkdocs build --strict >/dev/null 2>&1 && echo OK || echo FAIL`
Expected: `OK`

- [ ] **Step 2: No broken intra-doc links from README**

Run: `grep -oE 'docs/[a-z-]+\.md' README.md | sort -u | while read p; do test -f "$p" && echo "ok $p" || echo "MISSING $p"; done`
Expected: every line starts with `ok` — no `MISSING`.

- [ ] **Step 3: Working tree is clean**

Run: `git status`
Expected: "nothing to commit, working tree clean" (only ignored files like `docs-site/` or `.claude/` local overrides remain untracked/ignored).

- [ ] **Step 4: Review the commit sequence**

Run: `git log --oneline -18`
Expected: the scaffold → per-page → strict-build → README → Cline → gitignore commits in order.

---

## Self-Review

**Spec coverage:**
- Full MkDocs Material site → Task 1 (`mkdocs.yml`), Tasks 2–13 (pages). ✓
- README split, slim executive README → Tasks 2–12 (split), Task 15 (slim). ✓
- Retire `memory-bank/` + `.clinerules/`, fold useful content into docs → Task 13 (mine), Task 16 (remove). ✓
- Taskfile (go-task), config-only, no CI → Task 1 (`Taskfile.yml`, `requirements-docs.txt`). ✓
- `.gitignore` sidesupport pattern + track `plans/` → Task 17. ✓
- Keep existing `plans/` convention → untouched; tracked in Task 17. ✓
- Commit sequence (scaffold → README split → retire Cline → gitignore) → matches Tasks 1–17. ✓

**Deviation flagged:** `docs/architecture.md` (Task 13) is beyond the spec's 11 pages; reviewer opt-out documented in Task 13 and Task 1 nav.

**Placeholder scan:** Content moves use exact `README.md` line ranges with explicit heading-promotion and link-rewrite instructions; config files and the home/getting-started/configuration/reference/README pages are shown in full. The two pages transcribed from large sources (`backends.md`, `architecture.md`) reference exact source line ranges plus verification greps rather than reproducing hundreds of duplicated lines — concrete, not vague.

**Consistency check:** Anchor `#automatic-lock-handling` is produced by `## Automatic Lock Handling` in `features.md` (Task 8) and consumed as `features.md#automatic-lock-handling` in `troubleshooting.md` (Task 10). Page filenames match `mkdocs.yml` nav (Task 1) one-to-one. `task docs-serve`/`task docs` names match the README instructions (Task 15).
```
