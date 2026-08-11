#!/usr/bin/env bash
# =============================================================================
# scripts/checks/customer-names.sh — no customer-internal names (CONSTITUTION §7)
#
# Purpose:  All examples must be fictive. The name list itself has to appear
#           somewhere to be checkable, so the files that legitimately carry it
#           are excluded by pathspec rather than by weakening the pattern.
# Changes:  Nothing — read-only.
# Usage:    scripts/checks/customer-names.sh [--help]
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

if match="$(git grep -nIiE '(daimler|toennies|tönnies)' -- . \
    ':(exclude)CONSTITUTION.md' \
    ':(exclude,glob)**/LESSONS.md' \
    ':(exclude,glob)scripts/checks/customer-names.sh' 2>/dev/null)"; then
    violation "customer-internal name found (CONSTITUTION §7.2)"
    printf '%s\n' "$match" >&2
    exit 1
fi

note "no customer-internal names"
exit 0
