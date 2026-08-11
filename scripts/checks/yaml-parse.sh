#!/usr/bin/env bash
# =============================================================================
# scripts/checks/yaml-parse.sh — every workflow and the registry must parse
#
# Purpose:  Catch YAML that GitHub would reject before it is pushed. Uses yq —
#           the same parser CI uses — so local and CI cannot disagree (INV-7).
#           The previous implementation used an undeclared PyYAML import, which
#           aborted the whole gate on any machine without it.
# Changes:  Nothing — read-only.
# Usage:    scripts/checks/yaml-parse.sh [--help]
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

require yq

fail=0
n=0
for f in .github/workflows/*.yml .github/workflows/*.yaml manifests/*.yaml; do
    [ -e "$f" ] || continue
    n=$((n + 1))
    if ! err=$(yq e '.' "$f" 2>&1 >/dev/null); then
        violation "not valid YAML: $f"
        printf '%s\n' "$err" >&2
        fail=1
    fi
done

[ "$fail" -eq 0 ] && note "YAML parses ($n files)"
exit "$fail"
