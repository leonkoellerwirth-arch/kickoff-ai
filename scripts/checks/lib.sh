#!/usr/bin/env bash
# =============================================================================
# scripts/checks/lib.sh — shared helpers for the individual check scripts
#
# Purpose:  One implementation of "which files are in scope" and "is this tool
#           available", so every check agrees and local/CI cannot drift (INV-7).
# Changes:  Nothing — sourced only, never executed.
# Usage:    . "$(dirname "$0")/lib.sh"
#
# Exit-code contract for every check script that sources this file:
#   0  pass
#   1  violation found — the thing being checked is broken
#   2  cannot run — a required tool is missing (fail-closed, never a silent skip)
# =============================================================================

# Resolve the repo root from this file's location, so checks work no matter
# what the caller's working directory is.
CHECK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export CHECK_ROOT
cd "$CHECK_ROOT" || exit 2

# --- dependency handling -----------------------------------------------------
# A missing tool is exit 2, never a pass. INV-6: a check that cannot run has
# not passed. The message names the install command so CI logs are actionable.
require() {
    command -v "$1" >/dev/null 2>&1 && return 0
    printf 'MISSING DEPENDENCY: %s (%s)\n' "$1" "${2:-brew install $1}" >&2
    exit 2
}

# --- file selection ----------------------------------------------------------
# Every tracked shell file: *.sh plus extension-less executables carrying a
# shell shebang (automation/bin/* has no suffix but is still shell). Tracked
# only — untracked scratch files are not the repo's problem, and local/ is the
# gitignored private area.
shell_files() {
    git ls-files -z | while IFS= read -r -d '' f; do
        case "$f" in
            local/*) continue ;;
            *.sh) printf '%s\0' "$f" ;;
            *.*) continue ;;
            *)
                head -n 1 "$f" 2>/dev/null \
                    | grep -qE '^#!.*/(env +)?(ba)?sh( |$)' && printf '%s\0' "$f"
                ;;
        esac
    done
}

# Every tracked text file, using git's own binary detection (-I). This is the
# scope the sanitization scan must have: an extension allowlist silently misses
# extension-less CLIs, config/gitconfig and .env.example — exactly the files
# that carry tokens, URLs and personal paths.
# NUL-separated, so a filename can never be split on whitespace. local/ is
# excluded via a git pathspec rather than a grep filter, because filtering a
# NUL stream with line-oriented grep is exactly the kind of thing that works
# until the first unusual filename.
tracked_text_files() {
    git grep -I --name-only -z -e '' -- . ':(exclude)local/*' 2>/dev/null || true
}

# --- reporting ---------------------------------------------------------------
violation() { printf 'VIOLATION: %s\n' "$*" >&2; }
note() { printf '  %s\n' "$*"; }
