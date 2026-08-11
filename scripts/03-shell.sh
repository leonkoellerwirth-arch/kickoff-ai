#!/usr/bin/env bash
# =============================================================================
# scripts/03-shell.sh — Shell configuration
#
# Purpose:  Install oh-my-zsh, Powerlevel10k theme, plugins,
#           install config/zshrc + config/zprofile as symlinks
# Changes:  ~/.zshrc, ~/.zprofile, ~/.oh-my-zsh (installation),
#           ZSH custom directory (plugins)
# Requires: Homebrew installed (module 02)
# Usage:    ./scripts/03-shell.sh [--dry-run] [--yes]
# =============================================================================
set -euo pipefail
# shellcheck disable=SC2088  # Tilde in display strings is intentional (display-only)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib.sh"

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1; export DRY_RUN ;;
        --yes)     YES_MODE=1; export YES_MODE ;;
    esac
done

step "03 · Shell configuration"

# =============================================================================
# Install oh-my-zsh
# =============================================================================
info "Checking oh-my-zsh..."

OMZ_DIR="$HOME/.oh-my-zsh"
if [ -d "$OMZ_DIR" ]; then
    ok "oh-my-zsh already present: $OMZ_DIR"
else
    info "Installing oh-my-zsh..."
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would install: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
    else
        # --unattended prevents oh-my-zsh from overwriting .zshrc
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        ok "oh-my-zsh installed"
    fi
fi

# =============================================================================
# Powerlevel10k theme
# =============================================================================
info "Checking Powerlevel10k..."

P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ -d "$P10K_DIR" ]; then
    ok "Powerlevel10k already present"
else
    info "Installing Powerlevel10k..."
    run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    ok "Powerlevel10k installed"
fi

# =============================================================================
# ZSH plugins
# =============================================================================
info "Checking ZSH plugins..."

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# zsh-autosuggestions
PLUGIN_AS="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
if [ -d "$PLUGIN_AS" ]; then
    ok "Plugin present: zsh-autosuggestions"
else
    info "Installing zsh-autosuggestions..."
    run git clone https://github.com/zsh-users/zsh-autosuggestions "$PLUGIN_AS"
    ok "Plugin installed: zsh-autosuggestions"
fi

# zsh-syntax-highlighting
PLUGIN_SH="$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
if [ -d "$PLUGIN_SH" ]; then
    ok "Plugin present: zsh-syntax-highlighting"
else
    info "Installing zsh-syntax-highlighting..."
    run git clone https://github.com/zsh-users/zsh-syntax-highlighting "$PLUGIN_SH"
    ok "Plugin installed: zsh-syntax-highlighting"
fi

# =============================================================================
# Install config/zprofile
# =============================================================================
info "Installing config/zprofile → ~/.zprofile..."

CONFIG_ZPROFILE="$REPO_DIR/config/zprofile"
TARGET_ZPROFILE="$HOME/.zprofile"

if [ ! -f "$CONFIG_ZPROFILE" ]; then
    err "config/zprofile not found: $CONFIG_ZPROFILE"
fi

if [ -e "$TARGET_ZPROFILE" ] && [ ! -L "$TARGET_ZPROFILE" ]; then
    # Exists as a real file, not a symlink
    if confirm "$HOME/.zprofile exists and will be backed up + replaced. OK?"; then
        backup_file "$TARGET_ZPROFILE"
        run ln -sf "$CONFIG_ZPROFILE" "$TARGET_ZPROFILE"
        ok "$HOME/.zprofile → $CONFIG_ZPROFILE"
    else
        warn "$HOME/.zprofile will not be replaced."
    fi
elif [ -L "$TARGET_ZPROFILE" ]; then
    # Already a symlink
    CURRENT_TARGET=$(readlink "$TARGET_ZPROFILE" 2>/dev/null || echo "?")
    if [ "$CURRENT_TARGET" = "$CONFIG_ZPROFILE" ]; then
        ok "$HOME/.zprofile is already linked correctly"
    else
        warn "$HOME/.zprofile points to: $CURRENT_TARGET"
        if confirm "Change symlink to $CONFIG_ZPROFILE?"; then
            run ln -sf "$CONFIG_ZPROFILE" "$TARGET_ZPROFILE"
            ok "$HOME/.zprofile → $CONFIG_ZPROFILE"
        fi
    fi
else
    run ln -sf "$CONFIG_ZPROFILE" "$TARGET_ZPROFILE"
    ok "$HOME/.zprofile → $CONFIG_ZPROFILE"
fi

# =============================================================================
# Install config/zshrc
# =============================================================================
info "Installing config/zshrc → ~/.zshrc..."

CONFIG_ZSHRC="$REPO_DIR/config/zshrc"
TARGET_ZSHRC="$HOME/.zshrc"

if [ ! -f "$CONFIG_ZSHRC" ]; then
    err "config/zshrc not found: $CONFIG_ZSHRC"
fi

if [ -e "$TARGET_ZSHRC" ] && [ ! -L "$TARGET_ZSHRC" ]; then
    if confirm "$HOME/.zshrc exists and will be backed up + replaced. OK?"; then
        backup_file "$TARGET_ZSHRC"
        run ln -sf "$CONFIG_ZSHRC" "$TARGET_ZSHRC"
        ok "$HOME/.zshrc → $CONFIG_ZSHRC"
    else
        warn "$HOME/.zshrc will not be replaced."
    fi
elif [ -L "$TARGET_ZSHRC" ]; then
    CURRENT_TARGET=$(readlink "$TARGET_ZSHRC" 2>/dev/null || echo "?")
    if [ "$CURRENT_TARGET" = "$CONFIG_ZSHRC" ]; then
        ok "$HOME/.zshrc is already linked correctly"
    else
        warn "$HOME/.zshrc points to: $CURRENT_TARGET"
        if confirm "Change symlink to $CONFIG_ZSHRC?"; then
            run ln -sf "$CONFIG_ZSHRC" "$TARGET_ZSHRC"
            ok "$HOME/.zshrc → $CONFIG_ZSHRC"
        fi
    fi
else
    run ln -sf "$CONFIG_ZSHRC" "$TARGET_ZSHRC"
    ok "$HOME/.zshrc → $CONFIG_ZSHRC"
fi

# =============================================================================
# p10k configuration (if present)
# =============================================================================
if [ -f "$HOME/.p10k.zsh" ]; then
    ok "$HOME/.p10k.zsh already present"
else
    warn "$HOME/.p10k.zsh not found."
    warn "On first start of a new shell, p10k will run the configuration wizard."
    warn "Or copy an existing .p10k.zsh file to ~/.p10k.zsh"
fi

ok "Module 03 (Shell) complete."
info "Important: please open a new shell session for the configuration to take effect."
