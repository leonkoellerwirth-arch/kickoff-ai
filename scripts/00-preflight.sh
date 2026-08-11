#!/usr/bin/env bash
# =============================================================================
# scripts/00-preflight.sh — Preflight checks
#
# Purpose:  Verifies all prerequisites before anything is installed
# Changes:  Nothing — read-only (except Rosetta installation if needed)
# Requires: Nothing
# Usage:    ./scripts/00-preflight.sh [--dry-run] [--yes]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# Read flags from arguments (for standalone invocation)
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1; export DRY_RUN ;;
        --yes)     YES_MODE=1; export YES_MODE ;;
    esac
done

step "00 · Preflight checks"

# =============================================================================
# 1. Operating system
# =============================================================================
info "Checking operating system..."
if ! is_macos; then
    err "This setup system is for macOS only. Current OS: $(uname -s)"
fi
ok "macOS detected"

# =============================================================================
# 2. Architecture
# =============================================================================
info "Checking CPU architecture..."
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    warn "Expected arm64 (Apple Silicon), found: $ARCH"
    warn "This setup is optimized for M-series Macs. Intel Macs are not supported."
    confirm "Continue anyway?" || err "Aborted."
else
    ok "Apple Silicon (arm64) detected"
fi

# =============================================================================
# 3. macOS version
# =============================================================================
info "Checking macOS version..."
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)

if [ "$MACOS_MAJOR" -lt 15 ]; then
    err "macOS 15 (Sequoia) or later required. Found: $MACOS_VERSION"
fi
ok "macOS $MACOS_VERSION — OK"

# =============================================================================
# 4. Free disk space
# =============================================================================
info "Checking free disk space..."
# df -k returns KB; convert to GB
FREE_KB=$(df -k "$HOME" | awk 'NR==2 {print $4}')
FREE_GB=$(( FREE_KB / 1024 / 1024 ))

if [ "$FREE_GB" -lt 20 ]; then
    warn "Only ${FREE_GB} GB free (recommended: at least 20 GB)."
    warn "Tip: clean up Docker images (docker system prune), check Ollama models."
    confirm "Continue anyway?" || err "Aborted — not enough disk space."
elif [ "$FREE_GB" -lt 40 ]; then
    warn "Only ${FREE_GB} GB free. Setup needs approx. 10–15 GB."
    ok "Warning noted, continuing."
else
    ok "${FREE_GB} GB free — sufficient"
fi

# =============================================================================
# 5. Network connection
# =============================================================================
info "Checking network connection..."
if ! curl -sf --max-time 10 https://www.apple.com >/dev/null 2>&1; then
    err "No internet connection. Please check your network."
fi
ok "Internet connection available"

# =============================================================================
# 6. sudo access
# =============================================================================
info "Checking sudo access..."
if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] sudo check skipped (no password needed in dry-run)"
elif ! sudo -n true 2>/dev/null; then
    info "Sudo password required for setup (once)."
    sudo -v || err "No sudo access. Please run as an administrator."
fi
ok "sudo access confirmed"

# =============================================================================
# 7. Rosetta 2 (for x86 compatibility)
# =============================================================================
info "Checking Rosetta 2..."
if [ "$ARCH" = "arm64" ]; then
    if ! /usr/bin/pgrep -q oahd 2>/dev/null; then
        # Check whether Rosetta is installed (alternative check)
        if ! arch -x86_64 /usr/bin/true 2>/dev/null; then
            info "Installing Rosetta 2 (for x86-compatible tools)..."
            run /usr/sbin/softwareupdate --install-rosetta --agree-to-license
            ok "Rosetta 2 installed"
        else
            ok "Rosetta 2 already active (via arch support)"
        fi
    else
        ok "Rosetta 2 (oahd) running"
    fi
fi

# =============================================================================
# 8. Xcode Command Line Tools present?
# =============================================================================
info "Checking Command Line Tools..."
if xcode-select -p >/dev/null 2>&1; then
    CLT_PATH=$(xcode-select -p)
    ok "Developer Tools: $CLT_PATH"
else
    warn "Command Line Tools not found — will be installed in module 01."
fi

# =============================================================================
# 9. Shell is zsh?
# =============================================================================
info "Checking current shell..."
CURRENT_SHELL=$(basename "$SHELL")
if [ "$CURRENT_SHELL" != "zsh" ]; then
    warn "Default shell is '$CURRENT_SHELL', not zsh."
    warn "Setup is optimized for zsh. Switch with: chsh -s /bin/zsh"
else
    ok "Shell: zsh"
fi

# =============================================================================
# Done
# =============================================================================
ok "All preflight checks passed."

# Keep sudo warm for the rest of the setup (not in dry-run)
if [ "${_BOOTSTRAP_MODE:-0}" = "1" ] && [ "$DRY_RUN" != "1" ]; then
    sudo_keepalive
    trap sudo_keepalive_stop EXIT
fi
