#!/usr/bin/env bash
# =============================================================================
# automation/launchd/uninstall-launchd.sh — Uninstall launchd jobs
#
# Purpose:    Unloads and removes all dev.kickoff.* LaunchAgents.
#             Idempotent: also works when jobs are not loaded.
#             Deletes plist files from ~/Library/LaunchAgents/.
#             Leaves ~/Library/Logs/kickoff/ untouched (logs are kept).
# Changes:    Removes ~/Library/LaunchAgents/dev.kickoff.*.plist
# Usage:      bash automation/launchd/uninstall-launchd.sh [--dry-run] [--help]
# Idempotent: already unloaded jobs are skipped without error.
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
Usage: bash automation/launchd/uninstall-launchd.sh [--dry-run] [--help]

  Unloads and removes all dev.kickoff.* LaunchAgents.

Options:
  --dry-run   Show what would be removed without deleting
  --help      This help

Note: Logs in ~/Library/Logs/kickoff/ are not deleted.
      Install: bash automation/launchd/install-launchd.sh
EOF
            exit 0
            ;;
    esac
done

# =============================================================================
# Constants
# =============================================================================
LAUNCHD_DST="$HOME/Library/LaunchAgents"
USER_UID=$(id -u)

step "=== uninstall-launchd.sh ==="
if [ "$DRY_RUN" = "1" ]; then
    warn "DRY-RUN: No files will be removed."
fi
printf "\n" >&2

# =============================================================================
# Unload jobs and remove plist files
# =============================================================================
removed=0
not_found=0

for plist_dst in "$LAUNCHD_DST"/dev.kickoff.*.plist; do
    [ -f "$plist_dst" ] || continue

    label=$(basename "${plist_dst%.plist}")

    step "Uninstalling: $label"

    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would unload: $label"
        info "[dry-run] Would delete: $plist_dst"
        not_found=$((not_found + 1))
        continue
    fi

    # Unload: modern form first, fall back
    if launchctl list "$label" >/dev/null 2>&1; then
        if launchctl bootout "gui/$USER_UID/$label" 2>/dev/null; then
            ok "Unloaded (bootout): $label"
        elif launchctl unload "$plist_dst" 2>/dev/null; then
            ok "Unloaded (unload): $label"
        else
            warn "Could not unload $label — removing file anyway."
        fi
    else
        info "Not loaded (skipping bootout): $label"
    fi

    # Remove plist file
    rm -f "$plist_dst"
    ok "Removed: $plist_dst"
    removed=$((removed + 1))
done

if [ "$removed" -eq 0 ] && [ "$not_found" -eq 0 ]; then
    info "No dev.kickoff.* LaunchAgents found — nothing to do."
fi

# =============================================================================
# Summary
# =============================================================================
printf "\n" >&2
step "Done"
if [ "$DRY_RUN" = "0" ]; then
    ok "$removed job(s) uninstalled."
    info "Logs remain in: $HOME/Library/Logs/kickoff/"
    info "Re-install: bash automation/launchd/install-launchd.sh"
else
    info "$not_found job(s) would be uninstalled (dry-run)."
fi
