#!/usr/bin/env bash
# =============================================================================
# scripts/02-homebrew.sh — Homebrew + taps + Brewfile bundle
#
# Purpose:  Install Homebrew (if not present), register taps,
#           install Brewfile, optionally Brewfile.optional
# Changes:  /opt/homebrew, ~/Library/... (Homebrew files)
# Requires: CLT installed (module 01), internet connection
# Usage:    ./scripts/02-homebrew.sh [--dry-run] [--yes] [--full]
#
# Environment variables:
#   OVERRIDE_BREWFILE=<path>  Use an alternative Brewfile path
#                             (e.g. Brewfile.level0 for level 0)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib.sh"

FULL_MODE="${FULL_MODE:-0}"
# OVERRIDE_BREWFILE: if set, this Brewfile path is used instead of Brewfile
OVERRIDE_BREWFILE="${OVERRIDE_BREWFILE:-}"

parse_module_args "${BASH_SOURCE[0]}" "$@"

step "02 · Homebrew"

# =============================================================================
# Install Homebrew (if not present)
# =============================================================================
info "Checking Homebrew..."

if have brew; then
    BREW_VERSION=$(brew --version | head -1)
    ok "$BREW_VERSION present"
else
    info "Installing Homebrew..."
    warn "This requires sudo and an internet connection."
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    else
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add Homebrew to current PATH
        eval "$(/opt/homebrew/bin/brew shellenv)"
        ok "Homebrew installed"
    fi
fi

# Ensure Homebrew PATH
if [ -f "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# =============================================================================
# Update Homebrew
# =============================================================================
info "Updating Homebrew..."
run brew update

# =============================================================================
# Register taps
# =============================================================================
info "Registering taps..."

# Only required taps — OpenClaw/tap removed (OpenClaw is being uninstalled)
REQUIRED_TAPS=(
    "homebrew/services"
    "keith/formulae"
    "steipete/tap"
)

for tap in "${REQUIRED_TAPS[@]}"; do
    if brew tap | grep -qx "$tap" 2>/dev/null; then
        ok "  Tap already active: $tap"
    else
        info "  Adding tap: $tap"
        run brew tap "$tap"
    fi
done

# =============================================================================
# Select Brewfile (OVERRIDE_BREWFILE for level 0, otherwise Brewfile)
# =============================================================================

# If OVERRIDE_BREWFILE is set and exists → use it
if [ -n "$OVERRIDE_BREWFILE" ] && [ -f "$OVERRIDE_BREWFILE" ]; then
    ACTIVE_BREWFILE="$OVERRIDE_BREWFILE"
    info "Level-0 mode: using minimal Brewfile: $ACTIVE_BREWFILE"
else
    ACTIVE_BREWFILE="$REPO_DIR/Brewfile"
    if [ -n "$OVERRIDE_BREWFILE" ] && [ ! -f "$OVERRIDE_BREWFILE" ]; then
        warn "OVERRIDE_BREWFILE not found ($OVERRIDE_BREWFILE), using default Brewfile"
    fi
fi

info "Installing packages from $(basename "$ACTIVE_BREWFILE")..."

if [ ! -f "$ACTIVE_BREWFILE" ]; then
    err "Brewfile not found: $ACTIVE_BREWFILE"
fi

if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] Would run: brew bundle --file=$ACTIVE_BREWFILE"
    info "[dry-run] Formulae (excerpt):"
    grep -v "^#" "$ACTIVE_BREWFILE" | grep -v "^$" | grep -E "^brew |^cask " | head -20
else
    brew bundle --file="$ACTIVE_BREWFILE" --no-lock
    ok "Packages installed (from $(basename "$ACTIVE_BREWFILE"))"
fi

# =============================================================================
# Optional: Brewfile.optional
# =============================================================================
if [ "$FULL_MODE" = "1" ]; then
    info "Installing optional packages from Brewfile.optional (--full)..."
    if [ ! -f "$REPO_DIR/Brewfile.optional" ]; then
        warn "Brewfile.optional not found, skipping."
    elif [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would run: brew bundle --file=$REPO_DIR/Brewfile.optional"
    else
        brew bundle --file="$REPO_DIR/Brewfile.optional" --no-lock
        ok "Optional packages installed"
    fi
else
    info "Optional packages skipped (use --full to install)"
fi

# =============================================================================
# brew doctor (warnings)
# =============================================================================
info "Running brew doctor..."
if [ "$DRY_RUN" != "1" ]; then
    brew_doctor_out=$(brew doctor 2>&1 || true)
    if echo "$brew_doctor_out" | grep -q "Your system is ready to brew"; then
        ok "brew doctor: System ready"
    else
        warn "brew doctor reports:"
        echo "$brew_doctor_out" | grep -v "^$" | head -20 >&2
    fi
fi

# =============================================================================
# Ensure PATH order (brew before /usr/bin)
# =============================================================================
info "Checking PATH order..."
BREW_GIT_PATH="/opt/homebrew/bin/git"
if [ -f "$BREW_GIT_PATH" ]; then
    if [ "$(which git 2>/dev/null)" = "$BREW_GIT_PATH" ]; then
        ok "brew git takes priority in PATH"
    else
        warn "Note: /usr/bin/git still takes priority over brew git."
        warn "config/zprofile fixes this — please open a new shell."
    fi
fi

ok "Module 02 (Homebrew) complete."
