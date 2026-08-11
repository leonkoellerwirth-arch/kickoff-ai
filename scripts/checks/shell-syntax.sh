#!/usr/bin/env bash
# =============================================================================
# scripts/checks/shell-syntax.sh — bash -n over every tracked shell file
#
# Purpose:  Catch syntax errors before they reach a machine that is mid-setup.
# Changes:  Nothing — read-only.
# Usage:    scripts/checks/shell-syntax.sh [--help]
# =============================================================================
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
    -h | --help)
        sed -n '2,9p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    "") ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

fail=0
n=0
while IFS= read -r -d '' f; do
    n=$((n + 1))
    if ! err=$(bash -n "$f" 2>&1); then
        violation "bash -n: $f"
        printf '%s\n' "$err" >&2
        fail=1
    fi
done < <(shell_files)

[ "$fail" -eq 0 ] && note "bash -n clean ($n shell files)"
exit "$fail"
