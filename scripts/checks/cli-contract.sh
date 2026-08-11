#!/usr/bin/env bash
# =============================================================================
# scripts/checks/cli-contract.sh — every executable keeps its --help/--dry-run promise
#
# Purpose:  INV-5 requires --help and --dry-run on every command, and
#           SECURITY.md tells readers a dry run executes nothing. Both were
#           untrue: the modules accepted their two known flags and silently
#           ignored everything else, so `./scripts/04-node.sh --help` installed
#           Node, and a typo in a pasted command ran as a normal setup.
#
#           One cheap, exact check: --help exits 0 and an unknown option exits
#           2, for every module.
#
#           Dry-run purity is deliberately NOT checked statically. Four writes
#           outside the run abstraction were found and fixed by hand; a grep for
#           the rest kept flagging writes that sit correctly inside an explicit
#           `if [ "$DRY_RUN" = "1" ] ... else` branch, and a heuristic that
#           needs tuning to stop lying is worse than an honest gap. A full
#           temp-HOME dry-run diff would prove it properly but means running
#           brew, npm and ssh-keygen in CI. Recorded as an open item rather than
#           implied to be covered.
#
# Changes:  Nothing — --help only.
# Usage:    scripts/checks/cli-contract.sh [--help]
# =============================================================================
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
    -h | --help)
        sed -n '2,25p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    "") ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

fail=0
n_ok=0

# --- 1. --help and unknown-option contract ----------------------------------
for m in scripts/[0-9]*.sh; do
    [ -f "$m" ] || continue

    if ! out="$(bash "$m" --help 2>&1)"; then
        violation "$m --help exits non-zero"
        fail=1
        continue
    fi
    if [ -z "$out" ]; then
        violation "$m --help prints nothing"
        fail=1
        continue
    fi

    bash "$m" --definitely-not-an-option >/dev/null 2>&1
    code=$?
    if [ "$code" -ne 2 ]; then
        violation "$m accepts an unknown option (exit $code, expected 2)"
        fail=1
        continue
    fi
    n_ok=$((n_ok + 1))
done

[ "$fail" -eq 0 ] && note "CLI contract holds ($n_ok modules: --help exits 0, unknown option exits 2)"
exit "$fail"
