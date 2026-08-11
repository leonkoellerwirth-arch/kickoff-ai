# Zero to Hero — Complete Setup Guide

> Goal: You are standing in front of a freshly unboxed Mac and want to end up with exactly this working environment.
> Read this guide top to bottom. Each phase has a clear goal, an automated part (script), and a manual remainder (checklist).

**In a hurry?** Use [QUICKSTART.md](../QUICKSTART.md) instead — four cumulative levels, one page, no prose. Come back here when you need the background or troubleshooting.

For a complete checklist of manual steps: [01-MANUAL.md](01-MANUAL.md).
For the rationale behind tool decisions: [04-DECISIONS.md](04-DECISIONS.md).

---

## Phase 0 — Before the Mac Is On

**Goal:** Have all credentials and reference points ready so you do not spend hours searching in phases 1–11.

### What You Need to Have Ready

| What | Where | Blocks without? |
|---|---|---|
| Apple ID + password | Vaultwarden / Enpass | Yes — App Store, iCloud, Xcode |
| GitHub credentials (both accounts) | Vaultwarden | Yes — cloning repos |
| Anthropic API key | Vaultwarden | Yes — Claude Code |
| OpenAI API key | Vaultwarden | Yes — Codex CLI |
| Google AI (Gemini) API key | Vaultwarden | Yes — Gemini CLI |
| Apple Developer account | Vaultwarden | Only for iOS projects |
| SSH key backup or decision: generate new | — | Recommendation: generating new is safer |
| Licenses: Adobe CC, IBM SPSS, Topaz/Luminar/Nik, JetBrains | Vaultwarden / email | For app activation |
| `.env` files for running projects | Secure storage — **never** via AirDrop/plaintext | Yes for active projects |
| List of Docker volumes with real data | Note this now! | Risk of data loss |

### Backup the Old Machine

```bash
# Which Docker volumes have real data?
docker volume ls
docker volume inspect <name>

# Inventory .env files
find ~/dev -name ".env" -o -name "*.env" 2>/dev/null

# Own repo collection: which have no remote?
for d in ~/dev/*/; do
  git -C "$d" remote -v 2>/dev/null || echo "NO REMOTE: $d"
done

# Commit + push dev/base before the old Mac is retired
cd ~/dev/base && git status && git push
```

**Critical:** Secrets from running agent tools (Telegram bots, gateway credentials) must be moved to Vaultwarden before legacy tools are uninstalled. Details in [01-MANUAL.md](01-MANUAL.md) section "Secrets Migration".

---

## Phase 1 — Initial macOS Setup

**Script:** none — entirely manual.
**Duration:** 20–30 minutes.

### What to Do

1. Setup assistant: language, region, sign in with Apple ID.
2. **Enable FileVault immediately** — `System Settings → Privacy & Security → FileVault → Enable`. Store the FileVault recovery key in Vaultwarden — without it the device is unrecoverable if lost.
3. iCloud: **disable** "Desktop & Documents" in iCloud (prevents unintended sync of dev files).
4. Software Update: `System Settings → General → Software Update` — let it run until "Up to Date".
5. The settings applied by `scripts/09-macos-defaults.sh` (Finder, Dock, key repeat) do **not** need to be done by hand here.

### Verification

```bash
fdesetup status          # FileVault On
sw_vers                  # macOS version is correct
```

---

## Phase 2 — Apple Toolchain

**Goal:** Set up Xcode + Command Line Tools so Swift projects build and the rest of the toolchain (Homebrew, Python C bindings, etc.) sits on the correct SDK paths.

**Script:** `scripts/01-apple-toolchain.sh`

### CLT vs. Full Xcode

You need both — CLT alone is not enough if you have `.xcodeproj` projects.

```bash
# CLT is automatically checked/installed by bootstrap.sh
xcode-select --install

# Xcode itself: exclusively via App Store (no automatable path)
# → Download Xcode.app, launch it, confirm component installation
```

The script handles the following after Xcode installation:
```bash
sudo xcodebuild -license accept
# Install simulators (only --full): iOS, watchOS, visionOS
xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### What Remains Manual

- Download Xcode from the App Store (4–8 GB, 15–30 min)
- On first launch: confirm component installation

### Verification

```bash
xcode-select -p
# Expected: /Applications/Xcode.app/Contents/Developer

swift --version
# Swift 6.x

xcrun simctl list runtimes
# iOS, watchOS, visionOS present (with --full)
```

### Common Errors

- `error: invalid active developer path` → `sudo xcode-select -r` or `-s /Applications/Xcode.app`
- Simulators missing after `--minimal` → `./bootstrap.sh --only 01-apple-toolchain`

---

## Phase 3 — Homebrew + Core Packages

**Goal:** Set up the package manager and install all tools defined in `Brewfile`.

**Script:** `scripts/02-homebrew.sh`

### What Runs Automatically

```bash
# Install Homebrew (if not already present)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Taps and core packages
brew bundle --file=Brewfile

# Optional packages (only --full)
brew bundle --file=Brewfile.optional
```

### What Is in the Brewfile (Selected Items with Purpose)

| Package | Purpose |
|---|---|
| `git`, `git-lfs` | Version control; lfs for binary assets |
| `gh` | GitHub CLI for PRs, issues, release management |
| `uv` | Python project management, lockfile-based |
| `pnpm` | Package manager for Vite/React projects |
| `jq` | JSON processing in shell scripts, API debugging |
| `ripgrep` | Code search across many repos |
| `gitleaks` | Secret scanning before commits |
| `shellcheck` | Linting for setup scripts |
| `ollama` | Local language models |
| `gemini-cli` | Gemini as a second AI agent |
| `postgresql@14` | Postgres locally (projects without docker-compose) |
| `openjdk@17` | Java for Spring Boot projects + Maven/Gradle |
| `go`, `rust`, `php` | Supporting roles depending on project |
| `vips` | Image processing for `sharp-cli`/optimization workflows |
| `pre-commit` | Git hooks — **missing on the previous machine, now required** |

### Verification

```bash
brew doctor            # no errors
brew bundle check      # "The Brewfile's dependencies are satisfied."
which git              # /opt/homebrew/bin/git  — NOT /usr/bin/git
```

### Common Errors

- `/usr/bin/git` takes precedence: PATH problem, fixed in phase 4.
- `brew bundle` fails because a legacy tap was removed: `brew untap <tap>` and try again.

---

## Phase 4 — Terminal & Shell

**Goal:** A clean, fast shell configuration that replaces the accumulated drift of a long-lived `.zshrc`.

**Script:** `scripts/03-shell.sh`

### What Runs Automatically

- Install/update oh-my-zsh
- Plugins: `git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `web-search`
- Theme: powerlevel10k
- `config/zshrc` → `~/.zshrc` (backup of old file at `~/.zshrc.bkp.$(date +%Y%m%d)`)
- `config/zprofile` → `~/.zprofile`

### Why the New .zshrc Is Structured Differently

A `.zshrc` that has grown over years accumulates problems. Here are the most common ones and how the new configuration fixes them:

| Problem | Cause | Fix in new .zshrc |
|---|---|---|
| PATH duplicates (`/usr/bin` 2×, `/usr/local/bin` 2×) | Multiple sources extend PATH without coordination | `typeset -U path` deduplicates automatically |
| System git beats brew git | `/usr/bin` precedes `/opt/homebrew/bin` in PATH | `/opt/homebrew/bin` comes first |
| Slow shell startup from nvm | `nvm.sh` loads all Node bindings on every startup | Lazy load: nvm initializes only on the first `node`/`npm` call |
| `python3` → conda-base | conda init activates base on every startup | conda not auto-activated — only on explicit `conda activate` |
| VS Code PATH duplicated in `.zprofile` | Line-by-line duplicates from repeated edits | Once, deduplicated |
| `.local/bin/env` in both `.profile` and `.zshrc` | Different shell init paths | Once, in `.zprofile` only |
| Completion for a non-installed framework | `ng completion` without Angular CLI | Removed |
| Environment variable points at nonexistent directory | Leftover after tool change | Cleaned up |
| Completion block duplicated | No merge mechanism on insertion | Deduplicated |
| Missing blank line before `export PATH` | Text concatenation without separator | Correctly formatted |

**Lazy nvm:**
```zsh
nvm() {
  unfunction nvm
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  nvm "$@"
}
node() { nvm > /dev/null 2>&1; node "$@"; }
npm()  { nvm > /dev/null 2>&1; npm  "$@"; }
```

**Lazy conda:**
```zsh
conda() {
  unfunction conda
  __conda_setup="$($HOME/miniforge3/bin/conda shell.zsh hook 2>/dev/null)"
  eval "$__conda_setup"
  conda "$@"
}
```

### iTerm2 vs. Ghostty

Both terminals are installed. iTerm2 is the active default (uses a status hook for Claude Code events). Ghostty has a minimal base config and serves as a fast alternative. Default application: set manually.

### Verification

```bash
exec zsh

# No duplicate PATH entries
echo $PATH | tr ':' '\n' | sort | uniq -d   # must be empty

# brew-git wins
which git   # /opt/homebrew/bin/git

# powerlevel10k
echo $PROMPT   # p10k prompt or configuration wizard starts
```

---

## Phase 5 — Git, SSH, GitHub, Signing

**Goal:** git fully configured, ed25519 key instead of old RSA, both GitHub accounts cleanly separated, signed commits, pre-commit hooks running.

**Script:** `scripts/08-git-ssh.sh`

### What Runs Automatically

```bash
# Apply git configuration from config/gitconfig
git config --global include.path ~/dev/kickoff-ai/config/gitconfig

# Generate a new ed25519 key
ssh-keygen -t ed25519 -C "<your@email.com>" -f ~/.ssh/id_ed25519

# Enable SSH commit signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true

# Register core.excludesfile
git config --global core.excludesfile ~/.gitignore_global

# Install pre-commit in dev/base
cd ~/dev/base && pre-commit install --install-hooks

# Wire gitleaks via pre-commit
# (already defined in dev/base/.pre-commit-config.yaml)
```

### What Remains Manual

- Register the SSH key with GitHub (separately for both accounts):
  ```bash
  gh auth login --hostname github.com
  gh ssh-key add ~/.ssh/id_ed25519.pub --title "kickoff-$(date +%Y%m%d)"
  ```

- Set up the second account in `~/.ssh/config` with its own key entry:
  ```sshconfig
  Host github-primary
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

  Host github-secondary
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_secondary
    IdentitiesOnly yes
  ```

- Decide which account is the default and which uses the host alias in the relevant repos.

### Why ed25519 Instead of RSA

RSA-2048 is secure, but ed25519 is smaller (shorter keys, faster signing), supported by all current systems, and the modern standard. Copying an old RSA key gives the same security level as before — a rebuild is the right moment for a new key. Details: [04-DECISIONS.md](04-DECISIONS.md).

### Verification

```bash
git config --global core.excludesfile   # ~/.gitignore_global
git config --global gpg.format         # ssh
git config --global commit.gpgsign     # true
ssh -T github-primary                   # Hi <username>!
ssh -T github-secondary                 # Hi <second-username>!
pre-commit --version                    # present
git commit --allow-empty -m "test signing"
git log --show-signature -1            # Good "git" signature
```

---

## Phase 6 — Languages & Version Management

**Goal:** Node via nvm, Python via uv as default, conda as opt-in, Java/Go/Rust/PHP from Homebrew.

**Scripts:** `scripts/04-node.sh`, `scripts/05-python.sh`

### Node

```bash
nvm install 24
nvm alias default 24

# Global packages (minimal list)
npm install -g @openai/codex sharp-cli
```

You have 36 `package.json` projects and use pnpm as the default package manager, Bun as fallback for performance-critical builds, Deno for standalone scripts.

### Python — Why uv Instead of conda-base

The typical baseline on an evolved machine: `python3` points to conda-base, which is cluttered with hundreds of packages (torch, jupyter, scraping libraries, scientific packages for one-off experiments). This is a classic anti-pattern:

- conda-base is not a project env but the system root of the conda ecosystem
- Packages in base block updates and mix dependencies
- `python3` never points to the project Python → "works on my machine" problems
- conda 22.x is two major versions behind

**uv as the primary path:**
```bash
# New Python project
uv init my-project
cd my-project
uv add fastapi pydantic httpx

# Run a tool without installing it
uvx ruff check .
uvx pytest

# Pin a Python version
uv python pin 3.13
```

uv is 10–100× faster than pip/conda for dependency resolution, lockfile-based (`uv.lock`), and automatically isolates projects.

**Keep conda as opt-in** for:
- Projects with conda-only packages (MKL, SPSS integration, cvxpy)
- Existing Jupyter notebooks that require a conda env
- `conda activate <env>` continues to work; conda-base is not removed from PATH, just not activated by default

### Java / Go / Rust / PHP

All from Homebrew, no additional configuration:
```bash
# Java 17 — for Spring Boot projects
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
# Maven runs directly from /opt/homebrew/bin/mvn — no M2_HOME needed

# Go, Rust, PHP
which go rustc php   # all at /opt/homebrew/bin/
```

### Verification

```bash
node --version          # v24.x
python3 --version       # NOT conda-base 3.10.9 anymore
uv --version            # 0.10.x+
java -version           # 17.x
go version              # 1.x
rustc --version         # 1.x
```

---

## Phase 7 — Containers & Databases

**Goal:** Docker Desktop running, the project pattern documented, containers running only when needed.

**Script:** `scripts/06-containers.sh`

### What Runs Automatically

- Check/install Docker Desktop (cask: `docker`)
- Verify `docker compose version`
- Pull base images: `mysql:8.0`, `postgres:17-alpine`, `qdrant/qdrant:v1.13.0`, `valkey/valkey:8-alpine`

### The Pattern: One docker-compose per Project

Each web project has its own `docker-compose.yml` with the database stack (mysql:8.0 + phpMyAdmin + API container). This is consistent and isolated.

**The problem on evolved machines:** Many containers run permanently — even if the associated project has not been touched in weeks. This wastes RAM and energy.

**Recommended pattern:**
```bash
# Before work — bring up only the active project
cd ~/dev/<project-name> && docker compose up -d

# After work
docker compose down   # without -v: data in named volumes is preserved

# Stay oriented
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

The setup script sets **no** containers to autostart. Persistent data lives in named volumes (not in the container layer) — `docker compose down` without `-v` deletes nothing.

### Specialized Services for AI Projects

For projects with vector database + queue + Postgres:
```yaml
services:
  db:      image: postgres:17-alpine
  vector:  image: qdrant/qdrant:v1.13.0
  queue:   image: valkey/valkey:8-alpine
```

Ollama runs natively (brew formula), not as a Docker container — details in phase 8.

### Verification

```bash
docker info | grep "Server Version"
docker compose version
docker ps   # ideally: only active projects
```

---

## Phase 8 — The AI Stack

**Goal:** Claude Code, Codex CLI, Gemini CLI, Ollama, and MCP fully configured — the primary toolset.

**Script:** `scripts/07-ai-stack.sh`

> Legacy agent gateways (OpenClaw etc.) are removed on the existing machine via `scripts/90-cleanup-legacy.sh`. On a fresh build they are never created.

### Claude Code

Claude Code is the primary tool — with `claude-opus-5[1m]` as the main model and `claude-sonnet-4-6` for subagents (cost brake).

```bash
# Installation
npm install -g @anthropic-ai/claude-code   # or via ~/.local/bin/claude

# Subagent cost brake (in .zshrc)
export CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6
```

**Permissions (`~/.claude/settings.json`):**
```json
{
  "permissions": {
    "allow": ["curl 127.0.0.1", "npm test", "git status", "npx tsc"],
    "deny": ["Read(**/.env)", "Read(**/secrets/**)"],
    "ask": ["Bash(rm *)"]
  }
}
```

**Plugins (active):**
- `claude-mem` — cross-project memory
- `frontend-design` — frontend design guidelines
- `apple-skills` — iOS/Swift/App Store workflows

**Hooks:** A status script receives all Claude Code events (SessionStart/End, PreToolUse, PostToolUse, Stop, Notification) and displays the current status in the terminal status bar. The script file must be transferred or recreated manually — it lives under `~/.config/iterm2/`.

**Security settings:** `skipDangerousModePermissionPrompt` and `skipAutoPermissionPrompt` are active. Read [docs/02-GAP-ANALYSIS.md](02-GAP-ANALYSIS.md) finding A.15 for the risk assessment and recommended middle ground.

**CLAUDE.md (subagent routing rules):** `~/.claude/CLAUDE.md` contains global routing rules. This file is created by the script.

### Codex CLI

```bash
npm install -g @openai/codex

# ~/.codex/config.toml
# model = "gpt-5.6-terra"
# reasoning = "medium"
# service_tier = "fast"
# approval_mode: recommendation is "suggest" instead of "full-auto" — see gap analysis A.15
```

MCP servers for Codex: `basic-memory` (via `uvx`), `openaiDeveloperDocs`.

### Gemini CLI

```bash
brew install gemini-cli
# API key: GEMINI_API_KEY via env-run (bw://gemini-api/password)
# ~/.gemini/settings.json: claude-mem hooks on all events
```

Gemini CLI uses the same claude-mem memory system as Claude — sessions across different agents share context.

### Ollama + Local Models

```bash
# Only the brew formula — no cask, no container (avoid duplication)
brew install ollama

# Start the service (on demand, not permanently)
ollama serve &

# Pull models — check free space first!
ollama pull llama3.2          # 2.0 GB — fast general-purpose model
ollama pull deepseek-r1:14b   # 9.0 GB — reasoning tasks
ollama pull glm-ocr           # 2.2 GB — OCR workflows
ollama pull aya-expanse:8b    # 5.1 GB — multilingual tasks
# Total: ~18 GB

# Use models on demand (via API or directly)
ollama run llama3.2 "hello"
curl http://localhost:11434/api/generate -d '{"model":"llama3.2","prompt":"ping"}'
```

**Why native instead of a container:** Ollama natively (brew) uses Metal acceleration on Apple Silicon directly. An Ollama container loses GPU access on macOS and runs CPU-only — significantly slower. Details: [04-DECISIONS.md](04-DECISIONS.md).

**Storage note:** All models combined ~18 GB. If storage is tight, clean up first (see gap analysis A.14), then `ollama pull`.

### MCP Servers

MCP (Model Context Protocol) connects Claude to external tools:
```bash
# basic-memory — local file memory
claude mcp add basic-memory -- uvx basic-memory

# Additional servers as needed
claude mcp add <name> <command>
claude mcp list
```

### Verification

```bash
claude --version
codex --version
gemini --version
ollama list         # installed models
ollama run llama3.2 "ping"   # response in < 5 sec
```

---

## Phase 9 — Editors

**Goal:** VS Code with a complete extension set, IntelliJ via JetBrains Toolbox, Xcode from phase 2.

**Script:** `scripts/10-editors.sh`

### VS Code

```bash
brew install --cask visual-studio-code

# Extensions from config/vscode-extensions.txt
cat config/vscode-extensions.txt | xargs -L1 code --install-extension
```

Extension set by area:

| Area | Extensions |
|---|---|
| Python | ms-python.python, Pylance, debugpy, python-envs, environment-manager |
| Jupyter | Jupyter + 4 companions |
| Java/Spring | redhat.java, vscjava ×7, Spring Boot ×3, gradle, maven |
| PHP | Devsense ×4, composer, phpserver |
| Containers | docker.docker, remote-containers, ms-azuretools |
| AI/Pair | continue.continue |
| Diagrams | plantuml ×2, structurizr |
| Frontend | Prettier, **ESLint** (newly added — was missing on the previous machine), liveserver |

### JetBrains Toolbox + IntelliJ

```bash
brew install --cask jetbrains-toolbox
# IntelliJ: install via the Toolbox UI (no CLI path)
# After installation: idea <project-path> from the terminal
```

### Ghostty

Ghostty is installed with a minimal base config (font, theme, scrollback). Primary terminal remains iTerm2 with the Claude Code status hook.

### Verification

```bash
code --version
code --list-extensions | wc -l   # ~70
idea --version   # if JetBrains PATH is set
```

---

## Phase 10 — The Custom Paved Road (`dev/base`)

**Goal:** Have the personal quality standard immediately available across all repos.

**Script:** `scripts/11-paved-road.sh`

### Why This Comes First

`dev/base` defines the standards for all other projects — templates, quality gates, pre-commit hooks, security rules. Without `~/dev/base/bin` in PATH, custom commands (`base new`, `base sync`, `base doctor`) do not work.

```bash
# Clone base
git clone git@github-primary:<account>/base.git ~/dev/base

# Extend PATH (in .zshrc)
export PATH="$HOME/dev/base/bin:$PATH"

# Verify availability
base list
```

### What `dev/base` Does

| Command | Function |
|---|---|
| `base new <template> <name>` | Scaffolds a new repo from a template (vite-react-pwa, python-service, book, …) |
| `base sync [repo]` | Adds missing standard files to existing repos (purely additive, never overwriting) |
| `base doctor [repo]` | Checks whether a repo meets the standards |
| `base lesson "<text>"` | Adds a lesson to the global `memory/LESSONS.md` |
| `base harvest [repo]` | Pulls findings from a repo into the global knowledge base |
| `base status` | Overview of all repos |

### Structure

```
dev/base/
  CONSTITUTION.md          Invariants — what never changes
  memory/LESSONS.md        Accumulated findings from all projects
  standards/               Code standards (ci, git, python, web, security …)
  backbone/                Shell scripts for gates, budgets, security checks
  hooks/                   Git hook templates
  skills/                  Claude skills (session-start, project-state, naming …)
  templates/               Starter templates for new repos
```

---

## Phase 11 — First Smoke Test

**Goal:** Verify everything works together — from `base new` to a green gate.

```bash
# 1 — Check setup state
./doctor.sh   # in ~/dev/kickoff-ai: ~40 checks, all PASS or WARN

# 2 — Scaffold a new project
cd ~/dev
base new vite-react-pwa smoke-test-$(date +%Y%m%d)
cd smoke-test-*/

# 3 — Install dependencies
pnpm install

# 4 — Run the gate
npm run verify:ci   # type-check + lint + tests

# 5 — Start the dev server
pnpm dev   # browser opens, no console errors

# 6 — Claude Code in context
claude   # reads CLAUDE.md, recognizes the project

# 7 — Clean up
cd ~/dev && rm -rf smoke-test-*/
```

All 7 steps green → setup is complete.

---

## Cleanup Module for the Existing Machine

On a **fresh build**, accumulated drift never occurs. On the **existing machine**, there is an opt-in cleanup script that removes it:

```bash
# Dry run: what would be removed?
./bootstrap.sh --only 90-cleanup-legacy --dry-run

# Execute (with automatic backup to ~/.setup-backups/<timestamp>/)
./bootstrap.sh --only 90-cleanup-legacy
```

What the script does:
1. Backs up relevant configuration data to `~/.setup-backups/<timestamp>/`
2. Removes the legacy agent gateway (npm global + pnpm link + LaunchAgent + config directory with credentials)
3. Cleans up `.zshrc`: stale variables, dead aliases, duplicate completion blocks
4. Removes orphaned LaunchAgents (e.g., for uninstalled packages)
5. Removes the associated Homebrew taps

The script does **not** run automatically as part of `bootstrap.sh`.
