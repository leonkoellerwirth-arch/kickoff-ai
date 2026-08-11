#!/usr/bin/env bash
# =============================================================================
# scripts/08-git-ssh.sh — Git, SSH key, GitHub CLI, pre-commit, gitleaks
#
# Purpose:  Apply Git configuration, generate a new ed25519 SSH key,
#           configure SSH agent + Keychain, check gh auth,
#           set up pre-commit (via uv) and a global gitleaks hook.
# Changes:  ~/.gitconfig, ~/.gitignore_global, ~/.ssh/config,
#           ~/.ssh/id_ed25519 (new), ~/.config/git/allowed_signers,
#           git global config, uv tool install pre-commit
# Requires: Homebrew (module 02), Python/uv (module 05)
# Usage:    ./scripts/08-git-ssh.sh [--dry-run] [--yes]
#           Environment variables for --yes mode:
#             GIT_AUTHOR_NAME  → git user.name
#             GIT_AUTHOR_EMAIL → git user.email
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

step "08 · Git, SSH & secrets tools"

# =============================================================================
# Install config/gitconfig
# =============================================================================
info "Installing config/gitconfig → ~/.gitconfig..."

CONFIG_GITCONFIG="$REPO_DIR/config/gitconfig"
TARGET_GITCONFIG="$HOME/.gitconfig"

if [ ! -f "$CONFIG_GITCONFIG" ]; then
    err "config/gitconfig not found: $CONFIG_GITCONFIG"
fi

if [ -e "$TARGET_GITCONFIG" ] && [ ! -L "$TARGET_GITCONFIG" ]; then
    if confirm "$HOME/.gitconfig exists and will be backed up + replaced. OK?"; then
        backup_file "$TARGET_GITCONFIG"
        run ln -sf "$CONFIG_GITCONFIG" "$TARGET_GITCONFIG"
        ok "$HOME/.gitconfig → $CONFIG_GITCONFIG"
    else
        warn "$HOME/.gitconfig will not be replaced."
    fi
elif [ -L "$TARGET_GITCONFIG" ]; then
    CURRENT_TARGET=$(readlink "$TARGET_GITCONFIG" 2>/dev/null || echo "?")
    if [ "$CURRENT_TARGET" = "$CONFIG_GITCONFIG" ]; then
        ok "$HOME/.gitconfig already linked correctly"
    else
        run ln -sf "$CONFIG_GITCONFIG" "$TARGET_GITCONFIG"
        ok "$HOME/.gitconfig → $CONFIG_GITCONFIG"
    fi
else
    run ln -sf "$CONFIG_GITCONFIG" "$TARGET_GITCONFIG"
    ok "$HOME/.gitconfig → $CONFIG_GITCONFIG"
fi

# =============================================================================
# git user.name / user.email — interactive or via env vars
# =============================================================================
info "Configuring Git identity..."

CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

if [ -n "${GIT_AUTHOR_NAME:-}" ]; then
    GIT_NAME="$GIT_AUTHOR_NAME"
elif [ "$YES_MODE" = "1" ]; then
    if [ -n "$CURRENT_NAME" ]; then
        GIT_NAME="$CURRENT_NAME"
        info "Keeping existing git user.name: $GIT_NAME"
    else
        warn "GIT_AUTHOR_NAME not set and --yes active → user.name will not be set"
        GIT_NAME=""
    fi
else
    printf "%s  Git user.name [%s]: %s" "$_YELLOW" "${CURRENT_NAME:-empty}" "$_RESET" >&2
    read -r GIT_NAME </dev/tty
    GIT_NAME="${GIT_NAME:-$CURRENT_NAME}"
fi

if [ -n "${GIT_AUTHOR_EMAIL:-}" ]; then
    GIT_EMAIL="$GIT_AUTHOR_EMAIL"
elif [ "$YES_MODE" = "1" ]; then
    if [ -n "$CURRENT_EMAIL" ]; then
        GIT_EMAIL="$CURRENT_EMAIL"
        info "Keeping existing git user.email: $GIT_EMAIL"
    else
        warn "GIT_AUTHOR_EMAIL not set and --yes active → user.email will not be set"
        GIT_EMAIL=""
    fi
else
    printf "%s  Git user.email [%s]: %s" "$_YELLOW" "${CURRENT_EMAIL:-empty}" "$_RESET" >&2
    read -r GIT_EMAIL </dev/tty
    GIT_EMAIL="${GIT_EMAIL:-$CURRENT_EMAIL}"
fi

if [ -n "$GIT_NAME" ]; then
    run git config --global user.name "$GIT_NAME"
    ok "git user.name = $GIT_NAME"
fi
if [ -n "$GIT_EMAIL" ]; then
    run git config --global user.email "$GIT_EMAIL"
    ok "git user.email = $GIT_EMAIL"
fi

# =============================================================================
# Install config/gitignore_global
# =============================================================================
info "Installing config/gitignore_global..."

CONFIG_GITIGNORE="$REPO_DIR/config/gitignore_global"
TARGET_GITIGNORE="$HOME/.gitignore_global"

if [ -e "$TARGET_GITIGNORE" ] && [ ! -L "$TARGET_GITIGNORE" ]; then
    backup_file "$TARGET_GITIGNORE"
fi
run ln -sf "$CONFIG_GITIGNORE" "$TARGET_GITIGNORE"
run git config --global core.excludesfile "$TARGET_GITIGNORE"
ok "$HOME/.gitignore_global set up"

# =============================================================================
# Generate ed25519 SSH key
# =============================================================================
info "Checking SSH keys..."

SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519"
KEY_COMMENT="${GIT_EMAIL:-git-setup}"

if [ -f "$KEY_PATH" ]; then
    ok "ed25519 SSH key already present: $KEY_PATH"
    KEY_TYPE=$(ssh-keygen -l -f "${KEY_PATH}.pub" 2>/dev/null | awk '{print $4}' || echo "?")
    info "Key type: $KEY_TYPE"
else
    # Check for an older RSA key
    RSA_KEY=$(ls "$SSH_DIR"/id_rsa* 2>/dev/null | head -1 || echo "")
    if [ -n "$RSA_KEY" ]; then
        warn "Older RSA key found: $RSA_KEY"
        warn "A new ed25519 key will be generated in addition."
    fi

    info "Generating new ed25519 SSH key..."
    info "Key will be saved to: $KEY_PATH"
    info "Key comment: $KEY_COMMENT"

    if [ "$DRY_RUN" = "1" ]; then
        info "[dry-run] Would run: ssh-keygen -t ed25519 -C \"$KEY_COMMENT\" -f $KEY_PATH"
    else
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        ssh-keygen -t ed25519 -C "$KEY_COMMENT" -f "$KEY_PATH"
        ok "SSH key generated: $KEY_PATH"
    fi
fi

# =============================================================================
# Configure SSH agent + macOS Keychain
# =============================================================================
info "Configuring SSH agent + Keychain..."

SSH_CONFIG="$SSH_DIR/config"

# Back up if present
if [ -f "$SSH_CONFIG" ] && [ ! -L "$SSH_CONFIG" ]; then
    # Only back up if our lines are not already there
    if ! grep -q "UseKeychain" "$SSH_CONFIG" 2>/dev/null; then
        backup_file "$SSH_CONFIG"
    fi
fi

# GitHub block in ~/.ssh/config
GITHUB_SSH_BLOCK="Host github.com
  User git
  Hostname github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes"

GITHUB_MARKER="# kickoff-ai: github.com"

append_once "$SSH_CONFIG" "$GITHUB_MARKER" "# kickoff-ai: github.com
$GITHUB_SSH_BLOCK"

chmod 600 "$SSH_CONFIG" 2>/dev/null || true
ok "$HOME/.ssh/config updated"

# Add key to agent
if [ -f "${KEY_PATH}.pub" ] && [ "$DRY_RUN" != "1" ]; then
    ssh-add --apple-use-keychain "$KEY_PATH" 2>/dev/null || \
    ssh-add "$KEY_PATH" 2>/dev/null || \
    warn "SSH key could not be added to agent (agent may not be running)"
    ok "SSH key added to agent"
fi

# Display public key (for GitHub)
if [ -f "${KEY_PATH}.pub" ]; then
    info ""
    info "Public SSH key (add to GitHub):"
    info "  Website: https://github.com/settings/ssh/new"
    cat "${KEY_PATH}.pub" >&2
    info ""
fi

# =============================================================================
# gh ssh-key add (optional)
# =============================================================================
if have gh && [ -f "${KEY_PATH}.pub" ]; then
    info "GitHub CLI: add SSH key to GitHub account..."
    if gh auth status >/dev/null 2>&1; then
        if confirm "Add SSH key to GitHub via gh CLI?"; then
            KEY_TITLE="kickoff-ai-setup-$(hostname -s)-$(date +%Y%m%d)"
            run gh ssh-key add "${KEY_PATH}.pub" --title "$KEY_TITLE"
            ok "SSH key added to GitHub: $KEY_TITLE"
        fi
    else
        warn "gh not logged in — please run 'gh auth login' first"
    fi
fi

# =============================================================================
# Set up SSH commit signing
# =============================================================================
info "Setting up SSH commit signing..."

ALLOWED_SIGNERS="$HOME/.config/git/allowed_signers"

if [ -f "${KEY_PATH}.pub" ]; then
    mkdir -p "$HOME/.config/git"

    if [ -n "$GIT_EMAIL" ]; then
        SIGNER_LINE="${GIT_EMAIL} $(cat "${KEY_PATH}.pub")"
        if [ "$DRY_RUN" != "1" ]; then
            echo "$SIGNER_LINE" > "$ALLOWED_SIGNERS"
            ok "allowed_signers created: $ALLOWED_SIGNERS"
        else
            info "[dry-run] Would create allowed_signers"
        fi
    else
        warn "git user.email not set — allowed_signers will not be created"
    fi

    # git config for SSH signing (enabled via ~/.gitconfig.local, as it is optional)
    info "SSH commit signing can be enabled in ~/.gitconfig.local:"
    info "  [user]"
    info "    signingkey = $KEY_PATH"
    info "  [commit]"
    info "    gpgsign = true"
    info "  [gpg]"
    info "    format = ssh"
    info "  [gpg \"ssh\"]"
    info "    allowedSignersFile = $ALLOWED_SIGNERS"
fi

# =============================================================================
# Install pre-commit (via uv)
# =============================================================================
info "Checking pre-commit..."

if have pre-commit; then
    PRE_COMMIT_VERSION=$(pre-commit --version 2>/dev/null || echo "?")
    ok "pre-commit $PRE_COMMIT_VERSION present"
else
    info "Installing pre-commit via uv tool..."
    run uv tool install pre-commit
    ok "pre-commit installed"
fi

# =============================================================================
# Global gitleaks hook
# =============================================================================
info "Setting up global gitleaks pre-commit hook..."

GLOBAL_HOOKS_DIR="$HOME/.config/git/hooks"
GITLEAKS_HOOK="$GLOBAL_HOOKS_DIR/pre-commit"

if have gitleaks; then
    if [ -f "$GITLEAKS_HOOK" ]; then
        ok "Global pre-commit hook already present: $GITLEAKS_HOOK"
    else
        if [ "$DRY_RUN" != "1" ]; then
            mkdir -p "$GLOBAL_HOOKS_DIR"
            cat > "$GITLEAKS_HOOK" <<'HOOK'
#!/usr/bin/env bash
# Global pre-commit hook: secret scanning via gitleaks
# Prevents accidental commits of tokens and credentials

if command -v gitleaks >/dev/null 2>&1; then
    gitleaks protect --staged --redact --no-banner 2>&1
    EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        echo ""
        echo "ERROR: gitleaks found potential secrets."
        echo "Please review and clean the flagged files."
        echo "To skip (NOT recommended): git commit --no-verify"
        exit $EXIT_CODE
    fi
fi
HOOK
            chmod +x "$GITLEAKS_HOOK"
            ok "Global gitleaks hook installed: $GITLEAKS_HOOK"
        else
            info "[dry-run] Would create global gitleaks hook: $GITLEAKS_HOOK"
        fi

        # Point git to the global hooks directory
        run git config --global core.hooksPath "$GLOBAL_HOOKS_DIR"
        ok "git core.hooksPath = $GLOBAL_HOOKS_DIR"
    fi
else
    warn "gitleaks not found — please run 'brew install gitleaks'"
    warn "Then re-run: ./scripts/08-git-ssh.sh"
fi

# =============================================================================
# gh auth status
# =============================================================================
info "GitHub CLI auth status..."
if have gh; then
    if gh auth status 2>/dev/null; then
        ok "gh auth: logged in"
    else
        warn "gh not logged in."
        warn "Manual: gh auth login"
    fi
else
    warn "gh not installed (should be installed via Brewfile)"
fi

ok "Module 08 (Git/SSH) complete."
