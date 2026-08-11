#!/usr/bin/env bash
# =============================================================================
# automation/launchd/install-launchd.sh — Install launchd jobs
#
# Purpose:  Installs all dev.kickoff.* plist files to ~/Library/LaunchAgents/
#           and loads them with launchctl.
#           Replaces __HOME__, __BIN_DIR__, __REPO_ROOT__ in the plist
#           templates with the actual paths.
# Changes:  ~/Library/LaunchAgents/dev.kickoff.*.plist (new files)
#           ~/Library/Logs/kickoff/ (log directory)
#           Activates the LaunchAgents via launchctl bootstrap/load.
# Usage:    bash automation/launchd/install-launchd.sh [--dry-run] [--help]
# Requires: Run from the repo root: cd ~/dev/kickoff-ai && bash automation/launchd/install-launchd.sh
# Idempotent: existing jobs are unloaded first, then reloaded.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$REPO_ROOT/scripts/lib.sh"

# =============================================================================
# Argument-Parsing
# =============================================================================
for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=1 ;;
        --help|-h)
            cat >&2 <<'EOF'
Usage: bash automation/launchd/install-launchd.sh [--dry-run] [--help]

  Installs all dev.kickoff.* LaunchAgents.

Options:
  --dry-run   Show what would be installed without installing
  --help      This help

Steps:
  1. Copy plist template from automation/launchd/
  2. Replace __HOME__, __BIN_DIR__, __REPO_ROOT__
  3. Write to ~/Library/LaunchAgents/
  4. Register via launchctl

Uninstall: bash automation/launchd/uninstall-launchd.sh

Logs: ~/Library/Logs/kickoff/<jobname>.log
EOF
            exit 0
            ;;
    esac
done

# =============================================================================
# Constants
# =============================================================================
LAUNCHD_SRC="$SCRIPT_DIR"
LAUNCHD_DST="$HOME/Library/LaunchAgents"
BIN_DIR="$REPO_ROOT/automation/bin"
LOG_DIR="$HOME/Library/Logs/kickoff"
# macOS UID for launchctl bootstrap
USER_UID=$(id -u)

step "=== install-launchd.sh ==="
info "Repo root:   $REPO_ROOT"
info "Bin dir:     $BIN_DIR"
info "Target:      $LAUNCHD_DST"
info "Logs:        $LOG_DIR"
if [ "$DRY_RUN" = "1" ]; then
    warn "DRY-RUN: No files will be installed."
fi
printf "\n" >&2

# =============================================================================
# Prerequisites
# =============================================================================
if [ ! -d "$LAUNCHD_DST" ]; then
    run mkdir -p "$LAUNCHD_DST"
fi

run mkdir -p "$LOG_DIR"

# Make all bin scripts executable
if [ "$DRY_RUN" = "0" ]; then
    if [ -d "$BIN_DIR" ]; then
        chmod +x "$BIN_DIR"/* 2>/dev/null || true
        ok "automation/bin/*: chmod +x set"
    fi
fi

# =============================================================================
# Install plist files
# =============================================================================
installed=0
skipped=0

for plist_src in "$LAUNCHD_SRC"/*.plist; do
    [ -f "$plist_src" ] || continue

    plist_name=$(basename "$plist_src")
    plist_dst="$LAUNCHD_DST/$plist_name"
    label="${plist_name%.plist}"

    step "Installing: $label"

    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would install: $plist_src → $plist_dst"
        info "[dry-run] __HOME__ → $HOME"
        info "[dry-run] __BIN_DIR__ → $BIN_DIR"
        info "[dry-run] __REPO_ROOT__ → $REPO_ROOT"
        skipped=$((skipped + 1))
        continue
    fi

    # Unload existing job first (idempotent)
    # Modern form: launchctl bootout; fall back to unload
    if launchctl list "$label" >/dev/null 2>&1; then
        info "Unloading existing job: $label"
        launchctl bootout "gui/$USER_UID/$label" 2>/dev/null || \
            launchctl unload "$plist_dst" 2>/dev/null || true
    fi

    # Write plist with real paths
    sed \
        -e "s|__HOME__|$HOME|g" \
        -e "s|__BIN_DIR__|$BIN_DIR|g" \
        -e "s|__REPO_ROOT__|$REPO_ROOT|g" \
        "$plist_src" > "$plist_dst"

    # Permissions
    chmod 644 "$plist_dst"

    # Validate plist
    if ! plutil -lint "$plist_dst" >/dev/null 2>&1; then
        err "Plist syntax error in $plist_dst — installation aborted."
    fi

    # Load: modern form first, fall back
    if launchctl bootstrap "gui/$USER_UID" "$plist_dst" 2>/dev/null; then
        ok "Loaded (bootstrap): $label"
    elif launchctl load "$plist_dst" 2>/dev/null; then
        ok "Loaded (load): $label"
    else
        warn "Could not load $label — check manually: launchctl load $plist_dst"
    fi

    installed=$((installed + 1))
done

# =============================================================================
# Summary
# =============================================================================
printf "\n" >&2
step "Done"
if [ "$DRY_RUN" = "0" ]; then
    ok "$installed job(s) installed."
    info "Check status: launchctl list | grep dev.kickoff"
    info "Logs: ls $LOG_DIR"
    info "Uninstall: bash automation/launchd/uninstall-launchd.sh"
else
    info "$skipped job(s) would be installed (dry-run)."
fi
