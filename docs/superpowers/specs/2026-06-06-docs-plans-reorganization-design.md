# Docs & Plans Reorganization — Design

**Date:** 2026-06-06
**Status:** Approved (pending implementation plan)

## Goal

Reorganize this project's documentation and planning structure to mirror the
conventions used in the `sidesupport` project: a Material-themed MkDocs site
under `docs/`, a slim GitHub-facing `README.md`, a `plans/` convention for
implementation plans, and a `.gitignore` that tracks `.claude/settings.json`
while ignoring local overrides.

## Scope decisions (from brainstorming)

- **Docs depth:** Full MkDocs site (Material theme), config-only tooling plus a
  local task runner. No CI publishing.
- **README:** Split the 673-line monolith into per-topic docs pages; keep a slim
  executive-summary `README.md` for GitHub. Single source of truth, no
  duplication.
- **Cline artifacts:** Retire `memory-bank/` and `.clinerules/` after folding any
  still-useful content into `docs/`.
- **Task runner:** `Taskfile.yml` (go-task), matching sidesupport.

## Target structure

```
borgbackup/
├── README.md              # slim executive summary (GitHub landing)
├── mkdocs.yml             # Material theme
├── Taskfile.yml           # docs:serve / docs:build
├── requirements-docs.txt  # mkdocs-material + plugins
├── docs/
│   ├── index.md           # docs home / overview
│   ├── getting-started.md # requirements + quick start
│   ├── configuration.md   # environment variables
│   ├── backends.md        # S3 / USB / Local
│   ├── usage.md           # running backups, interactive, common commands
│   ├── restore.md         # full restoring-from-backup guide
│   ├── features.md        # lock handling, progress, db dumps, retention
│   ├── scheduling.md      # cron, multiple backends
│   ├── troubleshooting.md # debug, common issues
│   ├── security.md        # credentials, hardening, encryption
│   ├── reference.md       # versions, capabilities, mounts, filesystems
│   └── superpowers/
│       └── specs/         # brainstorming design docs land here
├── plans/                 # implementation plans (existing convention kept)
│   └── fix-security-and-robustness/plan.md
└── .gitignore             # updated
```

Removed after mining: `memory-bank/`, `.clinerules/`.

## README → docs page mapping

The current `README.md` sections map 1:1 onto docs pages:

| README section | Docs page |
|-|-|
| Overview, Key Features, Architecture | `index.md` |
| Requirements, Quick Start | `getting-started.md` |
| Configuration → Environment Variables | `configuration.md` |
| Configuration → Storage Backends (S3/USB/Local) | `backends.md` |
| Usage (running, interactive, common commands) | `usage.md` |
| Restoring from Backup (full guide) | `restore.md` |
| Features (locks, progress, db dumps, retention) | `features.md` |
| Scheduling Backups | `scheduling.md` |
| Troubleshooting | `troubleshooting.md` |
| Security Considerations | `security.md` |
| Technical Reference | `reference.md` |

The new `README.md` keeps: title, one-paragraph overview, key-features bullets,
a 4-command quick start, and links into the docs site.

## mkdocs.yml

- Material theme (mirror sidesupport's feature set: navigation sections, code
  copy, palette).
- `docs_dir: docs`, `site_dir: docs-site` (git-ignored).
- `nav:` mirroring the pages above.

## Taskfile.yml

Two tasks:
- `docs:serve` → `mkdocs serve`
- `docs:build` → `mkdocs build`

Introduces a go-task dependency (matching sidesupport). `requirements-docs.txt`
pins `mkdocs-material` and any plugins referenced by `mkdocs.yml`.

## Cline retirement

Scan `memory-bank/systemPatterns.md` and `memory-bank/techContext.md` for
content not already represented in the README; fold it into the relevant docs
page (likely `reference.md`). Then `git rm -r memory-bank/ .clinerules/`.

## .gitignore (adopt sidesupport pattern)

```
.env
.claude/*
!.claude/settings.json
docs-site/
# vim swap
[._]*.sw[a-p]
```

Also `git add plans/` so plans are tracked, like sidesupport.

## Commit sequence

1. Docs scaffold + `mkdocs.yml` + `Taskfile.yml` + `requirements-docs.txt`.
2. README split (move content into docs pages, slim the README).
3. Retire Cline artifacts (`memory-bank/`, `.clinerules/`).
4. `.gitignore` update + track `plans/`.

## Out of scope

- CI / GitHub Pages publishing.
- Any change to backup behavior, scripts, or container config.
- Restructuring `plans/` (the existing `fix-security-and-robustness/plan.md`
  already follows the convention).
```
