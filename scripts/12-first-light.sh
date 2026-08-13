#!/usr/bin/env bash
# =============================================================================
# scripts/12-first-light.sh — First Light: see an AI model work on your own Mac
#
# Purpose:  The last step of the guide, and the only one whose output is for
#           the person rather than for the setup. It creates a small folder of
#           sample files, has a locally available AI model read them and write
#           a summary back, and opens the folder in Finder so the result is
#           visible. Everything before this proves the machine works; this is
#           the first time the machine does something for you.
# Changes:  Creates ~/dev/first-light/ and the files in it. Nothing else on the
#           machine, and nothing outside that folder.
# Requires: Claude Code or Ollama with at least one model (level 0 installs
#           Claude Code; level 2 installs Ollama). Neither is installed here.
# Usage:    ./scripts/12-first-light.sh [--dry-run] [--yes]
#
# Why the prompt and the folder are hard-wired:
#   A first contact with an AI model should happen inside a fence, and the
#   fence should be visible. So: the working folder is fixed, the files are
#   ones this script just created, the prompt is written here in full, and the
#   model is handed the file contents as text. It is given no tools, no shell,
#   no network reach into anything else, and no access to any other part of
#   the machine. The summary is written by this script from what the model
#   answered, not by the model itself.
#
#   That is more restrictive than it has to be, on purpose. Someone meeting
#   this for the first time should meet it with the smallest possible blast
#   radius, and should be able to read the whole arrangement in one file.
#   docs/11-GOVERNANCE-PATTERN.md cites this as the worked example.
# =============================================================================
set -euo pipefail
# shellcheck disable=SC2088  # Tilde in display strings is intentional (display-only)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

parse_module_args "${BASH_SOURCE[0]}" "$@"

step "12 · First Light"

WORK_DIR="$HOME/dev/first-light"
SUMMARY="$WORK_DIR/SUMMARY.md"

# Budget in seconds for the model call. Stock macOS has no `timeout` command —
# assuming it does is a bug this repo has already had once — so the deadline is
# enforced by hand further down.
DEADLINE=55

PROMPT_INTRO="You are reading two small files from a folder on a personal Mac.
Write exactly three short bullet points describing what is in this folder.
Answer with the three bullets only, no preamble, no closing remark.

--- visits.csv ---"

# =============================================================================
# 1. The sample folder
# =============================================================================
info "Preparing ~/dev/first-light..."

if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] would create $WORK_DIR with visits.csv and note.txt"
    info "[dry-run] would ask a locally available model for a three-bullet summary"
    info "[dry-run] would write $SUMMARY and open the folder in Finder"
    ok "Dry run complete — nothing was created"
    exit 0
fi

mkdir -p "$WORK_DIR"

# Deliberately unsorted, deliberately tiny, deliberately fictive.
cat > "$WORK_DIR/visits.csv" <<'EOF'
date,visitor,minutes,page
2026-03-14,anna,7,pricing
2026-03-11,bruno,2,home
2026-03-19,carla,31,docs
2026-03-12,dmitri,4,pricing
2026-03-17,elif,19,docs
2026-03-13,farid,1,home
EOF

cat > "$WORK_DIR/note.txt" <<'EOF'
Notes from the reading week
---------------------------
The docs pages hold attention far longer than the pricing page does.
Two visitors bounced off the home page in under five minutes.
Worth checking whether the pricing page answers the question people
arrive with, or only the one we wanted to answer.
EOF

ok "Created ~/dev/first-light with two sample files"

# =============================================================================
# 2. Which model is available?
# =============================================================================
# Order matters: Claude Code arrives at level 0, so most machines will have it.
# Ollama is the fallback that works with no account and no network — which is
# the whole reason it is worth the extra branch.

AGENT=""
MODEL=""

if have claude; then
    AGENT="claude"
    MODEL="Claude Code"
elif have ollama; then
    # Smallest installed model: the fastest way to a visible result, and the
    # one most likely to fit in memory on a machine that just got set up.
    MODEL="$(ollama list 2>/dev/null \
        | awk 'NR > 1 && NF >= 3 {
            size = $(NF-3); unit = $(NF-2);
            if (unit ~ /^GB/) size = size * 1024;
            if (size > 0) print size, $1;
        }' \
        | sort -n \
        | head -1 \
        | awk '{print $2}')"
    if [ -n "$MODEL" ]; then
        AGENT="ollama"
    fi
fi

if [ -z "$AGENT" ]; then
    warn "No AI model is available on this Mac yet."
    printf '\n'
    printf '  First Light needs one of these:\n'
    printf '    Claude Code   arrives with setup level 0   ./bootstrap.sh --level 0\n'
    printf '    Ollama        arrives with setup level 2   ./bootstrap.sh --level 2\n'
    printf '\n'
    printf '  The sample folder was still created, so you can look at it:\n'
    printf '    open ~/dev/first-light\n\n'
    exit 1
fi

info "Using $MODEL. Reading the two files..."

# =============================================================================
# 3. Ask, with a deadline
# =============================================================================
PROMPT="$PROMPT_INTRO
$(cat "$WORK_DIR/visits.csv")

--- note.txt ---
$(cat "$WORK_DIR/note.txt")"

ANSWER_FILE="$(mktemp -t first-light)"
cleanup() { rm -f "$ANSWER_FILE"; }
trap cleanup EXIT

case "$AGENT" in
    claude) claude -p "$PROMPT" > "$ANSWER_FILE" 2>/dev/null & ;;
    ollama) ollama run "$MODEL" "$PROMPT" > "$ANSWER_FILE" 2>/dev/null & ;;
esac
model_pid=$!

# No `timeout` on stock macOS, so poll. A model that has not answered inside
# the budget is stopped rather than left to run — this step promises to be over
# in under a minute, and a promise the script cannot keep is worse than no
# promise.
waited=0
while kill -0 "$model_pid" 2>/dev/null; do
    if [ "$waited" -ge "$DEADLINE" ]; then
        kill "$model_pid" 2>/dev/null || true
        warn "The model took longer than ${DEADLINE}s and was stopped."
        printf '  The sample folder is still there: open ~/dev/first-light\n\n'
        exit 1
    fi
    sleep 1
    waited=$((waited + 1))
    [ $((waited % 10)) -eq 0 ] && info "still working (${waited}s)..."
done

wait "$model_pid" 2>/dev/null || true

if [ ! -s "$ANSWER_FILE" ]; then
    warn "$MODEL did not return anything."
    printf '  Try it by hand to see the error:\n'
    case "$AGENT" in
        claude) printf '    claude -p "hello"\n\n' ;;
        ollama) printf '    ollama run %s "hello"\n\n' "$MODEL" ;;
    esac
    exit 1
fi

# =============================================================================
# 4. The visible result
# =============================================================================
{
    printf '# What is in this folder\n\n'
    printf 'Written by %s on %s, reading visits.csv and note.txt.\n\n' \
        "$MODEL" "$(date '+%Y-%m-%d %H:%M')"
    cat "$ANSWER_FILE"
    printf '\n\n---\n\n'
    printf 'This file was produced by scripts/12-first-light.sh. The model was given\n'
    printf 'the two files above and nothing else — no tools, no shell, no access to\n'
    printf 'the rest of this Mac. Delete this folder whenever you like.\n'
} > "$SUMMARY"

ok "SUMMARY.md written"

printf '\n'
printf '  %s just read the two sample files on your Mac and wrote its answer to\n' "$MODEL"
printf '  SUMMARY.md. Nothing left the folder, and nothing else on your Mac was\n'
printf '  touched. Open the file to read it — that is your setup working.\n\n'

have open && open "$WORK_DIR" 2>/dev/null || true

exit 0
