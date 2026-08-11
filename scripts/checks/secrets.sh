#!/usr/bin/env bash
# =============================================================================
# scripts/checks/secrets.sh — gitleaks over the full history
#
# Purpose:  Secret detection with the maintained default ruleset, over history
#           rather than only the worktree. gitleaks is a declared dependency, so
#           a missing binary is exit 2 (cannot run) and never a quiet pass:
#           a regex fallback that finds nothing looks identical to a clean repo.
# Changes:  Nothing — read-only. --redact keeps found values out of the log.
# Usage:    scripts/checks/secrets.sh [--help]
# =============================================================================
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
    -h | --help)
        sed -n '2,12p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    "") ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

require gitleaks

if ! out="$(gitleaks git --no-banner --redact . 2>&1)"; then
    violation "gitleaks found secrets (values redacted)"
    printf '%s\n' "$out" >&2
    exit 1
fi

note "gitleaks clean (full history, redacted)"
exit 0
