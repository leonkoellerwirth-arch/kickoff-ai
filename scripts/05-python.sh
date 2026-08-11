#!/usr/bin/env bash
# =============================================================================
# scripts/05-python.sh — Python stack
#
# Purpose:  uv as the primary Python manager, pipx fallback,
#           Miniforge optional for Conda/notebook needs
# Changes:  ~/.local/bin (uv, pipx), optionally ~/miniforge3
# Requires: Homebrew (module 02)
# Usage:    ./scripts/05-python.sh [--dry-run] [--yes] [--full]
#
# NOTE: uv is the standard path. Conda/Miniforge only for special
#       notebook use (ML courses, SPSS analysis). NOTHING is installed
#       in conda-base — projects use their own envs.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

FULL_MODE="${FULL_MODE:-0}"

parse_module_args "${BASH_SOURCE[0]}" "$@"

step "05 · Python stack"

# =============================================================================
# uv — primary Python manager
# =============================================================================
info "Checking uv..."

if have uv; then
    UV_VERSION=$(uv --version 2>/dev/null || echo "?")
    ok "uv $UV_VERSION present"
else
    info "Installing uv (via brew)..."
    run brew install uv
fi

# =============================================================================
# Python 3.13 via uv
# =============================================================================
info "Checking Python 3.13 via uv..."

if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] Would run: uv python install 3.13"
else
    if uv python list 2>/dev/null | grep -q "3\.13"; then
        ok "Python 3.13 already available via uv"
    else
        uv python install 3.13
        ok "Python 3.13 installed via uv"
    fi
fi

# =============================================================================
# uv quick-reference
# =============================================================================
info "Key uv commands:"
info "  uv init my-project        → Create a new Python project"
info "  uv add fastapi            → Add a dependency"
info "  uv run python main.py     → Run inside the project venv"
info "  uv tool install ruff      → Install a CLI tool (like pipx)"
info "  uv python install 3.x     → Install a Python version"

# =============================================================================
# Install uv tools (replaces pipx packages)
# =============================================================================
info "Installing uv tools (CLI tools via uv tool install)..."

# Useful tools from the inventory context
UV_TOOLS=(
    "ruff"
    "pre-commit"
    "httpie"
)

for tool in "${UV_TOOLS[@]}"; do
    if uv tool list 2>/dev/null | grep -q "^$tool "; then
        ok "  uv tool: $tool (present)"
    else
        info "  Installing: $tool"
        run uv tool install "$tool"
    fi
done

# =============================================================================
# pipx — present (from brew), but primarily replaced by uv tools
# =============================================================================
info "Checking pipx..."
if have pipx; then
    ok "pipx $(pipx --version) present (fallback for packages uv doesn't know)"
else
    info "Installing pipx via brew..."
    run brew install pipx
    run pipx ensurepath
fi

# =============================================================================
# nano-pdf via uv (was already installed, inventory §4)
# =============================================================================
info "Checking nano-pdf (uv tool)..."
if uv tool list 2>/dev/null | grep -q "^nano-pdf "; then
    ok "nano-pdf already installed"
else
    info "Installing nano-pdf..."
    run uv tool install nano-pdf
fi

# =============================================================================
# Miniforge — OPTIONAL, only via --full
# =============================================================================
if [ "$FULL_MODE" = "1" ]; then
    info "Optional: Miniforge (--full enabled)..."
    MINIFORGE_DIR="$HOME/miniforge3"

    if [ -d "$MINIFORGE_DIR" ]; then
        ok "Miniforge already present: $MINIFORGE_DIR"
        CONDA_VERSION=$("$MINIFORGE_DIR/bin/conda" --version 2>/dev/null || echo "?")
        ok "conda $CONDA_VERSION"
        warn "REMINDER: conda base contains ${MINIFORGE_DIR}/bin — this can shadow 'python3'."
        warn "Projects should use their own conda envs or uv venvs, NOT install into base."
    else
        warn "Miniforge is NOT installed."
        warn "For notebook/ML work it can be installed with:"
        warn "  curl -L https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-arm64.sh | bash"
        warn "Then: conda init zsh (for the notebook shell only!)"
        warn "Do NOT install anything into conda-base — use dedicated envs only."
        if confirm "Install Miniforge now?"; then
            if [ "$DRY_RUN" = "1" ]; then
                info "[dry-run] Would install: Miniforge3"
            else
                MINIFORGE_INSTALLER="/tmp/miniforge-installer.sh"
                curl -L "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-MacOSX-arm64.sh" -o "$MINIFORGE_INSTALLER"
                bash "$MINIFORGE_INSTALLER" -b -p "$MINIFORGE_DIR"
                rm -f "$MINIFORGE_INSTALLER"
                "$MINIFORGE_DIR/bin/conda" init zsh
                ok "Miniforge installed in $MINIFORGE_DIR"
                warn "Important: do NOT fill conda-base with packages!"
            fi
        fi
    fi
else
    info "Miniforge installation skipped (use --full to install)"
    if [ -d "$HOME/miniforge3" ]; then
        warn "Miniforge already exists at ~/miniforge3"
        warn "Note: the existing conda-base is over-populated with packages (anti-pattern)."
        warn "Recommendation: create new projects with 'uv', use Conda only for specific ML envs."
    fi
fi

# =============================================================================
# Check python3 path
# =============================================================================
info "Checking python3 path..."
PYTHON3_PATH=$(which python3 2>/dev/null || echo "not found")
info "  python3 → $PYTHON3_PATH"
PYTHON3_VERSION=$(python3 --version 2>/dev/null || echo "not available")
info "  Version: $PYTHON3_VERSION"

if echo "$PYTHON3_PATH" | grep -q "miniforge"; then
    warn "python3 comes from conda-base ($PYTHON3_PATH)."
    warn "This is the existing Miniforge installation (conda 22.11.1, Python 3.10.9 — outdated)."
    warn "For new projects: use 'uv run python ...' or 'uv venv'."
fi

ok "Module 05 (Python) complete."
