#!/usr/bin/env bash
# =============================================================================
# scripts/90-cleanup-legacy.sh — Legacy cleanup (OPT-IN)
#
# Purpose:  Removes legacy artifacts from an existing machine:
#           - OpenClaw (LaunchAgent, npm/pnpm packages, ~/.openclaw, tap)
#           - Orphaned LaunchAgents (homebrew.mxcl.mariadb)
#           This script does NOT run automatically during bootstrap.
#           It must be called explicitly.
# Changes:  ~/Library/LaunchAgents, npm global packages, pnpm global packages,
#           ~/.openclaw, Homebrew taps
# Requires: Homebrew and npm present
# Usage:    ./scripts/90-cleanup-legacy.sh [--dry-run] [--yes]
#           Or via bootstrap: ./bootstrap.sh --only cleanup-legacy
#
# IMPORTANT: A backup is created before deleting ~/.openclaw.
#            ~/.openclaw contains credentials, Telegram configuration,
#            memory and workspace data. These are NOT migrated automatically
#            — please back up / export them before running cleanup.
# =============================================================================
set -euo pipefail
# shellcheck disable=SC2088  # Tilde in display strings is intentional (display-only)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1; export DRY_RUN ;;
        --yes)     YES_MODE=1; export YES_MODE ;;
    esac
done

step "90 · Legacy cleanup (OpenClaw + orphaned LaunchAgents)"

warn "This script removes OpenClaw and other legacy artifacts from the machine."
warn "Everything will be backed up first. The operation cannot be undone automatically."
if [ "$DRY_RUN" = "1" ]; then
    info "DRY-RUN mode: no changes will be made."
fi

if ! confirm "Start cleanup?"; then
    info "Aborted."
    exit 0
fi

# =============================================================================
# Helper: unload + remove LaunchAgent
# =============================================================================
remove_launch_agent() {
    local plist_name="$1"
    local plist_path="$HOME/Library/LaunchAgents/$plist_name"

    if [ ! -f "$plist_path" ]; then
        ok "  LaunchAgent not present (already removed): $plist_name"
        return 0
    fi

    info "  Unloading LaunchAgent: $plist_name"

    # Back up
    backup_file "$plist_path"

    if [ "$DRY_RUN" = "1" ]; then
        info "  [dry-run] launchctl bootout gui/$UID $plist_path"
        info "  [dry-run] rm $plist_path"
        return 0
    fi

    # Try to unload (ignore errors — may already be stopped)
    launchctl bootout "gui/$UID" "$plist_path" 2>/dev/null || \
    launchctl unload "$plist_path" 2>/dev/null || \
    warn "  Could not unload LaunchAgent (may not be loaded): $plist_name"

    rm -f "$plist_path"
    ok "  LaunchAgent removed: $plist_name"
}

# =============================================================================
# 1. OpenClaw LaunchAgent
# =============================================================================
info "Cleaning up OpenClaw LaunchAgent..."
remove_launch_agent "ai.openclaw.gateway.plist"

# =============================================================================
# 2. Terminate OpenClaw processes
# =============================================================================
info "Terminating running OpenClaw processes..."

OPENCLAW_PROCS=$(pgrep -f "openclaw" 2>/dev/null || echo "")
if [ -n "$OPENCLAW_PROCS" ]; then
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would terminate: PIDs $OPENCLAW_PROCS"
    else
        echo "$OPENCLAW_PROCS" | xargs kill 2>/dev/null || true
        ok "OpenClaw processes terminated"
    fi
else
    ok "No running OpenClaw processes found"
fi

# =============================================================================
# 3. npm global: remove openclaw + clawhub
# =============================================================================
info "Cleaning up global npm packages (openclaw, clawhub)..."

for pkg in openclaw clawhub; do
    if npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
        info "  Removing npm global: $pkg"
        if [ "$DRY_RUN" = "1" ]; then
            info "  [dry-run] npm -g uninstall $pkg"
        else
            npm -g uninstall "$pkg" 2>/dev/null || warn "  Could not uninstall $pkg"
            ok "  npm global removed: $pkg"
        fi
    else
        ok "  npm global not installed: $pkg"
    fi
done

# =============================================================================
# 4. pnpm global: remove openclaw link
# =============================================================================
info "Cleaning up pnpm global link (openclaw)..."

PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
if have pnpm; then
    if pnpm list -g 2>/dev/null | grep -q "openclaw"; then
        info "  Removing pnpm global: openclaw"
        if [ "$DRY_RUN" = "1" ]; then
            info "  [dry-run] pnpm -g remove openclaw"
        else
            pnpm -g remove openclaw 2>/dev/null || warn "  Could not remove pnpm openclaw"
            ok "  pnpm global removed: openclaw"
        fi
    else
        ok "  pnpm global not installed: openclaw"
    fi
else
    info "  pnpm not available — skipping pnpm cleanup"
fi

# =============================================================================
# 5. Back up and delete ~/.openclaw
# =============================================================================
info "Cleaning up ~/.openclaw..."

OPENCLAW_DIR="$HOME/.openclaw"
if [ -d "$OPENCLAW_DIR" ]; then
    warn "$HOME/.openclaw will be backed up and deleted."
    warn "CONTENTS: credentials/, telegram/, memory/, workspace data."
    warn "PLEASE MAKE SURE all important data has been exported!"
    warn "Backup destination: ~/.setup-backups/<timestamp>/"

    if confirm "Back up and delete $HOME/.openclaw now?"; then
        backup_file "$OPENCLAW_DIR"
        if [ "$DRY_RUN" = "1" ]; then
            info "[dry-run] Would delete: rm -rf $OPENCLAW_DIR"
        else
            rm -rf "$OPENCLAW_DIR"
            ok "$HOME/.openclaw deleted (backup present)"
        fi
    else
        warn "$HOME/.openclaw will NOT be deleted."
    fi
else
    ok "$HOME/.openclaw not present (already cleaned up)"
fi

# =============================================================================
# 6. Remove openclaw/tap
# =============================================================================
info "Cleaning up Homebrew tap openclaw/tap..."

if brew tap 2>/dev/null | grep -q "openclaw/tap"; then
    # Check whether packages from this tap are still installed
    OPENCLAW_PKGS=$(brew list --formula 2>/dev/null | grep "openclaw" || echo "")
    if [ -n "$OPENCLAW_PKGS" ]; then
        warn "Packages from openclaw/tap still installed: $OPENCLAW_PKGS"
        warn "These will be uninstalled first..."
        for pkg in $OPENCLAW_PKGS; do
            if [ "$DRY_RUN" = "1" ]; then
                info "[dry-run] brew uninstall $pkg"
            else
                brew uninstall "$pkg" 2>/dev/null || warn "Could not uninstall $pkg"
            fi
        done
    fi

    info "Removing tap: openclaw/tap"
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] brew untap openclaw/tap"
    else
        brew untap openclaw/tap 2>/dev/null || warn "Could not remove openclaw/tap"
        ok "Tap removed: openclaw/tap"
    fi
else
    ok "Tap openclaw/tap not registered"
fi

# =============================================================================
# 7. Orphaned LaunchAgent: homebrew.mxcl.mariadb
# =============================================================================
info "Cleaning up orphaned mariadb LaunchAgent..."
info "(mariadb is no longer installed, but the LaunchAgent still exists)"

remove_launch_agent "homebrew.mxcl.mariadb.plist"

# =============================================================================
# 8. Check ~/.zshrc for OpenClaw references
# =============================================================================
info "Checking ~/.zshrc for OpenClaw references..."

ZSHRC="$HOME/.zshrc"
if [ -f "$ZSHRC" ]; then
    OPENCLAW_LINES=$(grep -n "openclaw\|OPENCLAW\|clawhub" "$ZSHRC" 2>/dev/null || echo "")
    if [ -n "$OPENCLAW_LINES" ]; then
        warn "$HOME/.zshrc still contains OpenClaw references:"
        echo "$OPENCLAW_LINES" >&2
        warn "If ~/.zshrc is linked to config/zshrc (via module 03), these are already cleaned up."
        warn "If ~/.zshrc is a standalone file, please clean it up manually."
    else
        ok "$HOME/.zshrc contains no OpenClaw references"
    fi
fi

# =============================================================================
# Final report
# =============================================================================
info ""
ok "Legacy cleanup complete."
if [ "$DRY_RUN" = "1" ]; then
    warn "DRY-RUN: no changes were made."
    info "To run for real: ./scripts/90-cleanup-legacy.sh --yes"
fi
