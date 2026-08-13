#!/usr/bin/env bash
# =============================================================================
# scripts/checks/registry-privacy.sh — the public registry stays a reference
#
# Purpose:  manifests/tools.yaml is published. It is meant to be a curated
#           reference manifest: the tools this setup installs or deliberately
#           tracks, each with an impersonal reason. It is not meant to be a
#           report on one particular machine.
#
#           It drifted into being one. Entries carried the raw output of an
#           inventory run — "Origin unclear — found in global npm packages" —
#           and personal decision notes in the first person. Together they
#           described the private state of a real machine and the opinions of
#           its owner, in a public, machine-readable file. Machine-specific
#           findings belong in local/manifests/tools.local.yaml, which is
#           gitignored and read on top of the public file.
#
#           This check makes that class of mistake unable to come back.
#
# Changes:  Nothing.
# Usage:    scripts/checks/registry-privacy.sh [--help]
# =============================================================================
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
    -h | --help)
        sed -n '2,23p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    "") ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

REGISTRY="manifests/tools.yaml"

if [ ! -f "$REGISTRY" ]; then
    printf 'MISSING: %s\n' "$REGISTRY" >&2
    exit 2
fi

# Two classes, one check. The first four are the phrasings that were actually
# there; the last two are the same mistake said differently. Case-insensitive,
# because the point is the content and not the capitalisation.
PATTERNS='user decision
the user
by the user
found in global npm
origin unclear
on this machine'

fail=0
while IFS= read -r pattern; do
    [ -n "$pattern" ] || continue
    if hits="$(grep -niE "$pattern" "$REGISTRY")" && [ -n "$hits" ]; then
        violation "$REGISTRY describes a specific machine or a personal decision: \"$pattern\""
        printf '%s\n' "$hits" | sed 's/^/    /' >&2
        fail=1
    fi
done <<EOF
$PATTERNS
EOF

if [ "$fail" -eq 1 ]; then
    {
        echo
        echo "Move the entry to local/manifests/tools.local.yaml (gitignored, same schema,"
        echo "read on top of the public file), or rewrite the reason impersonally:"
        echo "  \"replaced by X; rationale in BIBLE.md\"  not  \"User decision: ...\""
    } >&2
    exit 1
fi

note "public registry carries no machine-specific findings ($(printf '%s\n' "$PATTERNS" | grep -c .) patterns)"
exit 0
