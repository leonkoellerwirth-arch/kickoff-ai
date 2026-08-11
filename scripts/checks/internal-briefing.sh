#!/usr/bin/env bash
# =============================================================================
# scripts/checks/internal-briefing.sh — no internal briefing tracked
#
# Purpose:  Working briefings are private context, not public artefacts. If one
#           is ever committed to this Bridge-zone repo it must fail loudly.
# Changes:  Nothing — read-only.
# Usage:    scripts/checks/internal-briefing.sh [--help]
# =============================================================================
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
    -h | --help)
        sed -n '2,10p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    "") ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

if match="$(git ls-files -- '*CLAUDE-CODE-BRIEFING*' '*BRIEFING*.md' 2>/dev/null)" \
    && [ -n "$match" ]; then
    violation "internal briefing is tracked"
    printf '%s\n' "$match" >&2
    exit 1
fi

note "no internal briefing tracked"
exit 0
