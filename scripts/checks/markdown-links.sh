#!/usr/bin/env bash
# =============================================================================
# scripts/checks/markdown-links.sh — relative Markdown links must resolve
#
# Purpose:  CONSTITUTION §7.4 — everything documented must work. A dead link in
#           a public README is a broken promise, so this blocks rather than
#           warns. Links resolve relative to the file containing them.
# Changes:  Nothing — read-only.
# Usage:    scripts/checks/markdown-links.sh [--help]
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

broken=0
checked=0
while IFS= read -r -d '' md; do
    case "$md" in *.md) ;; *) continue ;; esac
    md_dir="$(dirname "$md")"
    while IFS= read -r ref; do
        [ -n "$ref" ] || continue
        case "$ref" in http* | \#* | mailto:*) continue ;; esac
        target="${ref%%#*}"
        [ -n "$target" ] || continue
        checked=$((checked + 1))
        [ -e "$md_dir/$target" ] || {
            violation "$md: link does not resolve: $ref"
            broken=$((broken + 1))
        }
    done < <(grep -oE '\]\([^)]+\)' "$md" 2>/dev/null | sed 's/^](//; s/)$//')
done < <(tracked_text_files)

[ "$broken" -eq 0 ] && note "markdown links resolve ($checked relative links)"
exit $((broken > 0 ? 1 : 0))
