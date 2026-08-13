#!/usr/bin/env bash
# =============================================================================
# scripts/lib.sh — Shared helper functions for all setup scripts
#
# Purpose:  Logging, idempotency helpers, backup, confirmation, dry-run wrapper
# Changes:  Nothing directly — sourced by other scripts
# Requires: bash 3.2+ (macOS-compatible, no associative arrays)
# Usage:    source "$(dirname "$0")/lib.sh"  or  source ./scripts/lib.sh
# =============================================================================

# Prevent double-loading
[ "${_KICKOFF_LIB_LOADED:-}" = "1" ] && return 0
_KICKOFF_LIB_LOADED=1

# =============================================================================
# Global flags (set by bootstrap.sh, defaults here)
# =============================================================================
DRY_RUN="${DRY_RUN:-0}"
YES_MODE="${YES_MODE:-0}"
VERBOSE="${VERBOSE:-0}"

# =============================================================================
# Colors (only when the terminal supports them)
# =============================================================================
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    _RED=$(tput setaf 1)
    _GREEN=$(tput setaf 2)
    _YELLOW=$(tput setaf 3)
    _BLUE=$(tput setaf 4)
    _CYAN=$(tput setaf 6)
    _BOLD=$(tput bold)
    _RESET=$(tput sgr0)
else
    _RED=""
    _GREEN=""
    _YELLOW=""
    _BLUE=""
    _CYAN=""
    _BOLD=""
    _RESET=""
fi

# =============================================================================
# Logging functions
# =============================================================================

# General log output with timestamp
log() {
    printf "%s %s\n" "$(date '+%H:%M:%S')" "$*" >&2
}

# Info message (blue)
info() {
    printf "%s%s  %s%s\n" "$_BLUE" "ℹ" "$*" "$_RESET" >&2
}

# Success (green)
ok() {
    printf "%s%s  %s%s\n" "$_GREEN" "✓" "$*" "$_RESET" >&2
}

# Warning (yellow)
warn() {
    printf "%s%s  %s%s\n" "$_YELLOW" "⚠" "$*" "$_RESET" >&2
}

# Error (red, then exit)
err() {
    printf "%s%s  %s%s\n" "$_RED" "✗" "$*" "$_RESET" >&2
    exit 1
}

# Step header (bold + separator)
step() {
    printf "\n%s%s==> %s%s\n" "$_BOLD" "$_CYAN" "$*" "$_RESET" >&2
}

# =============================================================================
# Check functions
# =============================================================================

# Check whether a command is available in PATH
have() {
    command -v "$1" >/dev/null 2>&1
}

# Check whether a Homebrew formula is installed
is_installed_brew() {
    brew list --formula 2>/dev/null | grep -qx "$1"
}

# Check whether a Homebrew cask is installed
is_installed_cask() {
    brew list --cask 2>/dev/null | grep -qx "$1"
}

# =============================================================================
# User confirmation
# =============================================================================

# Ask the user for confirmation (respects --yes / YES_MODE)
# Returns: 0 = yes, 1 = no
confirm() {
    local prompt="${1:-Continue?}"
    if [ "$YES_MODE" = "1" ]; then
        info "$prompt [auto: yes]"
        return 0
    fi
    # A dry run must never ask. It is a preview: the question is about something
    # that will not happen, and answering it changes nothing. Asking anyway makes
    # --dry-run unusable anywhere without a terminal — the Control Room's preview
    # button and any agent driving this repo both pipe stdout and have no tty, so
    # the prompt used to abort the whole run instead of previewing it.
    if [ "$DRY_RUN" = "1" ]; then
        info "$prompt [dry-run: showing what a yes would do]"
        return 0
    fi
    printf "%s%s  %s [y/N] %s" "$_YELLOW" "?" "$prompt" "$_RESET" >&2
    local answer
    # No terminal is a "no", not a crash. Same guard prepare.sh already uses.
    if ! read -r answer </dev/tty 2>/dev/null; then
        printf '\n' >&2
        warn "No terminal available to ask — assuming no. Use --yes to answer in advance."
        return 1
    fi
    case "$answer" in
        [jJyY]|[jJ][aA]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# =============================================================================
# Backup function
# =============================================================================

# Back up a file to ~/.setup-backups/<timestamp>/
# Usage: backup_file "$HOME/.zshrc"
backup_file() {
    local src="$1"
    [ -e "$src" ] || return 0  # Nothing to do if file does not exist

    local backup_base="$HOME/.setup-backups"
    local timestamp
    timestamp=$(date '+%Y%m%d-%H%M%S')
    local backup_dir="$backup_base/$timestamp"

    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would back up: $src → $backup_dir/"
        return 0
    fi

    mkdir -p "$backup_dir"
    cp -a "$src" "$backup_dir/"
    ok "Backed up: $src → $backup_dir/$(basename "$src")"
}

# =============================================================================
# append_once — Insert a line/block into a file exactly once
# =============================================================================

# Appends <content> to <file> only if <marker> is not already present.
# Usage: append_once "$HOME/.zshrc" "# MARKER_NVM" "$(cat /tmp/block.txt)"
append_once() {
    local datei="$1"
    local marker="$2"
    local inhalt="$3"

    if grep -qF "$marker" "$datei" 2>/dev/null; then
        return 0  # Already present
    fi

    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would append to $datei (marker: $marker)"
        return 0
    fi

    printf '\n%s\n' "$inhalt" >> "$datei"
    ok "Added to $datei: $marker"
}

# =============================================================================
# run — Execute a command (respects --dry-run)
# =============================================================================

# Executes a command or only prints it (when --dry-run is active).
# Usage: run brew install git
run() {
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] $*"
        return 0
    fi
    "$@"
}

# Create a directory, honouring dry-run.
#
# Several modules called `mkdir -p` and `chmod` directly, outside the run
# abstraction. SECURITY.md tells readers that --dry-run executes nothing, and
# the audit path this repo recommends before a real install is exactly that —
# so a dry run that creates directories and adjusts permissions breaks the one
# promise the safety advice depends on.
run_mkdir() {
    run mkdir -p "$@"
}

run_chmod() {
    run chmod "$@"
}

# =============================================================================
# Strict option parsing for the modules
#
# Every module accepted its two known flags and silently ignored everything
# else, so `./scripts/04-node.sh --help` installed Node instead of printing
# help, and a typo in a copy-pasted command was accepted as a normal run. Both
# matter more here than usual: these commands are published for people to paste
# into a terminal on a machine they are still setting up.
#
# Contract: --help exits 0 BEFORE anything happens, an unknown option exits 2.
# =============================================================================
# Usage: parse_module_args "${BASH_SOURCE[0]}" "$@"
parse_module_args() {
    local script="$1"
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run)
                DRY_RUN=1
                export DRY_RUN
                ;;
            --yes)
                YES_MODE=1
                export YES_MODE
                ;;
            --full)
                FULL_MODE=1
                export FULL_MODE
                ;;
            -h | --help)
                # The file header is the help text, so the two cannot drift.
                sed -n '/^# ===/,/^# ===$/p' "$script" | sed 's/^# \{0,1\}//'
                exit 0
                ;;
            *)
                printf 'unknown option: %s\n' "$1" >&2
                printf 'try: %s --help\n' "$script" >&2
                exit 2
                ;;
        esac
        shift
    done
}

# =============================================================================
# sudo keep-alive
# =============================================================================

# Obtains a sudo token once and refreshes it every 55 seconds
# Usage: call sudo_keepalive; clean up with sudo_keepalive_stop
sudo_keepalive() {
    sudo -v
    # Background process to keep the token alive (every 55 seconds)
    (
        while true; do
            sleep 55
            sudo -n true 2>/dev/null || break
        done
    ) &
    _SUDO_KEEPALIVE_PID=$!
}

sudo_keepalive_stop() {
    if [ -n "${_SUDO_KEEPALIVE_PID:-}" ]; then
        kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null || true
        _SUDO_KEEPALIVE_PID=""
    fi
}

# =============================================================================
# Module filter (for --only / --skip in bootstrap.sh)
# =============================================================================

# Determines whether a module should run.
# Global vars: ONLY_MODULES (comma-separated), SKIP_MODULES (comma-separated)
# Returns: 0 = run, 1 = skip
should_run_module() {
    local modul="$1"

    # --only takes priority
    if [ -n "${ONLY_MODULES:-}" ]; then
        case ",$ONLY_MODULES," in
            *",$modul,"*) return 0 ;;
            *) return 1 ;;
        esac
    fi

    # --skip
    if [ -n "${SKIP_MODULES:-}" ]; then
        case ",$SKIP_MODULES," in
            *",$modul,"*) return 1 ;;
        esac
    fi

    return 0
}

# =============================================================================
# Architecture helpers
# =============================================================================

is_arm64() {
    [ "$(uname -m)" = "arm64" ]
}

is_macos() {
    [ "$(uname -s)" = "Darwin" ]
}

# macOS version as integer (e.g. 15 for macOS 15)
macos_major_version() {
    sw_vers -productVersion | cut -d. -f1
}

# =============================================================================
# Summary tracking
# =============================================================================

# Global arrays (bash 3.2: plain arrays)
_SUMMARY_DONE=()
_SUMMARY_SKIP=()
_SUMMARY_WARN=()
_SUMMARY_MANUAL=()

summary_done() {
    _SUMMARY_DONE[${#_SUMMARY_DONE[@]}]="$1"
}

summary_skip() {
    _SUMMARY_SKIP[${#_SUMMARY_SKIP[@]}]="$1"
}

summary_warn() {
    _SUMMARY_WARN[${#_SUMMARY_WARN[@]}]="$1"
}

summary_manual() {
    _SUMMARY_MANUAL[${#_SUMMARY_MANUAL[@]}]="$1"
}

print_summary() {
    printf "\n%s%s========================================%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
    printf "%s%s  SUMMARY%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
    printf "%s%s========================================%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2

    if [ ${#_SUMMARY_DONE[@]} -gt 0 ]; then
        printf "\n%sDone:%s\n" "$_GREEN" "$_RESET" >&2
        local item
        for item in "${_SUMMARY_DONE[@]}"; do
            printf "  %s✓  %s%s\n" "$_GREEN" "$item" "$_RESET" >&2
        done
    fi

    if [ ${#_SUMMARY_SKIP[@]} -gt 0 ]; then
        printf "\n%sSkipped (already present):%s\n" "$_BLUE" "$_RESET" >&2
        local item
        for item in "${_SUMMARY_SKIP[@]}"; do
            printf "  %sℹ  %s%s\n" "$_BLUE" "$item" "$_RESET" >&2
        done
    fi

    if [ ${#_SUMMARY_WARN[@]} -gt 0 ]; then
        printf "\n%sWarnings:%s\n" "$_YELLOW" "$_RESET" >&2
        local item
        for item in "${_SUMMARY_WARN[@]}"; do
            printf "  %s⚠  %s%s\n" "$_YELLOW" "$item" "$_RESET" >&2
        done
    fi

    if [ ${#_SUMMARY_MANUAL[@]} -gt 0 ]; then
        printf "\n%sManual steps required:%s\n" "$_YELLOW" "$_RESET" >&2
        local item
        for item in "${_SUMMARY_MANUAL[@]}"; do
            printf "  %s→  %s%s\n" "$_YELLOW" "$item" "$_RESET" >&2
        done
    fi

    printf "\n" >&2
}
