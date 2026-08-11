#!/usr/bin/env bash
# =============================================================================
# scripts/07-ai-stack.sh — AI stack
#
# Purpose:  Install and configure Claude Code, OpenAI Codex CLI, Gemini CLI,
#           Ollama + models, and MCP base configuration.
# Changes:  ~/.local/bin (claude), ~/.codex/, ~/.gemini/,
#           Ollama model cache (~/.ollama/)
# Requires: Homebrew (module 02), Node (module 04)
# Usage:    ./scripts/07-ai-stack.sh [--dry-run] [--yes]
#
# Note:     Auth steps (claude login, gh auth, codex login) stay interactive.
#           This script only installs tools, not credentials.
# =============================================================================
set -euo pipefail
# shellcheck disable=SC2088  # Tilde in display strings is intentional (display-only)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib.sh"

# AI_CLAUDE_ONLY: if set, only Claude Code and its settings are configured.
# Codex, Gemini, Ollama are skipped (level 0/1).
AI_CLAUDE_ONLY="${AI_CLAUDE_ONLY:-0}"

parse_module_args "${BASH_SOURCE[0]}" "$@"

if [ "$AI_CLAUDE_ONLY" = "1" ]; then
    step "07 · AI stack (Claude Code only — level 0)"
else
    step "07 · AI stack (full)"
fi

# =============================================================================
# Claude Code
# =============================================================================
info "Checking Claude Code..."

CLAUDE_BIN="$HOME/.local/bin/claude"

if [ -f "$CLAUDE_BIN" ] || have claude; then
    CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1 || echo "?")
    ok "Claude Code present: $CLAUDE_VERSION"
else
    info "Installing Claude Code..."
    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would install: npm install -g @anthropic-ai/claude-code"
    else
        npm install -g @anthropic-ai/claude-code
        ok "Claude Code installed"
        info "Login: claude login"
    fi
fi

# Claude settings.json — template without personal data
CLAUDE_DIR="$HOME/.claude"
CLAUDE_SETTINGS="$CLAUDE_DIR/settings.json"
TEMPLATE_SETTINGS="$REPO_DIR/config/claude-settings-template.json"

if [ -f "$TEMPLATE_SETTINGS" ]; then
    if [ -f "$CLAUDE_SETTINGS" ]; then
        ok "$HOME/.claude/settings.json already exists — will not be overwritten"
        info "Template at: $TEMPLATE_SETTINGS"
    else
        info "Creating ~/.claude/settings.json from template..."
        run_mkdir "$CLAUDE_DIR"
        run cp "$TEMPLATE_SETTINGS" "$CLAUDE_SETTINGS"
        ok "$HOME/.claude/settings.json created (from template)"
    fi
fi

# =============================================================================
# Level-0 short-circuit: Claude Code only
# =============================================================================
if [ "$AI_CLAUDE_ONLY" = "1" ]; then
    ok "Module 07 (Claude Code only) complete."
    info "For full AI stack (Codex, Gemini, Ollama): ./bootstrap.sh --level 2"
    exit 0
fi

# =============================================================================
# OpenAI Codex CLI
# =============================================================================
info "Checking @openai/codex..."

if npm list -g --depth=0 "@openai/codex" >/dev/null 2>&1; then
    CODEX_VERSION=$(npm list -g --depth=0 @openai/codex 2>/dev/null | grep codex | awk -F@ '{print $NF}' || echo "?")
    ok "@openai/codex $CODEX_VERSION present"
else
    info "Installing @openai/codex..."
    run npm install -g @openai/codex
    ok "@openai/codex installed"
    info "Login: codex login"
fi

# Create codex config template (without personal data)
CODEX_CONFIG="$HOME/.codex/config.toml"
if [ ! -f "$CODEX_CONFIG" ]; then
    info "Creating ~/.codex/config.toml (base template)..."
    if [ "$DRY_RUN" != "1" ]; then
        mkdir -p "$HOME/.codex"
        cat > "$CODEX_CONFIG" <<'TOML'
# Codex CLI configuration
# Customize after 'codex login'
model = "o4-mini"
model_reasoning_effort = "medium"
approval_mode = "suggest"
service_tier = "default"
TOML
        ok "$HOME/.codex/config.toml created"
    else
        info "[dry-run] Would create ~/.codex/config.toml"
    fi
else
    ok "$HOME/.codex/config.toml already present"
fi

# =============================================================================
# Gemini CLI (via Homebrew — already in Brewfile)
# =============================================================================
info "Checking Gemini CLI..."

if have gemini; then
    GEMINI_VERSION=$(gemini --version 2>/dev/null || echo "?")
    ok "Gemini CLI present: $GEMINI_VERSION"
else
    info "Installing gemini-cli via brew..."
    run brew install gemini-cli
    ok "Gemini CLI installed"
    info "Login: gemini login (or API key in ~/.gemini/settings.json)"
fi

# =============================================================================
# Ollama + models
# =============================================================================
info "Checking Ollama..."

# Note on dual installation
if is_installed_brew "ollama" && is_installed_cask "ollama"; then
    warn "Ollama is installed twice (brew formula + cask)."
    warn "Recommendation: brew uninstall ollama && brew install --cask ollama"
    warn "Or: cask version for the GUI, formula version for CLI."
    warn "Currently using the brew formula version (service)."
fi

if have ollama; then
    OLLAMA_VERSION=$(ollama --version 2>/dev/null | awk '{print $NF}' || echo "?")
    ok "Ollama $OLLAMA_VERSION present"

    # Start Ollama service (if not running)
    if ! curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
        info "Starting Ollama service..."
        if [ "$DRY_RUN" != "1" ]; then
            ollama serve &>/dev/null &
            OLLAMA_PID=$!
            sleep 3
            if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
                ok "Ollama service started (PID: $OLLAMA_PID)"
            else
                warn "Ollama service could not be started — model pull skipped"
                OLLAMA_PID=""
            fi
        else
            info "[dry-run] Would start Ollama service"
        fi
    else
        ok "Ollama service already running"
        OLLAMA_PID=""
    fi

    # Models from inventory (verified installed)
    OLLAMA_MODELS=(
        "llama3.2"
        "deepseek-r1:14b"
        "aya-expanse:8b"
        "glm-ocr"
    )

    if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
        for model in "${OLLAMA_MODELS[@]}"; do
            # Check if model already present locally (base name without tag)
            MODEL_NAME="${model%%:*}"

            if ollama list 2>/dev/null | grep -q "^${MODEL_NAME}"; then
                ok "  Ollama model present: $model"
            else
                warn "  Ollama model missing: $model"
                info "  Hint: 'ollama pull $model' to download (~2-9 GB)"
                if confirm "  Download model $model now?"; then
                    run ollama pull "$model"
                fi
            fi
        done
    else
        warn "Ollama not reachable — model check skipped"
        info "Pull models manually: ollama pull llama3.2 / deepseek-r1:14b / aya-expanse:8b / glm-ocr"
    fi

    # Stop the temporary Ollama process (if we started it)
    if [ -n "${OLLAMA_PID:-}" ]; then
        kill "$OLLAMA_PID" 2>/dev/null || true
    fi
else
    info "Installing Ollama via brew..."
    run brew install ollama
    ok "Ollama installed"
    info "Start with: brew services start ollama"
    info "Or manually: ollama serve"
    info "Pull models: ollama pull llama3.2"
fi

# =============================================================================
# Manual steps (login)
# =============================================================================
info ""
info "Manual auth steps (cannot be automated):"
info "  claude login           → Connect Claude Code to your Anthropic account"
info "  codex login            → Authenticate OpenAI Codex CLI"
info "  gemini login           → Connect Gemini CLI to your Google account"
info "  gh auth login          → GitHub CLI (if not done yet)"

ok "Module 07 (AI stack) complete."
