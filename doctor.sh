#!/usr/bin/env bash
# =============================================================================
# doctor.sh — System verification (read-only)
#
# Purpose:  Checks ~41 items of the developer stack for correctness.
#           For each item: PASS / WARN / FAIL + fix hint.
#           Exit code: 0 = all OK, 1 = at least one FAIL.
# Changes:  Nothing — read-only
# Requires: Ideally run after bootstrap.sh
# Usage:    ./doctor.sh [--level <0|1|2|3>] [--report] [--no-exit]
#           --level N   Check only items at minimum level N (cumulative)
#                       Level 0 = emergency basics; without --level = all checks
#           --report    Write Markdown report to local/doctor-report.md
#           --no-exit   No non-zero exit code on FAILs (bootstrap integration)
#
# Check level assignment:
#   Level 0: preflight, CLT, brew core, Shell/PATH, git/SSH/gh, Node, Claude
#   Level 1: full Brewfile, uv/Python, VS Code, macOS defaults, ~/dev
#   Level 2: Docker, full Xcode, Codex, Gemini, Ollama + models
#   Level 3: Brewfile.optional, automation/, OpenClaw remnant checks
# =============================================================================
set -euo pipefail
# shellcheck disable=SC2088  # Tilde in display strings is intentional (display-only)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib.sh"

WRITE_REPORT=0
NO_EXIT=0
DOCTOR_LEVEL=""   # empty = all checks

usage() {
    cat <<'EOF'
Usage: ./doctor.sh [options]

Verifies the setup against the current machine. Read-only — changes nothing.

Options:
  --level <0-3>   Only run checks relevant up to that setup level
                  (0 emergency, 1 base, 2 full, 3 maximal).
                  Without it, all checks run.
  --report        Additionally write a Markdown report to local/doctor-report.md
  --no-exit       Always exit 0, even when checks fail (useful in wrappers)
  --help, -h      Show this help

Exit codes:
  0  No FAIL (warnings are tolerated)
  1  At least one FAIL
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --report)  WRITE_REPORT=1 ;;
        --no-exit) NO_EXIT=1 ;;
        --level)   shift; DOCTOR_LEVEL="${1:-}" ;;
        --level=*) DOCTOR_LEVEL="${1#--level=}" ;;
        --help|-h) usage; exit 0 ;;
        *)         printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

# Validate level
if [ -n "$DOCTOR_LEVEL" ]; then
    case "$DOCTOR_LEVEL" in
        0|1|2|3) ;;
        *) printf "Invalid level: '%s' (allowed: 0-3)\n" "$DOCTOR_LEVEL" >&2; exit 1 ;;
    esac
fi

# Total number of checks (for summary line)
TOTAL_CHECKS=41
SKIPPED_COUNT=0

# =============================================================================
# Result tracking
# =============================================================================
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
REPORT_LINES=""

_check() {
    local level="$1"   # PASS / WARN / FAIL
    local name="$2"
    local detail="$3"
    local fix="${4:-}"

    case "$level" in
        PASS)
            printf "%s[PASS]%s  %-40s %s\n" "$_GREEN" "$_RESET" "$name" "$detail" >&2
            PASS_COUNT=$((PASS_COUNT + 1))
            ;;
        WARN)
            printf "%s[WARN]%s  %-40s %s\n" "$_YELLOW" "$_RESET" "$name" "$detail" >&2
            [ -n "$fix" ] && printf "       %s→ %s%s\n" "$_YELLOW" "$fix" "$_RESET" >&2
            WARN_COUNT=$((WARN_COUNT + 1))
            ;;
        FAIL)
            printf "%s[FAIL]%s  %-40s %s\n" "$_RED" "$_RESET" "$name" "$detail" >&2
            [ -n "$fix" ] && printf "       %s→ %s%s\n" "$_RED" "$fix" "$_RESET" >&2
            FAIL_COUNT=$((FAIL_COUNT + 1))
            ;;
    esac

    # For report
    REPORT_LINES="${REPORT_LINES}| ${level} | ${name} | ${detail} |"
    if [ -n "$fix" ]; then
        REPORT_LINES="${REPORT_LINES} **Fix:** ${fix}"
    fi
    REPORT_LINES="${REPORT_LINES}
"
}

pass() { _check "PASS" "$1" "$2" ""; }
warn() { _check "WARN" "$1" "$2" "${3:-}"; }
fail() { _check "FAIL" "$1" "$2" "${3:-}"; }

# check_at_level <min_level> <check_function> <args...>
# Runs a check only when the current level >= min_level.
# Without --level: always run.
check_at_level() {
    local min_stufe="$1"
    shift
    local check_func="$1"
    shift

    if [ -n "$DOCTOR_LEVEL" ] && [ "$DOCTOR_LEVEL" -lt "$min_stufe" ]; then
        # Skip check
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        return 0
    fi
    "$check_func" "$@"
}

# Short forms: passN, warnN, failN — level N = minimum setup level
pass0() { _check "PASS" "$1" "$2" ""; }
warn0() { _check "WARN" "$1" "$2" "${3:-}"; }
fail0() { _check "FAIL" "$1" "$2" "${3:-}"; }

pass1() { check_at_level 1 _check "PASS" "$1" "$2" ""; }
warn1() { check_at_level 1 _check "WARN" "$1" "$2" "${3:-}"; }
fail1() { check_at_level 1 _check "FAIL" "$1" "$2" "${3:-}"; }

pass2() { check_at_level 2 _check "PASS" "$1" "$2" ""; }
warn2() { check_at_level 2 _check "WARN" "$1" "$2" "${3:-}"; }
fail2() { check_at_level 2 _check "FAIL" "$1" "$2" "${3:-}"; }

pass3() { check_at_level 3 _check "PASS" "$1" "$2" ""; }
warn3() { check_at_level 3 _check "WARN" "$1" "$2" "${3:-}"; }
fail3() { check_at_level 3 _check "FAIL" "$1" "$2" "${3:-}"; }

# =============================================================================
# Header
# =============================================================================
printf "\n%s%s========================================%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
printf "%s%s  doctor.sh — System check%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
printf "%s%s  %s%s\n" "$_BOLD" "$_CYAN" "$(date '+%Y-%m-%d %H:%M:%S')" "$_RESET" >&2
if [ -n "$DOCTOR_LEVEL" ]; then
    case "$DOCTOR_LEVEL" in
        0) LEVEL_NAME="Emergency (level 0)" ;;
        1) LEVEL_NAME="Base (level 1)" ;;
        2) LEVEL_NAME="Full (level 2)" ;;
        3) LEVEL_NAME="Maximum (level 3)" ;;
        *) LEVEL_NAME="Level $DOCTOR_LEVEL" ;;
    esac
    printf "%s%s  Level: %s%s\n" "$_BOLD" "$_CYAN" "$LEVEL_NAME" "$_RESET" >&2
fi
printf "%s%s========================================%s\n\n" "$_BOLD" "$_CYAN" "$_RESET" >&2

step "Apple Toolchain"

# =============================================================================
# 01. Xcode CLT
# =============================================================================
if xcode-select -p >/dev/null 2>&1; then
    CLT_PATH=$(xcode-select -p)
    pass0 "Xcode CLT" "$CLT_PATH"
else
    fail0 "Xcode CLT" "Not found" "xcode-select --install"
fi

# =============================================================================
# 02. Xcode.app
# =============================================================================
if [ -d "/Applications/Xcode.app" ]; then
    XCODE_VER=$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}' || echo "?")
    pass2 "Xcode.app" "Version $XCODE_VER"
else
    warn2 "Xcode.app" "Not installed" "App Store → Xcode"
fi

# =============================================================================
# 03. Swift
# =============================================================================
if have swift; then
    SWIFT_VER=$(swift --version 2>/dev/null | head -1 | awk '{print $4}' || echo "?")
    pass2 "Swift" "$SWIFT_VER"
else
    warn2 "Swift" "Not in PATH" "Install Xcode CLT"
fi

step "Homebrew"

# =============================================================================
# 04. Homebrew
# =============================================================================
if have brew; then
    BREW_VER=$(brew --version | head -1 | awk '{print $2}')
    pass0 "Homebrew" "$BREW_VER @ $(brew --prefix)"
else
    fail0 "Homebrew" "Not installed" "./bootstrap.sh --only homebrew"
fi

# =============================================================================
# 05. brew doctor
# =============================================================================
if have brew; then
    BREW_DOC=$(brew doctor 2>&1 || true)
    if echo "$BREW_DOC" | grep -q "Your system is ready to brew"; then
        pass0 "brew doctor" "System ready"
    else
        WARN_MSG=$(echo "$BREW_DOC" | grep -v "^$" | head -3 | tr '\n' ' ')
        warn0 "brew doctor" "Warnings: $WARN_MSG" "brew doctor for details"
    fi
fi

# =============================================================================
# 06. PATH order: brew before /usr/bin
# =============================================================================
BREW_GIT="/opt/homebrew/bin/git"
ACTIVE_GIT=$(which git 2>/dev/null || echo "not found")
if [ "$ACTIVE_GIT" = "$BREW_GIT" ]; then
    pass0 "PATH: brew-git before /usr/bin/git" "$ACTIVE_GIT"
else
    fail0 "PATH: brew-git not taking priority" "Active: $ACTIVE_GIT" "Open a new shell or check ~/.zprofile"
fi

step "Node"

# =============================================================================
# 07. Node.js
# =============================================================================
if have node; then
    NODE_VER=$(node --version 2>/dev/null || echo "?")
    if echo "$NODE_VER" | grep -q "^v24"; then
        pass0 "Node.js" "$NODE_VER"
    else
        warn0 "Node.js" "$NODE_VER (expected v24.x)" "nvm install 24 && nvm alias default 24"
    fi
else
    fail0 "Node.js" "Not found" "nvm install 24"
fi

# =============================================================================
# 08. pnpm
# =============================================================================
if have pnpm; then
    PNPM_VER=$(pnpm --version 2>/dev/null || echo "?")
    pass0 "pnpm" "$PNPM_VER"
else
    fail0 "pnpm" "Not found" "brew install pnpm"
fi

# =============================================================================
# 09. bun
# =============================================================================
BUN_BIN="${HOME}/.bun/bin/bun"
if have bun || [ -f "$BUN_BIN" ]; then
    BUN_VER=$(bun --version 2>/dev/null || "$BUN_BIN" --version 2>/dev/null || echo "?")
    pass0 "bun" "$BUN_VER"
else
    warn0 "bun" "Not found" "curl -fsSL https://bun.sh/install | bash"
fi

# =============================================================================
# 10. deno
# =============================================================================
if have deno; then
    DENO_VER=$(deno --version 2>/dev/null | head -1 | awk '{print $2}' || echo "?")
    pass0 "deno" "$DENO_VER"
else
    warn0 "deno" "Not found" "brew install deno"
fi

step "Python"

# =============================================================================
# 11. uv
# =============================================================================
if have uv; then
    UV_VER=$(uv --version 2>/dev/null | awk '{print $2}' || echo "?")
    pass0 "uv" "$UV_VER"
else
    fail0 "uv" "Not found" "brew install uv"
fi

# =============================================================================
# 12. Python 3.13 via uv
# =============================================================================
if have uv; then
    if uv python list 2>/dev/null | grep -q "3\.13"; then
        pass1 "Python 3.13 (via uv)" "present"
    else
        warn1 "Python 3.13 (via uv)" "Not installed" "uv python install 3.13"
    fi
fi

# =============================================================================
# 13. pipx
# =============================================================================
if have pipx; then
    PIPX_VER=$(pipx --version 2>/dev/null || echo "?")
    pass1 "pipx" "$PIPX_VER"
else
    warn1 "pipx" "Not found" "brew install pipx"
fi

step "Container"

# =============================================================================
# 14. Docker
# =============================================================================
if have docker; then
    DOCKER_VER=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || echo "?")
    pass2 "Docker CLI" "$DOCKER_VER"
else
    warn2 "Docker CLI" "Not found" "brew install --cask docker"
fi

# =============================================================================
# 15. Docker Daemon
# =============================================================================
if docker info >/dev/null 2>&1; then
    DOCKER_CTX=$(docker context show 2>/dev/null || echo "default")
    pass2 "Docker Daemon" "running (context: $DOCKER_CTX)"
else
    warn2 "Docker Daemon" "Not reachable" "open -a Docker"
fi

# =============================================================================
# 16. Docker Compose
# =============================================================================
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VER=$(docker compose version --short 2>/dev/null || echo "?")
    pass2 "Docker Compose" "v$COMPOSE_VER"
else
    warn2 "Docker Compose" "Not available" "Update Docker Desktop"
fi

step "AI Tools"

# =============================================================================
# 17. Claude Code
# =============================================================================
CLAUDE_BIN="$HOME/.local/bin/claude"
if have claude || [ -f "$CLAUDE_BIN" ]; then
    CLAUDE_VER=$(claude --version 2>/dev/null | head -1 || echo "?")
    pass0 "Claude Code" "$CLAUDE_VER"
else
    fail0 "Claude Code" "Not found" "npm install -g @anthropic-ai/claude-code"
fi

# =============================================================================
# 18. Codex CLI
# =============================================================================
if npm list -g --depth=0 @openai/codex >/dev/null 2>&1; then
    CODEX_VER=$(npm list -g --depth=0 @openai/codex 2>/dev/null | grep codex | awk -F@ '{print $NF}' || echo "?")
    pass2 "@openai/codex" "$CODEX_VER"
else
    warn2 "@openai/codex" "Not installed" "npm install -g @openai/codex"
fi

# =============================================================================
# 19. Gemini CLI
# =============================================================================
if have gemini; then
    GEMINI_VER=$(gemini --version 2>/dev/null || echo "?")
    pass2 "Gemini CLI" "$GEMINI_VER"
else
    warn2 "Gemini CLI" "Not found" "brew install gemini-cli"
fi

# =============================================================================
# 20. Ollama
# =============================================================================
if have ollama; then
    OLLAMA_VER=$(ollama --version 2>/dev/null | awk '{print $NF}' || echo "?")
    pass2 "Ollama" "$OLLAMA_VER"
else
    warn2 "Ollama" "Not found" "brew install ollama"
fi

# =============================================================================
# 21. Ollama models
# =============================================================================
if curl -sf --max-time 3 http://localhost:11434/api/tags >/dev/null 2>&1; then
    OLLAMA_MODELS=$(ollama list 2>/dev/null | awk 'NR>1{print $1}' | tr '\n' ',' | sed 's/,$//')
    if [ -n "$OLLAMA_MODELS" ]; then
        pass2 "Ollama models" "$OLLAMA_MODELS"
    else
        warn2 "Ollama models" "No models loaded" "ollama pull llama3.2"
    fi
else
    warn2 "Ollama models" "Ollama not reachable" "ollama serve"
fi

step "Git / SSH / Security"

# =============================================================================
# 22. git user.name
# =============================================================================
GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
if [ -n "$GIT_NAME" ]; then
    pass0 "git user.name" "$GIT_NAME"
else
    fail0 "git user.name" "Not set" "git config --global user.name 'Your Name'"
fi

# =============================================================================
# 23. git user.email
# =============================================================================
GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
if [ -n "$GIT_EMAIL" ]; then
    pass0 "git user.email" "$GIT_EMAIL"
else
    fail0 "git user.email" "Not set" "git config --global user.email 'you@example.com'"
fi

# =============================================================================
# 24. SSH key type (ed25519 preferred)
# =============================================================================
ED25519_KEY="$HOME/.ssh/id_ed25519"
RSA_KEY=$(ls "$HOME/.ssh"/id_rsa* 2>/dev/null | head -1 || echo "")

if [ -f "$ED25519_KEY" ]; then
    pass0 "SSH key (ed25519)" "$ED25519_KEY"
elif [ -n "$RSA_KEY" ]; then
    warn0 "SSH key (RSA)" "$RSA_KEY" "./scripts/08-git-ssh.sh → create new ed25519 key"
else
    fail0 "SSH key" "No SSH key found" "./scripts/08-git-ssh.sh"
fi

# =============================================================================
# 25. gh auth
# =============================================================================
if have gh; then
    if gh auth status >/dev/null 2>&1; then
        GH_USER=$(gh api user -q .login 2>/dev/null || echo "?")
        pass0 "gh auth" "Logged in as $GH_USER"
    else
        warn0 "gh auth" "Not logged in" "gh auth login"
    fi
else
    fail0 "gh CLI" "Not found" "brew install gh"
fi

# =============================================================================
# 26. git init.defaultBranch
# =============================================================================
DEFAULT_BRANCH=$(git config --global init.defaultBranch 2>/dev/null || echo "master")
if [ "$DEFAULT_BRANCH" = "main" ]; then
    pass0 "git defaultBranch" "main"
else
    warn0 "git defaultBranch" "$DEFAULT_BRANCH" "git config --global init.defaultBranch main"
fi

# =============================================================================
# 27. git core.excludesfile
# =============================================================================
EXCLUDES=$(git config --global core.excludesfile 2>/dev/null || echo "")
if [ -n "$EXCLUDES" ] && [ -f "$EXCLUDES" ]; then
    pass0 "git excludesfile" "$EXCLUDES"
else
    warn0 "git excludesfile" "Not set or not found" "./scripts/08-git-ssh.sh"
fi

# =============================================================================
# 28. pre-commit
# =============================================================================
if have pre-commit; then
    PRE_COMMIT_VER=$(pre-commit --version 2>/dev/null || echo "?")
    pass0 "pre-commit" "$PRE_COMMIT_VER"
else
    warn0 "pre-commit" "Not found" "uv tool install pre-commit"
fi

# =============================================================================
# 29. gitleaks
# =============================================================================
if have gitleaks; then
    GITLEAKS_VER=$(gitleaks version 2>/dev/null || echo "?")
    pass0 "gitleaks" "$GITLEAKS_VER"
else
    warn0 "gitleaks" "Not found" "brew install gitleaks"
fi

# =============================================================================
# 30. Global gitleaks pre-commit hook
# =============================================================================
GLOBAL_HOOK="$HOME/.config/git/hooks/pre-commit"
HOOKS_PATH=$(git config --global core.hooksPath 2>/dev/null || echo "")
if [ -f "$GLOBAL_HOOK" ] && [ -n "$HOOKS_PATH" ]; then
    pass0 "Global gitleaks hook" "$GLOBAL_HOOK"
else
    warn0 "Global gitleaks hook" "Not configured" "./scripts/08-git-ssh.sh"
fi

step "Shell configuration"

# =============================================================================
# 31. oh-my-zsh
# =============================================================================
if [ -d "$HOME/.oh-my-zsh" ]; then
    pass0 "oh-my-zsh" "$HOME/.oh-my-zsh"
else
    warn0 "oh-my-zsh" "Not installed" "./scripts/03-shell.sh"
fi

# =============================================================================
# 32. Powerlevel10k
# =============================================================================
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ -d "$P10K_DIR" ]; then
    pass0 "Powerlevel10k" "$P10K_DIR"
else
    warn0 "Powerlevel10k" "Not installed" "./scripts/03-shell.sh"
fi

# =============================================================================
# 33. ~/.zshrc (symlink to config/zshrc?)
# =============================================================================
if [ -L "$HOME/.zshrc" ]; then
    ZSHRC_TARGET=$(readlink "$HOME/.zshrc")
    pass0 "$HOME/.zshrc" "Symlink → $ZSHRC_TARGET"
elif [ -f "$HOME/.zshrc" ]; then
    warn0 "$HOME/.zshrc" "Own file (not a symlink to config/zshrc)" "./scripts/03-shell.sh"
else
    fail0 "$HOME/.zshrc" "Not present" "./scripts/03-shell.sh"
fi

# =============================================================================
# 34. PATH: ~/dev/base/bin present
# =============================================================================
BASE_BIN="$HOME/dev/base/bin"
if echo "$PATH" | tr ':' '\n' | grep -qx "$BASE_BIN"; then
    pass1 "PATH: ~/dev/base/bin" "in PATH"
elif [ -d "$BASE_BIN" ]; then
    warn1 "PATH: ~/dev/base/bin" "Directory exists but not in PATH" "Open a new shell"
else
    warn1 "PATH: ~/dev/base/bin" "Not present" "./scripts/11-paved-road.sh"
fi

step "macOS system"

# =============================================================================
# 35. Free disk space
# =============================================================================
FREE_KB=$(df -k "$HOME" | awk 'NR==2 {print $4}')
FREE_GB=$((FREE_KB / 1024 / 1024))
if [ "$FREE_GB" -ge 20 ]; then
    pass0 "Free disk space" "${FREE_GB} GB"
elif [ "$FREE_GB" -ge 10 ]; then
    warn0 "Free disk space" "${FREE_GB} GB (recommended: 20 GB)" "Clean up Docker/Ollama data"
else
    fail0 "Free disk space" "${FREE_GB} GB (critical)" "docker system prune, ollama rm, conda clean"
fi

# =============================================================================
# 36. Rosetta 2
# =============================================================================
if [ "$(uname -m)" = "arm64" ]; then
    if arch -x86_64 /usr/bin/true 2>/dev/null; then
        pass0 "Rosetta 2" "installed"
    else
        warn0 "Rosetta 2" "Not installed" "softwareupdate --install-rosetta --agree-to-license"
    fi
fi

# =============================================================================
# 37. macOS version
# =============================================================================
MACOS_VER=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VER" | cut -d. -f1)
if [ "$MACOS_MAJOR" -ge 15 ]; then
    pass0 "macOS version" "$MACOS_VER"
else
    fail0 "macOS version" "$MACOS_VER (minimum: 15)" "Update macOS"
fi

step "OpenClaw legacy cleanup"

# =============================================================================
# 38. OpenClaw LaunchAgent — should NOT be present any more
# =============================================================================
OPENCLAW_AGENT="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
if [ -f "$OPENCLAW_AGENT" ]; then
    fail3 "OpenClaw LaunchAgent" "Still present: $OPENCLAW_AGENT" "./scripts/90-cleanup-legacy.sh"
else
    pass3 "OpenClaw LaunchAgent" "Not present (cleaned up)"
fi

# =============================================================================
# 39. ~/.openclaw — should NOT be present any more
# =============================================================================
if [ -d "$HOME/.openclaw" ]; then
    warn3 "$HOME/.openclaw" "Still present" "./scripts/90-cleanup-legacy.sh"
else
    pass3 "$HOME/.openclaw" "Not present (cleaned up)"
fi

# =============================================================================
# 40. npm global: openclaw/clawhub — should NOT be installed any more
# =============================================================================
if have npm; then
    OPENCLAW_NPM=$(npm list -g --depth=0 2>/dev/null | grep -E "openclaw|clawhub" || echo "")
    if [ -n "$OPENCLAW_NPM" ]; then
        warn3 "npm global: openclaw/clawhub" "Still installed: $OPENCLAW_NPM" "./scripts/90-cleanup-legacy.sh"
    else
        pass3 "npm global: no OpenClaw packages" "Cleaned up"
    fi
fi

# =============================================================================
# 41. ~/.zshrc: no OpenClaw references
# =============================================================================
if [ -f "$HOME/.zshrc" ]; then
    OPENCLAW_REFS=$(grep -c "openclaw\|OPENCLAW" "$HOME/.zshrc" 2>/dev/null || echo "0")
    if [ "$OPENCLAW_REFS" = "0" ]; then
        pass3 "$HOME/.zshrc: OpenClaw-free" "no references found"
    else
        warn3 "$HOME/.zshrc: OpenClaw references" "$OPENCLAW_REFS line(s) found" "Switch to config/zshrc (module 03)"
    fi
fi

# =============================================================================
# Result summary
# =============================================================================
printf "\n%s%s========================================%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
printf "%s%s  Result:%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
printf "%s%s========================================%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
printf "\n" >&2
printf "%s  PASS: %d%s\n" "$_GREEN" "$PASS_COUNT" "$_RESET" >&2
printf "%s  WARN: %d%s\n" "$_YELLOW" "$WARN_COUNT" "$_RESET" >&2
printf "%s  FAIL: %d%s\n" "$_RED" "$FAIL_COUNT" "$_RESET" >&2
if [ -n "$DOCTOR_LEVEL" ] && [ "$SKIPPED_COUNT" -gt 0 ]; then
    printf "     Skipped: %d (level > %s)\n" "$SKIPPED_COUNT" "$DOCTOR_LEVEL" >&2
fi
TOTAL_RUN=$((PASS_COUNT + WARN_COUNT + FAIL_COUNT))
printf "     Checked: %d / %d\n" "$TOTAL_RUN" "$TOTAL_CHECKS" >&2
printf "\n" >&2

# =============================================================================
# Optional: report to local/
# =============================================================================
if [ "$WRITE_REPORT" = "1" ]; then
    REPORT_DIR="$SCRIPT_DIR/local"
    mkdir -p "$REPORT_DIR"
    REPORT_FILE="$REPORT_DIR/doctor-report.md"

    {
        printf "# Doctor Report\n\n"
        printf "**Date:** %s  \n" "$(date '+%Y-%m-%d %H:%M:%S')"
        printf "**Machine:** %s  \n" "$(hostname)"
        printf "**macOS:** %s  \n\n" "$(sw_vers -productVersion)"
        printf "## Result\n\n"
        printf "- PASS: %d\n" "$PASS_COUNT"
        printf "- WARN: %d\n" "$WARN_COUNT"
        printf "- FAIL: %d\n\n" "$FAIL_COUNT"
        printf "## Details\n\n"
        printf "| Status | Check | Detail |\n"
        printf "|--------|-------|--------|\n"
        printf "%s\n" "$REPORT_LINES"
    } > "$REPORT_FILE"

    ok "Report written: $REPORT_FILE"
fi

# =============================================================================
# Exit-Code
# =============================================================================
if [ "$NO_EXIT" = "1" ]; then
    exit 0
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
exit 0
