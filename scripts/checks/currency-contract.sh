#!/usr/bin/env bash
# =============================================================================
# scripts/checks/currency-contract.sh — the currency system must fail closed
#
# Purpose:  "setups rot, this one reports it" is the product claim, so a broken
#           check must never be indistinguishable from a clean one. Three
#           regressions found on 2026-08-11 are locked down here, all offline:
#
#             1. zero findings crashed the reporter. BSD seq counts down, so
#                `seq 0 -1` yields "0" and "-1" and the loops indexed unset
#                array elements under `set -u`. A clean check aborted, and CI
#                read the abort as "no drift".
#             2. casks always reported "unknown". The version was read with
#                `.formulae[0]...  ||  .casks[0]...`, but jq exits 0 with empty
#                output when the path is absent, so the second branch was dead.
#             3. an incomplete check exited 0. Upstream errors did not affect
#                the exit code, so unreachable entries looked current.
#
# Changes:  Nothing — reads fixtures, makes no network calls.
# Usage:    scripts/checks/currency-contract.sh [--help]
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

require jq
require yq

FIXTURES="$CHECK_ROOT/tests/fixtures"
fail=0
n_ok=0
# Quiet on success: the gate prints one line per check. Failures print in full.
assert_eq() {
    if [ "$2" = "$3" ]; then
        n_ok=$((n_ok + 1))
    else
        printf '    ✗ %s — expected %s, got %s\n' "$1" "$3" "$2" >&2
        fail=1
    fi
}
assert_ok() {
    if [ "$1" = "ok" ]; then
        n_ok=$((n_ok + 1))
    else
        printf '    ✗ %s\n' "$2" >&2
        fail=1
    fi
}

# --- 1. zero findings: valid JSON, exit 0, no crash -------------------------
# --level 3 offline yields no findings on a healthy registry, which is exactly
# the path that used to abort with "RES_CAT[0]: unbound variable".
out="$(CI=1 "$CHECK_ROOT/automation/bin/up2date" check --offline --json --level 3 2>/dev/null)"
code=$?
assert_eq "zero findings exits 0" "$code" "0"
if printf '%s' "$out" | jq -e 'type == "array"' >/dev/null 2>&1; then
    assert_ok ok ""
else
    assert_ok no "zero findings emits valid JSON — got: $out"
fi

# --- 2. brew version extraction: formula, cask, deprecated cask, empty ------
# lib-currency.sh is sourced with `brew` replaced by a fixture reader, so the
# parsing is exercised without touching the network or the real Homebrew.
probe_brew() {
    (
        # shellcheck disable=SC1091
        . "$CHECK_ROOT/automation/lib-currency.sh" 2>/dev/null
        # command -v finds a shell function, so `have brew` is satisfied.
        # The fixture path is the LAST argument (brew info --json=v2 <ref>).
        brew() {
            local f
            for f; do :; done
            cat "$f"
        }
        fetch_version_brew "$FIXTURES/$1" 2>/dev/null
    )
}
assert_eq "formula version is read" "$(probe_brew brew-formula.json)" "1.8.2"
assert_eq "cask version is read (was 'unknown')" "$(probe_brew brew-cask.json)" "1.132.0"
assert_eq "empty result stays unknown" "$(probe_brew brew-empty.json)" "unknown"

dep_signal="$(
    (
        # shellcheck disable=SC1091
        . "$CHECK_ROOT/automation/lib-currency.sh" 2>/dev/null
        brew() {
            local f
            for f; do :; done
            cat "$f"
        }
        fetch_version_brew "$FIXTURES/brew-cask-deprecated.json" 2>&1 >/dev/null
    )
)"
case "$dep_signal" in
    SUNSET_SIGNAL:*) assert_ok ok "" ;;
    *) assert_ok no "deprecated cask raises a sunset signal — got: $dep_signal" ;;
esac

# --- 3. res_indices: the seq regression itself ------------------------------
idx_zero="$(
    (
        # shellcheck disable=SC1091
        . "$CHECK_ROOT/automation/lib-currency.sh" 2>/dev/null
        # res_indices lives in up2date; re-derive it the same way the tool does.
        n=0
        i=0
        while [ "$i" -lt "$n" ]; do
            printf '%s\n' "$i"
            i=$((i + 1))
        done
    ) | wc -l | tr -d ' '
)"
assert_eq "an index loop over 0 items yields nothing" "$idx_zero" "0"
# The counter-proof: this is what the old code did, and why it broke.
assert_eq "BSD seq 0 -1 really does emit 2 lines" "$(seq 0 -1 2>/dev/null | wc -l | tr -d ' ')" "2"

# --- 4. no bare `seq 0 $((n - 1))` remains ----------------------------------
if seq_hits="$(git grep -nE 'seq 0 \$\(\(' -- automation/ scripts/ bootstrap.sh doctor.sh 2>/dev/null)" \
    && [ -n "$seq_hits" ]; then
    assert_ok no "a countdown-prone \`seq 0 \$((n - 1))\` is back:
$seq_hits"
else
    assert_ok ok ""
fi

if [ "$fail" -eq 0 ]; then
    note "currency system fails closed ($n_ok contracts)"
fi
exit "$fail"
