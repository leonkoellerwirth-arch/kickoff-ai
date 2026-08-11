#!/usr/bin/env bash
# =============================================================================
# automation/lib-automation.sh — Supplementary helpers for the automation layer
#
# Purpose:  Sources scripts/lib.sh and adds automation-specific helpers:
#           notifications, size formatting, Docker checks, time calculations.
# Changes:  Nothing directly — sourced by the automation/bin/* commands.
# Requires: bash 3.2+, scripts/lib.sh reachable via <repo-root>/scripts/lib.sh.
# Usage:    AUTOMATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
#           source "$AUTOMATION_DIR/lib-automation.sh"
# =============================================================================

[ "${_KICKOFF_AUTOMATION_LIB_LOADED:-}" = "1" ] && return 0
_KICKOFF_AUTOMATION_LIB_LOADED=1

# Path to this file → repo root → source scripts/lib.sh
_LIB_AUTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "$_LIB_AUTO_DIR/.." && pwd)"
source "$_REPO_ROOT/scripts/lib.sh"

# Output directory for local reports (gitignored)
LOCAL_DIR="$_REPO_ROOT/local"
DEV_DIR="${DEV_DIR:-$HOME/dev}"

# =============================================================================
# Notifications
# =============================================================================

# Sends a desktop notification if terminal-notifier is available,
# otherwise logs only.
# Usage: notify "Title" "Message text"
notify() {
    local title="$1"
    local message="${2:-}"
    if have terminal-notifier; then
        terminal-notifier -title "kickoff: $title" -message "$message" -sound default >/dev/null 2>&1 || true
    fi
    log "[$title] $message"
}

# =============================================================================
# Size formatting
# =============================================================================

# Returns a human-readable file size (KB/MB/GB)
# Usage: human_size <bytes>
human_size() {
    local bytes="$1"
    if [ "$bytes" -ge 1073741824 ] 2>/dev/null; then
        printf "%d GB" "$((bytes / 1073741824))"
    elif [ "$bytes" -ge 1048576 ] 2>/dev/null; then
        printf "%d MB" "$((bytes / 1048576))"
    elif [ "$bytes" -ge 1024 ] 2>/dev/null; then
        printf "%d KB" "$((bytes / 1024))"
    else
        printf "%d B" "${bytes:-0}"
    fi
}

# Returns free disk space in GB
free_space_gb() {
    df -k "$HOME" | awk 'NR==2 {printf "%d", $4/1024/1024}'
}

# Returns directory size in megabytes (only if directory exists)
dir_size_mb() {
    local d="$1"
    [ -d "$d" ] || { echo "0"; return; }
    du -sm "$d" 2>/dev/null | awk '{print $1}' || echo "0"
}

# Returns directory size in bytes
dir_size_bytes() {
    local d="$1"
    [ -d "$d" ] || { echo "0"; return; }
    du -sk "$d" 2>/dev/null | awk '{print $1 * 1024}' || echo "0"
}

# =============================================================================
# Docker helpers
# =============================================================================

# Checks whether the Docker daemon is running
docker_running() {
    docker info >/dev/null 2>&1
}

# Exits cleanly when Docker is not available
require_docker() {
    if ! have docker; then
        err "Docker not found. Install Docker Desktop: brew install --cask docker"
    fi
    if ! docker_running; then
        err "Docker not running. Start Docker Desktop: open -a Docker"
    fi
}

# =============================================================================
# Time calculations
# =============================================================================

# Parses a duration like "4h", "30m", "120s" into seconds
parse_duration() {
    local dur="$1"
    local num unit
    num=$(printf '%s' "$dur" | tr -dc '0-9')
    unit=$(printf '%s' "$dur" | tr -dc 'a-zA-Z')
    case "$unit" in
        h|H) printf '%d' "$((num * 3600))" ;;
        m|M) printf '%d' "$((num * 60))" ;;
        s|S) printf '%d' "$num" ;;
        *)   printf '%d' "$((num * 3600))" ;;
    esac
}

# Returns a readable duration from seconds
format_duration() {
    local secs="$1"
    local h=$((secs / 3600))
    local m=$(( (secs % 3600) / 60 ))
    if [ "$h" -gt 0 ]; then
        printf "%d h %d min" "$h" "$m"
    else
        printf "%d min" "$m"
    fi
}

# Returns hours since a Unix timestamp
hours_since() {
    local ts="$1"
    local now
    now=$(date +%s)
    echo $(( (now - ts) / 3600 ))
}

# Returns the Unix timestamp of the last commit in a repo, or 0
repo_last_commit_ts() {
    local repo_dir="$1"
    git -C "$repo_dir" log -1 --format="%ct" 2>/dev/null || echo "0"
}

# =============================================================================
# Compose stack helpers
# =============================================================================

# Finds the Compose file in a directory
find_compose_file() {
    local dir="$1"
    for f in "$dir/docker-compose.yml" "$dir/docker-compose.yaml" \
              "$dir/compose.yml" "$dir/compose.yaml"; do
        [ -f "$f" ] && { echo "$f"; return 0; }
    done
    return 1
}

# =============================================================================
# File logging
# =============================================================================

# Creates the output directory if not present
ensure_local_dir() {
    local subdir="${1:-}"
    if [ -n "$subdir" ]; then
        mkdir -p "$LOCAL_DIR/$subdir"
    else
        mkdir -p "$LOCAL_DIR"
    fi
}
