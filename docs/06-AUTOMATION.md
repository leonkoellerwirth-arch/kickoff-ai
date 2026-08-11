# Automation Layer — Overview and Operating Guide

> [Deutsch](de/06-AUTOMATISIERUNG.md)

This document describes the 14 scripts in `automation/bin/`
and the associated launchd background jobs. Every automation addresses a problem
documented in the inventory. Problems without inventory evidence were not automated.

All commands are shell-first, macOS-only, bash 3.2-compatible, use
`scripts/lib.sh` (logging, dry-run, confirmation) and verify their prerequisites
before starting.

**Sources:** INVENTORY.md §0–§15, docs/02-GAP-ANALYSIS.md A.1–A.17, B.1–B.10.

---

## Overview Table

| Command | Problem (inventory reference) | Default frequency | Destructive? |
|---|---|---|---|
| `dev-up / dev-down / dev-ps` | 16 containers always on, 5× MySQL (§5, A.13) | manual / daily (down-idle) | no (down stops only) |
| `mac-clean` | 96 % SSD full, 43 GB free (§0, A.14) | weekly (report) | yes — only with `--apply` |
| `mac-update` | 6+ tools updated manually one by one (§2-§7) | weekly (dry-run) | yes — updates |
| `mac-snapshot` | setup repo is outdated from day one | manual | no (local/ gitignored) |
| `repo-sweep` | 58 repos without lifecycle management (§13, B.10) | manual / weekly | no |
| `secret-sweep` | gitleaks without hook, .env in plaintext (A.7, B.1) | weekly | no (install-hooks: writes hooks) |
| `db-backup` | DB volumes without dump routine (§5) | daily | no (writes new files only) |
| `ollama-sync` | Ollama installed 3×, 4 models (§6, A.12) | manual / --sync | yes — only with `--sync` |
| `env-run` | .env plaintext, no secret backend (§9, B.1) | manual | migrate: writes .template |
| `up2date` | version drift between registry and upstream | weekly (launchd) | no |
| `sunset` | tool status transitions in the registry | manual | no |
| `migration-diff` | old-to-new comparison after machine migration | manual | no |

---

## 1. Container Lifecycle: `dev-up` / `dev-down` / `dev-ps`

### Problem

16 Docker containers run permanently, including 5 MySQL instances for different
projects (INVENTORY §5). Pattern: Docker Compose stacks were started and never
stopped. Several GB of RAM permanently occupied, ports blocked.

### What the Commands Do

**`dev-up [<project>]`**: Finds `docker-compose.yml`/`compose.yaml` in `~/dev/<project>`
and starts the stack. Without argument: lists all available stacks.

**`dev-down [<project>] [--all] [--idle 4h]`**: Stops one or all stacks.
`--idle 4h` stops containers with ~0 % CPU that have been running for ≥4 hours.

**`dev-ps [<filter>]`**: Compact table of all containers with uptime, CPU, memory.

### Usage

```bash
dev-up                     # List available stacks
dev-up my-project          # Start ~/dev/my-project/docker-compose.yml
dev-down my-project        # Stop this stack
dev-down --all             # Stop all stacks
dev-down --idle 4h --dry-run  # Show idle containers
dev-ps                     # All running containers
dev-ps mysql               # Filtered by "mysql"
```

### Schedule (launchd)

`dev.kickoff.dev-down-idle`: daily 02:30 — stops containers with ~0 % CPU after ≥4 h.

### What It Deliberately Does NOT Do

Volumes are never deleted. `dev-down` only stops containers, not `docker compose down -v`.
Volumes persist until an explicit `docker volume rm` is run.

### Effort / Risk

Risk: minimal (stops containers, no data deletion). Effort: 0 — immediately usable.

---

## 2. Storage Hygiene: `mac-clean`

### Problem

43 GB of 926 GB free — 96 % occupied (INVENTORY §0, gap analysis A.14). Docker images,
Xcode DerivedData, Homebrew caches, conda-base packages fill the SSD permanently.

### What the Command Does

Cleans in fixed order, reporting size before/after:
Docker (system prune, volumes only with confirmation), Xcode DerivedData + iOS DeviceSupport +
Simulator runtimes, Homebrew cleanup, npm/pnpm/bun/uv caches, conda clean,
orphaned `node_modules` listed (never deleted), Trash.

**Default is dry-run** — not a single byte is deleted without `--apply`.

### Usage

```bash
mac-clean                        # Dry-run: shows savings potential
mac-clean --apply                # Actually clean
mac-clean --only docker          # Docker only (dry-run)
mac-clean --apply --only brew    # Homebrew only, for real
```

### Schedule (launchd)

`dev.kickoff.mac-clean`: weekly Saturday 10:00 — dry-run report, no deletion.

### What It Deliberately Does NOT Do

- Volumes are only deleted with explicit confirmation (`confirm()`).
- `node_modules` are only listed, never deleted.
- conda environments are not deleted (caches only).

### Effort / Risk

Risk without `--apply`: zero. With `--apply`: Docker volumes may contain data
(hence confirmation). Recommendation: run `--dry-run` first, then selectively
`--apply --only <group>`.

---

## 3. System Updates: `mac-update`

### Problem

Brew (~275 formulae), 11 global npm packages, 4 AI CLIs, 4 Ollama models, VS Code
extensions are all updated manually one by one (INVENTORY §2-§7). No unified
workflow, no log.

### What the Command Does

Updates in fixed order: brew, npm global, pnpm/bun self-update, uv,
Claude Code, Codex CLI, Gemini CLI, Ollama + models, VS Code extensions, App Store (mas),
Xcode CLT. Writes log to `../local/updates/<date>.md`.

### Usage

```bash
mac-update                        # Update all groups
mac-update --dry-run              # Only check what is outdated
mac-update --only brew            # Homebrew only
mac-update --skip mas --skip vscode
```

Groups: `brew npm pnpm bun uv claude codex gemini ollama vscode mas xcode`

### Schedule (launchd)

`dev.kickoff.mac-update`: weekly Sunday 09:00 — dry-run (check only, no install).

### What It Deliberately Does NOT Do

The launchd job never installs automatically — dry-run only. Actual updates remain
deliberately manual (`mac-update` without flags, outside launchd).

### Effort / Risk

Risk: updates can contain breaking changes — that is why launchd runs dry-run only.

---

## 4. Repo Snapshot: `mac-snapshot`

### Problem

A setup repo is outdated from the day it is created. New tools are installed locally,
extensions added, but never checked in. No overview of the drift between actual state
(machine) and target state (repo).

### What the Command Does

Dumps the current state (`brew bundle dump`, `npm ls -g`, `code --list-extensions`,
Ollama models, version numbers) into `../local/snapshot/` and diffs against the
checked-in target state (`Brewfile`, `config/vscode-extensions.txt`,
`automation/manifests/ollama-models.txt`).

With `--write`: writes proposals as `../local/snapshot/proposal-*.diff`.

### Usage

```bash
mac-snapshot                  # Show diff
mac-snapshot --write          # Also save diffs as files
```

### What It Deliberately Does NOT Do

Repo files are **never overwritten automatically**. Proposals only exist in
`local/` (gitignored). The developer consciously decides what enters the repo.

### Effort / Risk

No risk — read-only. `local/` is gitignored.

---

## 5. Repo Overview: `repo-sweep`

### Problem

58 repos under `~/dev/` without lifecycle management (INVENTORY §13, gap analysis B.10).
No quick overview of drift, stale branches, missing standard files.

### What the Command Does

Checks per repo — supplementing `base status` (gate/CI/BIBLE/agent status) — :
branch ≠ main/master, branches without remote tracking, last commit >N days,
missing standard files (README/CHANGELOG/HANDOFF), .env files in the directory,
repo size. Sortable, Markdown output to `../local/repo-sweep.md`.

### Usage

```bash
base status               # Run this first: gate/CI/BIBLE/agent
repo-sweep                # Supplementary check
repo-sweep --sort age     # Oldest repos first
repo-sweep --sort size --markdown  # Largest repos + write report
repo-sweep --age-days 60  # Set threshold to 60 days
```

### What It Deliberately Does NOT Do

Intentionally does not overlap with `base status`. No deletion, no archiving,
no branch deletion.

---

## 6. Secret Scanning: `secret-sweep`

### Problem

`gitleaks` is installed but runs without a hook (gap analysis A.7). `.pre-commit-config.yaml`
exists in `base` but `pre-commit` is not installed (gap analysis A.7).
`.env` files exist in plaintext, at least one outside a repo (gap analysis B.1).

### What the Command Does

Runs `gitleaks detect` across all repos under `~/dev/` (with timeout, progress).
Finds all `.env*` files (including outside repos), checks if gitignored, checks
if `.env` appears in git history (most critical case). Report to `../local/secret-sweep.md`.

Subcommand `secret-sweep install-hooks`: installs `pre-commit` (via uv/pipx/brew)
and runs `pre-commit install --install-hooks` in all repos with `.pre-commit-config.yaml`.

### Usage

```bash
secret-sweep               # Full scan
secret-sweep --dry-run     # Show what would be checked
secret-sweep install-hooks # Set up pre-commit in all matching repos
```

### Schedule (launchd)

`dev.kickoff.secret-sweep`: weekly Wednesday 04:00 — read-only scan, writes report.

### What It Deliberately Does NOT Do

Deletes no files. Writes nothing to Vaultwarden. Does not clean git history
(use `git-filter-repo` or BFG for that — deliberately manual, as it is destructive
and repo-specific).

---

## 7. Database Backup: `db-backup`

### Problem

5 MySQL containers + Postgres + Qdrant + Valkey run with volumes, without any visible
dump routine (INVENTORY §5). Data loss from `docker system prune` would be permanent.

### What the Command Does

Automatically detects running MySQL/MariaDB/PostgreSQL containers, runs `mysqldump`
or `pg_dump` from inside, compresses to `~/backups/db/<container>/<date>.sql.gz`,
rotates (keeps N days), validates plausibility (size > 0, end marker).

Credentials are NOT stored in the script — read from container env variables
(`MYSQL_ROOT_PASSWORD`, `POSTGRES_PASSWORD`), then Bitwarden CLI (bw), then interactive prompt.

### Usage

```bash
db-backup                         # Back up all running DB containers
db-backup --dry-run               # Show what would be backed up
db-backup --container my-mysql    # This container only
db-backup --keep-days 30          # 30-day rotation
```

### Schedule (launchd)

`dev.kickoff.db-backup`: daily 03:00 — writes dumps, deletes old ones (rotation).

### What It Deliberately Does NOT Do

No volume deletion. No backup of Qdrant/Valkey (no standard dump tool via
Docker exec — these require project-specific backup strategies).

---

## 8. Ollama Models: `ollama-sync`

### Problem

Ollama is installed three times: brew formula, brew cask, Docker container (INVENTORY §6,
gap analysis A.12). No declarative overview of which models are desired.
4 models (~18 GB). The Docker container has no Metal GPU access on macOS (CPU-only).

### What the Command Does

Compares installed models against `../automation/manifests/ollama-models.txt`.
Reports missing, surplus, and outdated models with storage usage.
Warns about multiple installations with a resolution guide.
With `--sync`: pulls missing models, updates existing ones.

### Usage

```bash
ollama-sync               # Check only (no pull)
ollama-sync --sync        # Pull missing models + update
ollama-sync --sync --dry-run
```

### Editing the Manifest

```bash
# Add a model:
echo "mistral:7b  # For code assistance" >> automation/manifests/ollama-models.txt
ollama-sync --sync

# Remove a model:
ollama rm llama3.2  # Manual (safety)
# Then remove from manifest
```

### What It Deliberately Does NOT Do

Does not delete models automatically (surplus models are reported, never deleted).
Does not resolve the multiple-installation situation automatically — that is a
one-time, manual step.

---

## 9. Vaultwarden Integration: `env-run`

### Problem

`.env` files exist as plaintext files on disk (INVENTORY §9, gap analysis B.1).
At least one `.env` found outside a repo. No secret backend in place.

### What the Command Does

**`env-run [--env-file .env.template] [--serve] [--dry-run] -- <command>`**: Resolves
`bw://` references via the Bitwarden CLI and starts the command with secrets
exclusively in the process environment — never as `ps`-visible arguments, never as a file.

**`env-run migrate <.env>`**: Rewrites an existing `.env` into a `.env.template`
with `bw://` reference suggestions — writes **nothing** to Vaultwarden (deliberately manual).

**`env-run check <.env.template>`**: Checks whether all references are resolvable,
without printing values.

### Usage

```bash
# Open the vault
export BW_SESSION=$(bw unlock --raw)

# 1. Migrate an existing .env:
env-run migrate .env
# → creates .env.template with bw:// suggestions
# → prints values to stderr for manual entry in Vaultwarden

# 2. Create items in Vaultwarden manually (web UI or bw create)
# 3. Verify references:
env-run check .env.template

# 4. Run command with resolved secrets:
env-run -- uvicorn app.main:app --port 8000
env-run --env-file config/.env.prod.template -- ./scripts/deploy.sh

# Faster with many secrets:
env-run --serve -- python scripts/seed.py

# What would be set? (without values)
env-run --dry-run -- env
```

### What It Deliberately Does NOT Do

Writes **nothing** to Vaultwarden — that remains deliberately manual. No automatic
secret rotation. Does not delete the original `.env` (kept as backup until manually
verified and deleted).

Full guide: [08-SECRETS.md](08-SECRETS.md)

---

## 10. Currency Check: `up2date`

### Problem

Installed tools drift against upstream — new versions appear, some become deprecated.
Without regular checks the registry quietly becomes stale.

### What the Command Does

Checks every `active`/`candidate` entry in `manifests/tools.yaml` against upstream
(brew, npm, GitHub API, mas, Ollama Registry). Reports four categories:
update available, sunset candidate, adoption candidate, review due.

Writes found version updates back to the registry with `--apply-versions`.
Checks with `--consistency` whether the registry and implementation lists (Brewfile etc.)
are consistent.

### Usage

```bash
up2date                          # Check all active/candidate entries
up2date --consistency --offline  # Consistency only, no network
up2date --apply-versions         # Write version updates to tools.yaml
up2date check --json --markdown  # Machine-readable output for CI
```

### Schedule (launchd)

`dev.kickoff.up2date`: weekly Monday 08:00 — via `up2date.yml` as a GitHub Action.
Opens a PR for version updates and an issue for sunset candidates.

### What It Deliberately Does NOT Do

Installs and uninstalls nothing. Changes no `status` value.
Full documentation: [07-CURRENCY.md](07-CURRENCY.md)

---

## 11. State Machine: `sunset`

### Problem

Without a formalized retirement process, outdated tools quietly remain in the registry
and in the implementation lists — installed invisibly, unmaintained.

### What the Command Does

Documents status transitions in `manifests/tools.yaml` and writes the decision
to `CHANGELOG.md`. Never automatic — every step is a human command.

### Usage

```bash
sunset propose <id> --reason "Why"  # deprecated, 90-day grace period
sunset confirm <id>                  # sunset (after grace period)
sunset revive <id> --reason "Why"   # reactivation
sunset adopt <id>                    # candidate → active
sunset list --due                    # show due sunsets
```

### What It Deliberately Does NOT Do

Uninstalls nothing. Does not remove any entry from the registry.
Full documentation: [07-CURRENCY.md](07-CURRENCY.md)

---

## 12. Migration Diff: `migration-diff`

### Problem

After a machine migration there is no systematic comparison: what was on the old
machine, what is still missing on the new one?

### What the Command Does

Compares `local/status-quo/<DATE>/profile.json` (export from the old machine) against
the current state of the new machine. For every open item it outputs the concrete
reinstall command. Exit code 1 when open items remain.

### Usage

```bash
migration-diff                   # Interactive comparison
migration-diff --markdown        # Write report to local/migration-diff.md
```

### What It Deliberately Does NOT Do

Installs nothing. Does not decide what should be carried over.
Full documentation: [09-MIGRATION.md](09-MIGRATION.md)

---

## Installation

### Step 1: Install Brewfile.automation

```bash
cd ~/dev/kickoff-ai
brew bundle --file=Brewfile.automation
```

### Step 2: Add automation/bin/ to PATH

```bash
# Add to ~/.zshrc (or via bootstrap.sh):
export PATH="$HOME/dev/kickoff-ai/automation/bin:$PATH"

# Activate immediately:
source ~/.zshrc
```

### Step 3: Install launchd jobs (optional)

```bash
cd ~/dev/kickoff-ai
bash automation/launchd/install-launchd.sh --dry-run  # Check first
bash automation/launchd/install-launchd.sh            # Then install

# Check status:
launchctl list | grep dev.kickoff
```

### Disable launchd jobs / shut down individual jobs

```bash
# Uninstall all:
bash automation/launchd/uninstall-launchd.sh

# Disable a single job:
launchctl bootout gui/$(id -u)/dev.kickoff.db-backup
# or:
launchctl unload ~/Library/LaunchAgents/dev.kickoff.db-backup.plist
```

### Where are the logs?

```bash
ls ~/Library/Logs/kickoff/

# Follow a single log:
tail -f ~/Library/Logs/kickoff/db-backup.log
```

---

## Log Overview

| Job | Log | Schedule |
|---|---|---|
| dev-down-idle | `~/Library/Logs/kickoff/dev-down-idle.log` | daily 02:30 |
| db-backup | `~/Library/Logs/kickoff/db-backup.log` | daily 03:00 |
| secret-sweep | `~/Library/Logs/kickoff/secret-sweep.log` | weekly Wed 04:00 |
| doctor | `~/Library/Logs/kickoff/doctor.log` | weekly Mon 08:00 |
| mac-update | `~/Library/Logs/kickoff/mac-update.log` | weekly Sun 09:00 |
| mac-clean | `~/Library/Logs/kickoff/mac-clean.log` | weekly Sat 10:00 |

---

## Deliberately NOT Automated

These actions were consciously excluded from automation:

| Action | Rationale |
|---|---|
| **Writing values to Vaultwarden** | Requires manual review; `env-run migrate` provides suggestions only |
| **Overwriting repo files** (mac-snapshot) | Drift may be intentional; manual review required |
| **Deleting Docker volumes** | Data loss risk; only with explicit confirmation |
| **Deleting node_modules** | Too many dependencies; `repo-sweep` lists only |
| **Cleaning git history** | Destructive and repo-specific; BFG/git-filter-repo manually |
| **Auth operations** (GitHub, `bw login`, `bw unlock`) | Requires interactive context |
| **macOS system updates** | `softwareupdate` requires restart; not unattended |
| **Deleting conda environments** | `notebooklm` env may be active; clean caches only |
| **Deleting Ollama models** | Download can take hours; report only in `ollama-sync` |
| **Status changes in the registry** | Every deprecated/sunset decision is a human judgment call |
