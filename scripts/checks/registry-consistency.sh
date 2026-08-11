#!/usr/bin/env bash
# =============================================================================
# scripts/checks/registry-consistency.sh — registry vs. the install lists
#
# Purpose:  INV-8 — manifests/tools.yaml is the single source of truth; the
#           Brewfiles and manifests are its implementation. This runs the same
#           offline consistency pass locally and in CI.
# Changes:  Nothing — read-only, --offline makes no network calls.
# Usage:    scripts/checks/registry-consistency.sh [--help]
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

[ -x automation/bin/up2date ] || {
    violation "automation/bin/up2date is missing or not executable"
    exit 1
}

if ! out="$(CI=1 STATE_JSON="$(mktemp)" automation/bin/up2date --consistency --offline 2>&1)"; then
    violation "registry and install lists disagree (INV-8)"
    printf '%s\n' "$out" >&2
    exit 1
fi

note "registry consistent with install lists"
exit 0
