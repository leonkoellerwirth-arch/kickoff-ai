#!/usr/bin/env bash
# =============================================================================
# scripts/checks/gitconfig-isolation.sh — the setup must never write into the
# tracked git config (INV-3)
#
# Purpose:  ~/.gitconfig is a symlink to the tracked config/gitconfig. git
#           resolves symlinks before taking its lockfile, so `git config
#           --global` writes THROUGH the link into a tracked file — and the
#           next commit publishes the operator's name, email and absolute local
#           paths from a public repo.
#
#           Two independent guards, because either alone is weak:
#             1. a static rule — no `git config --global` write form anywhere in
#                the executable surface or in the documented commands
#             2. a behavioural test in a throwaway HOME that reproduces the
#                hazard and proves the chosen mechanism avoids it
#
# Changes:  Nothing outside a temp dir it removes on exit.
# Usage:    scripts/checks/gitconfig-isolation.sh [--help]
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

fail=0

# --- guard 1: static ---------------------------------------------------------
# The rule is deliberately absolute: `git config --global` must not appear at
# all in the executable surface or in the runnable documentation. Telling reads
# from writes by regex is guesswork — `git config --global user.name 2>/dev/null`
# is a read that looks exactly like a write — and a rule that needs a clever
# regex is a rule that will be got wrong later. Reads use `git config --get`,
# writes use `git config --file ~/.gitconfig.local`; neither can touch the
# tracked template, so neither needs an exception.
#
# Excluded by path: the review (quotes the old code as evidence), the gap
# analysis (documents the state of a machine before any setup ran),
# config/gitconfig and this file (both state the prohibition itself).
#
# Prose *about* the prohibition must stay possible — the warnings in the docs
# and the comments in module 08 are the main way a reader learns the rule, and
# a check that forbids naming the hazard would delete its own explanation.
# So three line shapes are not invocations and are filtered out:
#   * shell comments      →  # ... git config --global ...
#   * markdown blockquotes →  > ... git config --global ...
#   * inline code spans   →  `git config --global`
# What remains is a bare command on its own line, which is the only form that
# actually runs or gets copy-pasted out of a fenced block.
hits="$(git grep -nE 'git config --global' -- \
    scripts/ automation/ bootstrap.sh doctor.sh prepare.sh status-quo.sh \
    docs/ config/ README.md CONTRIBUTING.md \
    ':(exclude,glob)docs/reviews/**' \
    ':(exclude)config/gitconfig' \
    ':(exclude)scripts/checks/gitconfig-isolation.sh' \
    ':(exclude,glob)docs/**/02-GAP-ANALY*' 2>/dev/null |
    grep -vE '^[^:]+:[0-9]+:[[:space:]]*[#>]' |
    grep -vE '`[^`]*git config --global')"
if [ -n "$hits" ]; then
    violation "'git config --global' must not appear here"
    printf '%s\n' "$hits" >&2
    printf '  read:  git config --get <key>\n' >&2
    printf '  write: git config --file ~/.gitconfig.local <key> <value>\n' >&2
    fail=1
fi

# --- guard 2: behavioural ----------------------------------------------------
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FAKE_HOME="$TMP/home"
FAKE_REPO="$TMP/repo"
mkdir -p "$FAKE_HOME" "$FAKE_REPO"
cp "$CHECK_ROOT/config/gitconfig" "$FAKE_REPO/gitconfig"
before="$(shasum "$FAKE_REPO/gitconfig" | awk '{print $1}')"
ln -sf "$FAKE_REPO/gitconfig" "$FAKE_HOME/.gitconfig"

# 2a. The safe form must leave the tracked template untouched.
HOME="$FAKE_HOME" git config --file "$FAKE_HOME/.gitconfig.local" \
    user.email "isolation-test@example.com" 2>/dev/null
after_safe="$(shasum "$FAKE_REPO/gitconfig" | awk '{print $1}')"
if [ "$before" != "$after_safe" ]; then
    violation "git config --file wrote into the tracked template"
    fail=1
fi
if ! grep -q 'isolation-test@example.com' "$FAKE_HOME/.gitconfig.local" 2>/dev/null; then
    violation "git config --file did not write to ~/.gitconfig.local at all"
    fail=1
fi

# 2b. Counter-proof: the forbidden form really does modify the tracked file.
# If this ever stops being true the static rule above is over-strict, and this
# check should say so rather than quietly enforcing a rule with no basis.
HOME="$FAKE_HOME" git config --global user.email "hazard@example.com" 2>/dev/null
after_unsafe="$(shasum "$FAKE_REPO/gitconfig" | awk '{print $1}')"
if [ "$before" = "$after_unsafe" ]; then
    note "note: --global no longer writes through the symlink on this git version;"
    note "      the static rule is kept regardless, since older git still does."
fi

[ "$fail" -eq 0 ] && note "git identity stays out of the tracked config"
exit "$fail"
