#!/usr/bin/env bash
# =============================================================================
# status-quo.sh — Snapshot of the current state on the OLD machine
#
# Purpose:  Captures everything needed for a machine migration: toolchain
#           versions, installed software, Git repos with local state, Docker
#           stacks, Ollama models, macOS settings. Writes to local/status-quo/
#           (gitignored). Never secrets or key material.
#
# Changes:  Nothing — read-only (writes only to local/)
# Requires: Homebrew, git, python3 (all present on the old machine)
# Usage:    ./status-quo.sh [--out <directory>] [--dry-run] [--help]
#
# Output files (under local/status-quo/<YYYY-MM-DD>/):
#   profile.json    Machine-readable profile for migration-diff
#   repos.md        Git repos with remote URL, branch, change state
#   repos.txt       Machine-readable repo list (pipe-separated)
#   STATUS-QUO.md   Human-readable overview (hardware, stack, apps)
#   manual.md       Derived to-do list for the migration
#
# Secrets boundary: Key material, tokens, .env contents are NEVER captured.
# Only names and locations (e.g. "SSH key 'id_rsa_github' present").
# For migrating secrets: docs/08-SECRETS.md (Vaultwarden path).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

# =============================================================================
# Argument-Parsing
# =============================================================================
OUT_DIR=""
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --out)      shift; OUT_DIR="${1:-}" ;;
        --dry-run)  DRY_RUN=1; export DRY_RUN ;;
        --help|-h)
            cat >&2 <<'HELP'
Usage: status-quo.sh [options]

  Captures the current state of this machine for a migration.
  Writes only to local/status-quo/ (gitignored).
  NEVER captures secrets or key material.

Options:
  --out <directory>  Output directory (default: local/status-quo/<YYYY-MM-DD>)
  --dry-run          Show what would be captured, write NOTHING
  --help             This help text

Output files:
  profile.json   Machine-readable — basis for migration-diff
  repos.md       Git repos with remote/branch/change state
  repos.txt      Machine-readable repo list
  STATUS-QUO.md  Human-readable full report
  manual.md      To-do list for the migration

Examples:
  ./status-quo.sh
  ./status-quo.sh --out /tmp/my-export
  ./status-quo.sh --dry-run
HELP
            exit 0
            ;;
        *) err "Unknown option: $1 (--help for usage)" ;;
    esac
    shift
done

# =============================================================================
# Ausgabeverzeichnis
# =============================================================================
_TODAY=$(date '+%Y-%m-%d')
if [ -z "$OUT_DIR" ]; then
    OUT_DIR="$SCRIPT_DIR/local/status-quo/$_TODAY"
fi

if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] Output would go to: $OUT_DIR"
else
    mkdir -p "$OUT_DIR"
    ok "Output: $OUT_DIR"
fi

# =============================================================================
# Helper: write file (respects --dry-run)
# =============================================================================
_write_file() {
    local pfad="$1"
    local inhalt="$2"
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would write: $pfad"
        return 0
    fi
    printf '%s\n' "$inhalt" > "$pfad"
    ok "Written: $(basename "$pfad")"
}

# =============================================================================
# PHASE 1 — Collect base data
# =============================================================================
step "Base data"

_MACOS_VER=$(sw_vers -productVersion 2>/dev/null || echo "?")
_MACOS_BUILD=$(sw_vers -buildVersion 2>/dev/null || echo "?")
_ARCH=$(uname -m)
_HOSTNAME=$(hostname -s 2>/dev/null || echo "unknown")
_RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
_RAM_GB=$((_RAM_BYTES / 1024 / 1024 / 1024))
_FREE_KB=$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
_FREE_GB=$((_FREE_KB / 1024 / 1024))
_DISK_KB=$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {print $2}' || echo "0")
_DISK_GB=$((_DISK_KB / 1024 / 1024))
_XCODE_VER="not installed"
if [ -d "/Applications/Xcode.app" ]; then
    _XCODE_VER=$(defaults read /Applications/Xcode.app/Contents/Info.plist \
        CFBundleShortVersionString 2>/dev/null || echo "?")
fi
_CLT_PATH=$(xcode-select -p 2>/dev/null || echo "not installed")

info "macOS $_MACOS_VER · Arch $_ARCH · RAM ${_RAM_GB} GB · Disk ${_FREE_GB}/${_DISK_GB} GB free"

# =============================================================================
# PHASE 2 — Capture Homebrew
# =============================================================================
step "Homebrew"

_BREW_VER="not installed"
_BREW_FORMULAE=""
_BREW_CASKS=""
_BREW_TAPS=""
_BREW_SERVICES=""

if have brew; then
    _BREW_VER=$(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo "?")
    info "Homebrew v$_BREW_VER — collecting formulae, casks, taps ..."
    _BREW_FORMULAE=$(brew leaves 2>/dev/null | sort || echo "")
    _BREW_CASKS=$(brew list --cask 2>/dev/null | sort || echo "")
    _BREW_TAPS=$(brew tap 2>/dev/null | sort || echo "")
    # brew services: name and status
    _BREW_SERVICES=$(brew services list 2>/dev/null \
        | awk 'NR>1 && $2!="none" {print $1"="$2}' | sort || echo "")
    ok "Homebrew: $(printf "%s" "$_BREW_FORMULAE" | wc -l | tr -d ' ') formulae, \
$(printf "%s" "$_BREW_CASKS" | wc -l | tr -d ' ') casks"
else
    warn "Homebrew not found"
fi

# =============================================================================
# PHASE 3 — Capture Node stack
# =============================================================================
step "Node stack"

_NODE_VER=$(node --version 2>/dev/null || echo "")
_NPM_VER=$(npm --version 2>/dev/null || echo "")
_PNPM_VER=$(pnpm --version 2>/dev/null || echo "")
_BUN_VER="${HOME}/.bun/bin/bun"
_BUN_VER=$(bun --version 2>/dev/null || { [ -f "${HOME}/.bun/bin/bun" ] && "${HOME}/.bun/bin/bun" --version 2>/dev/null; } || echo "")
_DENO_VER=$(deno --version 2>/dev/null | head -1 | awk '{print $2}' || echo "")

# npm globals: package names without version suffix from parseable format
_NPM_GLOBALS=""
if have npm; then
    _NPM_GLOBALS=$(npm list -g --depth=0 --parseable 2>/dev/null \
        | awk -F/ 'NR>1{print $NF}' | sort || echo "")
    info "npm globals: $(printf "%s" "$_NPM_GLOBALS" | wc -l | tr -d ' ') packages"
fi

# =============================================================================
# PHASE 4 — Capture Python stack
# =============================================================================
step "Python stack"

_PYTHON_VER=$(python3 --version 2>/dev/null | awk '{print $2}' || echo "")
_UV_VER=$(uv --version 2>/dev/null | awk '{print $2}' || echo "")
_PIPX_VER=$(pipx --version 2>/dev/null || echo "")

# =============================================================================
# PHASE 5 — Further languages
# =============================================================================
step "Other versions"

_JAVA_VER=$(java -version 2>&1 | head -1 | grep -oE '"[0-9]+\.[0-9.]+[^"]*"' | tr -d '"' || echo "")
_GO_VER=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//' || echo "")
_RUST_VER=$(rustc --version 2>/dev/null | awk '{print $2}' || echo "")

# =============================================================================
# PHASE 6 — VS Code extensions
# =============================================================================
step "VS Code extensions"

_VSCODE_EXTENSIONS=""
_CODE_BIN=""
if have code; then
    _CODE_BIN="code"
elif [ -f "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" ]; then
    _CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
fi

if [ -n "$_CODE_BIN" ]; then
    _VSCODE_EXTENSIONS=$("$_CODE_BIN" --list-extensions 2>/dev/null | sort || echo "")
    info "VS Code: $(printf "%s" "$_VSCODE_EXTENSIONS" | wc -l | tr -d ' ') extensions"
else
    warn "VS Code ('code') not found"
fi

# =============================================================================
# PHASE 7 — Ollama models
# =============================================================================
step "Ollama models"

_OLLAMA_VER=$(ollama --version 2>/dev/null | awk '{print $NF}' || echo "")
_OLLAMA_MODELS=""
if have ollama && curl -sf --max-time 3 http://localhost:11434/api/tags >/dev/null 2>&1; then
    _OLLAMA_MODELS=$(ollama list 2>/dev/null | awk 'NR>1{print $1}' | sort || echo "")
    info "Ollama $_OLLAMA_VER — $(printf "%s" "$_OLLAMA_MODELS" | grep -c . || echo "0") models"
elif have ollama; then
    info "Ollama installed (v$_OLLAMA_VER) but not reachable — start with: ollama serve"
else
    info "Ollama not installed"
fi

# =============================================================================
# PHASE 8 — macOS defaults (setup-relevant settings)
# =============================================================================
step "macOS defaults"

_SHOW_ALL_FILES=$(defaults read com.apple.finder AppleShowAllFiles 2>/dev/null || echo "not set")
_SHOW_EXTENSIONS=$(defaults read NSGlobalDomain AppleShowAllExtensions 2>/dev/null || echo "not set")
_DOCK_AUTOHIDE=$(defaults read com.apple.dock autohide 2>/dev/null || echo "not set")
_KEY_REPEAT=$(defaults read NSGlobalDomain KeyRepeat 2>/dev/null || echo "not set")
_INIT_KEY_REPEAT=$(defaults read NSGlobalDomain InitialKeyRepeat 2>/dev/null || echo "not set")

# =============================================================================
# PHASE 9 — Docker
# =============================================================================
step "Docker"

_DOCKER_VER=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo "")
_DOCKER_RUNNING_CONTAINERS=""
_DOCKER_IMAGES=""
_DOCKER_STACKS=""

if have docker && docker info >/dev/null 2>&1; then
    _DOCKER_RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}|{{.Image}}|{{.Status}}" 2>/dev/null | sort || echo "")
    _DOCKER_IMAGES=$(docker images --format "{{.Repository}}:{{.Tag}}|{{.Size}}" 2>/dev/null \
        | grep -v '<none>' | sort || echo "")
    # Docker Compose stacks: directories under ~/dev with docker-compose.yml
    _DOCKER_STACKS=$(find "${HOME}/dev" -maxdepth 2 \
        \( -name "docker-compose.yml" -o -name "docker-compose.yaml" \
           -o -name "compose.yml" -o -name "compose.yaml" \) \
        -not -path "*/.git/*" 2>/dev/null \
        | awk -F/ '{print $(NF-1)}' | sort || echo "")
    info "Docker v$_DOCKER_VER — \
$(printf "%s" "$_DOCKER_RUNNING_CONTAINERS" | grep -c . || echo 0) containers running"
else
    info "Docker not reachable — containers/images not captured"
fi

# =============================================================================
# PHASE 10 — SSH keys (names only, never content)
# =============================================================================
step "SSH keys"

_SSH_KEYS=""
if [ -d "${HOME}/.ssh" ]; then
    # List only private keys (without .pub) — never read content
    # Glob instead of ls-pipe (shellcheck SC2010)
    for _ssh_key in "${HOME}/.ssh"/id_*; do
        [ -f "$_ssh_key" ] || continue
        case "$_ssh_key" in *.pub) continue ;; esac
        _ssh_type=$(ssh-keygen -l -f "$_ssh_key" 2>/dev/null \
            | awk '{print $4}' | tr -d '()' || echo "?")
        _SSH_KEYS="${_SSH_KEYS}$(basename "$_ssh_key")|${_ssh_type}
"
    done
fi

# .env files: capture paths only, never content
_ENV_FILES=$(find "${HOME}/dev" -maxdepth 3 -name ".env*" \
    -not -name ".env.example" -not -name ".env.template" \
    -not -path "*/.git/*" 2>/dev/null | wc -l | tr -d ' ')

info "SSH keys: $(printf "%s" "$_SSH_KEYS" | grep -c . || echo "0") | .env files in ~/dev: $_ENV_FILES"

# =============================================================================
# PHASE 11 — LaunchAgents (names only)
# =============================================================================
step "LaunchAgents"

# Glob instead of ls-pipe (shellcheck SC2011)
_LAUNCH_AGENTS=""
for _la_plist in "${HOME}/Library/LaunchAgents/"*.plist; do
    [ -f "$_la_plist" ] || continue
    _LAUNCH_AGENTS="${_LAUNCH_AGENTS}$(basename "$_la_plist" .plist)
"
done
_LAUNCH_AGENTS=$(printf "%s" "$_LAUNCH_AGENTS" | sort)

# =============================================================================
# PHASE 12 — Capture repos
# =============================================================================
step "Git repos under ~/dev"

_REPOS_MD_LINES=""
_REPOS_TXT_LINES=""
_UNSAFE_REPOS=""
_NO_REMOTE_REPOS=""
_REPO_COUNT=0
_UNSAFE_COUNT=0
_NO_REMOTE_COUNT=0

for _REPO_PATH in "${HOME}/dev"/*/; do
    [ -d "$_REPO_PATH/.git" ] || continue
    _REPO_NAME=$(basename "$_REPO_PATH")
    _REPO_COUNT=$((_REPO_COUNT + 1))

    _REMOTE=$(git -C "$_REPO_PATH" remote get-url origin 2>/dev/null || echo "")
    _BRANCH=$(git -C "$_REPO_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    _DIRTY=$(git -C "$_REPO_PATH" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    _AHEAD=0
    _UPSTREAM=$(git -C "$_REPO_PATH" rev-parse --abbrev-ref "@{u}" 2>/dev/null || echo "")
    if [ -n "$_UPSTREAM" ]; then
        _AHEAD=$(git -C "$_REPO_PATH" rev-list "@{u}..HEAD" 2>/dev/null | wc -l | tr -d ' ')
    fi

    # Machine-readable line
    _REPOS_TXT_LINES="${_REPOS_TXT_LINES}${_REPO_NAME}|${_REMOTE}|${_BRANCH}|${_DIRTY}|${_AHEAD}
"

    # Risky repos (uncommitted or unpushed)
    if [ "$_DIRTY" -gt 0 ] || [ "$_AHEAD" -gt 0 ]; then
        _WARN_MARKER="⚠"
        [ "$_DIRTY" -gt 0 ] && _WARN_MARKER="${_WARN_MARKER} ${_DIRTY} uncommitted"
        [ "$_AHEAD" -gt 0 ] && _WARN_MARKER="${_WARN_MARKER} ${_AHEAD} unpushed"
        _UNSAFE_REPOS="${_UNSAFE_REPOS}| ${_REPO_NAME} | \`${_BRANCH}\` | ${_WARN_MARKER} |
"
        _UNSAFE_COUNT=$((_UNSAFE_COUNT + 1))
    fi

    # Repos without remote
    if [ -z "$_REMOTE" ]; then
        _NO_REMOTE_REPOS="${_NO_REMOTE_REPOS}- **${_REPO_NAME}** (no remote — manual backup required!)
"
        _NO_REMOTE_COUNT=$((_NO_REMOTE_COUNT + 1))
    fi

    _REPOS_MD_LINES="${_REPOS_MD_LINES}| ${_REPO_NAME} | ${_REMOTE:-_(no remote)_} | \`${_BRANCH}\` | ${_DIRTY} | ${_AHEAD} |
"
done

info "Repos: $_REPO_COUNT total, $_UNSAFE_COUNT with open state, $_NO_REMOTE_COUNT without remote"

# =============================================================================
# OUTPUT: profile.json (machine-readable, basis for migration-diff)
# =============================================================================
step "Writing profile.json"

if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] Would generate profile.json"
else
    _PROFILE_FILE="$OUT_DIR/profile.json"

    # JSON generation via python3 (always available, no jq needed)
    export _SQ_MACOS_VER="$_MACOS_VER"
    export _SQ_MACOS_BUILD="$_MACOS_BUILD"
    export _SQ_ARCH="$_ARCH"
    export _SQ_RAM_GB="$_RAM_GB"
    export _SQ_XCODE_VER="$_XCODE_VER"
    export _SQ_BREW_VER="$_BREW_VER"
    export _SQ_BREW_FORMULAE="$_BREW_FORMULAE"
    export _SQ_BREW_CASKS="$_BREW_CASKS"
    export _SQ_BREW_TAPS="$_BREW_TAPS"
    export _SQ_BREW_SERVICES="$_BREW_SERVICES"
    export _SQ_NPM_GLOBALS="$_NPM_GLOBALS"
    export _SQ_NODE_VER="$_NODE_VER"
    export _SQ_PYTHON_VER="$_PYTHON_VER"
    export _SQ_JAVA_VER="$_JAVA_VER"
    export _SQ_GO_VER="$_GO_VER"
    export _SQ_RUST_VER="$_RUST_VER"
    export _SQ_UV_VER="$_UV_VER"
    export _SQ_VSCODE_EXTENSIONS="$_VSCODE_EXTENSIONS"
    export _SQ_OLLAMA_VER="$_OLLAMA_VER"
    export _SQ_OLLAMA_MODELS="$_OLLAMA_MODELS"
    export _SQ_DOCKER_VER="$_DOCKER_VER"
    export _SQ_DEFAULTS_SHOW_FILES="$_SHOW_ALL_FILES"
    export _SQ_DEFAULTS_SHOW_EXT="$_SHOW_EXTENSIONS"
    export _SQ_DEFAULTS_DOCK="$_DOCK_AUTOHIDE"
    export _SQ_DEFAULTS_KEY_REPEAT="$_KEY_REPEAT"
    export _SQ_PROFILE_FILE="$_PROFILE_FILE"

    python3 <<'PYEOF'
import json, os, datetime

def lines(env_key):
    """Read environment variable as a list of lines (filter empty lines)."""
    val = os.environ.get(env_key, "")
    return [l for l in val.splitlines() if l.strip()]

def field(env_key, default=""):
    return os.environ.get(env_key, default) or default

profile = {
    "generated_at": datetime.datetime.now().isoformat(),
    "schema_version": "1",
    "machine": {
        "macos": field("_SQ_MACOS_VER"),
        "macos_build": field("_SQ_MACOS_BUILD"),
        "arch": field("_SQ_ARCH"),
        "ram_gb": int(field("_SQ_RAM_GB", "0") or 0),
        "xcode": field("_SQ_XCODE_VER"),
    },
    "brew": {
        "version": field("_SQ_BREW_VER"),
        "formulae": lines("_SQ_BREW_FORMULAE"),
        "casks": lines("_SQ_BREW_CASKS"),
        "taps": lines("_SQ_BREW_TAPS"),
        "services": dict(
            s.split("=", 1) for s in lines("_SQ_BREW_SERVICES") if "=" in s
        ),
    },
    "npm": {
        "global": lines("_SQ_NPM_GLOBALS"),
    },
    "vscode": {
        "extensions": lines("_SQ_VSCODE_EXTENSIONS"),
    },
    "ollama": {
        "version": field("_SQ_OLLAMA_VER"),
        "models": lines("_SQ_OLLAMA_MODELS"),
    },
    "docker": {
        "version": field("_SQ_DOCKER_VER"),
    },
    "versions": {
        "node": field("_SQ_NODE_VER"),
        "python": field("_SQ_PYTHON_VER"),
        "java": field("_SQ_JAVA_VER"),
        "go": field("_SQ_GO_VER"),
        "rust": field("_SQ_RUST_VER"),
        "uv": field("_SQ_UV_VER"),
    },
    "defaults": {
        "finder_show_all_files": field("_SQ_DEFAULTS_SHOW_FILES"),
        "show_all_extensions": field("_SQ_DEFAULTS_SHOW_EXT"),
        "dock_autohide": field("_SQ_DEFAULTS_DOCK"),
        "key_repeat": field("_SQ_DEFAULTS_KEY_REPEAT"),
    },
}

out = os.environ.get("_SQ_PROFILE_FILE", "/dev/stdout")
with open(out, "w", encoding="utf-8") as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF

    ok "profile.json written: $_PROFILE_FILE"
fi

# =============================================================================
# OUTPUT: repos.md and repos.txt
# =============================================================================
step "Writing repos.md / repos.txt"

_REPOS_MD=$(printf '%s' "# Repo overview — migration export — $_TODAY

> Created by status-quo.sh on the old machine.
> Repos without a remote or with open state must be **backed up/pushed before migration**,
> because the new machine only clones — local-only data would otherwise be lost.

## Stats

- Total: **$_REPO_COUNT** repos
- With open state: **$_UNSAFE_COUNT** (uncommitted or unpushed)
- Without remote: **$_NO_REMOTE_COUNT** (cannot be cloned — back up manually!)

")

if [ "$_UNSAFE_COUNT" -gt 0 ]; then
    _REPOS_MD="${_REPOS_MD}## ⚠ Back up before migration — uncommitted or unpushed state

| Repo | Branch | Status |
|------|--------|--------|
${_UNSAFE_REPOS}
"
fi

if [ "$_NO_REMOTE_COUNT" -gt 0 ]; then
    _REPOS_MD="${_REPOS_MD}## No remote — manual backup required

These repos cannot be brought to the new machine via \`git clone\`.
Options: (a) create a remote and push, (b) copy directory manually (rsync/AirDrop).

${_NO_REMOTE_REPOS}
"
fi

_REPOS_MD="${_REPOS_MD}## All repos (complete list)

| Repo | Remote | Branch | Uncommitted | Unpushed |
|------|--------|--------|:---:|:---:|
${_REPOS_MD_LINES}"

_write_file "$OUT_DIR/repos.md" "$_REPOS_MD"
_write_file "$OUT_DIR/repos.txt" "# REPO|REMOTE|BRANCH|UNCOMMITTED|UNPUSHED
${_REPOS_TXT_LINES}"

# =============================================================================
# OUTPUT: STATUS-QUO.md (human-readable report)
# =============================================================================
step "Writing STATUS-QUO.md"

_STATUS_QUO=$(printf '%s' "# Current state — old machine — $_TODAY

> Created by status-quo.sh. Machine-specific data, gitignored.

## Hardware & operating system

- **macOS:** $_MACOS_VER (build $_MACOS_BUILD)
- **Architecture:** $_ARCH
- **RAM:** ${_RAM_GB} GB
- **SSD:** ${_DISK_GB} GB total, ${_FREE_GB} GB free
- **Xcode:** $_XCODE_VER
- **Command Line Tools:** $_CLT_PATH

## Toolchain versions

| Tool | Version |
|------|---------|
| Node.js | ${_NODE_VER:-—} |
| npm | ${_NPM_VER:-—} |
| pnpm | ${_PNPM_VER:-—} |
| bun | ${_BUN_VER:-—} |
| deno | ${_DENO_VER:-—} |
| Python | ${_PYTHON_VER:-—} |
| uv | ${_UV_VER:-—} |
| pipx | ${_PIPX_VER:-—} |
| Java | ${_JAVA_VER:-—} |
| Go | ${_GO_VER:-—} |
| Rust | ${_RUST_VER:-—} |
| Ollama | ${_OLLAMA_VER:-—} |
| Homebrew | ${_BREW_VER:-—} |
| Docker | ${_DOCKER_VER:-—} |

## Homebrew

- **Formulae (top-level):** $(printf "%s" "$_BREW_FORMULAE" | grep -c . || echo "0")
- **Casks:** $(printf "%s" "$_BREW_CASKS" | grep -c . || echo "0")
- **Taps:** $(printf "%s" "$_BREW_TAPS" | grep -c . || echo "0")

### Active brew services
\`\`\`
$(printf "%s" "$_BREW_SERVICES" | tr '|' ' ')
\`\`\`

## VS Code

- **Extensions:** $(printf "%s" "$_VSCODE_EXTENSIONS" | grep -c . || echo "0") installed

## Ollama models

$(if [ -n "$_OLLAMA_MODELS" ]; then
    printf "%s" "$_OLLAMA_MODELS" | while IFS= read -r m; do printf -- "- %s\n" "$m"; done
else
    echo "No models loaded or Ollama not reachable."
fi)

## Docker

### Running containers
\`\`\`
$(printf "%s" "$_DOCKER_RUNNING_CONTAINERS" | tr '|' '  ')
\`\`\`

### Images
\`\`\`
$(printf "%s" "$_DOCKER_IMAGES" | tr '|' '  ')
\`\`\`

## Git repos

- **Total:** $_REPO_COUNT repos under ~/dev
- **With open state:** $_UNSAFE_COUNT
- **Without remote:** $_NO_REMOTE_COUNT

Full list: repos.md

## SSH keys (names only, no key material)

$(if [ -n "$_SSH_KEYS" ]; then
    printf "%s" "$_SSH_KEYS" | while IFS='|' read -r name type; do
        printf -- "- \`%s\` (%s)\n" "$name" "$type"
    done
else
    echo "No SSH keys found under ~/.ssh/id_*."
fi)

For migrating secrets: \`docs/08-SECRETS.md\` (Vaultwarden path).

## LaunchAgents (~\/Library\/LaunchAgents)

$(if [ -n "$_LAUNCH_AGENTS" ]; then
    printf "%s" "$_LAUNCH_AGENTS" | while IFS= read -r la; do printf -- "- %s\n" "$la"; done
else
    echo "No LaunchAgents found."
fi)

## macOS settings

| Setting | Value |
|---------|-------|
| Finder: show all files | $_SHOW_ALL_FILES |
| Show all extensions | $_SHOW_EXTENSIONS |
| Dock: auto-hide | $_DOCK_AUTOHIDE |
| KeyRepeat | ${_KEY_REPEAT} |
| InitialKeyRepeat | ${_INIT_KEY_REPEAT} |

---
*Generated: $(date '+%Y-%m-%d %H:%M:%S')*
")

_write_file "$OUT_DIR/STATUS-QUO.md" "$_STATUS_QUO"

# =============================================================================
# OUTPUT: manual.md (to-do list for the migration)
# =============================================================================
step "Writing manual.md"

_MANUELL=$(printf '%s' "# Manual migration steps — $_TODAY

> What the script cannot automate. Check off before migrating.

## Before migration — on the OLD machine

### Git repos with open state

$(if [ "$_UNSAFE_COUNT" -gt 0 ]; then
    printf "**%d repo(s)** have uncommitted or unpushed changes — please review:\n\n" "$_UNSAFE_COUNT"
    # Table rows start with '|' → first field empty (_ld captures it)
    printf "%s" "$_REPOS_MD_LINES" | while IFS='|' read -r _ld name _remote branch dirty ahead _; do
        dirty=$(printf "%s" "$dirty" | tr -d ' ')
        ahead=$(printf "%s" "$ahead" | tr -d ' ')
        if [ "${dirty:-0}" -gt 0 ] 2>/dev/null || [ "${ahead:-0}" -gt 0 ] 2>/dev/null; then
            printf -- "- **%s** (branch: %s) — %s uncommitted, %s unpushed\n" \
                "$(printf "%s" "$name" | tr -d ' ')" \
                "$(printf "%s" "$branch" | tr -d ' \`')" \
                "${dirty:-0}" "${ahead:-0}"
        fi
    done
else
    echo "All repos are clean."
fi)

### Repos without remote

$(if [ "$_NO_REMOTE_COUNT" -gt 0 ]; then
    printf "**%d repo(s)** have no remote — they cannot be cloned:\n\n" "$_NO_REMOTE_COUNT"
    printf "%s" "$_NO_REMOTE_REPOS"
else
    echo "All repos have a remote."
fi)

### Secure secrets (CRITICAL)

Store all secrets in Vaultwarden before migrating — docs/08-SECRETS.md.

- [ ] SSH private keys to Vaultwarden (or generate fresh ones on the new machine)
- [ ] .env files (${_ENV_FILES} in ~/dev) — verify completeness
- [ ] API keys (Anthropic, OpenAI, etc.) — from environment variables/Keychain
- [ ] Database passwords from Docker Compose files
- [ ] 1Password / Enpass: export data and transfer to new machine

### Backup

- [ ] Run Time Machine or a full backup
- [ ] Docker volumes: shut down all running stacks cleanly (docker compose down)
- [ ] Ollama models: will be **re-pulled** on the new machine (not copied) — saves transfer time

## On the NEW machine

### Not automatically migrated

These items require manual work on the new machine:

- [ ] **App Store apps:** must be reinstalled manually (purchases are preserved)
- [ ] **JetBrains Toolbox:** install manually + enter licenses
- [ ] **Docker Desktop:** via bootstrap.sh (level 2) — restart containers afterwards
- [ ] **Re-pull Ollama models:**
$(if [ -n "$_OLLAMA_MODELS" ]; then
    printf "%s" "$_OLLAMA_MODELS" | while IFS= read -r m; do
        printf "  - \`ollama pull %s\`\n" "$m"
    done
else
    echo "  - No models captured"
fi)
- [ ] **VS Code settings:** enable sync via GitHub or run \`code --install-extension\` per extension
- [ ] **SSH keys:** either generate fresh ones (recommended) or restore from Vaultwarden
- [ ] **Git repos:** via \`repos.md\` — clone all remotes:
  \`\`\`bash
  # Example for all repos with a remote
  while IFS='|' read -r name remote branch _ _; do
    [ -z \"\$remote\" ] && continue
    git clone \"\$remote\" ~/dev/\"\$name\"
  done < local/status-quo/$_TODAY/repos.txt
  \`\`\`

### Final check

- [ ] Run \`./doctor.sh\`
- [ ] Run \`./automation/bin/migration-diff --markdown\`

---
*Generated: $(date '+%Y-%m-%d %H:%M:%S')*
")

_write_file "$OUT_DIR/manual.md" "$_MANUELL"

# =============================================================================
# Done
# =============================================================================
printf "\n" >&2
step "Done"

if [ "$DRY_RUN" = "1" ]; then
    ok "[dry-run] No files written — all actions were only shown"
else
    ok "Export complete: $OUT_DIR"
    printf "\n%sNext steps:%s\n" "$_BOLD" "$_RESET" >&2
    printf "  1. Open %s/manual.md and work through the list\n" "$OUT_DIR" >&2
    printf "  2. Transfer the profile to the new machine (do not share publicly!)\n" >&2
    printf "  3. On the new machine: ./prepare.sh --profile %s/profile.json\n" "$OUT_DIR" >&2
    printf "  4. Afterwards: ./automation/bin/migration-diff\n\n" >&2

    if [ "$_UNSAFE_COUNT" -gt 0 ]; then
        warn "$_UNSAFE_COUNT repo(s) have uncommitted or unpushed state — please push first!"
    fi
    if [ "$_NO_REMOTE_COUNT" -gt 0 ]; then
        warn "$_NO_REMOTE_COUNT repo(s) without remote — back up manually before migrating!"
    fi
fi
