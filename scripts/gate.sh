#!/usr/bin/env bash
# =============================================================================
# scripts/gate.sh — the hard gate (CONSTITUTION.md §4)
#
# Purpose:  Run every check in scripts/checks/ and print exactly one verdict:
#           "GATE: PASS" (exit 0) or "GATE: FAIL" (exit 1). Zero AI.
# Changes:  Nothing — every check is read-only.
# Usage:    scripts/gate.sh [--help] [--list]
#
#   --list   print the checks that would run, then exit
#
# Design notes (these are the fix for a real defect, do not undo them):
#   * Checks are executed as SUBPROCESSES, never with eval. A check that calls
#     exit can therefore not terminate the gate itself. The previous version
#     used eval and a bare `exit 1` inside a check string, so on any machine
#     without PyYAML the gate died after the fourth check — silently skipping
#     the secret scan, the customer-name scan and the verdict itself.
#   * A missing required tool is a FAILURE (exit 2 from the check), not a skip.
#     INV-6: a check that cannot run has not passed.
#   * The verdict is printed from an EXIT trap, so the gate cannot terminate
#     without one — that is the property the review found missing.
# =============================================================================
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

CHECK_DIR="$ROOT_DIR/scripts/checks"

fail=0
verdict_printed=0

# The verdict is unconditional. If anything below dies unexpectedly, this still
# runs and reports FAIL rather than leaving the caller without an answer.
print_verdict() {
    [ "$verdict_printed" -eq 1 ] && return
    verdict_printed=1
    echo
    if [ "$fail" -eq 0 ]; then
        echo "GATE: PASS"
    else
        echo "GATE: FAIL"
    fi
}
trap 'print_verdict' EXIT

usage() { sed -n '2,17p' "${BASH_SOURCE[0]}"; }

# --- the check list ----------------------------------------------------------
# Order matters only for readability: cheap and structural first, then content,
# then the publication guardrails. Every one of them always runs.
CHECKS="
shell-syntax.sh
shellcheck.sh
plists.sh
yaml-parse.sh
workflow-run-blocks.sh
registry-schema.sh
registry-consistency.sh
gitconfig-isolation.sh
markdown-links.sh
sanitize.sh
secrets.sh
customer-names.sh
internal-briefing.sh
"

case "${1:-}" in
    -h | --help)
        trap - EXIT
        usage
        exit 0
        ;;
    --list)
        trap - EXIT
        for c in $CHECKS; do echo "scripts/checks/$c"; done
        exit 0
        ;;
    "") ;;
    *)
        trap - EXIT
        printf 'unknown option: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
esac

echo "== hard gate =="

run_check() {
    script="$CHECK_DIR/$1"
    if [ ! -x "$script" ]; then
        printf '  ✗ %s (missing or not executable)\n' "$1"
        fail=1
        return
    fi
    if out="$("$script" 2>&1)"; then
        # A passing check prints its own one-line summary.
        printf '%s\n' "${out:-  ✓ $1}"
    else
        code=$?
        if [ "$code" -eq 2 ]; then
            printf '  ✗ %s — CANNOT RUN (dependency missing)\n' "$1"
        else
            printf '  ✗ %s\n' "$1"
        fi
        printf '%s\n' "$out" | sed 's/^/      /'
        fail=1
    fi
}

for c in $CHECKS; do
    run_check "$c"
done

# --- Python surface (inert in this repo; kept for base-sync parity) ----------
if [ -f pyproject.toml ]; then
    PY=".venv/bin/python"
    [ -x "$PY" ] || PY="python3"
    RUFF=".venv/bin/ruff"
    [ -x "$RUFF" ] || RUFF="ruff"
    for spec in "ruff check clean|$RUFF check ." \
        "ruff format clean|$RUFF format --check ." \
        "pytest green (offline)|$PY -m pytest -q -m not-slow"; do
        name="${spec%%|*}"
        cmd="${spec#*|}"
        if ($cmd >/dev/null 2>&1); then printf '  ✓ %s\n' "$name"; else
            printf '  ✗ %s\n' "$name"
            fail=1
        fi
    done
fi

# --- Web surface (inert in this repo; kept for base-sync parity) -------------
WEB="."
[ -f app/package.json ] && WEB="app"
if [ -f "$WEB/package.json" ] && [ -d "$WEB/node_modules" ]; then
    if grep -sq '"verify:ci"' "$WEB/package.json"; then
        if (cd "$WEB" && npm run -s verify:ci >/dev/null 2>&1); then
            printf '  ✓ verify:ci (typecheck·lint·budgets·tests·build)\n'
        else
            printf '  ✗ verify:ci (typecheck·lint·budgets·tests·build)\n'
            fail=1
        fi
    fi
fi

# --- Token / LOC ratchet (CONSTITUTION.md §4) --------------------------------
if [ -f "$ROOT_DIR/scripts/budget.sh" ]; then
    if out="$(bash "$ROOT_DIR/scripts/budget.sh" 2>&1)"; then
        printf '  ✓ token/LOC budget within ceiling\n'
    else
        printf '  ✗ token/LOC budget exceeded\n'
        printf '%s\n' "$out" | sed 's/^/      /'
        fail=1
    fi
fi

exit "$fail"
