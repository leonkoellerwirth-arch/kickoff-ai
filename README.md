# kickoff-ai

> Every setup repo is correct on the day it's written. This one knows when it stops being true.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-lightgrey)](#what-this-is-not)
[![shellcheck](https://img.shields.io/badge/shellcheck-clean-brightgreen)](https://github.com/koalaman/shellcheck)
[![CI](https://github.com/leonkoellerwirth-arch/kickoff-ai/actions/workflows/validate.yml/badge.svg)](https://github.com/leonkoellerwirth-arch/kickoff-ai/actions/workflows/validate.yml)

---

## The Problem

Tools move. Homebrew formulas get deprecated. npm packages go unmaintained. The AI CLI you pinned six months ago is three major versions behind. And the setup repo that was exact on day one drifts silently until the next machine migration reveals the gap.

Most setup repos have no answer for this. They are documentation, not systems.

---

## What Makes This Different

| Pillar | What it does | Numbers |
|--------|-------------|---------|
| **Staged installation** | One command, four cumulative levels: emergency shell in 15 min, full AI stack in 2 h | 12 modules, `--dry-run` on everything |
| **Verification** | `doctor.sh` checks every layer of the stack after setup | 42 checks, PASS / WARN / FAIL |
| **Currency system** | A registry of 102 tools is the single source of truth; CI opens a PR for version drift and an issue for rot every Monday | `candidate → active → deprecated → sunset`, 90-day sunset window |
| **Migration** | `status-quo.sh` exports the old machine; `migration-diff` shows what the new one is still missing | Machine-readable `profile.json`, concrete commands for every gap |

The hard rule behind the currency system: **nothing installs or retires itself**. The machine reports; the human decides.

---

## Quickstart

On a brand-new machine — no Homebrew, no git, no repo:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/kickoff-ai/main/prepare.sh)"
```

`prepare.sh` checks readiness, installs Xcode CLT, clones the repo, and hands off to `bootstrap.sh --level 0`. You can stop there or continue:

| Level | Time | After this level |
|-------|------|-----------------|
| 0 — Emergency | ~15 min | Clone repos, commit to git, run Claude Code, start pnpm projects |
| 1 — Base | ~45 min | + Python via uv, VS Code with extensions, paved road (`base new`) |
| 2 — Full | ~2 h | + Docker, full Xcode, Codex CLI, Gemini CLI, Ollama + local models |
| 3 — Maximal | ~3 h+ | + optional Brewfile, automation layer with launchd jobs |

Each level includes everything from the previous one. Running the same level twice is safe.

To check readiness before starting anything:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/kickoff-ai/main/prepare.sh)" -- --check-only
```

---

## What the Output Looks Like

```
$ ./bootstrap.sh --list-levels

┌─────────────────────────────────────────────────────────────────────┐
│  kickoff-ai — Setup levels (./bootstrap.sh --level <N>)             │
└─────────────────────────────────────────────────────────────────────┘

Level Name          Duration   Modules
─────────────────────────────────────────────────────────────────────
0     Emergency     ~15 min    preflight, apple-toolchain (CLT), homebrew (core),
                               shell, node, git-ssh, ai-stack (Claude Code only)

1     Base          ~45 min    + full Brewfile, python (uv),
                               macos-defaults, editors (VS Code), paved-road

2     Full          ~2 h       + containers (Docker), apple-toolchain (Xcode),
                               ai-stack (Codex, Gemini, Ollama + models)
                               [= default run without --level]

3     Maximum       ~3 h+      + Brewfile.optional (ML, security, media),
                               automation/ (launchd jobs, if present)

Note: Each level includes all modules from previous levels (cumulative).
      Re-running a level that was already completed is safe.
```

After a full setup, `doctor.sh` runs 42 checks and prints a structured result. This is real output from the AI-tools section:

```
==> AI Tools
[PASS]  Claude Code                              2.1.227 (Claude Code)
[PASS]  @openai/codex                            0.147.0
[PASS]  Gemini CLI                               0.46.0
[PASS]  Ollama                                   0.32.4
[PASS]  Ollama models                            glm-ocr:latest,llama3.2:latest,deepseek-r1:14b,aya-expanse:8b

...

  PASS: 29
  WARN: 10
  FAIL: 2
     Checked: 42 / 42
```

WARN and FAIL entries each include a concrete fix command. FAILs block the setup as complete.

---

## What's Inside

```
prepare.sh              Entry point for bare machines — no git or Homebrew needed
bootstrap.sh            Orchestrator — runs modules in order, levels 0–3
doctor.sh               Read-only check — 42 points, PASS/WARN/FAIL, exit 1 on FAIL
status-quo.sh           Export the current machine state before migration

scripts/
  lib.sh                Logging, helpers, shared variables
  00-preflight.sh       Arch, macOS version, disk space, sudo, Rosetta
  01-apple-toolchain.sh CLT, Xcode, license, simulators
  02-homebrew.sh        Homebrew + taps + brew bundle
  03-shell.sh           oh-my-zsh, powerlevel10k, zsh plugins, dotfiles
  04-node.sh            nvm + Node 24, pnpm/bun/deno, global npm packages
  05-python.sh          uv as primary, Miniforge optional, pipx tools
  06-containers.sh      Docker Desktop + Compose
  07-ai-stack.sh        Claude Code, Codex, Gemini CLI, Ollama + models, MCP
  08-git-ssh.sh         git config, ed25519 key, gh auth, signing, pre-commit
  09-macos-defaults.sh  macOS developer settings
  10-editors.sh         VS Code + extensions
  11-paved-road.sh      ~/dev structure + clone dev/base
  90-cleanup-legacy.sh  Opt-in: remove legacy installations (not in bootstrap.sh)

manifests/
  tools.yaml            Registry — 102 tools, the single source of truth
  schema.md             Field definitions and allowed values

automation/bin/         14 commands — all support --dry-run and --help
  up2date               Check tools against upstream; report drift
  sunset                State machine: propose / confirm / revive / adopt
  migration-diff        Compare old-machine profile.json with current state
  dev-up / dev-down / dev-ps   Docker stack lifecycle per project
  mac-clean             Disk hygiene — dry-run by default, --apply to act
  mac-update            Update all tool groups in a fixed sequence
  mac-snapshot          Diff current machine state against repo declarations
  repo-sweep            Audit ~/dev repos for drift, age, missing files
  secret-sweep          gitleaks over all repos; find plain-text .env files
  db-backup             mysqldump / pg_dump from running containers, with rotation
  ollama-sync           Compare installed models to manifest; pull missing ones
  env-run               Inject Vaultwarden secrets into process environment

automation/launchd/     launchd job templates + install/uninstall scripts
automation/manifests/   ollama-models.txt and other managed lists

Brewfile                Pinned core packages
Brewfile.optional       Optional tools (nmap, sqlmap, ocrmypdf, …)
Brewfile.level0         Minimal set for Level 0 only

templates/vaultwarden/  docker-compose.yml + .env.example for self-hosted secrets
config/                 zshrc, zprofile, gitconfig, gitignore_global, vscode-extensions.txt
local/                  Gitignored — machine-specific data, snapshots, private overrides

docs/
  00-ZERO-TO-HERO.md    Full setup guide phase by phase
  01-MANUAL.md          Checklist: what stays manual and why
  02-GAP-ANALYSIS.md    Honest audit: defects and what's missing
  03-BASELINE.md        The reproduced stack as a measurable profile
  04-DECISIONS.md       ADR-style rationale for tool choices
  05-SANITIZATION.md    Rules for public publication
  06-AUTOMATION.md      launchd jobs, automation layer
  07-CURRENCY.md        The currency system in full detail
  08-SECRETS.md         Secrets management: Vaultwarden + env-run
  09-MIGRATION.md       Machine migration: export → prepare → diff
```

The migration toolchain (`status-quo.sh` → `prepare.sh --profile` → `automation/bin/migration-diff`) is the part most setup repos skip. [docs/09-MIGRATION.md](docs/09-MIGRATION.md) covers it in detail.

---

## The AI Stack

The repo is built around an AI-heavy workflow. The stack is declared, not assumed:

| Tool | Role |
|------|------|
| Claude Code | Primary coding agent (`claude-opus-5[1m]`), subagents on Sonnet for cost |
| Codex CLI | OpenAI agent, `suggest` mode, MCP-connected |
| Gemini CLI | Second opinion, shares the claude-mem memory system |
| Ollama + local models | llama3.2, deepseek-r1:14b, glm-ocr, aya-expanse — native Metal, no Docker |
| MCP | basic-memory, openaiDeveloperDocs, and project-specific servers |

Ollama runs as a brew formula, not a container — Metal acceleration on Apple Silicon requires the native binary. Details in [docs/04-DECISIONS.md](docs/04-DECISIONS.md).

---

## What This Is Not

- **Not Nix.** There is no byte-level reproducibility guarantee. Two setups from the same repo at different points in time will differ by tool version drift, macOS delta updates, and Homebrew formula changes. The currency system makes that drift visible; it does not eliminate it.
- **Not a fleet management tool.** No MDM integration, no multi-machine rollout, no central control plane. This is a single-developer setup for a single machine.
- **Not cross-platform.** macOS on Apple Silicon only. The Intel path has not been maintained.
- **Not tested on multiple machines.** It is distilled from one real setup — 58 repositories, a verified inventory of the actual machine state, and a gap analysis that was deliberately unsympathetic. [docs/02-GAP-ANALYSIS.md](docs/02-GAP-ANALYSIS.md) shows what that means in practice.
- **Not zero-config for your setup.** You will adapt `manifests/tools.yaml`, `Brewfile`, and `config/` to your stack. The structure is the value, not the exact tool list.

---

## Who It's For

A senior developer running a mixed stack — web frontends, Python services, iOS apps, AI agents — who wants a setup that can be reproduced exactly one year from now, not just today.

The background is enterprise architecture in regulated environments (AI governance, BaFin/DORA context). That means: audit trails over convenience, explicit decisions over automation, and a strong preference for tools that do exactly what they say and nothing more.

If that's your context, the design decisions in [docs/04-DECISIONS.md](docs/04-DECISIONS.md) will make sense immediately. If you want a one-click setup that makes choices for you, this is the wrong repo.

---

## Contributing

Contributions to this repo are usually registry changes, not code. See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and the rules that apply to scripts.

## Security

`curl | bash` is trust by definition. See [SECURITY.md](SECURITY.md) for the threat model, what's built in, and how to verify before running.

## License

MIT — see [LICENSE](LICENSE).

---

A German-language version of the documentation is archived under [`docs/de/`](docs/de/) — English is authoritative; the German files are a frozen snapshot and are not kept in sync.
