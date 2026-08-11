#!/usr/bin/env bash
# =============================================================================
# scripts/checks/self-test.sh — prove the gate actually blocks (INV-6)
#
# Purpose:  A gate that passes vacuously is worse than no gate. This runs the
#           gate against a throwaway clone of the repo, once clean and once
#           deliberately broken, and asserts:
#             1. the clean tree yields exactly one verdict, and it is PASS
#             2. the broken tree yields exactly one verdict, and it is FAIL
#             3. a failure in an EARLY check does not stop LATER checks from
#                running — the exact regression the 2026-08-11 review found,
#                where a missing PyYAML aborted the gate before the secret and
#                customer-name scans and before any verdict at all
#             4. the registry schema validator rejects a known-invalid fixture
#             5. the gate changes nothing in the tree it is judging
#
# Changes:  Nothing in this repo — all work happens in a temp clone that is
#           removed on exit.
# Usage:    scripts/checks/self-test.sh [--help]
# =============================================================================
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
    -h | --help)
        sed -n '2,20p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    "") ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail=0
assert() {
    if [ "$1" = "ok" ]; then
        printf '    ✓ %s\n' "$2"
    else
        printf '    ✗ %s\n' "$2"
        fail=1
    fi
}

verdict_count() { grep -cE '^GATE: (PASS|FAIL)$' <<<"$1"; }

echo "== gate self-test =="

# A copy of the WORKING TREE, not a clone of HEAD: the gate is supposed to
# judge what is about to be committed, so the self-test must exercise the same
# uncommitted state. .git comes along so git ls-files and git grep still work.
WORK="$TMP/tree"
mkdir -p "$WORK"
if ! cp -R "$CHECK_ROOT/." "$WORK/" 2>/dev/null; then
    printf 'cannot copy the repo into a temp dir — self-test unavailable\n' >&2
    exit 2
fi
rm -rf "$WORK/local"

# --- 1. clean tree -----------------------------------------------------------
echo "  case 1: clean tree"

# Snapshot before, compare after. The copy inherits whatever is uncommitted in
# the real tree, so "is it dirty" says nothing; only the DIFFERENCE the gate
# makes is meaningful.
before_status="$(git -C "$WORK" status --porcelain 2>/dev/null)"

clean_out="$("$WORK/scripts/gate.sh" 2>&1)"
clean_code=$?
[ "$(verdict_count "$clean_out")" = "1" ] && assert ok "exactly one verdict" \
    || assert no "exactly one verdict (got $(verdict_count "$clean_out"))"
grep -q '^GATE: PASS$' <<<"$clean_out" && assert ok "verdict is PASS" \
    || assert no "verdict is PASS"
[ "$clean_code" -eq 0 ] && assert ok "exit 0" || assert no "exit 0 (got $clean_code)"

# The gate must not modify the tree it is judging. currency-contract.sh and
# registry-consistency.sh both invoke up2date, which rewrites the tracked
# manifests/STATE.json — so for a while the gate dirtied the worktree on every
# run, including the one it was judging. Both now redirect STATE_JSON to a temp
# file; this asserts it stays that way.
after_status="$(git -C "$WORK" status --porcelain 2>/dev/null)"
if [ "$before_status" = "$after_status" ]; then
    assert ok "the gate changed nothing in the tree"
else
    assert no "the gate modified the tree it was judging:
$(diff <(printf '%s\n' "$before_status") <(printf '%s\n' "$after_status") | sed 's/^/      /')"
fi

# --- 2./3. deliberately broken tree -----------------------------------------
# Two independent defects are planted: a shell syntax error, caught by the
# FIRST check, and a personal path, caught by a LATE check. Both must be
# reported by the same run. If only the first appears, the gate is aborting
# early again and the security checks are not running.
echo "  case 2: two planted defects, one early, one late"
printf '\nif then fi\n' >>"$WORK/scripts/checks/lib.sh"
# Assembled at runtime on purpose: written out literally, this line would be a
# real denylist hit in this very file, and the sanitization scan — which now
# covers every tracked text file, including this one — would be right to flag it.
_u="Users"
_n="plantedtestuser"
printf '\nA path: /%s/%s/dev\n' "$_u" "$_n" >>"$WORK/README.md"

broken_out="$("$WORK/scripts/gate.sh" 2>&1)"
broken_code=$?

[ "$(verdict_count "$broken_out")" = "1" ] && assert ok "exactly one verdict" \
    || assert no "exactly one verdict (got $(verdict_count "$broken_out"))"
grep -q '^GATE: FAIL$' <<<"$broken_out" && assert ok "verdict is FAIL" \
    || assert no "verdict is FAIL"
[ "$broken_code" -eq 1 ] && assert ok "exit 1" || assert no "exit 1 (got $broken_code)"
grep -q 'shell-syntax' <<<"$broken_out" && assert ok "early check reported the syntax error" \
    || assert no "early check reported the syntax error"
grep -q 'plantedtestuser' <<<"$broken_out" \
    && assert ok "LATE check still ran after the early failure (the H7 regression)" \
    || assert no "LATE check still ran after the early failure (the H7 regression)"

# --- 4. registry schema rejects a known-bad fixture --------------------------
echo "  case 3: registry schema validator rejects the invalid fixture"
FIXTURE="$CHECK_ROOT/tests/fixtures/registry-invalid.yaml"
if [ -f "$FIXTURE" ]; then
    if "$CHECK_ROOT/scripts/checks/registry-schema.sh" "$FIXTURE" >/dev/null 2>&1; then
        assert no "invalid registry fixture is rejected"
    else
        assert ok "invalid registry fixture is rejected"
    fi
else
    assert no "fixture present at tests/fixtures/registry-invalid.yaml"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "SELF-TEST: PASS"
else
    echo "SELF-TEST: FAIL"
fi
exit "$fail"
