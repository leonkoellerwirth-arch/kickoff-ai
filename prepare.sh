#!/bin/bash
# =============================================================================
# prepare.sh — Preparation on a brand-new macOS machine
#
# Purpose:  Checks the machine for setup readiness (phase 1: CHECK),
#           installs Xcode Command Line Tools, clones the kickoff-ai repo
#           (phase 2: PREPARE), and hands off to bootstrap.sh (phase 3).
#           Fully standalone — runs WITHOUT Homebrew, git or the repo.
#           Only macOS built-ins: bash 3.2, curl, sw_vers, sysctl, df,
#           softwareupdate, xcode-select, defaults, pmset, fdesetup.
#
# Requires: macOS 15+, internet connection, admin rights (sudo)
#
# One-liner for a brand-new machine (no repo needed):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/kickoff-ai/main/prepare.sh)"
#
# Usage after cloning:
#   ./prepare.sh [options]
#
# Flags:
#   --check-only      Phase 1 (check) — GUARANTEED to change nothing
#   --dir <path>      Target directory for dev repos (default: ~/dev)
#   --repo <url>      Repo URL (default: https://github.com/leonkoellerwirth-arch/kickoff-ai)
#                     Alternative: environment variable KICKOFF_REPO
#   --level <0|1|2|3> bootstrap.sh level (default: 0)
#   --profile <file>  Profile JSON from old machine (optional)
#   --no-bootstrap    Prepare only, do not start bootstrap.sh
#   --yes             No interactive prompts (automatic yes)
#   --dry-run         Show actions, change nothing
#   --help            This help
#
# Note on interactivity:
#   With 'curl | bash' stdin is the script stream, NOT a TTY. All
#   interactive reads therefore go through /dev/tty so that both
#   invocation styles (direct call AND curl-pipe) work correctly.
# =============================================================================
set -euo pipefail

# =============================================================================
# Colors (only when stderr is a terminal)
# =============================================================================
if [ -t 2 ] && command -v tput >/dev/null 2>&1; then
    _G=$(tput setaf 2 2>/dev/null || printf '')   # Green
    _Y=$(tput setaf 3 2>/dev/null || printf '')   # Yellow
    _R=$(tput setaf 1 2>/dev/null || printf '')   # Red
    _C=$(tput setaf 6 2>/dev/null || printf '')   # Cyan
    _B=$(tput bold   2>/dev/null || printf '')    # Bold
    _X=$(tput sgr0   2>/dev/null || printf '')    # Reset
else
    _G="" _Y="" _R="" _C="" _B="" _X=""
fi

# =============================================================================
# Logging helpers (standalone — no lib.sh on a bare machine)
# =============================================================================
_ok()   { printf "%s[OK  ]%s  %s\n" "$_G" "$_X" "$*" >&2; }
_warn() { printf "%s[WARN]%s  %s\n" "$_Y" "$_X" "$*" >&2; }
_err()  { printf "%s[FAIL]%s  %s\n" "$_R" "$_X" "$*" >&2; exit 1; }
_info() { printf "%s[INFO]%s  %s\n" "$_C" "$_X" "$*" >&2; }
_step() { printf "\n%s%s==> %s%s\n" "$_B" "$_C" "$*" "$_X" >&2; }

_confirm() {
    local prompt="${1:-Continue?}"
    [ "$YES_MODE" = "1" ] && { _info "$prompt [auto: yes]"; return 0; }
    printf "%s?%s  %s [y/N] " "$_Y" "$_X" "$prompt" >&2
    local answer
    read -r answer </dev/tty 2>/dev/null || answer="n"
    case "$answer" in
        [jJyY]|[jJ][aA]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

_run() {
    [ "$DRY_RUN" = "1" ] && { _info "[dry-run] $*"; return 0; }
    "$@"
}

# =============================================================================
# Defaults
# =============================================================================
_DEFAULT_REPO="https://github.com/leonkoellerwirth-arch/kickoff-ai"

CHECK_ONLY=0
SETUP_DIR="${HOME}/dev"
REPO="${KICKOFF_REPO:-$_DEFAULT_REPO}"
LEVEL=0
PROFILE_FILE=""
NO_BOOTSTRAP=0
YES_MODE=0
DRY_RUN=0

# =============================================================================
# Argument parsing
# =============================================================================
while [ $# -gt 0 ]; do
    case "$1" in
        --check-only)   CHECK_ONLY=1 ;;
        --dir)          shift; SETUP_DIR="${1:-$HOME/dev}" ;;
        --repo)         shift; REPO="${1:-$_DEFAULT_REPO}" ;;
        --level)        shift; LEVEL="${1:-0}" ;;
        --profile)      shift; PROFILE_FILE="${1:-}" ;;
        --no-bootstrap) NO_BOOTSTRAP=1 ;;
        --yes|-y)       YES_MODE=1 ;;
        --dry-run)      DRY_RUN=1 ;;
        --help|-h)
            cat >&2 <<'HELP'
Usage: prepare.sh [options]

  Phase 1 (--check-only): Checks the machine. Changes NOTHING.
  Phase 2: Installs CLT, creates directory, clones repo.
  Phase 3: Starts bootstrap.sh.

Options:
  --check-only      Phase 1 only — GUARANTEED to change nothing
  --dir <path>      Target directory for repos (default: ~/dev)
  --repo <url>      Repo URL (default: https://github.com/leonkoellerwirth-arch/kickoff-ai)
                    Alternative: environment variable KICKOFF_REPO
  --level <0|1|2|3> bootstrap.sh level (default: 0)
  --profile <file>  Read profile.json from old machine
  --no-bootstrap    Clone only, do NOT start bootstrap.sh
  --yes             No prompts (automatic yes)
  --dry-run         Show actions, change NOTHING
  --help            This help

One-liner for a brand-new machine:
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/kickoff-ai/main/prepare.sh)"

Check only (changes NOTHING):
  /bin/bash -c "$(curl -fsSL .../prepare.sh)" -- --check-only
HELP
            exit 0
            ;;
        --) shift; break ;;
        *) printf "Unknown option: %s  (--help for help)\n" "$1" >&2; exit 1 ;;
    esac
    shift
done

# Validate level
case "$LEVEL" in
    0|1|2|3) ;;
    *) printf "Invalid level: '%s' (allowed: 0-3)\n" "$LEVEL" >&2; exit 1 ;;
esac

# =============================================================================
# PHASE 1 — CHECK
# Read-only. Counts OK/WARN/BLOCK and prints a verdict at the end.
# =============================================================================

_BLOCK_COUNT=0
_WARN_COUNT=0
_OK_COUNT=0

_row_ok() {
    printf "  %s[OK  ]%s  %-30s  %s\n" "$_G" "$_X" "$1" "$2" >&2
    _OK_COUNT=$((_OK_COUNT + 1))
}
_row_warn() {
    printf "  %s[WARN]%s  %-30s  %s\n" "$_Y" "$_X" "$1" "$2" >&2
    _WARN_COUNT=$((_WARN_COUNT + 1))
}
_row_block() {
    printf "  %s[BLCK]%s  %-30s  %s\n" "$_R" "$_X" "$1" "$2" >&2
    _BLOCK_COUNT=$((_BLOCK_COUNT + 1))
}

printf "\n%s%s" "$_B" "$_C" >&2
printf "╔════════════════════════════════════════════════╗\n" >&2
printf "║  prepare.sh — macOS readiness check           ║\n" >&2
printf "║  %-46s ║\n" "$(date '+%Y-%m-%d %H:%M:%S')" >&2
printf "╚════════════════════════════════════════════════╝\n\n%s" "$_X" >&2

_step "Phase 1 — System check"
printf "\n" >&2

# --- 1. Operating system ---
if [ "$(uname -s)" != "Darwin" ]; then
    _row_block "Operating system" "$(uname -s) — only macOS is supported"
else
    _MACOS_VER=$(sw_vers -productVersion 2>/dev/null || echo "?")
    _MACOS_MAJOR=$(printf "%s" "$_MACOS_VER" | cut -d. -f1)
    if [ "$_MACOS_MAJOR" -ge 15 ] 2>/dev/null; then
        _row_ok "macOS version" "$_MACOS_VER"
    elif [ "$_MACOS_MAJOR" -ge 13 ] 2>/dev/null; then
        _row_warn "macOS version" "$_MACOS_VER — recommended: macOS 15+ (Sequoia)"
    else
        _row_block "macOS version" "$_MACOS_VER — minimum: macOS 15 (Sequoia)"
    fi
fi

# --- 2. Architecture ---
_ARCH=$(uname -m)
if [ "$_ARCH" = "arm64" ]; then
    _row_ok "Architecture" "Apple Silicon (arm64)"
else
    _row_warn "Architecture" "$_ARCH — setup optimized for Apple Silicon (M chips); Intel support limited"
fi

# --- 3. RAM ---
_RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
_RAM_GB=$((_RAM_BYTES / 1024 / 1024 / 1024))
if [ "$_RAM_GB" -ge 16 ]; then
    _row_ok "RAM" "${_RAM_GB} GB"
elif [ "$_RAM_GB" -ge 8 ]; then
    _row_warn "RAM" "${_RAM_GB} GB — 16+ GB recommended (Docker + Ollama + IDEs)"
else
    _row_warn "RAM" "${_RAM_GB} GB — very low for the full stack"
fi

# --- 4. Free disk space ---
_FREE_KB=$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
_FREE_GB=$((_FREE_KB / 1024 / 1024))
if [ "$_FREE_GB" -ge 60 ]; then
    _row_ok "Free disk space" "${_FREE_GB} GB"
elif [ "$_FREE_GB" -ge 20 ]; then
    _row_warn "Free disk space" "${_FREE_GB} GB — recommended: 60+ GB (Xcode ~7 GB, Docker, Ollama)"
elif [ "$_FREE_GB" -ge 10 ]; then
    _row_warn "Free disk space" "${_FREE_GB} GB — tight; bootstrap level 0 needs ~10 GB"
else
    _row_block "Free disk space" "${_FREE_GB} GB — too low (minimum: ~10 GB)"
fi

# --- 5. Network connection (real reachability test — not just interface check) ---
_NET_OK=0
if curl -sf --max-time 10 --head https://raw.githubusercontent.com >/dev/null 2>&1; then
    _NET_OK=1
elif curl -sf --max-time 10 --head https://captive.apple.com >/dev/null 2>&1; then
    _NET_OK=1
fi

if [ "$_NET_OK" = "1" ]; then
    _row_ok "Network connection" "Internet reachable (GitHub/Apple)"
else
    _row_block "Network connection" "No internet connection — setup not possible"
fi

# --- 6. Admin / sudo rights ---
if sudo -n true 2>/dev/null; then
    _row_ok "Admin rights" "sudo cached"
elif groups 2>/dev/null | grep -qE '\badmin\b|\bwheel\b'; then
    _row_ok "Admin rights" "Group 'admin' — password will be requested during CLT installation"
else
    _row_block "Admin rights" "No admin access — sudo required for CLT installation"
fi

# --- 7. Power supply ---
_POWER=$(pmset -g batt 2>/dev/null | head -1 || echo "")
if printf "%s" "$_POWER" | grep -q "'AC Power'"; then
    _row_ok "Power supply" "Power adapter connected"
elif printf "%s" "$_POWER" | grep -q "'Battery Power'"; then
    _BATT_PCT=$(pmset -g batt 2>/dev/null | grep -Eo '[0-9]+%' | head -1 || echo "?")
    _row_warn "Power supply" "Battery ($_BATT_PCT) — connect power adapter! Xcode download and model pulls take hours"
else
    _row_warn "Power supply" "Status unknown — power adapter recommended"
fi

# --- 8. FileVault ---
_FV="unknown"
if command -v fdesetup >/dev/null 2>&1; then
    _FV=$(fdesetup status 2>/dev/null | head -1 || echo "unknown")
fi
if printf "%s" "$_FV" | grep -qi " On$\|ist aktiv\|FileVault is On"; then
    _row_ok "FileVault" "Active — data encrypted"
elif printf "%s" "$_FV" | grep -qi " Off$\|nicht aktiv\|FileVault is Off"; then
    _row_warn "FileVault" "NOT active — enable after setup (System Settings → Privacy & Security)"
else
    _row_warn "FileVault" "Status: $_FV"
fi

# --- 9. Command Line Tools / Xcode ---
if xcode-select -p >/dev/null 2>&1; then
    _CLT_PATH=$(xcode-select -p)
    if [ -d "/Applications/Xcode.app" ]; then
        _XCODE_VER=$(defaults read /Applications/Xcode.app/Contents/Info.plist \
            CFBundleShortVersionString 2>/dev/null || echo "?")
        _row_ok "Xcode.app" "Version $_XCODE_VER  (path: $_CLT_PATH)"
    else
        _row_ok "Command Line Tools" "$_CLT_PATH"
    fi
else
    _row_warn "Command Line Tools" "Not yet installed — will be set up in phase 2"
fi

# --- 10. Homebrew ---
_HAS_HOMEBREW=0
if command -v brew >/dev/null 2>&1; then
    _BREW_VER=$(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo "?")
    _row_warn "Homebrew" "Already present (v$_BREW_VER) — not a fresh machine; repo will still be cloned"
    _HAS_HOMEBREW=1
else
    _row_ok "Homebrew" "Not yet installed — will be set up by bootstrap.sh"
fi

# --- 11. Timezone / Locale ---
_TZ=""
if [ -L /etc/localtime ]; then
    _TZ=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||' || echo "")
fi
if [ -z "$_TZ" ]; then
    _TZ=$(systemsetup -gettimezone 2>/dev/null | awk '{print $NF}' || echo "?")
fi
_LANG="${LANG:-not set}"
if [ -n "$_TZ" ] && [ "$_TZ" != "?" ]; then
    _row_ok "Timezone / Locale" "TZ=$_TZ | LANG=$_LANG"
else
    _row_warn "Timezone / Locale" "TZ unknown | LANG=$_LANG — adjust after setup if needed"
fi

# --- 12. Apple ID (best effort — shows only signed in/out, never the email) ---
_AID_PLIST="$HOME/Library/Preferences/MobileMeAccounts.plist"
if [ -f "$_AID_PLIST" ]; then
    _AID=$(/usr/libexec/PlistBuddy -c "Print :Accounts:0:AccountID" \
        "$_AID_PLIST" 2>/dev/null || echo "")
    if [ -n "$_AID" ]; then
        _row_ok "Apple ID" "Signed in — App Store and iCloud available"
    else
        _row_warn "Apple ID" "Not signed in — App Store and iCloud not available"
    fi
else
    _row_warn "Apple ID" "Status cannot be determined (normal on a brand-new machine)"
fi

# =============================================================================
# Verdict
# =============================================================================
printf "\n" >&2
if [ "$_BLOCK_COUNT" -gt 0 ]; then
    printf "%s  NOT READY — %d blocker(s) must be resolved before setup.%s\n\n" \
        "$_R" "$_BLOCK_COUNT" "$_X" >&2
    [ "$CHECK_ONLY" = "1" ] && exit 1
    _confirm "Continue despite blockers? (not recommended)" || exit 1
elif [ "$_WARN_COUNT" -gt 0 ]; then
    printf "%s  READY WITH WARNINGS — %d warning(s). Can proceed.%s\n\n" \
        "$_Y" "$_WARN_COUNT" "$_X" >&2
else
    printf "%s  READY — all %d checks passed.%s\n\n" \
        "$_G" "$_OK_COUNT" "$_X" >&2
fi

if [ "$CHECK_ONLY" = "1" ]; then
    _info "Mode: --check-only — no changes made"
    exit 0
fi

# =============================================================================
# PHASE 2 — PREPARE
# =============================================================================
_step "Phase 2 — Preparation"

# --- Install CLT ---
# We use the softwareupdate method (no GUI dialog, fully in terminal) because
# it works better for automated setups and does not wait for mouse clicks.
# Prerequisite: a signal file under /tmp causes softwareupdate to list CLTs.
# Fallback: xcode-select --install (opens GUI dialog, asynchronous) with a
# wait loop. Both paths are idempotent (detect already-installed CLT).

if xcode-select -p >/dev/null 2>&1; then
    _ok "Command Line Tools already installed: $(xcode-select -p)"
elif [ "$DRY_RUN" = "1" ]; then
    _info "[dry-run] Would install Command Line Tools via softwareupdate"
else
    _info "Installing Command Line Tools (git prerequisite) ..."

    # Signal file: without it softwareupdate does not list CLTs
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

    _CLT_PKG=$(softwareupdate -l 2>/dev/null \
        | awk '/Label:.*Command Line Tools/{gsub(/.*Label: /,""); gsub(/[[:space:]]*$/,""); print}' \
        | sort | tail -1)

    if [ -n "$_CLT_PKG" ]; then
        _info "Package found: $_CLT_PKG"
        _info "Installation in progress (may take several minutes) ..."
        softwareupdate --install "$_CLT_PKG" --verbose 2>&1 \
            | grep -E '^(Downloading|Installing|Done|Fertig|Installed|Progress)' >&2 || true
        rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    else
        # Fallback: GUI dialog (xcode-select --install)
        rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
        _warn "softwareupdate package not found — opening GUI dialog"
        _info "Click 'Install' in the dialog that appears, then wait ..."
        xcode-select --install 2>/dev/null || true
        _i=0
        _max=180   # 180 × 10 s = 30 minutes
        while [ "$_i" -lt "$_max" ]; do
            if xcode-select -p >/dev/null 2>&1; then break; fi
            _i=$((_i + 1))
            printf "  Waiting for CLT installation ... [%d/%d]\r" "$_i" "$_max" >&2
            sleep 10
        done
        printf "\n" >&2
    fi

    if xcode-select -p >/dev/null 2>&1; then
        _ok "Command Line Tools installed: $(xcode-select -p)"
    else
        _err "CLT installation failed. Manual: xcode-select --install"
    fi
fi

# --- Create target directory ---
_info "Target directory: $SETUP_DIR"
if [ -d "$SETUP_DIR" ]; then
    _ok "Directory already exists: $SETUP_DIR"
else
    _run mkdir -p "$SETUP_DIR"
    _ok "Directory created: $SETUP_DIR"
fi

# --- Clone or update repo ---
_REPO_DIR="$SETUP_DIR/kickoff-ai"
_info "Repo: $REPO"

if [ -d "$_REPO_DIR/.git" ]; then
    _info "Repo already present — updating via git pull --ff-only ..."
    if [ "$DRY_RUN" = "1" ]; then
        _info "[dry-run] git -C \"$_REPO_DIR\" pull --ff-only"
    elif git -C "$_REPO_DIR" pull --ff-only 2>&1 | tail -3 >&2; then
        _ok "Repo updated: $_REPO_DIR"
    else
        _warn "git pull --ff-only failed — repo unchanged"
    fi
else
    _info "Cloning repo to $_REPO_DIR ..."
    _run git clone "$REPO" "$_REPO_DIR"
    _ok "Repo cloned: $_REPO_DIR"
fi

# --- Read profile from old machine (optional) ---
if [ -n "$PROFILE_FILE" ]; then
    if [ -f "$PROFILE_FILE" ]; then
        _PROFILE_DEST="$_REPO_DIR/local/status-quo"
        _info "Copying profile to $_PROFILE_DEST ..."
        _run mkdir -p "$_PROFILE_DEST"
        _run cp "$PROFILE_FILE" "$_PROFILE_DEST/profile.json"
        _ok "Profile saved: $_PROFILE_DEST/profile.json"
        _info "Check migration after setup: $_REPO_DIR/automation/bin/migration-diff"
    else
        _warn "Profile file not found: $PROFILE_FILE — skipped"
    fi
fi

# =============================================================================
# PHASE 3 — HAND-OFF
# =============================================================================
_step "Phase 3 — Hand-off to bootstrap.sh"

if [ "$NO_BOOTSTRAP" = "1" ]; then
    _ok "Preparation complete. bootstrap.sh was not started (--no-bootstrap)."
    printf "\n%sNext step — the guided way:%s\n" "$_B" "$_X" >&2
    printf "  cd %s\n" "$_REPO_DIR" >&2
    printf "  ./start.sh          opens the Control Room in your browser and walks\n" >&2
    printf "                      you through the rest. It changes nothing on its own.\n" >&2
    printf "\n%sOr straight from the command line:%s\n" "$_B" "$_X" >&2
    printf "  ./bootstrap.sh --level %s\n" "$LEVEL" >&2
    printf "  ./doctor.sh\n\n" >&2
    exit 0
fi

if [ "$DRY_RUN" = "1" ]; then
    _info "[dry-run] Would start: $_REPO_DIR/bootstrap.sh --level $LEVEL"
    exit 0
fi

if [ ! -f "$_REPO_DIR/bootstrap.sh" ]; then
    _warn "bootstrap.sh not found in $_REPO_DIR"
    printf "\nManual run:\n  cd %s\n  ./bootstrap.sh --level %s\n\n" \
        "$_REPO_DIR" "$LEVEL" >&2
    exit 1
fi

# Build bootstrap arguments
_BSARGS=("--level" "$LEVEL")
[ "$YES_MODE" = "1" ] && _BSARGS[${#_BSARGS[@]}]="--yes"

_info "Starting bootstrap.sh --level $LEVEL ..."
cd "$_REPO_DIR"
exec /bin/bash bootstrap.sh "${_BSARGS[@]}"
