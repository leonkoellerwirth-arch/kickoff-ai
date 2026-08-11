#!/usr/bin/env bash
# =============================================================================
# scripts/checks/shellcheck.sh — shellcheck -S warning over every shell file
#
# Purpose:  Static analysis of the whole shell surface. A missing shellcheck is
#           exit 2 (cannot run), never a silent skip — a gate that quietly
#           stops checking is worse than no gate (INV-6).
# Changes:  Nothing — read-only.
# Usage:    scripts/checks/shellcheck.sh [--help]
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

require shellcheck

fail=0
n=0
while IFS= read -r -d '' f; do
    n=$((n + 1))
    shellcheck -S warning "$f" || fail=1
done < <(shell_files)

[ "$fail" -eq 0 ] && note "shellcheck -S warning clean ($n shell files)"
exit "$fail"
