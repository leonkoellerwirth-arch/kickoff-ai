#!/usr/bin/env bash
# =============================================================================
# scripts/checks/python-syntax.sh — every tracked Python file still parses
#
# Purpose:  The Control Room (app/server.py) is shipped code, not a helper
#           script, and the gate's job is that a broken repo fails. This is the
#           Python equivalent of the bash -n check: a file that does not parse
#           cannot possibly work, and that must never reach main.
#
#           Deliberately syntax only. ruff and pytest are not dependencies of
#           this repo and adding them would make the gate unrunnable on the very
#           machine this setup exists to prepare — a fresh Mac has python3 and
#           nothing else. The app's behaviour is covered where it can be:
#           start.sh goes through shellcheck, and the app runs no command that
#           is not in its allow-list.
#
#           The compile happens in memory. py_compile would write __pycache__
#           into the tree the gate is judging, and the gate promises to change
#           nothing.
#
# Changes:  Nothing.
# Usage:    scripts/checks/python-syntax.sh [--help]
# =============================================================================
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
    -h | --help)
        sed -n '2,24p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    "") ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

files="$(git ls-files '*.py' | grep -v '^local/' || true)"

if [ -z "$files" ]; then
    note "no Python files tracked"
    exit 0
fi

require python3 "ships with the Xcode Command Line Tools"

fail=0
n=0
while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    if ! out="$(python3 -c '
import sys
path = sys.argv[1]
with open(path, encoding="utf-8") as fh:
    compile(fh.read(), path, "exec")
' "$f" 2>&1)"; then
        violation "$f does not parse"
        printf '%s\n' "$out" >&2
        fail=1
    fi
done <<EOF
$files
EOF

[ "$fail" -eq 0 ] && note "Python parses ($n file(s))"
exit "$fail"
