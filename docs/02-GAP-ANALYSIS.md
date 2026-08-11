# Gap Analysis — An Honest Look at the Setup

This document has two parts:

- **Part A:** Concrete, verified defects in the current setup — what is broken or working suboptimally.
- **Part B:** What professional AI developers with a similar profile do that is missing here.

At the end: a prioritized Top 10 list — the highest leverage per hour invested.

The findings are written so they transfer to any similarly evolved machine — as patterns, not as personal characterizations.

---

## Part A — Concrete Defects in the Current Setup

### A.1 — Legacy Agent Gateway: Remove Completely

**Finding:** An agent gateway tool (OpenClaw) is registered three times: as an npm global package, as a pnpm global link, and as a LaunchAgent. An environment variable `OPENCLAW_PATH` points to a directory (`~/dev/openclaw`) that **no longer exists**. Four shell aliases and two completion blocks in `.zshrc` point at nothing. The pnpm global link points to the same nonexistent path.

Verification:
```bash
ls ~/dev/openclaw 2>&1   # "No such file or directory"
npm list -g --depth=0 | grep openclaw
pnpm list -g | grep openclaw
cat ~/.zshrc | grep -n OPENCLAW
launchctl list | grep openclaw
```

**Impact:** Every shell startup potentially generates silent errors. `pnpm` executes a link call to a dead path. The LaunchAgent attempts to start the gateway at every login — and fails.

**Fix:** `scripts/90-cleanup-legacy.sh` (opt-in, not part of `bootstrap.sh`) cleans up completely. Back up first:

What to remove:
- `npm uninstall -g openclaw clawhub`
- `pnpm remove -g openclaw`
- `launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist` + delete the file
- `rm -rf ~/.openclaw` — **but only after backing up `~/.openclaw/credentials/` and `~/.openclaw/telegram/` to 1Password**
- `brew untap openclaw/tap` (also contains the `goplaces` formula)
- In `.zshrc`: `OPENCLAW_PATH`, four aliases (`openclaw`, `openclaw-gateway`, `wakeup-clawy`, `clawrestart`), two completion blocks

**Priority:** High — fix immediately. The script `scripts/90-cleanup-legacy.sh` handles this automatically with backup.

---

### A.2 — Environment Variable Pointing at a Nonexistent Directory (M2_HOME)

**Finding:** `M2_HOME=$HOME/dev/maven` is set in `.zshrc`. The directory does not exist — Maven runs from the Homebrew prefix (`/opt/homebrew/bin/mvn`). `M2_HOME` is also no longer necessary for current Maven; the value was historically required for Maven 2 projects.

Verification:
```bash
echo $M2_HOME && ls $M2_HOME 2>&1
mvn --version   # correctly points to brew-maven
```

**Fix:** Remove the `M2_HOME` line from `.zshrc`.
**Priority:** Low — no immediate harm, just configuration noise.

---

### A.3 — Framework Completion for a Tool That Is Not Installed

**Finding:** `source <(ng completion script)` in `.zshrc` loads the Angular CLI completion. Angular CLI is not installed. The command fails silently (suppressed) but slows down shell startup and is misleading for anyone reading the `.zshrc`.

Verification:
```bash
which ng 2>&1   # "ng not found"
```

**Fix:** Remove the line from `.zshrc`. If Angular is needed later: `npm install -g @angular/cli` and add the completion line back.
**Priority:** Low.

---

### A.4 — PATH Duplicates and Duplicate Dotfile Entries

**Finding:** Multiple shell files produce duplicate entries:
- `/usr/local/bin` appears multiple times in PATH
- `/usr/bin` appears multiple times in PATH
- `.local/bin` appears multiple times in PATH (once in `.profile`, once in `.zshrc`)
- VS Code PATH block is duplicated in `.zprofile`
- OpenClaw completion block is duplicated in `.zshrc`

Verification:
```bash
echo $PATH | tr ':' '\n' | sort | uniq -d
```

**Impact:** PATH grows longer than necessary, shell startup slows down, debugging becomes harder.

**Fix:** Use `config/zshrc` from this repo — it uses `typeset -U path` for automatic deduplication. `config/zprofile` contains the VS Code PATH entry exactly once.
**Priority:** Medium.

---

### A.5 — System git Wins Against Homebrew git

**Finding:** `/usr/bin/git` (Apple CLT version) precedes `/opt/homebrew/bin/git` (the most recent git version) in PATH order. This means `which git` returns `/usr/bin/git`, and features of newer git versions are unavailable. `git-lfs` and certain hooks may also be affected.

Verification:
```bash
which git          # shows /usr/bin/git instead of /opt/homebrew/bin/git
git --version      # shows Apple version (lower)
/opt/homebrew/bin/git --version   # shows brew version
```

**Fix:** Place `/opt/homebrew/bin` before `/usr/bin` in `.zshrc` PATH — `config/zshrc` already does this.
**Priority:** Medium.

---

### A.6 — conda-base Anti-Pattern

**Finding:** `python3` in the shell points to conda-base 3.10.9. The conda-base environment contains packages from various unrelated projects (machine learning, scientific computing, web scraping, flashcard software). conda itself is at version 22.11.1 — two major versions behind (current as of 2026: 25.x).

Verification:
```bash
python3 --version      # shows 3.10.9 instead of brew-Python or uv-managed Python
conda --version        # 22.11.1 vs. current 25.x
conda list | wc -l     # shows number of packages installed in base
which python3          # ~/miniforge3/bin/python3 instead of /opt/homebrew/bin/python3
```

**Impact:** Project isolation does not work in practice when `python3` globally points to conda-base. Newly set-up projects uncontrollably inherit packages from the base environment.

**Fix:** `config/zshrc` does not auto-activate conda-base. `python3` then points to Homebrew Python or is managed per-project by `uv python`. `conda activate <env>` continues to work explicitly. Do **not** delete conda-base — existing envs (`notebooklm` etc.) stay intact.
**Priority:** High.

---

### A.7 — pre-commit Config Exists but the Tool Is Missing

**Finding:** `dev/base` contains a `.pre-commit-config.yaml` (with a gitleaks hook and additional checks) and a `.gitleaks.toml`. The `pre-commit` tool itself is **not installed** on the machine — not via pip, pipx, or brew. The hooks therefore never run.

Verification:
```bash
pre-commit --version 2>&1   # "command not found"
ls ~/dev/base/.pre-commit-config.yaml   # file exists
```

**Impact:** Secret scanning and code quality checks run on no commit. The central safety net in `dev/base` is inactive.

**Fix:**
```bash
brew install pre-commit
cd ~/dev/base && pre-commit install --install-hooks
```

The script `scripts/02-homebrew.sh` now installs `pre-commit` as a required package in the `Brewfile`. `scripts/08-git-ssh.sh` runs `pre-commit install` in `dev/base`.
**Priority:** High — fix immediately.

---

### A.8 — Global .gitignore Is Empty and Not Registered

**Finding:** `~/.gitignore_global` exists but is empty (0 bytes). It is also not registered as `core.excludesfile` in the global git configuration — meaning git ignores it entirely.

Verification:
```bash
git config --global core.excludesfile   # empty or not set
wc -c ~/.gitignore_global               # 0 bytes
```

**Impact:** `.DS_Store`, `.env`, `node_modules`, `__pycache__`, `.idea`, `.vscode/` and other system-specific files are not ignored globally. They must be listed in every individual repo's `.gitignore` — or they end up in the repo accidentally.

**Fix:** `config/gitignore_global` from this repo contains sensible global ignores. `scripts/08-git-ssh.sh` registers it:
```bash
git config --global core.excludesfile ~/.gitignore_global
```
**Priority:** High.

---

### A.9 — Outdated SSH Key Type, No Commit Signing

**Finding:** There is only one SSH key, generated in 2024, in RSA format. No GPG keys (gnupg is installed, trust DB was empty at scan time). Commits are not signed (`commit.gpgsign` is not set).

Verification:
```bash
ls -la ~/.ssh/*.pub          # shows id_rsa_*.pub
ssh-keygen -l -f ~/.ssh/*.pub  # shows RSA
git config --global commit.gpgsign   # empty
gpg --list-keys              # no keys
```

**Impact:** RSA is not insecure, but ed25519 is the current standard. Without commit signing there is no cryptographic proof that commits actually came from you — this matters especially for public repos and GitHub contributions.

**Fix:** `scripts/08-git-ssh.sh` generates a new ed25519 key and configures SSH commit signing (no GPG — simpler, same security for this use case).
**Priority:** Medium.

---

### A.10 — git maintenance Points at a Nonexistent Path

**Finding:** `git config --global maintenance.repo` points to a path that no longer exists (a company repo path from an earlier configuration). git maintenance runs daily/hourly/weekly via LaunchAgents (`org.git-scm.git.daily/hourly/weekly`) — and fails silently.

Verification:
```bash
git config --global maintenance.repo   # shows a path that does not exist
ls <the-shown-path> 2>&1              # "No such file or directory"
```

**Fix:**
```bash
git config --global --unset maintenance.repo
# Then re-register if needed:
git maintenance register   # in the current repo
```
**Priority:** Low.

---

### A.11 — Stale LaunchAgent for an Uninstalled Package

**Finding:** `~/Library/LaunchAgents/homebrew.mxcl.mariadb.plist` exists even though MariaDB is no longer installed. The agent attempts to start MariaDB at every login — and fails.

Verification:
```bash
ls ~/Library/LaunchAgents/ | grep mariadb   # plist present
brew list | grep mariadb                     # empty
```

**Fix:** `scripts/90-cleanup-legacy.sh` removes this LaunchAgent.
```bash
launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.mariadb.plist
rm ~/Library/LaunchAgents/homebrew.mxcl.mariadb.plist
```
**Priority:** Low.

---

### A.12 — Ollama Installed Three Ways Simultaneously

**Finding:** Ollama is present through three separate channels: as a brew formula (`ollama`), as a brew cask (`ollama-app`), and as a running Docker container (in the context of an AI project). All three may be running in parallel. The brew formula and cask are different things — the cask is a native macOS app with a menu bar icon, the formula is a CLI service.

Verification:
```bash
brew list | grep ollama           # ollama (formula) AND ollama-app (cask)?
docker ps | grep ollama           # container?
ls /Applications/Ollama.app 2>/dev/null
```

**Impact:** Potentially two Ollama instances on port 11434 — race condition on `ollama serve`. The Docker container has no Metal GPU access on macOS and runs CPU-only.

**Fix:** Keep only the brew formula:
```bash
brew uninstall --cask ollama   # remove the GUI app
# stop the Docker container and do not start it again
```
The module `scripts/07-ai-stack.sh` installs only the formula.
**Priority:** Medium.

---

### A.13 — 16 Containers Running Permanently

**Finding:** At the time of measurement, 16 Docker containers were running, some for weeks, including five MySQL instances for different projects. Only one container was in `exited` state. The pattern: docker-compose stacks for various projects were started and never stopped.

Verification:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"
docker ps | wc -l   # number of running containers
```

**Impact:** Multiple GB of RAM permanently occupied, unnecessary energy consumption, ports blocked that other services might need.

**Fix:** Follow the convention: `docker compose up -d` before work, `docker compose down` after. No autostart for project containers.
```bash
# Immediately: stop all non-persistent containers
docker compose down   # in each project directory
# or globally:
docker stop $(docker ps -q)
```
**Priority:** Medium.

---

### A.14 — 96% Storage Used

**Finding:** Of 926 GB SSD, only ~43 GB are free (96% used). The largest blocks are Docker images and volumes, the conda-base installation with hundreds of packages, and Ollama models (~18 GB combined).

Verification:
```bash
df -h ~
docker system df          # Docker storage
du -sh ~/miniforge3/      # conda
du -sh ~/.ollama/models/  # Ollama models
```

**Impact:** macOS starts showing performance degradation below 10% free storage. Pulling new Ollama models fails. Docker builds may fail.

**Fix (by priority):**
```bash
docker system prune -a       # unused images, volumes, containers (CAUTION: check what will go)
conda clean --all            # conda caches
brew cleanup --prune=30      # Homebrew caches
rm -rf ~/Library/Caches/     # macOS app caches (selectively)
```

And structurally: remove packages from conda-base (keep base minimal, put packages in project-specific envs), delete Docker volumes for finished projects.
**Priority:** High — do this before pulling new models.

---

### A.15 — AI CLI Security Settings: Too Permissive

**Finding:** Claude Code is configured with `skipDangerousModePermissionPrompt`, `skipAutoPermissionPrompt`, and `defaultMode: auto`. Codex CLI has `approval_mode = "full-auto"` set and trusts 17 projects at the "trusted" level — including the entire home directory (`~`).

This means: Claude Code and Codex can write files, delete files, and execute commands in these directories without a confirmation dialog.

Verification:
```bash
jq '.skipDangerousModePermissionPrompt, .skipAutoPermissionPrompt' ~/.claude/settings.json
grep approval_mode ~/.codex/config.toml
grep -A2 'trust_level = "trusted"' ~/.codex/config.toml
```

**Impact:** With a bad prompt, a misunderstanding, or a prompt injection from processed files, an agent can perform destructive actions without asking. The risk is real — not theoretical.

**Recommended middle ground:**
- Claude Code: set `skipAutoPermissionPrompt` to `false` for all `Bash` commands except those on the explicit allow list. The allow list stays (curl, npm test, git status, tsc). Set `skipDangerousModePermissionPrompt` to `false`.
- Codex: set `approval_mode = "suggest"` instead of `full-auto`. Remove the home directory (`~`) from the trusted list — use only concrete project paths.
- Both: keeping `Read(**/.env)` in the deny list is correct and should stay.

The trade-off: slightly more confirmation clicks, but no unsupervised write access to the entire home directory.
**Priority:** High.

---

### A.16 — `~/dev/scripts` Contains No Scripts

**Finding:** A directory is named `~/dev/scripts` but contains not a general script collection but rather files from a specific project (prose files and project-specific helper scripts). Shell aliases point to a file (`media-tools.sh`) in this directory — that works, but the directory name is misleading for anyone looking for setup scripts.

Verification:
```bash
ls ~/dev/scripts/    # no setup scripts, instead a manuscript directory
```

**Impact:** Naming confusion. Someone searching `~/dev/scripts` expects scripts, finds a writing project.

**Fix:** Rename the directory to `~/dev/<project-name>` or `~/dev/writing/<project-name>`. Update aliases in `.zshrc`.
**Priority:** Low.

---

### A.17 — Two GitHub Accounts Without a Defined Separation Rule

**Finding:** Two GitHub accounts are logged in via `gh` — one as default, one as secondary. `.ssh/config` has only one SSH host block (for `github.com`). There is no documented rule for which account is used for which repos.

Verification:
```bash
gh auth status          # shows both accounts
cat ~/.ssh/config       # shows whether github.com has one or two entries
```

**Impact:** Without clear separation, `git push` can accidentally use the wrong account. CI secrets and deployment keys can become mixed.

**Fix:** Two SSH host aliases in `~/.ssh/config` (e.g., `github-primary` and `github-secondary`). Clone secondary-account repos with `git clone git@github-secondary:<org>/<repo>.git`. Update existing repos' remote URLs where needed:
```bash
git remote set-url origin git@github-secondary:<org>/<repo>.git
```
**Priority:** Medium.

---

## Part B — What Professional AI Developers with a Similar Profile Do That Is Missing Here

The profile: 36 frontend repos (Vite/React/TypeScript/Tailwind + vitest), 10 Python services (FastAPI/Pydantic/pytest/ruff), LangChain/LangGraph + Anthropic/OpenAI/Ollama for AI, iOS apps, 2 additional AI agent CLIs alongside Claude Code, a custom paved road (`dev/base`), 58 repos total.

---

### B.1 — Day-to-Day Secrets Management: .env Files in Plaintext

**Finding:** `.env` files are stored as plaintext files on disk — at least one of them directly in `~/dev/` (as a deploy env file). There is no secrets backend keeping the values off disk.

**Solution:** Vaultwarden (self-hosted Bitwarden server as a Docker stack) and `env-run` (a wrapper that resolves `bw://` references and injects secrets exclusively into the target process environment, never as a file or in `ps` arguments).

```bash
# Instead of .env with plaintext values:
env-run -- uvicorn app.main:app

# .env.template contains only references (can be committed):
# OPENAI_API_KEY=bw://openai-api/password
# DATABASE_URL=bw://my-service/url
```

**Leverage:** High — protects against accidental commits, AirDrop leaks, and shoulder surfing.

**Effort:** 3–5 hours (setting up the Vaultwarden stack + secret migration).
The Vaultwarden setup cost does not apply if using 1Password exclusively, but is a one-time investment here. Migration helper: `env-run migrate .env`.

Full guide: [docs/08-SECRETS.md](08-SECRETS.md)

---

### B.2 — Dotfiles as a Versioned Repo

**Finding:** Backups of the shell config exist (`~/.zshrc_bkp`, `~/.zshrc.save`), but there is no dotfiles repo. The configuration is therefore only locally versioned and not easily deployable on a new machine — which is one of the main reasons for this setup repo.

**Options:**
- **GNU Stow** (symlink-based): simple, transparent, widely used
- **Bare-repo approach**: no helper tool required, slightly more configuration overhead
- **chezmoi**: more advanced, supports encrypted secrets and templates

**Leverage:** Medium — this kickoff-ai repo solves the problem for new machine setups; a dotfiles repo would version *incremental changes* between setup runs.
**Effort:** 2–4 hours initially.

---

### B.3 — No Unified Toolchain Versioning (mise/asdf)

**Finding:** Node is managed via nvm, Python via uv + conda, Java via brew-openjdk. No single tool knows the complete version state. `.nvmrc` is present in only 2 of 36 frontend repos.

**What is missing:** A tool like `mise` (successor to `asdf`) can version-pin Node, Python, Java, Go, and Rust in a single `.mise.toml` per repo:
```toml
[tools]
node = "24"
python = "3.13"
```

**Counter-indication:** `mise` would be an additional tool on top of nvm+uv. The right time to migrate is a clean rebuild — not incrementally. The current decision (nvm+uv) is documented in [04-DECISIONS.md](04-DECISIONS.md).

**Leverage:** Medium — mainly relevant for reproducible project setups.
**Effort:** 1–2 hours migration, then ongoing maintenance.

---

### B.4 — LLM Observability: langfuse Cloned but Not Productively Used

**Finding:** `langfuse` is present as a repository under `~/dev/` (fork/clone). There is no indication it has been instrumented for any active projects.

**What is missing:**
```python
# In FastAPI/LangChain projects:
from langfuse.callback import CallbackHandler

handler = CallbackHandler(
    public_key=os.getenv("LANGFUSE_PUBLIC_KEY"),
    secret_key=os.getenv("LANGFUSE_SECRET_KEY"),
)
chain.invoke({"input": "..."}, config={"callbacks": [handler]})
```

Langfuse provides per-LLM-call: latency, token consumption, model, input/output — aggregated across projects.

**Leverage:** High for AI projects in production. With LangChain in 4 repos and LangGraph in 2, this is exactly the right use case.
**Effort:** 2–4 hours for integration into existing projects + self-hosting or Langfuse Cloud.

---

### B.5 — No Eval Harness for Prompts and Agents

**Finding:** No indication of systematic prompt testing or agent eval. LLM output quality is assessed manually.

**What professional AI developers do:**
- `pytest` + `langchain/evaluation` for unit tests of prompt templates
- Snapshot tests: fix expected outputs as regression tests
- LLM-as-judge: a cheap model evaluates the output of a more expensive model for correctness

```python
# Minimal: pytest-based eval
def test_extraction_quality():
    result = extract_entities(sample_text)
    assert result["persons"] == expected_persons
    assert result["confidence"] > 0.8
```

**Leverage:** High — prevents regressions when prompts change.
**Effort:** 4–8 hours initially, then as part of the quality gate.

---

### B.6 — No Cost Control Across All Agent CLIs

**Finding:** Claude Code has a cost brake for subagents (`CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6`). For the other CLIs (Codex, Gemini, and any further agent tools), there is no measured or visible cost control.

**What is missing:**
- Set monthly token budgets in the API consoles (Anthropic, OpenAI, Google)
- Aggregated dashboard: costs across all services per week
- Alert thresholds via email/webhook when budget reaches X%

**Leverage:** Medium — becomes important when agent workflows run on a schedule (cron, LaunchAgents).
**Effort:** 1 hour to configure budgets in all consoles.

---

### B.7 — CI Gate Does Not Match the Local Gate

**Finding:** `dev/base` defines a local quality gate (`./scripts/gate.sh` or `npm run verify:ci`). There is no CI pipeline (GitHub Actions or similar) that runs the same gate on every push.

**What is missing:**
```yaml
# .github/workflows/ci.yml (via dev/base/standards/ci)
jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run verify:ci   # type-check + lint + tests
```

**Context:** 15 of 58 repos have `docker-compose.yml`, 4 have `Makefile` — many already have build logic. What is missing is the GitHub Actions integration.

**Leverage:** High for repos with more than one contributor. Medium for solo projects.
**Effort:** 1–2 hours per repo category, then a template in `dev/base`.

---

### B.8 — Backup/Restore Strategy: Unclear

**Finding:** No Time Machine status visible. No indication of cloud backup (Backblaze, iCloud Drive for non-dev data, etc.).

**What to clarify:**
```bash
tmutil status       # is Time Machine running?
tmutil latestbackup # when was the last backup?
```

**Leverage:** Very high — with 96% storage utilization, the risk of data loss from running out of space is real.
**Effort:** 1 hour setup, then Time Machine runs automatically.

---

### B.9 — Storage Hygiene as a Recurring Job

**Finding:** 96% SSD utilization is a systemic condition, not a one-time problem. Without regular hygiene it will recur.

**Recommended monthly cron job:**
```bash
# Homebrew caches
brew cleanup --prune=30

# Docker
docker system prune -f --filter "until=720h"   # artifacts older than 30 days

# Conda caches
conda clean --all -y

# Report
df -h ~ && docker system df && du -sh ~/.ollama/models/
```

**Leverage:** High on this machine.
**Effort:** 30 minutes once, then automatic.

---

### B.10 — Repo Sprawl: 58 Directories, No Lifecycle Management

**Finding:** 58 entries in `~/dev/`, of which probably 10–15 are actively used. Many repos (open-source clones: langfuse, Scrapling, Anki-Android, screenshot-to-code, and others) were cloned, possibly used once, and remain on disk.

**What is missing:**
```bash
base status   # shows which repos are active vs. inactive
```

Or a lifecycle label: `active`, `archived`, `experiment`. Mark archive repos on GitHub as "archived", delete them locally (they are recoverable via git clone).

**Leverage:** Medium — disk space and mental clarity.
**Effort:** 1–2 hours of housekeeping, then 15 minutes monthly.

---

## Top 10: If You Only Do 10 Things, Do These

Prioritized by leverage per hour invested:

| # | Action | Part | Effort | Benefit |
|---|---|---|---|---|
| 1 | **Install pre-commit + wire it up in dev/base** (A.7) | A | 30 min | Safety net active |
| 2 | **Clean up 96% storage** (A.14) | A | 1–2 h | Stability, new models possible |
| 3 | **Remove legacy agent gateway** via `scripts/90-cleanup-legacy.sh` (A.1) | A | 30 min | Clean shell, no dead code |
| 4 | **Tighten Claude Code + Codex security settings** (A.15) | A | 30 min | No unsupervised full access |
| 5 | **Set up Vaultwarden + env-run** (B.1) | B | 3–5 h | Secrets never in plaintext again |
| 6 | **Remove conda-base from the default python** + uv as standard (A.6) | A | 1 h | Project isolation works |
| 7 | **Fill and register global .gitignore** (A.8) | A | 30 min | No system files in repos |
| 8 | **Integrate langfuse into LangChain/LangGraph projects** (B.4) | B | 2–4 h | Cost and quality visibility |
| 9 | **Clarify backup strategy** (Time Machine or cloud) (B.8) | B | 1 h | Data loss protection |
| 10 | **Configure two GitHub accounts with clean SSH separation** (A.17) | A | 1 h | No wrong account on wrong repo |
