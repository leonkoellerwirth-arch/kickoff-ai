#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Zero-to-Hero Mac setup (single-command entry point)
#
# Purpose:  Brings a fresh Mac to a full developer stack with one command.
#           A second run is safe (idempotent).
# Changes:  Homebrew, ~/.zshrc, ~/.gitconfig, VS Code, SSH keys,
#           Python/Node stack, AI tools, macOS defaults, ~/dev structure
# Requires: Internet connection, Apple Silicon (arm64).
#           Tested on macOS 26.5 only — that is the one machine this setup was
#           distilled from. prepare.sh accepts macOS 15+, which is the floor the
#           scripts are written against, not a version anyone has verified.
# Usage:    ./bootstrap.sh [options]
#
# Options:
#   --level <0|1|2|3>  Setup depth (cumulative, see --list-levels)
#   --list-levels      Show all levels with contents and duration, then exit 0
#   --dry-run          Print all steps, change nothing
#   --yes              No interactive prompts
#   --minimal          Alias for --level 0 (emergency setup, ~15 min)
#   --full             Alias for --level 3 (maximum setup incl. optional)
#   --only <module>    Run only specific modules (comma-separated)
#                      overrides --level
#   --skip <module>    Skip these modules (comma-separated)
#                      subtracts from --level
#   --help             Show this help
#
# Levels (cumulative, each level includes everything from the previous):
#   0  Emergency   ~15 min  CLT, minimal brew formulas, Shell, Node, git, Claude
#   1  Base        ~45 min  + Brewfile.level1, Python (uv), macOS defaults,
#                           VS Code + extensions, ~/dev + dev/base
#   2  Full        ~2 h     + Docker, Xcode (full), Codex, Gemini, Ollama
#   3  Maximum     ~3 h+    + Brewfile.optional, automation/ (if present)
#
# Without --level: default run = equivalent to level 2 (full)
#
# Modules (numbers or names):
#   00  preflight        Pre-flight checks
#   01  apple-toolchain  Xcode CLT, licenses (level 0/1: CLT only)
#   02  homebrew         Homebrew + taps + Brewfile
#                        (level 0: Brewfile.level0, level 1: Brewfile.level1)
#   03  shell            oh-my-zsh, p10k, config/zshrc
#   04  node             nvm, Node 24, pnpm, bun, deno
#   05  python           uv, pipx (level 1+ only)
#   06  containers       Docker Desktop (level 2+ only)
#   07  ai-stack         Claude Code, Codex, Gemini CLI, Ollama
#                        (level 0/1: Claude Code only)
#   08  git-ssh          git config, SSH key, gh, pre-commit, gitleaks
#   09  macos-defaults   macOS developer settings (level 1+ only)
#   10  editors          VS Code + extensions (level 1+ only)
#   11  paved-road       ~/dev structure, dev/base (level 1+ only)
#   90  cleanup-legacy   OpenClaw cleanup (opt-in, never automatic)
#
# Examples:
#   ./bootstrap.sh --level 0 --yes       Emergency setup without prompts
#   ./bootstrap.sh --level 1             Base setup
#   ./bootstrap.sh --level 2 --dry-run   Simulate full setup
#   ./bootstrap.sh --list-levels         Show level overview
#   ./bootstrap.sh --only homebrew,node  Homebrew and Node only
#   ./bootstrap.sh --skip macos-defaults Without macOS settings
#   ./bootstrap.sh --only cleanup-legacy Remove legacy leftovers only
# =============================================================================
set -euo pipefail
# shellcheck disable=SC2088  # Tilde in display strings is intentional (display-only)

# Working directory = repo root (so relative paths work)
cd "$(dirname "${BASH_SOURCE[0]}")"

REPO_DIR="$(pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

source "$SCRIPTS_DIR/lib.sh"

# =============================================================================
# Default flags
# =============================================================================
DRY_RUN=0
YES_MODE=0
FULL_MODE=0
ONLY_MODULES=""
SKIP_MODULES=""
BOOTSTRAP_LEVEL=""    # empty = default run (equivalent to level 2)
MODULE_FAILURES=0
DOCTOR_FAILED=0
LIST_LEVELS=0

# =============================================================================
# Parse arguments
# =============================================================================
show_help() {
    sed -n '/^# Usage:/,/^# ====/{/^# ====/q; p;}' "$0" | sed 's/^# \{0,2\}//'
    exit 0
}

show_levels() {
    printf "\n"
    printf "%s%s┌─────────────────────────────────────────────────────────────────────┐%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
    printf "%s%s│  kickoff-ai — Setup levels (./bootstrap.sh --level <N>)             │%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
    printf "%s%s└─────────────────────────────────────────────────────────────────────┘%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
    printf "\n" >&2
    printf "%-5s %-13s %-10s %s\n" "Level" "Name" "Duration" "Modules" >&2
    printf "%s\n" "─────────────────────────────────────────────────────────────────────" >&2
    printf "%-5s %-13s %-10s %s\n" "0" "Emergency" "~15 min" "preflight, apple-toolchain (CLT), homebrew (core)," >&2
    printf "%-5s %-13s %-10s %s\n" "" "" "" "shell, node, git-ssh, ai-stack (Claude Code only)" >&2
    printf "\n" >&2
    printf "%-5s %-13s %-10s %s\n" "1" "Base" "~45 min" "+ Brewfile.level1, python (uv)," >&2
    printf "%-5s %-13s %-10s %s\n" "" "" "" "macos-defaults, editors (VS Code), paved-road" >&2
    printf "\n" >&2
    printf "%-5s %-13s %-10s %s\n" "2" "Full" "~2 h   " "+ containers (Docker), apple-toolchain (Xcode)," >&2
    printf "%-5s %-13s %-10s %s\n" "" "" "" "ai-stack (Codex, Gemini, Ollama + models)" >&2
    printf "%-5s %-13s %-10s %s\n" "" "" "" "[= default run without --level]" >&2
    printf "\n" >&2
    printf "%-5s %-13s %-10s %s\n" "3" "Maximum" "~3 h+  " "+ Brewfile.optional (ML, security, media)," >&2
    printf "%-5s %-13s %-10s %s\n" "" "" "" "automation/ (launchd jobs, if present)" >&2
    printf "\n" >&2
    printf "%sNote:%s Each level includes all modules from previous levels (cumulative).\n" "$_YELLOW" "$_RESET" >&2
    printf "      Re-running a level that was already completed is safe.\n" >&2
    printf "\n%sNext step:%s ./bootstrap.sh --level 0 --yes\n" "$_GREEN" "$_RESET" >&2
    printf "\n" >&2
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)     DRY_RUN=1 ;;
        --yes)         YES_MODE=1 ;;
        --full)        FULL_MODE=1; BOOTSTRAP_LEVEL=3 ;;
        --minimal)     BOOTSTRAP_LEVEL=0 ;;
        --level)       shift; BOOTSTRAP_LEVEL="${1:-}" ;;
        --only)        shift; ONLY_MODULES="${1:-}" ;;
        --skip)        shift; SKIP_MODULES="${1:-}" ;;
        --list-levels) LIST_LEVELS=1 ;;
        --help|-h)     show_help ;;
        *)
            err "Unknown option: $1 (--help for help)"
            ;;
    esac
    shift
done

# --list-levels takes priority (no further code)
if [ "$LIST_LEVELS" = "1" ]; then
    show_levels
fi

# Validate level
if [ -n "$BOOTSTRAP_LEVEL" ]; then
    case "$BOOTSTRAP_LEVEL" in
        0|1|2|3) ;;
        *) err "Invalid level: '$BOOTSTRAP_LEVEL' (allowed: 0, 1, 2, 3)" ;;
    esac
fi

# Export flags so sub-scripts can see them
export DRY_RUN YES_MODE FULL_MODE ONLY_MODULES SKIP_MODULES BOOTSTRAP_LEVEL

# =============================================================================
# Mark bootstrap mode (so 00-preflight keeps sudo alive)
# =============================================================================
export _BOOTSTRAP_MODE=1

# =============================================================================
# Header
# =============================================================================
printf "\n"
printf "%s%s╔══════════════════════════════════════════════╗%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
printf "%s%s║  kickoff-ai — Mac Setup Bootstrap            ║%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
printf "%s%s╚══════════════════════════════════════════════╝%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
printf "\n" >&2

if [ "$DRY_RUN" = "1" ]; then
    warn "DRY-RUN mode: NO changes will be made."
fi

if [ -n "$BOOTSTRAP_LEVEL" ]; then
    case "$BOOTSTRAP_LEVEL" in
        0) info "Level 0 — Emergency setup (~15 min): CLT, Shell, Node, git, Claude Code" ;;
        1) info "Level 1 — Base setup (~45 min): + Brewfile, Python, VS Code, macOS defaults" ;;
        2) info "Level 2 — Full setup (~2 h): + Docker, Xcode, Codex, Gemini, Ollama" ;;
        3) info "Level 3 — Maximum setup (~3 h+): + Brewfile.optional, automation/" ;;
    esac
else
    info "Default run — equivalent to level 2 (full, without Brewfile.optional)"
    info "Tip: ./bootstrap.sh --list-levels for a level overview"
fi

START_TIME=$(date '+%s')

# =============================================================================
# Module execution helpers
# =============================================================================

# Run a module.
# Parameters: <module_name> <script_filename> <display_name> [extra_env=val ...]
# Environment variables are set BEFORE the call and unset again afterwards.
run_module() {
    local modul_name="$1"
    local modul_script="$SCRIPTS_DIR/$2"
    local display_name="${3:-$modul_name}"
    # Additional parameters: "VAR=value" pairs for module-specific env vars
    shift 3 || true

    # --only / --skip filter
    if ! should_run_module "$modul_name"; then
        info "Module skipped: $display_name"
        summary_skip "$display_name"
        return 0
    fi

    if [ ! -f "$modul_script" ]; then
        warn "Module script not found: $modul_script"
        summary_warn "$display_name (script missing)"
        return 0
    fi

    # Set module-specific environment variables
    local env_pairs=""
    while [ $# -gt 0 ]; do
        env_pairs="$env_pairs $1"
        export "${1%%=*}"="${1#*=}"
        shift
    done

    # Forward arguments
    local args=""
    [ "$DRY_RUN"  = "1" ] && args="$args --dry-run"
    [ "$YES_MODE" = "1" ] && args="$args --yes"
    [ "$FULL_MODE" = "1" ] && args="$args --full"

    # Run module
    # shellcheck disable=SC2086
    if bash "$modul_script" $args; then
        summary_done "$display_name"
    else
        warn "Module failed: $display_name"
        summary_warn "$display_name (error)"
        # Counted, not just warned about. Continuing after a failure is a
        # convenience, not a redefinition of success: the run still ends
        # non-zero and does not claim to be complete.
        MODULE_FAILURES=$((MODULE_FAILURES + 1))
        if ! confirm "Continue with the next module?"; then
            err "Bootstrap aborted."
        fi
    fi

    # Unset module-specific env vars
    for pair in $env_pairs; do
        varname="${pair%%=*}"
        unset "$varname" 2>/dev/null || true
    done
}

# Skip a module when the current level is below the minimum required level
run_module_if_level() {
    local min_level="$1"
    shift
    local modul_name="$1"

    # When --only is set, delegate the decision to should_run_module
    if [ -n "$ONLY_MODULES" ]; then
        run_module "$@"
        return $?
    fi

    # Check level (default run equals level 2)
    local effective_level="${BOOTSTRAP_LEVEL:-2}"
    if [ "$effective_level" -lt "$min_level" ]; then
        info "Module requires level $min_level — skipped (current level: $effective_level)"
        # Record in summary
        summary_skip "${2:-$modul_name} (requires level $min_level)"
        return 0
    fi

    run_module "$@"
}

# =============================================================================
# Level logic: determine module variants
# =============================================================================

EFFECTIVE_LEVEL="${BOOTSTRAP_LEVEL:-2}"

# With --only we ignore the level logic for the listed modules
# (so run_module executes them despite the level filter)

# Apple Toolchain: level 0/1 = CLT only; level 2+ = full
if [ "$EFFECTIVE_LEVEL" -le 1 ] && [ -z "$ONLY_MODULES" ]; then
    APPLE_TOOLCHAIN_EXTRA="APPLE_CLT_ONLY=1"
else
    APPLE_TOOLCHAIN_EXTRA=""
fi
export APPLE_CLT_ONLY
APPLE_CLT_ONLY="${APPLE_CLT_ONLY:-0}"

# Homebrew: level 0 = Brewfile.level0, level 1 = Brewfile.level1,
# level 2+ = full Brewfile.
#
# Level 1 used the FULL Brewfile until 2026-08-11, which pulled in 25 packages
# the README places at level 2 or 3 — Docker, Go, Rust, PHP, Ruby, the JVM
# stack, the media toolchain. The level table was therefore wrong about both
# scope and the ~45 minute estimate, and "cumulative levels" was not a real
# boundary. Brewfile.level1 is derived from the registry (INV-8).
if [ -z "$ONLY_MODULES" ]; then
    case "$EFFECTIVE_LEVEL" in
        0) HOMEBREW_EXTRA="OVERRIDE_BREWFILE=$REPO_DIR/Brewfile.level0" ;;
        1) HOMEBREW_EXTRA="OVERRIDE_BREWFILE=$REPO_DIR/Brewfile.level1" ;;
        *) HOMEBREW_EXTRA="" ;;
    esac
else
    HOMEBREW_EXTRA=""
fi

# AI stack: level 0/1 = Claude only; level 2+ = full
if [ "$EFFECTIVE_LEVEL" -le 1 ] && [ -z "$ONLY_MODULES" ]; then
    AI_STACK_EXTRA="AI_CLAUDE_ONLY=1"
else
    AI_STACK_EXTRA=""
fi

# =============================================================================
# Run modules (level-dependent)
# =============================================================================

# --- Level 0 (always) ---
run_module "preflight" "00-preflight.sh" "00 Preflight checks"

# shellcheck disable=SC2086
if [ -n "$APPLE_TOOLCHAIN_EXTRA" ]; then
    run_module "apple-toolchain" "01-apple-toolchain.sh" "01 Apple CLT (level 0)" $APPLE_TOOLCHAIN_EXTRA
else
    run_module "apple-toolchain" "01-apple-toolchain.sh" "01 Apple Toolchain (full)"
fi

# shellcheck disable=SC2086
if [ -n "$HOMEBREW_EXTRA" ]; then
    run_module "homebrew" "02-homebrew.sh" "02 Homebrew (emergency core)" $HOMEBREW_EXTRA
else
    run_module "homebrew" "02-homebrew.sh" "02 Homebrew"
fi

run_module "shell"    "03-shell.sh"  "03 Shell (oh-my-zsh, p10k)"
run_module "node"     "04-node.sh"   "04 Node (nvm, pnpm, bun)"

# --- Level 1+ ---
run_module_if_level 1 "python" "05-python.sh" "05 Python (uv)"

# --- Level 2+: Containers ---
run_module_if_level 2 "containers" "06-containers.sh" "06 Containers (Docker)"

# --- AI stack (level 0/1 = Claude only, level 2+ = full) ---
# shellcheck disable=SC2086
if [ -n "$AI_STACK_EXTRA" ]; then
    run_module "ai-stack" "07-ai-stack.sh" "07 AI stack (Claude Code only)" $AI_STACK_EXTRA
else
    run_module "ai-stack" "07-ai-stack.sh" "07 AI stack (full)"
fi

run_module "git-ssh" "08-git-ssh.sh" "08 Git, SSH, pre-commit"

# --- Level 1+ ---
run_module_if_level 1 "macos-defaults" "09-macos-defaults.sh" "09 macOS defaults"
run_module_if_level 1 "editors"        "10-editors.sh"         "10 Editors (VS Code)"
run_module_if_level 1 "paved-road"     "11-paved-road.sh"      "11 Paved Road (~/dev)"

# --- Level 3: Brewfile.optional and automation/ ---
if [ "$EFFECTIVE_LEVEL" -ge 3 ] || { [ -n "$ONLY_MODULES" ] && echo ",$ONLY_MODULES," | grep -q ",homebrew-optional,"; }; then
    step "Level 3 — Optional packages and automation"

    # Brewfile.optional
    if [ -f "$REPO_DIR/Brewfile.optional" ]; then
        info "Installing Brewfile.optional..."
        if [ "$DRY_RUN" = "1" ]; then
            info "[dry-run] Would run: brew bundle --file=$REPO_DIR/Brewfile.optional"
        else
            brew bundle --file="$REPO_DIR/Brewfile.optional" --no-lock
            ok "Brewfile.optional installed"
        fi
        summary_done "Brewfile.optional"
    fi

    # automation/ — built separately, just needs to be present
    AUTOMATION_DIR="$REPO_DIR/automation"
    LAUNCHD_SCRIPT="$AUTOMATION_DIR/launchd/install-launchd.sh"

    if [ -f "$LAUNCHD_SCRIPT" ]; then
        info "Running automation/launchd/install-launchd.sh..."
        if [ "$DRY_RUN" = "1" ]; then
            info "[dry-run] Would run: $LAUNCHD_SCRIPT"
            summary_done "automation/launchd"
        else
            bash "$LAUNCHD_SCRIPT" && summary_done "automation/launchd" || \
                summary_warn "automation/launchd (error)"
        fi
    else
        warn "automation/launchd/install-launchd.sh not found — skipped."
        info "Re-run once available: ./bootstrap.sh --level 3"
        summary_skip "automation/launchd (not yet present)"
    fi

    # Hint about legacy cleanup
    info ""
    info "Level 3 — Note: remove OpenClaw leftovers:"
    info "  ./bootstrap.sh --only cleanup-legacy --yes"
fi

# cleanup-legacy: ONLY via explicit --only
if [ -n "$ONLY_MODULES" ]; then
    case ",$ONLY_MODULES," in
        *",cleanup-legacy,"*)
            run_module "cleanup-legacy" "90-cleanup-legacy.sh" "90 Legacy cleanup"
            ;;
    esac
fi

# =============================================================================
# Zusammenfassung
# =============================================================================
END_TIME=$(date '+%s')
ELAPSED=$((END_TIME - START_TIME))

# "Complete" is a claim about the outcome, so it is only printed when the
# outcome supports it. README promises that FAILs block the setup as complete;
# until now this banner and exit 0 came unconditionally, so an automated caller
# could not tell a clean run from a broken one.
if [ "$MODULE_FAILURES" -eq 0 ]; then
    printf "\n%s%s========================================%s\n" "$_BOLD" "$_GREEN" "$_RESET" >&2
    printf "%s%s  All modules finished (%ds) — verifying...%s\n" "$_BOLD" "$_GREEN" "$ELAPSED" "$_RESET" >&2
    printf "%s%s========================================%s\n" "$_BOLD" "$_GREEN" "$_RESET" >&2
else
    printf "\n%s%s========================================%s\n" "$_BOLD" "$_RED" "$_RESET" >&2
    printf "%s%s  Bootstrap INCOMPLETE — %d module(s) failed (%ds)%s\n" \
        "$_BOLD" "$_RED" "$MODULE_FAILURES" "$ELAPSED" "$_RESET" >&2
    printf "%s%s========================================%s\n" "$_BOLD" "$_RED" "$_RESET" >&2
fi

# The guided app is the thing a person is most likely to want next and least
# likely to know exists — nothing on the command-line path mentions it, so
# somebody arriving through prepare.sh would never find out.
printf "\n%s%s  Next: ./start.sh%s opens the Control Room in your browser —\n" \
    "$_BOLD" "$_CYAN" "$_RESET" >&2
printf "  where this Mac stands, what to do next, and every command below behind\n" >&2
printf "  a button. It changes nothing until you tell it to.\n" >&2

# Manual steps
summary_manual "claude login                 → Connect Claude Code to your account"
summary_manual "Open a new shell             → Activate all PATH changes"
summary_manual "Create $HOME/.zshrc.local  → For tokens, CLAUDE_CODE_SUBAGENT_MODEL, etc."
if [ "$EFFECTIVE_LEVEL" -ge 2 ]; then
    summary_manual "codex login              → Authenticate OpenAI Codex CLI"
    summary_manual "gemini login             → Authenticate Gemini CLI"
    summary_manual "gh ssh-key add $HOME/.ssh/id_ed25519.pub  → Add SSH key to GitHub"
fi
if [ "$EFFECTIVE_LEVEL" -lt 3 ]; then
    summary_manual "./bootstrap.sh --only cleanup-legacy  → Remove OpenClaw leftovers"
fi

print_summary

# =============================================================================
# Next step (only when a level was explicitly selected)
# =============================================================================
if [ -n "$BOOTSTRAP_LEVEL" ] && [ "$BOOTSTRAP_LEVEL" -lt 3 ]; then
    NEXT_LEVEL=$((BOOTSTRAP_LEVEL + 1))
    printf "\n%s%s─────────────────────────────────────────────%s\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
    printf "%s%s  You are now at level %s.%s\n" "$_BOLD" "$_CYAN" "$BOOTSTRAP_LEVEL" "$_RESET" >&2
    case "$NEXT_LEVEL" in
        1) printf "  %sNext step:%s ./bootstrap.sh --level 1\n" "$_GREEN" "$_RESET" >&2
           printf "  (Adds: full Brewfile, Python, VS Code, macOS defaults)\n" >&2 ;;
        2) printf "  %sNext step:%s ./bootstrap.sh --level 2\n" "$_GREEN" "$_RESET" >&2
           printf "  (Adds: Docker, full Xcode, Codex, Gemini, Ollama)\n" >&2 ;;
        3) printf "  %sNext step:%s ./bootstrap.sh --level 3\n" "$_GREEN" "$_RESET" >&2
           printf "  (Adds: Brewfile.optional (ML, security), automation/)\n" >&2 ;;
    esac
    printf "%s%s─────────────────────────────────────────────%s\n\n" "$_BOLD" "$_CYAN" "$_RESET" >&2
fi

# =============================================================================
# Run doctor.sh
# =============================================================================
if [ -f "$REPO_DIR/doctor.sh" ]; then
    info "Running doctor.sh..."
    printf "\n" >&2
    # NOT --no-exit: that flag makes doctor return 0 even when it reports
    # FAILs, which is exactly how a FAIL used to end up in an overall exit 0.
    # The `if !` already prevents doctor from terminating bootstrap under
    # `set -e`, so suppressing its exit code buys nothing and hides the result.
    DOCTOR_ARGS=""
    [ -n "$BOOTSTRAP_LEVEL" ] && DOCTOR_ARGS="--level $BOOTSTRAP_LEVEL"
    # shellcheck disable=SC2086
    if ! bash "$REPO_DIR/doctor.sh" $DOCTOR_ARGS; then
        DOCTOR_FAILED=1
    fi
fi

if [ "$DRY_RUN" = "1" ]; then
    printf "\n%s%sDRY-RUN complete — no changes were made.%s\n" "$_BOLD" "$_YELLOW" "$_RESET" >&2
    printf "%sReal setup run: ./bootstrap.sh --level %s --yes%s\n" "$_YELLOW" "${BOOTSTRAP_LEVEL:-2}" "$_RESET" >&2
fi

sudo_keepalive_stop 2>/dev/null || true

# =============================================================================
# Exit code
#
# A setup script is something other scripts call. "It ran" and "it worked" have
# to be distinguishable, or every caller downstream inherits a false premise.
#   0  everything ran and doctor is clean
#   1  at least one module failed
#   2  modules ran, but doctor reports FAILs
# =============================================================================
if [ "$MODULE_FAILURES" -gt 0 ]; then
    warn "$MODULE_FAILURES module(s) failed — the setup is NOT complete."
    exit 1
fi
if [ "$DOCTOR_FAILED" = "1" ]; then
    warn "doctor.sh reports FAILs — the setup is not verified. Fix them and re-run."
    exit 2
fi
exit 0
