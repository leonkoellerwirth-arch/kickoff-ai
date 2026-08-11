#!/usr/bin/env bash
# =============================================================================
# scripts/11-paved-road.sh — ~/dev structure and dev/base paved road
#
# Purpose:  Create ~/dev directory, clone or link ~/dev/base,
#           and add ~/dev/base/bin to PATH.
#           ~/dev/base is the custom meta-repo that provides standards and
#           scaffolding templates for all projects.
# Changes:  ~/dev, ~/dev/base (clone), ~/.zshrc (PATH addition via
#           config/zshrc), optionally ~/.zshrc.local
# Requires: Shell config (module 03), Git/SSH (module 08)
# Usage:    ./scripts/11-paved-road.sh [--dry-run] [--yes]
#           Environment variable: BASE_REPO_URL → target URL of the base repo
#           (default: interactive prompt; skipped when --yes is active)
# =============================================================================
set -euo pipefail
# shellcheck disable=SC2088  # Tilde in display strings is intentional (display-only)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

parse_module_args "${BASH_SOURCE[0]}" "$@"

step "11 · Paved Road (~/dev structure)"

DEV_DIR="$HOME/dev"
BASE_DIR="$DEV_DIR/base"

# =============================================================================
# Create ~/dev
# =============================================================================
info "Checking ~/dev directory..."

if [ -d "$DEV_DIR" ]; then
    ok "$HOME/dev already present"
else
    info "Creating ~/dev..."
    run mkdir -p "$DEV_DIR"
    ok "$HOME/dev created"
fi

# =============================================================================
# ~/dev/base — clone or notice
# =============================================================================
info "Checking ~/dev/base..."

if [ -d "$BASE_DIR/.git" ]; then
    ok "$HOME/dev/base already cloned"
    BASE_REMOTE=$(git -C "$BASE_DIR" remote get-url origin 2>/dev/null || echo "no remote")
    info "  Remote: $BASE_REMOTE"

    # Update?
    if confirm "Update $HOME/dev/base (git pull)?"; then
        run git -C "$BASE_DIR" pull --rebase
        ok "$HOME/dev/base updated"
    fi

elif [ -d "$BASE_DIR" ]; then
    warn "$HOME/dev/base exists but is not a Git repo (no .git/)."
    warn "Please check manually."

else
    info "Cloning $HOME/dev/base..."

    # Determine URL
    if [ -n "${BASE_REPO_URL:-}" ]; then
        REPO_URL="$BASE_REPO_URL"
        info "Using BASE_REPO_URL: $REPO_URL"
    elif [ "$YES_MODE" = "1" ]; then
        warn "BASE_REPO_URL not set and --yes active."
        warn "$HOME/dev/base will NOT be cloned."
        warn "Manual: git clone <your-base-repo-url> ~/dev/base"
        REPO_URL=""
    else
        info "$HOME/dev/base is your personal meta-repo with standards and templates."
        info "If you don't have a base repo yet, you can create one later:"
        info "  git init ~/dev/base && cd ~/dev/base"
        printf "%s  Git URL for ~/dev/base (leave blank to skip): %s" "$_YELLOW" "$_RESET" >&2
        read -r REPO_URL </dev/tty
        REPO_URL="${REPO_URL:-}"
    fi

    if [ -n "$REPO_URL" ]; then
        if [ "$DRY_RUN" = "1" ]; then
            info "[dry-run] Would clone: git clone $REPO_URL $BASE_DIR"
        else
            git clone "$REPO_URL" "$BASE_DIR"
            ok "$HOME/dev/base cloned from $REPO_URL"
        fi
    else
        info "$HOME/dev/base will not be cloned — PATH entry will still be prepared."
        if [ "$DRY_RUN" != "1" ]; then
            mkdir -p "$BASE_DIR/bin"
            ok "$HOME/dev/base/bin created (empty)"
        fi
    fi
fi

# =============================================================================
# ~/dev/base/bin in PATH (via ~/.zshrc.local)
# =============================================================================
info "Checking ~/dev/base/bin in PATH..."

BASE_BIN="$BASE_DIR/bin"
ZSHRC_LOCAL="$HOME/.zshrc.local"

if [ -d "$BASE_BIN" ] || [ "$DRY_RUN" = "1" ]; then
    # PATH check
    if echo "$PATH" | tr ':' '\n' | grep -qx "$BASE_BIN"; then
        ok "$HOME/dev/base/bin already in PATH"
    else
        # config/zshrc already includes the PATH entry directly
        # Check ~/.zshrc.local override as fallback:
        if [ -f "$ZSHRC_LOCAL" ]; then
            if ! grep -q "dev/base/bin" "$ZSHRC_LOCAL" 2>/dev/null; then
                info "Note: PATH for $HOME/dev/base/bin is defined in config/zshrc."
                info "Please open a new shell for the change to take effect."
            fi
        fi
        ok "$HOME/dev/base/bin is defined in PATH via config/zshrc — open a new shell"
    fi
else
    warn "$HOME/dev/base/bin does not exist — PATH entry prepared but empty."
fi

# =============================================================================
# base commands available?
# =============================================================================
if [ -f "$BASE_BIN/base" ]; then
    ok "base CLI available: $BASE_BIN/base"
    info "Available commands:"
    info "  base list         → Show all repos and their status"
    info "  base new <tmpl> <name> → Create a new project from a template"
    info "  base sync         → Push standards to existing repos"
    info "  base doctor       → Repo quality check"
    info "  base lessons      → Show learned lessons"
else
    info "base CLI not found yet."
    info "After cloning ~/dev/base: chmod +x ~/dev/base/bin/base"
fi

# =============================================================================
# ~/dev subdirectories (convention)
# =============================================================================
info "Creating standard subdirectories in ~/dev..."

DEV_SUBDIRS=(
    "ai"
    "scripts"
    "tmp"
)

for subdir in "${DEV_SUBDIRS[@]}"; do
    TARGET="$DEV_DIR/$subdir"
    if [ -d "$TARGET" ]; then
        ok "  ~/dev/$subdir present"
    else
        run mkdir -p "$TARGET"
        ok "  ~/dev/$subdir created"
    fi
done

ok "Module 11 (Paved Road) complete."
