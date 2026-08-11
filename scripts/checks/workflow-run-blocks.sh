#!/usr/bin/env bash
# =============================================================================
# scripts/checks/workflow-run-blocks.sh — every run: block must be valid shell
#
# Purpose:  An indented heredoc delimiter inside a YAML run: block silently
#           breaks the whole CI step without any YAML error. This has already
#           happened once in this repo; the check exists so it cannot recur.
# Changes:  Nothing — read-only, writes only to a temp file it removes.
# Usage:    scripts/checks/workflow-run-blocks.sh [--help]
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

require yq
require jq

tmp="$(mktemp)"
json="$(mktemp)"
trap 'rm -f "$tmp" "$json"' EXIT

fail=0
n=0
for wf in .github/workflows/*.yml; do
    [ -e "$wf" ] || continue
    yq e -o=json '.' "$wf" >"$json" 2>/dev/null || {
        violation "cannot convert to JSON: $wf"
        fail=1
        continue
    }
    count=$(jq '[.jobs[]?.steps[]? | select(.run) | .run] | length' "$json")
    i=0
    while [ "$i" -lt "$count" ]; do
        jq -r "[.jobs[]?.steps[]? | select(.run) | .run] | .[$i]" "$json" >"$tmp"
        n=$((n + 1))
        if ! err=$(bash -n "$tmp" 2>&1); then
            violation "run: block $((i + 1)) in $wf is not valid shell"
            printf '%s\n' "$err" >&2
            fail=1
        fi
        i=$((i + 1))
    done
done

[ "$fail" -eq 0 ] && note "workflow run-blocks are valid shell ($n blocks)"
exit "$fail"
