# Decisions — Why Exactly This and Not Something Else

ADR-style rationale for the tool decisions in this setup. Each entry follows the pattern: Context · Decision · Why not the alternative · Cost.

This documentation is written for two audiences: for yourself when you ask in two years "why did we do it that way?" — and for others who want to adapt this setup but may not share certain decisions.

---

## 1. uv Instead of conda-base as the Python Default

**Context:** The Python stack is the largest source of maintenance overhead in a mixed development environment. A machine with conda-base quickly accumulates hundreds of packages from different projects, all in one environment, with `python3` pointing at it globally.

**Decision:** `uv` is the primary tool for Python projects. conda remains installed but is not auto-activated.

**Why not conda-base as the default:**
- conda-base is by convention the "system Python" of the conda ecosystem — it should stay minimal
- Hundreds of packages in base cause conflicts between projects
- conda 22.x is slow at dependency resolution; uv is 10–100× faster
- `uv.lock` is deterministic and committable — conda `environment.yml` is not reliably so

**Why not pip/venv:**
- uv fully replaces pip/venv and is faster
- `uv python install 3.13` also manages Python versions — no pyenv needed

**Cost:**
- Existing conda projects do not need to be migrated; they can continue using conda envs
- Teams with conda workflows (science, ML) need adjustment
- `uvx ruff` instead of `pipx run ruff` — a small habit change

**When conda is still the right choice:** Projects that require conda-forge-only packages (e.g., SPSS bindings, specific MKL optimizations, proprietary scientific packages).

---

## 2. nvm + Node 24 Instead of mise/asdf

**Context:** Node version management is a daily concern: 36 frontend repos, some with `.nvmrc`, some without.

**Decision:** nvm remains the primary tool for Node version management. Node 24 as default.

**Why not mise or asdf:**
- mise can *replace* nvm, conda, and uv — but migration in a running environment is expensive
- mise `.mise.toml` is an additional config layer; existing `.nvmrc` files would need to be retained
- mise is the better long-term choice for a clean rebuild from scratch; not for an incremental switch

**When mise would be the better choice:**
- A rebuild with no legacy projects
- A team environment where everyone should share the same toolchain solution
- When Python + Node + Go + Rust all need to be version-pinned per project

**Cost:** No `.mise.toml` files in repos → toolchain version must be documented separately in `.nvmrc` and `pyproject.toml`.

---

## 3. pnpm as Default Package Manager, bun as Second Choice

**Context:** npm, pnpm, bun, yarn — all solve the same problem, all have strengths.

**Decision:** pnpm is the standard package manager for all new projects. bun as fallback for performance-critical builds.

**Why pnpm over npm:**
- Symlink-based store: `node_modules` is smaller, installations are faster
- Stricter dependency isolation: prevents phantom dependencies
- Workspace support is better than npm
- `pnpm-lock.yaml` is more deterministic

**Why not bun as the default:**
- bun is not yet fully compatible with all npm packages
- As a runtime for existing Node.js projects it sometimes requires adjustments
- For fast tooling scripts (`bun run`, `bun install`) it is excellent

**Why not yarn:**
- pnpm has surpassed Yarn in performance and disk efficiency
- Yarn v1 (classic, in use) is no longer in active development

**Cost:** Existing projects with `package-lock.json` need to migrate to `pnpm-lock.yaml` (or run with `pnpm import`).

---

## 4. Docker Desktop Instead of colima or OrbStack

**Context:** On Apple Silicon, Docker does not run natively — it requires a Linux VM layer. Options: Docker Desktop (official), colima (lightweight, open source), OrbStack (commercial, performance-focused).

**Decision:** Docker Desktop.

**Why not colima:**
- colima has no GUI — not an issue for phpMyAdmin debugging from a browser, but it is for Docker Desktop dashboard workflows
- Volume mounting under colima occasionally has performance issues
- docker compose v2 requires manual configuration under colima

**Why not OrbStack:**
- Commercial (free for individual developers, but license changes are possible)
- Small team behind the product vs. Docker, Inc.

**Cost:** Docker Desktop is more resource-intensive than colima. Not a noticeable issue on 32 GB RAM.

---

## 5. Ollama Native (brew formula) Instead of in a Container

**Context:** Ollama can be installed natively (brew) or run as a Docker container.

**Decision:** Ollama natively via brew formula. No cask (GUI app), no container.

**Why not a container:**
- Docker on macOS has no direct access to Metal (Apple's GPU API)
- An Ollama container runs CPU-only on macOS — inference is 5–10× slower
- Metal-accelerated inference is one of the biggest advantages of Apple Silicon; giving it up via a container makes no sense

**Why not the cask (ollama-app):**
- The cask is a native macOS app with a menu bar icon and auto-start logic
- The formula gives more control over start/stop
- Having the cask and formula installed simultaneously causes port conflicts

**Cost:** Ollama does not start automatically at login. It must be started explicitly (`ollama serve`) when needed — this is a deliberate choice (no persistent background service).

---

## 6. zsh + oh-my-zsh + powerlevel10k Despite the Startup Time Cost

**Context:** oh-my-zsh and powerlevel10k have a measurable effect on shell startup time. Without lazy loading: 300–600 ms per new terminal window.

**Decision:** zsh + oh-my-zsh + powerlevel10k, with lazy loading for nvm and conda.

**Why not fish:**
- A `~/.config/fish` configuration exists on the machine — fish was evaluated
- fish scripts are not POSIX-compatible; many copy-paste scripts from documentation do not work directly
- oh-my-fish is smaller than oh-my-zsh; the plugin ecosystem is too

**Why not bare zsh without oh-my-zsh:**
- Plugins (zsh-autosuggestions, zsh-syntax-highlighting) are a genuine productivity gain
- powerlevel10k with git status, Python env, and Node version in the prompt saves manual `git status` calls

**How lazy loading reduces the startup cost:**
- nvm: lazy (loads only on the first `node`/`npm`/`nvm` call) → saves ~300 ms
- conda: lazy (activates only on `conda activate`) → saves ~100–200 ms
- Result: shell startup < 200 ms instead of > 600 ms

**Cost:** Lazy loading means the first `node` command in a session is slightly slower (~300 ms, one-time). Acceptable.

---

## 7. VS Code + Xcode + IntelliJ Side by Side Instead of One Editor

**Context:** Three editors installed and in use simultaneously. This sounds like overhead.

**Decision:** All three, for clearly separated use cases.

| Editor | Use case |
|---|---|
| VS Code | TypeScript/React, Python/FastAPI, PHP, everything that does not need native IDE support |
| Xcode | iOS/macOS Swift projects — no other editor can compete here |
| IntelliJ IDEA | Java/Spring Boot, Gradle/Maven — Red Hat Java in VS Code is good, but IntelliJ is better |

**Why not VS Code for everything:**
- Xcode simulators, iOS deployment, SwiftUI previews: technically only possible in Xcode
- IntelliJ Java refactoring (Extract Method, Change Signature across module boundaries) is superior to VS Code

**Cost:** IntelliJ license. Disk space (~3–4 GB). Mental context switching between editors — not an issue because the use cases are cleanly separated.

---

## 8. Custom Paved Road (`dev/base`) Instead of Copier/Cookiecutter/Nx

**Context:** There are many template/scaffolding tools: Cookiecutter (Python), Copier (Python, with update support), Yeoman (JS), Nx (monorepo).

**Decision:** Custom `dev/base` system with `base new` / `base sync`.

**Why not Copier or Cookiecutter:**
- These tools scaffold once — `base sync` can *incrementally update* existing repos (purely additive, never overwriting)
- `base harvest` pulls project-specific findings back into the global knowledge base — no standard tool does this
- The AI context (CLAUDE.md, AGENTS.md, HANDOFF.md, BIBLE.md) is specific enough that standard templates do not fit

**Why not Nx:**
- Nx is a monorepo tool — here there are 58 separate repos, not a monorepo
- Nx overhead (custom task runners, plugin ecosystem) is not justified for individual repos

**Cost:** `dev/base` is custom — new team members need to learn it. Updates to standards must be rolled out manually via `base sync` to all repos (the step is semi-automated, but not fully automatic).

---

## 9. Homebrew PATH Before `/usr/bin`

**Context:** macOS ships its own versions of git, python3, curl, etc. under `/usr/bin`. Homebrew installs newer versions under `/opt/homebrew/bin`.

**Decision:** `/opt/homebrew/bin` precedes `/usr/bin` in PATH order.

**Why:**
- Apple system tools are optimized for macOS compatibility, not for the latest features
- `git` in `/usr/bin`: Apple-patched, not always current
- brew-git, brew-python, brew-curl have more recent versions and more features
- Homebrew is the only package management system in use — all installed tools should actually be used

**Risk:** Occasionally a brew update breaks something that depended on Apple system tools. In practice: has not happened in years of use.

**Cost:** When brew has a problem, one can explicitly fall back to `/usr/bin/git`. This is documented.

---

## 10. ed25519 Instead of RSA for SSH Keys

**Context:** The old SSH key is RSA, generated in 2024.

**Decision:** New ed25519 key for all new SSH connections. Do not reuse the RSA key.

**Why ed25519:**
- Shorter key length (~68 characters public key vs. ~400 for RSA-2048) — easier to read, faster to transmit
- Faster signing (relevant for many SSH connections)
- More resistant to timing-based attacks (through constant-time operations)
- Modern standard — all current SSH implementations support it

**Why not copy the RSA key:**
- A rebuild is the right moment for a new key — fresh, with no history
- The old key can be revoked after migration (remove from GitHub)
- If the old key were compromised (unlikely, but possible), copying would carry the problem forward

**Cost:** New key must be registered with all services (GitHub ×2, all servers with SSH access). Effort: 30–60 minutes, one-time.

---

## 11. SSH Commit Signing Instead of GPG

**Context:** Commit signing cryptographically proves that a commit originated from a specific key. Two methods: GPG and SSH (since git 2.34).

**Decision:** SSH commit signing (`gpg.format = ssh`).

**Why not GPG:**
- GPG key management is complex: web of trust, expiry dates, subkeys, key servers
- The GPG agent is a frequent source of problems (pinentry, agent cache)
- An SSH key is already present — using the same key for signing is more elegant
- GitHub verifies SSH signatures the same as GPG signatures (green "Verified" badge)

**Why not skip signing entirely:**
- For public repos (this repo is public): signing gives external readers confidence
- In team code reviews: verified commits give assurance that the stated author actually made the commit

**Cost:** Minimal: one additional git config block. One-time effort.
