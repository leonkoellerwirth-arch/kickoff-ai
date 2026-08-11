# Baseline — The Reproduced Stack

This document describes the environment that `kickoff-ai` reproduces: not a wish list, but a measured current state. All figures are taken from direct commands.

For readers who want to build a similar environment: the baseline shows what this configuration is designed for — and what it is not.

---

## Hardware & OS

| Property | Value |
|---|---|
| Processor | Apple M2 Max (arm64) |
| RAM | 32 GB |
| Storage | 926 GB SSD |
| OS | macOS 26.5.2 |
| Shell | zsh (oh-my-zsh, powerlevel10k) |

M2 Max is relevant for: Metal-accelerated Ollama inference without a GPU bottleneck, running parallel Docker containers without noticeable overhead, and Swift/Xcode builds without simulator wait times.

---

## Repository Landscape

58 directories under `~/dev/`, of which:

| Metric | Count |
|---|---|
| Repos with `package.json` | 36 |
| Repos with `docker-compose.yml` | 15 |
| Repos with `Dockerfile` | 15 |
| Repos with `pyproject.toml` | 10 |
| Repos with `requirements.txt` | 5 |
| Repos with `Makefile` | 4 |
| Repos with `xcodeproj` | 2 |
| Repos with `.nvmrc` | 2 |

**What this indicates:** This is a polyglot environment — TypeScript on the frontend, Python on the backend, Swift for iOS, Java/Gradle for legacy projects. No monorepo — each project has its own directory. The pattern of one docker-compose per project is visible in 15 of the 36 JS projects.

### Agent Context Files per Repo

| File | Number of repos |
|---|---|
| `CLAUDE.md` | 32 |
| `AGENTS.md` | 26 |
| `HANDOFF.md` | 19 |
| `BIBLE.md` | 18 |

**What this indicates:** 32 of 58 repos have a `CLAUDE.md` — this is the norm, not the exception. AI agents in this workflow are not one tool among many, but a primary collaboration partner. `HANDOFF.md` in 19 repos points to a working style in which sessions are explicitly handed off to maintain context continuity between agent sessions.

---

## Frontend Stack — Histogram

Across all `package.json` files:

| Dependency | # Repos |
|---|---|
| `typescript` | 26 |
| `tailwindcss` | 22 |
| `react` | 22 |
| `vite` | 21 |
| `eslint` | 15 |
| `vitest` | 13 |
| `next` | 3 |
| `express` | 2 |
| `playwright` | 1 |
| `jest` | 1 |

**What this indicates:** The dominant frontend stack is Vite + React + TypeScript + Tailwind + vitest. Next.js is the exception, not the rule — used for server-side rendering when required. Prettier appears in only 3 repos (it may be configured globally or via the IDE in others). The vitest presence (13×) shows that unit testing is taken seriously.

---

## Backend Stack — Histogram

Across `pyproject.toml`, `requirements.txt`, `setup.py`:

| Dependency | # Repos |
|---|---|
| `pytest` | 13 |
| `pydantic` | 11 |
| `uvicorn` | 5 |
| `fastapi` | 5 |
| `ruff` | 4 |
| `langchain` | 4 |
| `httpx` | 4 |
| `playwright` | 4 |
| `anthropic` | 3 |
| `openai` | 2 |
| `langgraph` | 2 |
| `sqlalchemy` | 1 |

**What this indicates:** FastAPI + Pydantic is the backend standard. pytest + ruff reflects strong quality discipline on the Python side. LangChain/LangGraph in 4+2 repos confirms that this is not occasional AI experimentation but a productive stack. `httpx` in 4 repos shows a preference for async-capable HTTP clients over `requests`.

---

## Infrastructure Stack

### Containers (current pattern)

```
each web project:
  api:        php:8.2-cli or php:8.3-cli or custom
  db:         mysql:8.0
  phpmyadmin: phpmyadmin (web admin UI)

AI project:
  db:     postgres:17-alpine
  vector: qdrant/qdrant:v1.13.0   — vector database
  queue:  valkey/valkey:8-alpine  — Redis-compatible cache/queue
```

**What this indicates:** MySQL 8.0 + phpMyAdmin is the standard for PHP projects. AI projects use Postgres + Qdrant + Valkey — a modern stack designed for vector semantics.

### Local Services (brew services)

| Service | Status |
|---|---|
| mysql@8.0 | started |
| postgresql@14, ollama, php, unbound | installed, not started |

### Parallel Database Versions

- MySQL 8.0 (brew + Docker)
- PostgreSQL 14 (brew) + 17-alpine (Docker)

---

## AI Stack — Overview

### Local Models (Ollama)

| Model | Size | Use case |
|---|---|---|
| llama3.2 | 2.0 GB | Fast general-purpose tasks |
| deepseek-r1:14b | 9.0 GB | Reasoning-intensive tasks |
| glm-ocr | 2.2 GB | OCR workflows |
| aya-expanse:8b | 5.1 GB | Multilingual tasks |

Additionally installed (not via Ollama): GPT4All.app, openai-whisper (audio transcription), mlx + pytorch via brew (for local model experiments).

### Agent CLIs

| Tool | Model | Mode | Use case |
|---|---|---|---|
| Claude Code | claude-opus-5[1m] (primary), claude-sonnet-4-6 (subagents) | fullscreen TUI | Primary development tool |
| Codex CLI | gpt-5.6-terra | full-auto (see gap A.15) | Second opinion, OpenAI-specific tasks |
| Gemini CLI | gemini-* | default | Third perspective, Google context |
| Ollama (local) | llama3.2, deepseek-r1:14b, glm-ocr, aya-expanse:8b | API/CLI | Privacy-sensitive tasks, offline |

### Claude Code Plugins (active)

- `claude-mem` — cross-project memory (corpus, search, sessions)
- `frontend-design` — design system guidelines for artifacts
- `apple-skills` — iOS/macOS/Swift/App Store workflows

### MCP Servers (Model Context Protocol)

- `basic-memory` — local file memory (via uvx)
- `openaiDeveloperDocs` — OpenAI documentation in Codex

---

## Toolchain Overview

| Area | Tool | Version | Notes |
|---|---|---|---|
| Package management | Homebrew | 6.0.13 | ~275 formulae installed |
| Node | nvm → Node | v24.13.0 | default alias = 24 |
| Node packages | pnpm | 10.29.1 | default; bun as fallback |
| Python | uv | 0.10.1 | primary path (new) |
| Python (legacy) | Miniforge3/conda | 22.11.1 | opt-in; conda-base not auto-activated |
| Java | openjdk@17 | via brew | Spring Boot, Gradle, Maven |
| Go | go | via brew | various tools |
| Rust | rustc/cargo | via brew | |
| PHP | php | via brew | PHP web projects |
| Containers | Docker Desktop | 28.0.4 | |
| Editor | VS Code | — | 69 extensions (at time of measurement) |
| Editor | IntelliJ IDEA | via JetBrains Toolbox | Java/Spring projects |
| Editor | Xcode | 26.6 | iOS/macOS projects |
| Terminal | iTerm2 | — | primary terminal with Claude status hook |
| Terminal | Ghostty | — | fallback |
| VCS | git | brew | brew-git precedes system-git in PATH |
| VCS hosting | GitHub | — | two accounts |
| Secret scanning | gitleaks | via brew | integrated in pre-commit |
| Pre-commit | pre-commit | via brew | hooks in dev/base |
| Secrets backend | Vaultwarden + bitwarden-cli | — | self-hosted; replaces 1Password CLI; Enpass.app also present |
| SSH | ed25519 key | new from setup | replaces old RSA key |

---

## The Custom Paved Road (`dev/base`)

The most important repo in the entire installation. `dev/base` is not a framework — it is a set of conventions that propagates to all other repos via `base sync`.

**Core idea:** Define standards > bring repos up to standard > never write boilerplate by hand.

```
base new vite-react-pwa my-new-project   # zero to standard in ~10 seconds
base sync ~/dev/legacy-project           # adds missing files (purely additive)
base doctor ~/dev/legacy-project         # shows what is still missing
```

**What `dev/base` defines:**
- `CONSTITUTION.md` — what never changes (decisions, invariants)
- Templates for all project types (Vite/React, Python service, book project, event study, YouTube crawler)
- Security rules (.gitleaks.toml, .gitignore patterns)
- CI gate script (gate.sh for Python, npm run verify:ci for web)
- Claude/Codex standards (subagent routing, BIBLE.md convention)
- Backbone scripts (budget tracking, session snapshots, security gate, context harvesting)

**Why this matters:** 32 of 58 repos have `CLAUDE.md`, 26 have `AGENTS.md`, 19 have `HANDOFF.md` — that consistency comes from `dev/base`. Without it, every repo would need to be maintained individually.
