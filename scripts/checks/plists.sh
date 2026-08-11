#!/usr/bin/env bash
# =============================================================================
# scripts/checks/plists.sh — plutil -lint over the LaunchAgent templates
#
# Purpose:  A malformed plist fails silently at load time; catch it here.
#           Also enforces RunAtLoad=false (INV-2): a template that runs on load
#           turns an opt-in job into an automatic one.
# Changes:  Nothing — read-only.
# Usage:    scripts/checks/plists.sh [--help]
# =============================================================================
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
    -h | --help)
        sed -n '2,11p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    "") ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

[ -d automation/launchd ] || {
    note "no automation/launchd directory — nothing to lint"
    exit 0
}
require plutil "macOS built-in — this check requires macOS"

fail=0
n=0
for f in automation/launchd/*.plist; do
    [ -e "$f" ] || continue
    n=$((n + 1))
    plutil -lint "$f" >/dev/null || {
        violation "plutil: $f"
        fail=1
    }
    # INV-2: nothing runs itself. Every job template must be load-inert.
    if ! plutil -extract RunAtLoad raw -o - "$f" 2>/dev/null | grep -qx 'false'; then
        violation "RunAtLoad is not false: $f (INV-2 — nothing runs itself)"
        fail=1
    fi
done

[ "$fail" -eq 0 ] && note "plutil clean, RunAtLoad=false ($n plists)"
exit "$fail"
