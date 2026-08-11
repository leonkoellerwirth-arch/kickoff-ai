#!/usr/bin/env bash
# =============================================================================
# scripts/checks/registry-schema.sh — validate manifests/tools.yaml completely
#
# Purpose:  Enforce all 15 required fields and all 12 validation rules from
#           manifests/schema.md. The previous CI step read only a subset of the
#           fields and date-checked only `added`, so a formally invalid entry
#           could merge green and then corrupt currency/sunset logic — and the
#           registry is INV-8's single source of truth.
# Changes:  Nothing — read-only.
# Usage:    scripts/checks/registry-schema.sh [--help] [FILE]
# =============================================================================
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REGISTRY="manifests/tools.yaml"
case "${1:-}" in
    -h | --help)
        sed -n '2,13p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    "") ;;
    -*)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
    *) REGISTRY="$1" ;;
esac

require yq
require jq

[ -f "$REGISTRY" ] || {
    violation "registry not found: $REGISTRY"
    exit 1
}

json="$(mktemp)"
trap 'rm -f "$json"' EXIT
yq e -o=json '.' "$REGISTRY" >"$json" 2>/dev/null || {
    violation "registry is not valid YAML: $REGISTRY"
    exit 1
}

# The whole schema as one jq program. Emits one line per violation and nothing
# when the registry is clean, so the exit code follows directly from the output.
# The delimiter is deliberately unindented — an indented heredoc delimiter is
# the exact failure mode this repo already hit once in a workflow.
findings="$(jq -r '
def datefmt:
  type == "string"
  and test("^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$");

def required: [
  "id","name","category","source","ref","level","status","version_seen",
  "version_check","check_ref","why","added","reviewed","sunset","replaced_by"
];

def categories: [
  "apple","shell","node","python","containers","ai","editors","data",
  "media","security","automation"
];

def sources: [
  "brew","cask","npm","npx","mas","curl","uv","ollama","builtin","manual"
];

def statuses: ["candidate","active","deprecated","sunset"];
def checks: ["brew","npm","github-release","mas","ollama","manual"];

. as $all
| [$all[].id] as $ids
| (
    # Rule 1 — ids unique across the document.
    ([$ids | group_by(.) | .[] | select(length > 1) | .[0]]
      | map("duplicate id: " + .))
    +
    # Per-entry rules. The id is used as the label; a missing id is reported by
    # the required-field rule below and labelled by index instead.
    ( [ $all | to_entries[]
        | .key as $i | .value as $e
        | (($e.id // ("entry #" + ($i|tostring))) | tostring) as $lbl
        | (
            (required - ($e | keys) | map("[" + $lbl + "] missing required field: " + .))
            +
            (if ($e.why // "") | tostring | gsub("\\s";"") == "" then
               ["[" + $lbl + "] why must not be empty"] else [] end)
            +
            (if ($e.id // "") | tostring | test("^[a-z0-9]+(-[a-z0-9]+)*$") | not then
               ["[" + $lbl + "] id is not kebab-case"] else [] end)
            +
            (if categories | index($e.category) then [] else
               ["[" + $lbl + "] invalid category: " + ($e.category|tostring)] end)
            +
            (if sources | index($e.source) then [] else
               ["[" + $lbl + "] invalid source: " + ($e.source|tostring)] end)
            +
            (if statuses | index($e.status) then [] else
               ["[" + $lbl + "] invalid status: " + ($e.status|tostring)] end)
            +
            (if checks | index($e.version_check) then [] else
               ["[" + $lbl + "] invalid version_check: " + ($e.version_check|tostring)] end)
            +
            (if ($e.level | type) == "number" and ([0,1,2,3] | index($e.level)) then [] else
               ["[" + $lbl + "] invalid level: " + ($e.level|tostring) + " (expected 0-3)"] end)
            +
            (if $e.added | datefmt then [] else
               ["[" + $lbl + "] added is not a YYYY-MM-DD date: " + ($e.added|tostring)] end)
            +
            (if $e.reviewed | datefmt then [] else
               ["[" + $lbl + "] reviewed is not a YYYY-MM-DD date: " + ($e.reviewed|tostring)] end)
            +
            (if $e.sunset == null or ($e.sunset | datefmt) then [] else
               ["[" + $lbl + "] sunset is neither null nor a YYYY-MM-DD date: " + ($e.sunset|tostring)] end)
            +
            (if (["candidate","active"] | index($e.status)) and $e.sunset != null then
               ["[" + $lbl + "] status " + ($e.status|tostring) + " must not carry a sunset date"] else [] end)
            +
            (if (["deprecated","sunset"] | index($e.status)) and $e.sunset == null then
               ["[" + $lbl + "] status " + ($e.status|tostring) + " requires a sunset date"] else [] end)
            +
            (if $e.replaced_by == null or ($ids | index($e.replaced_by)) then [] else
               ["[" + $lbl + "] replaced_by points at an unknown id: " + ($e.replaced_by|tostring)] end)
          )
      ] | flatten )
  )
| .[]
' "$json")"

if [ -n "$findings" ]; then
    printf '%s\n' "$findings" >&2
    printf 'VIOLATION: %s entry/entries violate manifests/schema.md\n' \
        "$(printf '%s\n' "$findings" | wc -l | tr -d ' ')" >&2
    exit 1
fi

note "registry schema valid ($(jq 'length' "$json") entries, 12 rules)"
exit 0
