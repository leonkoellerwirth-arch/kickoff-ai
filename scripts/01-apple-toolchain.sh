#!/usr/bin/env bash
# =============================================================================
# scripts/01-apple-toolchain.sh — Apple developer toolchain
#
# Purpose:  Install Command Line Tools, accept Xcode license,
#           manage simulators
# Changes:  /Library/Developer/CommandLineTools (via xcode-select),
#           Xcode license database
# Requires: Internet connection, sudo access
# Usage:    ./scripts/01-apple-toolchain.sh [--dry-run] [--yes] [--clt-only]
#
# Environment variables:
#   APPLE_CLT_ONLY=1   Install CLT only; skip Xcode license and simulators
#                      (bootstrap level 0/1)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# APPLE_CLT_ONLY can be set via environment variable or argument
APPLE_CLT_ONLY="${APPLE_CLT_ONLY:-0}"

parse_module_args "${BASH_SOURCE[0]}" "$@"

if [ "$APPLE_CLT_ONLY" = "1" ]; then
    step "01 · Apple CLT (level 0 — Command Line Tools only)"
else
    step "01 · Apple Developer Toolchain (full)"
fi

# =============================================================================
# Command Line Tools (CLT)
# =============================================================================
info "Checking Command Line Tools..."

if xcode-select -p >/dev/null 2>&1; then
    CLT_PATH=$(xcode-select -p)
    ok "Command Line Tools present: $CLT_PATH"
else
    info "Installing Command Line Tools..."
    info "A dialog window will open — please click 'Install'."
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would run: xcode-select --install"
    else
        xcode-select --install 2>/dev/null || true
        # Wait for installation to complete
        info "Waiting for CLT installation to complete..."
        local_count=0
        while ! xcode-select -p >/dev/null 2>&1; do
            sleep 10
            local_count=$((local_count + 1))
            if [ $local_count -gt 60 ]; then
                err "Timeout: CLT installation took too long. Please check manually."
            fi
        done
        ok "Command Line Tools installed: $(xcode-select -p)"
    fi
fi

# =============================================================================
# Check CLT version
# =============================================================================
info "Checking CLT version..."
if have pkgutil; then
    CLT_PKG="com.apple.pkg.CLTools_Executables"
    if pkgutil --pkg-info "$CLT_PKG" >/dev/null 2>&1; then
        CLT_VERSION=$(pkgutil --pkg-info "$CLT_PKG" | awk '/version:/ {print $2}')
        ok "Command Line Tools $CLT_VERSION"
    fi
fi

# =============================================================================
# Xcode — notice and license (skipped at level 0/1)
# =============================================================================
if [ "$APPLE_CLT_ONLY" = "1" ]; then
    info "Xcode setup skipped (CLT-only mode / level 0)."
    info "For full Xcode setup: ./bootstrap.sh --level 2"
    ok "Module 01 (CLT) complete."
    exit 0
fi

info "Checking Xcode..."

if [ -d "/Applications/Xcode.app" ]; then
    XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
    ok "Xcode $XCODE_VERSION found"

    # Accept license (idempotent)
    info "Checking Xcode license..."
    if sudo xcodebuild -license status 2>/dev/null | grep -q "accepted"; then
        ok "Xcode license already accepted"
    else
        info "Xcode license must be accepted (requires sudo)..."
        run sudo xcodebuild -license accept
        ok "Xcode license accepted"
    fi

    # Install first-launch packages (if needed)
    if [ "$DRY_RUN" != "1" ]; then
        sudo xcodebuild -runFirstLaunch 2>/dev/null || true
    else
        info "[dry-run] Would run: xcodebuild -runFirstLaunch"
    fi

else
    warn "Xcode.app not found in /Applications."
    warn "For iOS/macOS/Swift development: https://developer.apple.com/xcode/"
    warn "Or via App Store: search for 'Xcode'."
    warn "Important: after installation please re-run '01-apple-toolchain.sh'."
fi

# =============================================================================
# xcrun — check base tools
# =============================================================================
info "Checking xcrun tools..."

for tool in clang clang++ swift swiftc make gcc; do
    if xcrun --find "$tool" >/dev/null 2>&1; then
        ok "  $tool: $(xcrun --find "$tool")"
    else
        warn "  $tool not found via xcrun"
    fi
done

# =============================================================================
# Simulators (notice)
# =============================================================================
info "Simulator status..."

if have simctl; then
    SIM_COUNT=$(xcrun simctl list devices available --json 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin)['devices']; print(sum(len(v) for v in d.values()))" 2>/dev/null || echo "?")
    ok "Available simulators: $SIM_COUNT"
    info "To add more: Xcode → Window → Devices and Simulators"
else
    warn "simctl not found — Xcode not installed?"
fi

ok "Module 01 (Apple Toolchain) complete."
