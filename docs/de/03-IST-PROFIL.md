# Ist-Profil — Der reproduzierte Stack

> ⚠️ Archivierte deutsche Fassung — maßgeblich ist die englische Version unter [`../03-BASELINE.md`](../03-BASELINE.md). Diese Datei wird nicht mehr aktualisiert.

Dieses Dokument beschreibt die Umgebung, die `kickoff-ai` reproduziert: nicht als Wunschliste, sondern als gemessener Ist-Zustand. Alle Zahlen sind aus direkten Kommandos erhoben.

Für Leser die eine ähnliche Umgebung aufbauen wollen: das Profil zeigt, was auf dieser Konfiguration ausgelegt ist — und was nicht.

---

## Hardware & OS

| Merkmal | Wert |
|---|---|
| Prozessor | Apple M2 Max (arm64) |
| Arbeitsspeicher | 32 GB |
| Speicher | 926 GB SSD |
| OS | macOS 26.5.2 |
| Shell | zsh (oh-my-zsh, powerlevel10k) |

M2 Max ist relevant für: Metal-beschleunigtes Ollama (Inferenz ohne GPU-Bottleneck), parallele Docker-Container ohne merkbaren Overhead, Swift/Xcode-Builds ohne Simulator-Wartezeiten.

---

## Repository-Landschaft

58 Verzeichnisse unter `~/dev/`, davon:

| Metrik | Zahl |
|---|---|
| Repos mit `package.json` | 36 |
| Repos mit `docker-compose.yml` | 15 |
| Repos mit `Dockerfile` | 15 |
| Repos mit `pyproject.toml` | 10 |
| Repos mit `requirements.txt` | 5 |
| Repos mit `Makefile` | 4 |
| Repos mit `xcodeproj` | 2 |
| Repos mit `.nvmrc` | 2 |

**Was man daraus ablesen kann:** Dies ist eine polyglotte Umgebung — TypeScript im Frontend, Python im Backend, Swift für iOS, Java/Gradle für Altprojekte. Kein Monorepo — jedes Projekt hat sein eigenes Verzeichnis. Das Muster "pro Projekt ein docker-compose" ist bei 15 von 36 JS-Projekten sichtbar.

### Agent-Kontext-Dateien pro Repo

| Datei | Anzahl Repos |
|---|---|
| `CLAUDE.md` | 32 |
| `AGENTS.md` | 26 |
| `HANDOFF.md` | 19 |
| `BIBLE.md` | 18 |

**Was man daraus ablesen kann:** In 32 von 58 Repos gibt es eine `CLAUDE.md` — das ist keine Ausnahme, sondern die Norm. KI-Agenten sind in diesem Workflow nicht ein Tool neben anderen, sondern ein primärer Kollaborationspartner. `HANDOFF.md` in 19 Repos deutet auf eine Arbeitsweise hin, bei der Sessions explizit übergeben werden (Kontext-Kontinuität zwischen Agent-Sessions).

---

## Frontend-Stack — Histogramm

Aus allen `package.json`-Dateien:

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

**Was man daraus ablesen kann:** Der dominante Frontend-Stack ist Vite + React + TypeScript + Tailwind + vitest. Next.js ist die Ausnahme, nicht die Regel — wahrscheinlich für Server-Side-Rendering wenn nötig. Prettier erscheint nur in 3 Repos (könnte in anderen global oder über IDE konfiguriert sein). Die vitest-Präsenz (13×) zeigt dass Unit-Testing ernsthaft betrieben wird.

---

## Backend-Stack — Histogramm

Aus `pyproject.toml`, `requirements.txt`, `setup.py`:

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

**Was man daraus ablesen kann:** FastAPI + Pydantic ist der Backend-Standard. pytest + ruff zeigt eine starke Qualitätsdisziplin im Python-Bereich. LangChain/LangGraph in 4+2 Repos bestätigt, dass dies kein gelegentliches KI-Experiment ist, sondern produktiver Stack. `httpx` in 4 Repos zeigt eine Präferenz für async-fähige HTTP-Clients gegenüber `requests`.

---

## Infrastruktur-Stack

### Container (Ist-Muster)

```
jedes Webprojekt:
  api:        php:8.2-cli oder php:8.3-cli oder custom
  db:         mysql:8.0
  phpmyadmin: phpmyadmin (Web-Verwaltungsoberfläche)

KI-Projekt:
  db:     postgres:17-alpine
  vector: qdrant/qdrant:v1.13.0   — Vektordatenbank
  queue:  valkey/valkey:8-alpine  — Redis-kompatibler Cache/Queue
```

**Was man daraus ablesen kann:** MySQL 8.0 + phpMyAdmin ist der Standard für PHP-Projekte. KI-Projekte nutzen Postgres + Qdrant + Valkey — ein moderner, auf Vektorsemantik ausgelegter Stack.

### Lokale Dienste (brew services)

| Dienst | Status |
|---|---|
| mysql@8.0 | gestartet |
| postgresql@14, ollama, php, unbound | installiert, nicht gestartet |

### Datenbankversionen parallel

- MySQL 8.0 (brew + Docker)
- PostgreSQL 14 (brew) + 17-alpine (Docker)

---

## KI-Stack — Übersicht

### Lokale Modelle (Ollama)

| Modell | Größe | Anwendungsfall |
|---|---|---|
| llama3.2 | 2.0 GB | Schnelle allgemeine Aufgaben |
| deepseek-r1:14b | 9.0 GB | Reasoning-intensive Aufgaben |
| glm-ocr | 2.2 GB | OCR-Workflows |
| aya-expanse:8b | 5.1 GB | Mehrsprachige Aufgaben |

Zusätzlich installiert (kein Ollama): GPT4All.app, openai-whisper (Audio-Transkription), mlx + pytorch via brew (für eigene Modellexperimente).

### Agenten-CLIs

| Tool | Modell | Modus | Anwendungsfall |
|---|---|---|---|
| Claude Code | claude-opus-5[1m] (Hauptmodell), claude-sonnet-4-6 (Subagenten) | fullscreen TUI | Primäres Entwicklungswerkzeug |
| Codex CLI | gpt-5.6-terra | full-auto (Achtung: Gap A.15) | Zweite Meinung, OpenAI-spezifische Tasks |
| Gemini CLI | gemini-* | Standard | Dritte Perspektive, Google-Kontext |
| Ollama (local) | llama3.2, deepseek-r1:14b, glm-ocr, aya-expanse:8b | API/CLI | Datenschutz-sensitive Tasks, Offline |

### Claude Code Plugins (aktiv)

- `claude-mem` — projektübergreifendes Gedächtnis (Corpus, Suche, Sessions)
- `frontend-design` — Designsystem-Richtlinien für Artifacts
- `apple-skills` — iOS/macOS/Swift/App-Store-Workflows

### MCP-Server (Model Context Protocol)

- `basic-memory` — lokales Dateigedächtnis (via uvx)
- `openaiDeveloperDocs` — OpenAI-Dokumentation in Codex

---

## Toolchain-Übersicht

| Bereich | Tool | Version | Anmerkung |
|---|---|---|---|
| Paketverwaltung | Homebrew | 6.0.13 | ~275 Formulae installiert |
| Node | nvm → Node | v24.13.0 | default alias = 24 |
| Node-Pakete | pnpm | 10.29.1 | Standard; bun als Fallback |
| Python | uv | 0.10.1 | Primärweg (neu) |
| Python (legacy) | Miniforge3/conda | 22.11.1 | Opt-in, conda-base wird nicht aktiviert |
| Java | openjdk@17 | via brew | Spring Boot, Gradle, Maven |
| Go | go | via brew | diverse Tools |
| Rust | rustc/cargo | via brew | |
| PHP | php | via brew | PHP-Webprojekte |
| Containers | Docker Desktop | 28.0.4 | |
| Editor | VS Code | — | 69 Extensions (Stand Aufnahme) |
| Editor | IntelliJ IDEA | via JetBrains Toolbox | Java/Spring-Projekte |
| Editor | Xcode | 26.6 | iOS/macOS-Projekte |
| Terminal | iTerm2 | — | Primärterminal mit Claude-Status-Hook |
| Terminal | Ghostty | — | Fallback |
| VCS | git | brew | brew-git vor System-git im PATH |
| VCS-Hosting | GitHub | — | zwei Accounts |
| Secret-Scanning | gitleaks | via brew | in pre-commit eingebunden |
| Pre-Commit | pre-commit | via brew | Hooks in dev/base |
| Secrets-Backend | Vaultwarden + bitwarden-cli | — | selbstgehostet; löst 1Password CLI ab; Enpass.app als weitere App vorhanden |
| SSH | ed25519-Key | neu ab Setup | ersetzt alten RSA-Key |

---

## Die selbstgebaute „Paved Road" (`dev/base`)

Das wichtigste Repo der ganzen Installation. `dev/base` ist kein Framework — es ist eine Konvention-Sammlung die per `base sync` auf alle anderen Repos ausgestrahlt wird.

**Kernidee:** Standards definieren > Repos nach Standard bringen > nie manuell Boilerplate schreiben.

```
base new vite-react-pwa mein-neues-projekt   # 0 auf Standard in ~10 Sekunden
base sync ~/dev/altprojekt                   # ergänzt fehlende Dateien (rein additiv)
base doctor ~/dev/altprojekt                 # zeigt was noch fehlt
```

**Was `dev/base` definiert:**
- `CONSTITUTION.md` — was sich nie ändert (Entscheidungen, Invarianten)
- Templates für alle Projekttypen (Vite/React, Python-Service, Buchprojekt, Event-Studie, YouTube-Crawler)
- Sicherheitsregeln (.gitleaks.toml, .gitignore-Patterns)
- CI-Gate-Skript (gate.sh für Python, npm run verify:ci für Web)
- Claude/Codex-Standards (Subagenten-Routing, BIBLE.md-Konvention)
- Backbone-Skripte (Budget-Tracking, Session-Snapshots, Security-Gate, Context-Harvesting)

**Warum das wichtig ist:** 32 von 58 Repos haben `CLAUDE.md`, 26 haben `AGENTS.md`, 19 haben `HANDOFF.md` — diese Konsistenz kommt aus `dev/base`. Ohne es müsste jedes Repo manuell gepflegt werden.
