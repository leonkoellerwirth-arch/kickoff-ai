#!/usr/bin/env bash
# =============================================================================
# scripts/04-node.sh — Node stack
#
# Purpose:  nvm + Node 24 LTS, corepack, pnpm, bun, deno, global npm packages
# Changes:  ~/.nvm, ~/Library/pnpm, ~/.bun, global npm/pnpm packages
# Requires: Homebrew (module 02), shell config (module 03)
# Usage:    ./scripts/04-node.sh [--dry-run] [--yes]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1; export DRY_RUN ;;
        --yes)     YES_MODE=1; export YES_MODE ;;
    esac
done

step "04 · Node stack"

# Target Node version
NODE_TARGET="24"

# =============================================================================
# Install nvm
# =============================================================================
info "Checking nvm..."
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

if [ -s "$NVM_DIR/nvm.sh" ]; then
    ok "nvm already present: $NVM_DIR"
else
    info "Installing nvm..."
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would install: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash"
    else
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
        ok "nvm installed"
    fi
fi

# Load nvm
if [ -s "$NVM_DIR/nvm.sh" ]; then
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
fi

# =============================================================================
# Install Node LTS (v24)
# =============================================================================
info "Checking Node $NODE_TARGET..."

if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] Would run: nvm install $NODE_TARGET"
    info "[dry-run] Would run: nvm alias default $NODE_TARGET"
else
    if have nvm; then
        CURRENT_NODE=$(nvm current 2>/dev/null || echo "none")
        if echo "$CURRENT_NODE" | grep -q "^v${NODE_TARGET}"; then
            ok "Node $CURRENT_NODE already active"
        else
            nvm install "$NODE_TARGET"
            nvm alias default "$NODE_TARGET"
            nvm use default
            ok "Node $(node --version) installed and set as default"
        fi
    else
        warn "nvm not available in this shell. Please open a new shell and re-run."
    fi
fi

# =============================================================================
# pnpm (via brew, already in Brewfile)
# =============================================================================
info "Checking pnpm..."
if have pnpm; then
    ok "pnpm $(pnpm --version) present"
else
    info "Installing pnpm via brew..."
    run brew install pnpm
fi

# Configure PNPM_HOME
PNPM_HOME="$HOME/Library/pnpm"
if [ ! -d "$PNPM_HOME" ]; then
    mkdir -p "$PNPM_HOME"
fi

# =============================================================================
# Enable corepack
# =============================================================================
info "Enabling corepack..."
if have corepack; then
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would run: corepack enable"
    else
        corepack enable 2>/dev/null || warn "corepack enable failed (sudo may be needed)"
    fi
    ok "corepack present"
else
    warn "corepack not found — will be installed automatically with Node"
fi

# =============================================================================
# bun (via brew, already in Brewfile — or direct installer)
# =============================================================================
info "Checking bun..."
BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
if [ -f "$BUN_INSTALL/bin/bun" ] || have bun; then
    BUN_VERSION=$(bun --version 2>/dev/null || "$BUN_INSTALL/bin/bun" --version 2>/dev/null || echo "?")
    ok "bun $BUN_VERSION present"
else
    info "Installing bun..."
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would install: curl -fsSL https://bun.sh/install | bash"
    else
        curl -fsSL https://bun.sh/install | bash
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        ok "bun $(bun --version) installed"
    fi
fi

# =============================================================================
# deno (via brew, already in Brewfile)
# =============================================================================
info "Checking deno..."
if have deno; then
    ok "deno $(deno --version | head -1) present"
else
    info "Installing deno via brew..."
    run brew install deno
fi

# =============================================================================
# Global npm packages
# =============================================================================
info "Checking global npm packages..."

# Candidate packages from the inventory. The registry — not this list — decides
# what is actually installed (INV-8), and it is consulted for two things:
#
#   status: only `active` is installed. INV-1 says adoption is a deliberate
#           human step, so a `candidate` entry must never be installed by a
#           default run. Six of the seven packages below are candidates.
#   level:  only entries at or below the selected level. The README promises
#           levels are cumulative and bounded; installing level-3 tools during
#           a level-1 run makes that promise false.
#
# Adopt a candidate with: automation/bin/sunset adopt <id>
NPM_GLOBAL_PACKAGES=(
    "@kilocode/cli"
    "@steipete/oracle"
    "mcporter"
    "omniroute"
    "ruflo"
    "sharp-cli"
    "uipro-cli"
)

REGISTRY="$(cd "$SCRIPT_DIR/.." && pwd)/manifests/tools.yaml"
EFFECTIVE_LEVEL="${BOOTSTRAP_LEVEL:-2}"

# Returns "<status> <level>" for an npm ref, or nothing if it is not registered.
registry_npm_entry() {
    [ -f "$REGISTRY" ] || return 0
    have yq || return 0
    yq e -r ".[] | select(.source == \"npm\" and .ref == \"$1\") | .status + \" \" + (.level | tostring)" \
        "$REGISTRY" 2>/dev/null | head -1
}

if have npm; then
    for pkg in "${NPM_GLOBAL_PACKAGES[@]}"; do
        entry="$(registry_npm_entry "$pkg")"
        pkg_status="${entry%% *}"
        pkg_level="${entry##* }"

        if [ -z "$entry" ]; then
            warn "  npm global: $pkg not in the registry — skipped (add it to manifests/tools.yaml)"
            continue
        fi
        if [ "$pkg_status" != "active" ]; then
            info "  npm global: $pkg skipped (status=$pkg_status — adopt it first: sunset adopt)"
            continue
        fi
        if [ "$pkg_level" -gt "$EFFECTIVE_LEVEL" ] 2>/dev/null; then
            info "  npm global: $pkg skipped (level $pkg_level > current level $EFFECTIVE_LEVEL)"
            continue
        fi

        # Check whether already installed globally
        if npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
            ok "  npm global: $pkg (present)"
        else
            info "  Installing npm global: $pkg"
            run npm install -g "$pkg"
        fi
    done
else
    warn "npm not available — please open a new shell and re-run"
fi

ok "Module 04 (Node) complete."
