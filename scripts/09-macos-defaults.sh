#!/usr/bin/env bash
# =============================================================================
# scripts/09-macos-defaults.sh — macOS system settings for developers
#
# Purpose:  Apply developer-friendly macOS defaults (Finder, Dock,
#           keyboard, screenshots, Activity Monitor, Terminal, etc.)
# Changes:  macOS user preferences via 'defaults write'
# Requires: macOS, no sudo needed (all user-domain settings)
# Usage:    ./scripts/09-macos-defaults.sh [--dry-run] [--yes]
#             [--relax-download-quarantine]
#
#           --relax-download-quarantine disables the macOS download quarantine
#           dialog (LSQuarantine). It is OFF by default: that dialog is a
#           security control, not a UI preference, and nothing in "developer
#           defaults" leads a first-time user to expect it to be switched off.
#
# Note:     Many settings only take full effect after logout or restart.
#           Some require restarting affected processes (Finder, Dock).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

RELAX_QUARANTINE=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1; export DRY_RUN ;;
        --yes)     YES_MODE=1; export YES_MODE ;;
        --relax-download-quarantine) RELAX_QUARANTINE=1 ;;
    esac
done

step "09 · macOS developer settings"

# Helper: defaults write with dry-run support
df_write() {
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] defaults write $*"
    else
        defaults write "$@"
    fi
}

# =============================================================================
# Finder
# =============================================================================
info "Finder settings..."

# Show hidden files
df_write com.apple.finder AppleShowAllFiles -bool true
ok "  Finder: hidden files visible"

# Always show file extensions
df_write NSGlobalDomain AppleShowAllExtensions -bool true
ok "  Finder: always show file extensions"

# Show status bar and path bar
df_write com.apple.finder ShowStatusBar -bool true
df_write com.apple.finder ShowPathbar -bool true
ok "  Finder: status bar and path bar enabled"

# Search: default to current folder
df_write com.apple.finder FXDefaultSearchScope -string "SCcf"
ok "  Finder: search in current folder"

# Don't create .DS_Store on network drives
df_write com.apple.desktopservices DSDontWriteNetworkStores -bool true
df_write com.apple.desktopservices DSDontWriteUSBStores -bool true
ok "  Finder: .DS_Store on network/USB disabled"

# Show size in list view
df_write com.apple.finder FXListViewGroupBy -string "None"
ok "  Finder: list view without grouping"

# =============================================================================
# Dock
# =============================================================================
info "Dock settings..."

# Auto-hide Dock
df_write com.apple.dock autohide -bool true
ok "  Dock: auto-hide enabled"

# Reduce Dock show delay
df_write com.apple.dock autohide-delay -float 0.2
df_write com.apple.dock autohide-time-modifier -float 0.3
ok "  Dock: show delay reduced"

# No 'recently used apps' in Dock
df_write com.apple.dock show-recents -bool false
ok "  Dock: recent apps hidden"

# =============================================================================
# Keyboard
# =============================================================================
info "Keyboard settings..."

# Fast key repeat
df_write NSGlobalDomain KeyRepeat -int 2
df_write NSGlobalDomain InitialKeyRepeat -int 15
ok "  Keyboard: fast repeat (KeyRepeat=2, InitialKeyRepeat=15)"

# Disable press-and-hold (to enable key repeat)
df_write NSGlobalDomain ApplePressAndHoldEnabled -bool false
ok "  Keyboard: press-and-hold disabled (key repeat enabled)"

# Disable auto-corrections (developers write code!)
df_write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
df_write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
df_write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
df_write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
df_write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
ok "  Keyboard: auto-corrections disabled"

# =============================================================================
# Trackpad
# =============================================================================
info "Trackpad settings..."

# Tap to click
df_write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
df_write com.apple.AppleMultitouchTrackpad Clicking -bool true
df_write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
ok "  Trackpad: tap to click enabled"

# =============================================================================
# Screenshots
# =============================================================================
info "Screenshot settings..."

SCREENSHOT_DIR="$HOME/Desktop/Screenshots"
if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "$SCREENSHOT_DIR"
fi
df_write com.apple.screencapture location "$SCREENSHOT_DIR"
df_write com.apple.screencapture type -string "png"
df_write com.apple.screencapture disable-shadow -bool true
ok "  Screenshots: location $SCREENSHOT_DIR, format PNG, no shadow"

# =============================================================================
# Activity Monitor
# =============================================================================
info "Activity Monitor..."

df_write com.apple.ActivityMonitor OpenMainWindow -bool true
df_write com.apple.ActivityMonitor IconType -int 5
df_write com.apple.ActivityMonitor ShowCategory -int 0
df_write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
df_write com.apple.ActivityMonitor SortDirection -int 0
ok "  Activity Monitor: CPU view as default"

# =============================================================================
# TextEdit (fallback editor)
# =============================================================================
info "TextEdit..."

df_write com.apple.TextEdit RichText -int 0
df_write com.apple.TextEdit PlainTextEncoding -int 4
df_write com.apple.TextEdit PlainTextEncodingForWrite -int 4
ok "  TextEdit: plain-text mode, UTF-8"

# =============================================================================
# Security
# =============================================================================
info "Security settings..."

# Download quarantine. Opt-in only.
#
# LSQuarantine=false suppresses the "downloaded from the internet, are you
# sure?" dialog. That is a security control being switched off, so it is not
# part of the default set — a level-1 run must not silently weaken the machine
# it is setting up. Gatekeeper and XProtect are unaffected either way; this
# specific prompt is what changes.
if [ "$RELAX_QUARANTINE" = "1" ]; then
    df_write com.apple.LaunchServices LSQuarantine -bool false
    warn "  Download quarantine dialog DISABLED (--relax-download-quarantine)"
    info "  Undo: defaults write com.apple.LaunchServices LSQuarantine -bool true"
else
    info "  Download quarantine left enabled (--relax-download-quarantine to disable)"
fi

# =============================================================================
# Menu bar
# =============================================================================
info "Menu bar settings..."

df_write NSGlobalDomain _HIHideMenuBar -bool false
df_write com.apple.menuextra.clock DateFormat -string "EEE d. MMM  HH:mm:ss"
ok "  Menu bar: date + seconds in clock"

# =============================================================================
# Restart processes (to activate changes)
# =============================================================================
if [ "$DRY_RUN" != "1" ]; then
    info "Restarting affected processes..."
    killall Finder 2>/dev/null || true
    killall Dock 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true
    ok "Finder, Dock and SystemUIServer restarted"
else
    info "[dry-run] Would restart Finder, Dock, SystemUIServer"
fi

ok "Module 09 (macOS defaults) complete."
info "Some settings (keyboard, trackpad) only take effect after logout/restart."
