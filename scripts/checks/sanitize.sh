#!/usr/bin/env bash
# =============================================================================
# scripts/checks/sanitize.sh — no personal data in tracked files (INV-3)
#
# Purpose:  The publication control for a public repo. Scans EVERY tracked text
#           file, determined by git's own binary detection — not an extension
#           allowlist. The previous extension list silently skipped
#           config/gitconfig, automation/bin/* and every .env.example, which are
#           exactly the files that carry tokens, URLs and personal paths.
# Changes:  Nothing — read-only.
# Usage:    scripts/checks/sanitize.sh [--help] [--list]
#
#   --list   print the files in scope and exit (for auditing the scope itself)
# =============================================================================
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

case "${1:-}" in
    -h | --help)
        sed -n '2,15p' "${BASH_SOURCE[0]}"
        exit 0
        ;;
    --list)
        tracked_text_files | tr '\0' '\n'
        exit 0
        ;;
    "") ;;
    *)
        printf 'unknown option: %s\n' "$1" >&2
        exit 2
        ;;
esac

DENYLIST=".github/sanitize-denylist.txt"
PRIVATE_DENYLIST="local/sanitize-denylist-private.txt"

files="$(mktemp)"
allow="$(mktemp)"
trap 'rm -f "$files" "$allow"' EXIT

tracked_text_files >"$files"
[ -s "$files" ] || {
    violation "no files in scope — the scan would pass vacuously"
    exit 1
}

# Allowlist: lines matching any of these are not findings. Every entry is a
# hole in the protection, which is why the list lives in the repo with a
# justification per entry rather than inline here.
for al in ".github/sanitize-allowlist.txt" "local/sanitize-allowlist-private.txt"; do
    [ -f "$al" ] && grep -vE '^[[:space:]]*(#|$)' "$al" >>"$allow"
done
[ -s "$allow" ] || printf '%s\n' '$^' >"$allow" # never-matching fallback

fail=0
check_pattern() {
    pattern="$1"
    label="$2"
    # /dev/null keeps the filename prefix even when xargs passes a single file.
    match="$(xargs -0 grep -nEI "$pattern" /dev/null <"$files" 2>/dev/null |
        grep -vEf "$allow" 2>/dev/null)"
    if [ -n "$match" ]; then
        violation "[$label]"
        printf '%s\n' "$match" >&2
        fail=1
    fi
}

# All patterns come from the denylists — one source of truth, so the scan and
# the documented pattern list cannot drift apart.
scan_denylist() {
    [ -f "$1" ] || return 0
    while IFS= read -r pattern; do
        case "$pattern" in '' | \#*) continue ;; esac
        check_pattern "$pattern" "$2: $pattern"
    done <"$1"
}

scan_denylist "$DENYLIST" "denylist"
scan_denylist "$PRIVATE_DENYLIST" "private denylist"

if [ "$fail" -eq 0 ]; then
    note "sanitization clean ($(tr -cd '\0' <"$files" | wc -c | tr -d ' ') tracked text files)"
fi
exit "$fail"
