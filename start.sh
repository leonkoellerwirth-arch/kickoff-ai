#!/usr/bin/env bash
# =============================================================================
# start.sh — open the Control Room, kickoff-ai's local app
#
# Purpose:  One command that opens a dashboard, a step-by-step guide and the
#           tool registry in the browser, so nothing about setting up this Mac
#           has to be guessed from a README.
# Changes:  Nothing on the machine. It starts a local server on 127.0.0.1 and
#           opens a browser tab. Setup steps that install something are handed
#           to Terminal.app from inside the app, never run by the server.
# Requires: python3 (ships with the Xcode Command Line Tools, which prepare.sh
#           installs). Nothing else — no Homebrew, no node, no npm.
# Usage:    ./start.sh [options]
#
# Options:
#   --no-open      Do not open a browser; just print the address
#   --port <n>     Use this port instead of searching from 8787 upwards
#   --stop         Stop a Control Room started earlier, then exit
#   --dry-run      Print what would happen, start nothing
#   --help, -h     Show this help
#
# Exit codes:
#   0  started (or stopped, or printed help)
#   1  could not start — the reason is printed
#   2  unknown option
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

SERVER="$ROOT_DIR/app/server.py"
PORT_FILE="$ROOT_DIR/local/.app-port"
PORT_DEFAULT=8787
PORT=""
OPEN=1
STOP=0
DRY_RUN=0

usage() { sed -n '2,29p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
        --no-open) OPEN=0 ;;
        --stop) STOP=1 ;;
        --dry-run) DRY_RUN=1 ;;
        --port)
            shift
            PORT="${1:-}"
            ;;
        --port=*) PORT="${1#--port=}" ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [ -n "$PORT" ] && ! printf '%s' "$PORT" | grep -qE '^[0-9]{2,5}$'; then
    printf 'Not a port number: %s\n' "$PORT" >&2
    exit 1
fi

# --- --stop ------------------------------------------------------------------
# Only ever stops a server this script started: the port comes from the file we
# wrote, and the process must actually be our server.py. Never kill by name.
if [ "$STOP" = 1 ]; then
    stopped=0
    if [ -f "$PORT_FILE" ]; then
        known_port="$(cat "$PORT_FILE" 2>/dev/null || true)"
        if [ -n "$known_port" ] && command -v lsof >/dev/null 2>&1; then
            for pid in $(lsof -ti tcp:"$known_port" 2>/dev/null || true); do
                if ps -o command= -p "$pid" 2>/dev/null | grep -q "app/server.py"; then
                    kill "$pid" 2>/dev/null && stopped=1
                fi
            done
        fi
        rm -f "$PORT_FILE"
    fi
    if [ "$stopped" = 1 ]; then
        echo "Control Room stopped."
    else
        echo "No Control Room was running."
    fi
    exit 0
fi

# --- python3 -----------------------------------------------------------------
# On a brand-new Mac /usr/bin/python3 exists as a stub that only works once the
# Command Line Tools are installed. Test that it actually runs, and if it does
# not, name the one command that fixes it rather than letting a dialog surprise
# the user.
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'pass' >/dev/null 2>&1; then
    cat >&2 <<'EOF'
python3 is not available yet.

It comes with the Xcode Command Line Tools, which are the very first thing this
setup installs. Run this once, confirm the dialog, wait for it to finish:

  ./prepare.sh

Then run ./start.sh again.
EOF
    exit 1
fi

if [ ! -f "$SERVER" ]; then
    printf 'Missing %s — is this a complete clone of the repository?\n' "$SERVER" >&2
    exit 1
fi

# --- pick a port -------------------------------------------------------------
port_free() {
    command -v lsof >/dev/null 2>&1 || return 0
    [ -z "$(lsof -ti tcp:"$1" 2>/dev/null || true)" ]
}

if [ -z "$PORT" ]; then
    candidate=$PORT_DEFAULT
    limit=$((PORT_DEFAULT + 20))
    while [ "$candidate" -lt "$limit" ]; do
        if port_free "$candidate"; then
            PORT=$candidate
            break
        fi
        candidate=$((candidate + 1))
    done
    if [ -z "$PORT" ]; then
        printf 'No free port between %s and %s.\n' "$PORT_DEFAULT" "$limit" >&2
        exit 1
    fi
elif ! port_free "$PORT"; then
    printf 'Port %s is already in use. Pick another with --port, or run ./start.sh --stop.\n' "$PORT" >&2
    exit 1
fi

URL="http://127.0.0.1:$PORT/"

if [ "$DRY_RUN" = 1 ]; then
    echo "Would start: python3 app/server.py"
    echo "Would listen on: $URL"
    [ "$OPEN" = 1 ] && echo "Would open that address in the browser."
    echo "Would write the port to: local/.app-port"
    echo "Nothing was started."
    exit 0
fi

mkdir -p "$ROOT_DIR/local"
printf '%s\n' "$PORT" > "$PORT_FILE"
# The server generates its own session token; nothing is written to disk.
cleanup() { rm -f "$PORT_FILE"; }
trap cleanup EXIT INT TERM

echo
echo "  kickoff-ai — Control Room"
echo "  $URL"
echo
echo "  Everything runs on this Mac. Nothing is sent anywhere."
echo "  Press Ctrl-C here to close it."
echo

if [ "$OPEN" = 1 ] && command -v open >/dev/null 2>&1; then
    # Give the server a moment to bind before the browser asks for the page.
    (sleep 1 && open "$URL") &
fi

APP_PORT="$PORT" exec python3 "$SERVER"
