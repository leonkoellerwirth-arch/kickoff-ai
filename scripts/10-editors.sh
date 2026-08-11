#!/usr/bin/env bash
# =============================================================================
# scripts/10-editors.sh — Editors and IDE configuration
#
# Purpose:  Install VS Code, install extensions,
#           maintain config/vscode-extensions.txt as reference.
# Changes:  /Applications/Visual Studio Code.app (cask),
#           VS Code extension directory (~/.vscode/extensions)
# Requires: Homebrew (module 02)
# Usage:    ./scripts/10-editors.sh [--dry-run] [--yes]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib.sh"

parse_module_args "${BASH_SOURCE[0]}" "$@"

step "10 · Editors"

# =============================================================================
# Install VS Code
# =============================================================================
info "Checking VS Code..."

VSCODE_APP="/Applications/Visual Studio Code.app"
CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

if [ -d "$VSCODE_APP" ]; then
    VSCODE_VERSION=$(cat "$VSCODE_APP/Contents/Resources/app/package.json" 2>/dev/null | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('version','?'))" 2>/dev/null || echo "?")
    ok "VS Code $VSCODE_VERSION present"
else
    info "Installing VS Code via brew cask..."
    run brew install --cask visual-studio-code
    ok "VS Code installed"
fi

# code CLI available?
if [ -f "$CODE_BIN" ] || have code; then
    CODE_CMD=$(have code && echo "code" || echo "$CODE_BIN")
    ok "code CLI available: $CODE_CMD"
else
    warn "code CLI not in PATH."
    warn "Open VS Code → Cmd+Shift+P → 'Shell Command: Install code in PATH'"
    CODE_CMD=""
fi

# =============================================================================
# Install VS Code extensions
# =============================================================================
EXTENSIONS_FILE="$REPO_DIR/config/vscode-extensions.txt"

if [ -z "$CODE_CMD" ]; then
    warn "Extensions cannot be installed — code CLI missing"
    warn "Please run 'Shell Command: Install code in PATH' in VS Code"
    warn "Then: code --install-extension <id> for each line in config/vscode-extensions.txt"
elif [ ! -f "$EXTENSIONS_FILE" ]; then
    warn "config/vscode-extensions.txt not found"
else
    info "Installing VS Code extensions from $EXTENSIONS_FILE..."

    # Determine already-installed extensions
    INSTALLED=$($CODE_CMD --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")

    INSTALLED_COUNT=0
    NEWLY_INSTALLED=0
    FAILED=0

    while IFS= read -r line; do
        # Skip comments and empty lines
        case "$line" in
            "#"*|"") continue ;;
        esac
        EXT_ID=$(echo "$line" | tr -d '[:space:]')
        [ -z "$EXT_ID" ] && continue

        EXT_ID_LOWER=$(echo "$EXT_ID" | tr '[:upper:]' '[:lower:]')

        if echo "$INSTALLED" | grep -qx "$EXT_ID_LOWER"; then
            INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
        else
            if [ "$DRY_RUN" = "1" ]; then
                info "[dry-run] Would install: $EXT_ID"
                NEWLY_INSTALLED=$((NEWLY_INSTALLED + 1))
            else
                if $CODE_CMD --install-extension "$EXT_ID" --force 2>/dev/null; then
                    NEWLY_INSTALLED=$((NEWLY_INSTALLED + 1))
                else
                    warn "  Could not install: $EXT_ID"
                    FAILED=$((FAILED + 1))
                fi
            fi
        fi
    done < "$EXTENSIONS_FILE"

    ok "Extensions: $INSTALLED_COUNT already present, $NEWLY_INSTALLED newly installed, $FAILED failed"
fi

# =============================================================================
# Postman (cask — already present per inventory)
# =============================================================================
info "Checking Postman..."

if [ -d "/Applications/Postman.app" ]; then
    ok "Postman present"
else
    if confirm "Install Postman?"; then
        run brew install --cask postman
    fi
fi

# =============================================================================
# JetBrains Toolbox notice
# =============================================================================
if [ -d "$HOME/Library/Application Support/JetBrains/Toolbox" ]; then
    ok "JetBrains Toolbox present"
    if have idea; then
        ok "IntelliJ IDEA available via Toolbox"
    fi
else
    info "JetBrains Toolbox not installed."
    info "Manual: https://www.jetbrains.com/toolbox-app/"
fi

ok "Module 10 (Editors) complete."
