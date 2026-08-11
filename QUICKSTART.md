# Quickstart — Up and running, level by level

## Brand-new machine (no Homebrew, no git, no repo)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/kickoff-ai/main/prepare.sh)"
```

`prepare.sh` checks readiness, installs Xcode CLT, clones the repo, and hands off to `bootstrap.sh --level 0`. To check readiness only without changing anything:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/kickoff-ai/main/prepare.sh)" -- --check-only
```

---

## If the repo is already cloned

```bash
xcode-select --install                            # confirm dialog, wait ~5 min
git clone https://github.com/leonkoellerwirth-arch/kickoff-ai ~/dev/kickoff-ai
cd ~/dev/kickoff-ai && ./bootstrap.sh --level 0
./doctor.sh
```

Each level builds on the previous one. You can upgrade at any time — `./bootstrap.sh --level 1` continues from where `--level 0` left off. Nothing runs twice.

Full phase-by-phase walkthrough: [docs/00-ZERO-TO-HERO.md](docs/00-ZERO-TO-HERO.md)

---

## Level 0 — Emergency (~15 min)

**Command:**
```bash
./bootstrap.sh --level 0
```

**After this:** Clone repos, commit to git, use Claude Code, start pnpm projects.

**Not yet available:** Docker, Python/uv, VS Code extensions, AI stack (Codex, Gemini, Ollama), Xcode, macOS defaults, dev/base.

**Verify:**
```bash
./doctor.sh --level 0
# Or manually:
which git && git --version        # /opt/homebrew/bin/git
which node && node --version      # v24.x
which claude && claude --version  # Claude Code
gh auth status                    # logged in
```

---

## Level 1 — Base (~45 min)

**Command:**
```bash
./bootstrap.sh --level 1
```

**After this:** Daily development work is possible — Python services with uv, frontend with pnpm, VS Code with extensions, your own paved road (`base new`, `base sync`).

**Not yet available:** Docker stack, AI CLIs (Codex, Gemini CLI), Ollama + models, Xcode + simulators, automation layer.

**Verify:**
```bash
./doctor.sh --level 1
# Spot checks:
uv --version                      # Python toolchain
code --list-extensions | wc -l   # ~70 extensions
base list                         # paved road reachable
pre-commit --version              # hooks installed
```

---

## Level 2 — Full (~2 h)

**Command:**
```bash
./bootstrap.sh --level 2
```

**After this:** Full stack — Docker per project, Claude Code + Codex + Gemini CLI + Ollama locally, iOS projects in Xcode, simulators running.

**Vaultwarden** belongs in this level (requires Docker). Template at `templates/vaultwarden/`:
```bash
cp -r ~/dev/kickoff-ai/templates/vaultwarden/ ~/dev/vaultwarden/
cd ~/dev/vaultwarden && cp .env.example .env
# Edit .env (ADMIN_TOKEN), then:
docker compose up -d
brew install bitwarden-cli
bw config server http://localhost:8080 && bw login
# Full guide: docs/08-SECRETS.md
```

**Not yet available:** Optional tools (Brewfile.optional: nmap, sqlmap, ocrmypdf, …), launchd jobs, legacy cleanup for existing machines.

**Verify:**
```bash
./doctor.sh --level 2
# Spot checks:
docker info | grep "Server Version"
ollama list                        # models present
codex --version && gemini --version
xcrun simctl list runtimes         # iOS/watchOS/visionOS
bw status                          # Vaultwarden connected
```

---

## Level 3 — Maximal (~3 h+)

**Command:**
```bash
./bootstrap.sh --level 3
```

**After this:** Full comfort stack — optional CLI tools, automation layer (`automation/`) with launchd jobs, legacy cleanup for the existing machine (`scripts/90-cleanup-legacy.sh`), everything in `Brewfile.optional`.

**Still manual:** App Store apps, secrets, logins, hardware-specific software. See [docs/01-MANUAL.md](docs/01-MANUAL.md).

**Verify:**
```bash
./doctor.sh
# All 41 checks: PASS or WARN, no FAIL
```

---

## Troubleshooting

**CLT dialog does not appear / `xcode-select --install` fails:**
```bash
sudo rm -rf /Library/Developer/CommandLineTools
xcode-select --install
```

**`brew: command not found` after installation:**
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"   # for this session
exec zsh                                     # restart shell
```

**`/usr/bin/git` instead of brew-git after Phase 4:**
```bash
exec zsh   # new shell loads the new .zshrc with correct PATH
which git  # should show /opt/homebrew/bin/git
```

**A module failed and you want to re-run it individually:**
```bash
./scripts/05-python.sh    # Python only
./scripts/07-ai-stack.sh  # AI stack only
./scripts/04-node.sh      # Node only
# any module: ./scripts/<NN>-<name>.sh
```

**doctor.sh shows FAIL and you don't know why:**
```bash
./doctor.sh 2>&1 | grep FAIL   # show only failures
# Each FAIL line names the affected module → re-run that module individually
```

For everything else: [docs/00-ZERO-TO-HERO.md](docs/00-ZERO-TO-HERO.md) → the relevant phase, section "Typische Fehler" (common errors).
