#!/usr/bin/env bash
# =============================================================================
# scripts/checks/workflow-trust.sh — trust boundaries in GitHub workflows
#
# Purpose:  Two rules that this repo broke once each, in workflows holding
#           contents: write on a public repository:
#
#   1. No ${{ }} expression inside a run: block. GitHub substitutes the value
#      into the script text BEFORE the shell sees it, so any expression
#      carrying attacker-influenceable content — a changelog line, a tag name,
#      a workflow_dispatch input, an issue title — becomes shell syntax.
#      Pass values through env: and reference them as "$VARS" instead; the
#      shell then treats them as data, whatever they contain.
#
#   2. Third-party actions must be pinned to a full 40-character commit SHA.
#      A tag is a mutable pointer owned by someone else: v6 can be repointed at
#      new code without any change here. Actions owned by this repo's own
#      account, and local ./ workflow references, are exempt.
#
# Changes:  Nothing — read-only.
# Usage:    scripts/checks/workflow-trust.sh [--help]
# =============================================================================
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
    -h | --help)
        sed -n '2,21p' "${BASH_SOURCE[0]}"
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

fail=0
json="$(mktemp)"
trap 'rm -f "$json"' EXIT

n_blocks=0
n_uses=0

for wf in .github/workflows/*.yml; do
    [ -e "$wf" ] || continue
    yq e -o=json '.' "$wf" >"$json" 2>/dev/null || {
        violation "cannot parse $wf"
        fail=1
        continue
    }

    # --- rule 1: no expressions in run: bodies -------------------------------
    count=$(jq '[.jobs[]?.steps[]? | select(.run) | .run] | length' "$json")
    i=0
    while [ "$i" -lt "$count" ]; do
        body="$(jq -r "[.jobs[]?.steps[]? | select(.run) | .run] | .[$i]" "$json")"
        n_blocks=$((n_blocks + 1))
        if printf '%s' "$body" | grep -q '\${{'; then
            violation "$wf: run: block $((i + 1)) interpolates a \${{ }} expression"
            printf '%s\n' "$body" | grep -n '\${{' | sed 's/^/      /' >&2
            printf '      pass it through env: and use "$VAR" instead\n' >&2
            fail=1
        fi
        i=$((i + 1))
    done

    # --- rule 2: third-party actions pinned to a SHA -------------------------
    while IFS= read -r use; do
        [ -n "$use" ] || continue
        n_uses=$((n_uses + 1))
        case "$use" in
            ./*) continue ;;                          # local reusable workflow
            leonkoellerwirth-arch/*) continue ;;      # owned by this account
        esac
        ref="${use##*@}"
        if ! printf '%s' "$ref" | grep -qE '^[0-9a-f]{40}$'; then
            violation "$wf: action is not pinned to a commit SHA: $use"
            printf '      resolve with: gh api repos/%s/git/ref/tags/%s --jq .object.sha\n' \
                "${use%@*}" "$ref" >&2
            fail=1
        fi
    done < <(jq -r '.jobs[]? | (.uses // empty), (.steps[]?.uses // empty)' "$json")
done

if [ "$fail" -eq 0 ]; then
    note "workflow trust boundaries ok ($n_blocks run-blocks, $n_uses action refs)"
fi
exit "$fail"
