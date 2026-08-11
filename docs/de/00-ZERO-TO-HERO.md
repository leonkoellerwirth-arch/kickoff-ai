# Zero to Hero — vollständiger Setup-Guide

> ⚠️ Archivierte deutsche Fassung — maßgeblich ist die englische Version unter [`../00-ZERO-TO-HERO.md`](../00-ZERO-TO-HERO.md). Diese Datei wird nicht mehr aktualisiert.

> Ziel: Du stehst vor einem frisch ausgepackten Mac und willst am Ende exakt diese Arbeitsumgebung haben.
> Lese diesen Guide von oben nach unten. Jede Phase hat ein klares Ziel, einen automatischen Teil (Skript) und einen manuellen Rest (Checkliste).

**Eilig?** Dann nimm stattdessen [QUICKSTART.md](../QUICKSTART.md) — vier kumulative Stufen, eine Seite, keine Prosa. Komm hierher zurück wenn du die Hintergründe oder Fehlerbehebung brauchst.

Für eine vollständige Checkliste der manuellen Schritte: [01-MANUELL.md](01-MANUELL.md).
Für die Begründungen hinter den Tool-Entscheidungen: [04-ENTSCHEIDUNGEN.md](04-ENTSCHEIDUNGEN.md).

---

## Phase 0 — Bevor der Mac an ist

**Ziel:** Alle Zugangsdaten und Referenzpunkte bereit haben, damit du in Phase 1–11 nicht stundenlang suchen musst.

### Was du bereithalten musst

| Was | Wo | Blockiert ohne? |
|---|---|---|
| Apple-ID + Passwort | Vaultwarden / Enpass | Ja — App Store, iCloud, Xcode |
| GitHub-Zugangsdaten (beide Accounts) | Vaultwarden | Ja — Repos klonen |
| Anthropic API Key | Vaultwarden | Ja — Claude Code |
| OpenAI API Key | Vaultwarden | Ja — Codex CLI |
| Google AI (Gemini) API Key | Vaultwarden | Ja — Gemini CLI |
| Apple Developer Account | Vaultwarden | Nur für iOS-Projekte |
| SSH-Key-Backup oder Entscheidung: neu generieren | — | Empfehlung: neu generieren ist sicherer |
| Lizenzen: Adobe CC, IBM SPSS, Topaz/Luminar/Nik, JetBrains | Vaultwarden / E-Mail | Für App-Aktivierung |
| `.env`-Dateien der laufenden Projekte | Sicherer Speicher — **nie** per AirDrop/Klartext | Ja für laufende Projekte |
| Liste der Docker-Volumes mit echten Daten | Jetzt notieren! | Datenverlust-Risiko |

### Backup der alten Maschine

```bash
# Welche Docker-Volumes haben echte Daten?
docker volume ls
docker volume inspect <name>

# .env-Dateien inventarisieren
find ~/dev -name ".env" -o -name "*.env" 2>/dev/null

# Eigene Repo-Sammlung: was hat noch keinen Remote?
for d in ~/dev/*/; do
  git -C "$d" remote -v 2>/dev/null || echo "KEIN REMOTE: $d"
done

# dev/base committen + pushen, bevor der alte Mac weggeht
cd ~/dev/base && git status && git push
```

**Kritisch:** Secrets aus laufenden Agenten-Tools (Telegram-Bots, Gateway-Credentials) müssen in Vaultwarden überführt werden, bevor Legacy-Tools deinstalliert werden. Details in [01-MANUELL.md](01-MANUELL.md) Abschnitt "Secrets-Migration".

---

## Phase 1 — macOS-Ersteinrichtung

**Skript:** keines — vollständig manuell.
**Dauer:** 20–30 Minuten.

### Was zu tun ist

1. Ersteinrichtungsassistent: Sprache, Region, Apple-ID einloggen.
2. **FileVault sofort aktivieren** — `Systemeinstellungen → Datenschutz & Sicherheit → FileVault → Aktivieren`. FileVault-Wiederherstellungsschlüssel in Vaultwarden speichern — ohne ihn ist das Gerät bei Verlust unrettbar.
3. iCloud: "Schreibtisch & Dokumente" in iCloud **deaktivieren** (verhindert ungewollte Synchronisation von Dev-Dateien).
4. Software-Update: `Systemeinstellungen → Allgemein → Softwareaktualisierung` — laufen lassen bis "Aktuell".
5. Die in `scripts/09-macos-defaults.sh` gesetzten Einstellungen (Finder, Dock, Key-Repeat) musst du hier **nicht** von Hand machen.

### Verifikation

```bash
fdesetup status          # FileVault On
sw_vers                  # macOS-Version stimmt
```

---

## Phase 2 — Apple-Toolchain

**Ziel:** Xcode + Command Line Tools aufsetzen, damit Swift-Projekte bauen und die restliche Toolchain (Homebrew, Python-C-Bindings, etc.) auf den richtigen SDK-Pfaden liegt.

**Skript:** `scripts/01-apple-toolchain.sh`

### CLT vs. vollständiges Xcode

Du brauchst beides — CLT allein reicht nicht, wenn du `.xcodeproj`-Projekte hast.

```bash
# CLT wird von bootstrap.sh automatisch geprüft/installiert
xcode-select --install

# Xcode selbst: ausschliesslich über App Store (kein automatisierbarer Weg)
# → Xcode.app laden, starten, Component-Installation bestätigen
```

Das Skript erledigt nach Xcode-Installation:
```bash
sudo xcodebuild -license accept
# Simulatoren installieren (nur --full): iOS, watchOS, visionOS
xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### Manuell bleibt

- Xcode aus dem App Store laden (4–8 GB, 15–30 Min)
- Beim ersten Start: Component-Installation bestätigen

### Verifikation

```bash
xcode-select -p
# Erwartung: /Applications/Xcode.app/Contents/Developer

swift --version
# Swift 6.x

xcrun simctl list runtimes
# iOS, watchOS, visionOS vorhanden (bei --full)
```

### Typische Fehler

- `error: invalid active developer path` → `sudo xcode-select -r` oder `-s /Applications/Xcode.app`
- Simulatoren fehlen nach `--minimal` → `./bootstrap.sh --only 01-apple-toolchain`

---

## Phase 3 — Homebrew + Kernpakete

**Ziel:** Paketmanager einrichten, alle in `Brewfile` definierten Tools installieren.

**Skript:** `scripts/02-homebrew.sh`

### Was automatisch läuft

```bash
# Homebrew installieren (falls nicht vorhanden)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Taps und Kernpakete
brew bundle --file=Brewfile

# Optionale Pakete (nur --full)
brew bundle --file=Brewfile.optional
```

### Was im Brewfile steht (Auswahl mit Verwendungszweck)

| Paket | Wozu |
|---|---|
| `git`, `git-lfs` | Versionskontrolle; lfs für Binary-Assets |
| `gh` | GitHub CLI für PRs, Issues, Release-Management |
| `uv` | Python-Projektmanagement, lockfilebasiert |
| `pnpm` | Package-Manager für Vite/React-Projekte |
| `jq` | JSON-Verarbeitung in Shell-Skripten, API-Debugging |
| `ripgrep` | Code-Suche über viele Repos |
| `gitleaks` | Secret-Scanning vor Commits |
| `shellcheck` | Lint für Setup-Skripte |
| `ollama` | Lokale Sprachmodelle |
| `gemini-cli` | Gemini als zweiten KI-Agenten |
| `postgresql@14` | Postgres lokal (Projekte ohne docker-compose) |
| `openjdk@17` | Java für Spring-Boot-Projekte + Maven/Gradle |
| `go`, `rust`, `php` | Nebenspieler je nach Projekt |
| `vips` | Bildverarbeitung für `sharp-cli`/Optimierungs-Workflow |
| `pre-commit` | Git-Hooks — **auf bisheriger Maschine fehlend, jetzt Pflicht** |

### Verifikation

```bash
brew doctor            # keine Errors
brew bundle check      # "The Brewfile's dependencies are satisfied."
which git              # /opt/homebrew/bin/git  — NICHT /usr/bin/git
```

### Typische Fehler

- `/usr/bin/git` hat Vorrang: PATH-Problem, wird in Phase 4 behoben.
- `brew bundle` schlägt fehl weil ein Legacy-Tap entfernt wurde: `brew untap <tap>` und erneut versuchen.

---

## Phase 4 — Terminal & Shell

**Ziel:** Eine saubere, schnelle Shell-Konfiguration die den Altlasten-Wildwuchs einer gewachsenen `.zshrc` ersetzt.

**Skript:** `scripts/03-shell.sh`

### Was automatisch läuft

- oh-my-zsh installieren/aktualisieren
- Plugins: `git`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `web-search`
- Theme: powerlevel10k
- `config/zshrc` → `~/.zshrc` (Backup der alten unter `~/.zshrc.bkp.$(date +%Y%m%d)`)
- `config/zprofile` → `~/.zprofile`

### Warum die neue .zshrc anders aufgebaut ist

Eine über Jahre gewachsene `.zshrc` akkumuliert Probleme. Hier sind die häufigsten und wie die neue Konfiguration sie löst:

| Problem | Ursache | Fix in neuer .zshrc |
|---|---|---|
| PATH-Duplikate (`/usr/bin` 2×, `/usr/local/bin` 2×) | Mehrere Quellen erweitern PATH unkontrolliert | `typeset -U path` dedupliziert automatisch |
| System-git gewinnt gegen brew-git | `/usr/bin` liegt vor `/opt/homebrew/bin` im PATH | `/opt/homebrew/bin` kommt zuerst |
| Langsamer Shell-Start durch nvm | `nvm.sh` lädt bei jedem Start alle Node-Bindings | Lazy-Load: nvm initialisiert sich erst beim ersten `node`/`npm`-Aufruf |
| `python3` → conda-base | conda init aktiviert base bei jedem Start | conda nicht automatisch aktiviert — nur bei `conda activate` |
| VS-Code-PATH doppelt in `.zprofile` | Zeilenweise Duplikate durch wiederholtes Editieren | Einmal, dedupliziert |
| `.local/bin/env` in `.profile` UND `.zshrc` | Unterschiedliche Shell-Initialisierungspfade | Nur einmal in `.zprofile` |
| Completion für nicht installiertes Framework | `ng completion` ohne Angular CLI | Entfernt |
| Umgebungsvariable zeigt auf nicht existierendes Verzeichnis | Altlast nach Toolwechsel | Bereinigt |
| Completion-Block doppelt | Kein Merge-Mechanismus beim Einfügen | Dedupliziert |
| Fehlende Leerzeile vor `export PATH` | Textkonkatenation ohne Trennzeichen | Korrekt formatiert |

**lazy nvm:**
```zsh
nvm() {
  unfunction nvm
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
  nvm "$@"
}
node() { nvm > /dev/null 2>&1; node "$@"; }
npm()  { nvm > /dev/null 2>&1; npm  "$@"; }
```

**lazy conda:**
```zsh
conda() {
  unfunction conda
  __conda_setup="$($HOME/miniforge3/bin/conda shell.zsh hook 2>/dev/null)"
  eval "$__conda_setup"
  conda "$@"
}
```

### iTerm2 vs. Ghostty

Beide Terminals sind installiert. iTerm2 ist der aktive Standard (nutzt einen Statushook für Claude-Code-Events). Ghostty hat eine minimale Basis-Config und dient als schnelle Alternative. Standardanwendung: manuell setzen.

### Verifikation

```bash
exec zsh

# Kein doppelter PATH-Eintrag
echo $PATH | tr ':' '\n' | sort | uniq -d   # muss leer sein

# brew-git gewinnt
which git   # /opt/homebrew/bin/git

# powerlevel10k
echo $PROMPT   # p10k-Prompt oder Konfigurationsassistent startet
```

---

## Phase 5 — Git, SSH, GitHub, Signierung

**Ziel:** git vollständig konfiguriert, ed25519-Key statt altem RSA, beide GitHub-Accounts klar getrennt, signierte Commits, pre-commit-Hooks laufen.

**Skript:** `scripts/08-git-ssh.sh`

### Was automatisch läuft

```bash
# git-Konfiguration aus config/gitconfig übernehmen
git config --global include.path ~/dev/kickoff-ai/config/gitconfig

# Neuen ed25519-Key generieren
ssh-keygen -t ed25519 -C "<deine@email.com>" -f ~/.ssh/id_ed25519

# SSH-Commit-Signierung aktivieren
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true

# core.excludesfile registrieren
git config --global core.excludesfile ~/.gitignore_global

# pre-commit in dev/base installieren
cd ~/dev/base && pre-commit install --install-hooks

# gitleaks über pre-commit einbinden
# (in dev/base/.pre-commit-config.yaml bereits definiert)
```

### Manuell bleibt

- SSH-Key bei GitHub hinterlegen (für beide Accounts separat):
  ```bash
  gh auth login --hostname github.com
  gh ssh-key add ~/.ssh/id_ed25519.pub --title "kickoff-$(date +%Y%m%d)"
  ```

- Zweiten Account in `~/.ssh/config` mit eigenem Key-Eintrag einrichten:
  ```sshconfig
  Host github-primary
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes

  Host github-secondary
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_secondary
    IdentitiesOnly yes
  ```

- Entscheiden welcher Account als Default gilt und welcher per Host-Alias in betreffenden Repos genutzt wird.

### Warum ed25519 statt RSA

RSA-2048 ist sicher, aber ed25519 ist kleiner (kürzere Schlüssel, schnellere Signierung), von allen aktuellen Systemen unterstützt, und der moderne Standard. Einen alten RSA-Key zu kopieren bringt den gleichen Sicherheitsstand wie vorher — ein Neuaufbau ist der richtige Moment für einen neuen Key. Details: [04-ENTSCHEIDUNGEN.md](04-ENTSCHEIDUNGEN.md).

### Verifikation

```bash
git config --global core.excludesfile   # ~/.gitignore_global
git config --global gpg.format         # ssh
git config --global commit.gpgsign     # true
ssh -T github-primary                   # Hi <username>!
ssh -T github-secondary                 # Hi <zweiter-username>!
pre-commit --version                    # vorhanden
git commit --allow-empty -m "test signing"
git log --show-signature -1            # Good "git" signature
```

---

## Phase 6 — Sprachen & Versionsmanagement

**Ziel:** Node über nvm, Python über uv als Standard, conda als Opt-in, Java/Go/Rust/PHP aus Homebrew.

**Skripte:** `scripts/04-node.sh`, `scripts/05-python.sh`

### Node

```bash
nvm install 24
nvm alias default 24

# Globale Pakete (minimale Liste)
npm install -g @openai/codex sharp-cli
```

Du hast 36 `package.json`-Projekte und nutzt pnpm als Standard-Package-Manager, Bun als Fallback für Performance-kritische Builds, Deno für eigenständige Skripte.

### Python — warum uv statt conda-base

Die Ausgangslage auf einer gewachsenen Maschine ist typischerweise: `python3` zeigt auf conda-base, das mit hunderten Paketen zugemüllt ist (torch, jupyter, scraping-Bibliotheken, wissenschaftliche Pakete für einmalige Experimente…). Das ist ein klassisches Anti-Pattern:

- conda-base ist kein Projekt-Env, sondern der Systemroot des conda-Ökosystems
- Pakete in base blockieren Updates und mischen Abhängigkeiten
- `python3` zeigt nie auf das Projekt-Python → "works on my machine"-Probleme
- conda 22.x ist zwei Major-Versionen alt

**uv als Primärweg:**
```bash
# Neues Python-Projekt
uv init mein-projekt
cd mein-projekt
uv add fastapi pydantic httpx

# Tool ausführen ohne Installation
uvx ruff check .
uvx pytest

# Python-Version pinnen
uv python pin 3.13
```

uv ist 10–100× schneller als pip/conda für Abhängigkeitsauflösung, lockfile-basiert (`uv.lock`), und isoliert Projekte automatisch.

**conda als Opt-in behalten** für:
- Projekte mit conda-only-Paketen (MKL, SPSS-Integration, cvxpy)
- Bestehende Jupyter-Notebooks die ein conda-Env brauchen
- `conda activate <env>` funktioniert weiter; conda-base wird nicht aus dem PATH geworfen, nur nicht standardmäßig aktiviert

### Java / Go / Rust / PHP

Alle aus Homebrew, keine weitere Konfiguration:
```bash
# Java 17 — für Spring-Boot-Projekte
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
# Maven läuft direkt aus /opt/homebrew/bin/mvn — kein M2_HOME nötig

# Go, Rust, PHP
which go rustc php   # alle /opt/homebrew/bin/
```

### Verifikation

```bash
node --version          # v24.x
python3 --version       # NICHT mehr conda-base 3.10.9
uv --version            # 0.10.x+
java -version           # 17.x
go version              # 1.x
rustc --version         # 1.x
```

---

## Phase 7 — Container & Datenbanken

**Ziel:** Docker Desktop läuft, das Projekt-Muster ist dokumentiert, Container laufen nur wenn gebraucht.

**Skript:** `scripts/06-containers.sh`

### Was automatisch läuft

- Docker Desktop prüfen/installieren (Cask: `docker`)
- `docker compose version` verifizieren
- Basisimages ziehen: `mysql:8.0`, `postgres:17-alpine`, `qdrant/qdrant:v1.13.0`, `valkey/valkey:8-alpine`

### Das Muster: pro Projekt ein docker-compose

Jedes Web-Projekt hat ein eigenes `docker-compose.yml` mit dem Datenbankstack (mysql:8.0 + phpMyAdmin + API-Container). Das ist konsistent und isoliert.

**Problem auf gewachsenen Maschinen:** Viele Container laufen dauerhaft — auch wenn das zugehörige Projekt seit Wochen nicht angefasst wurde. Das kostet RAM und Energie.

**Empfohlenes Muster:**
```bash
# Vor der Arbeit — nur das aktive Projekt hochfahren
cd ~/dev/<projektname> && docker compose up -d

# Nach der Arbeit
docker compose down   # ohne -v: Daten in benannten Volumes bleiben erhalten

# Überblick behalten
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Das Setup-Skript setzt **keine** Container auf Autostart. Persistente Daten liegen in benannten Volumes (nicht im Container-Layer) — `docker compose down` ohne `-v` löscht nichts.

### Spezialdienste für KI-Projekte

Für Projekte mit Vektordatenbank + Queue + Postgres:
```yaml
services:
  db:      image: postgres:17-alpine
  vector:  image: qdrant/qdrant:v1.13.0
  queue:   image: valkey/valkey:8-alpine
```

Ollama läuft nativ (brew formula), nicht als Docker-Container — Details in Phase 8.

### Verifikation

```bash
docker info | grep "Server Version"
docker compose version
docker ps   # idealerweise: nur aktive Projekte
```

---

## Phase 8 — Der KI-Stack

**Ziel:** Claude Code, Codex CLI, Gemini CLI, Ollama und MCP vollständig konfiguriert — das Primärwerkzeug.

**Skript:** `scripts/07-ai-stack.sh`

> Legacy-Agenten-Gateways (OpenClaw o. ä.) werden auf der bestehenden Maschine per `scripts/90-cleanup-legacy.sh` entfernt. Auf einem Neuaufbau entstehen sie nicht.

### Claude Code

Claude Code ist das Hauptwerkzeug — mit `claude-opus-5[1m]` als Hauptmodell und `claude-sonnet-4-6` für Subagenten (Kostenbremse).

```bash
# Installation
npm install -g @anthropic-ai/claude-code   # oder über ~/.local/bin/claude

# Subagenten-Kostenbremse (in .zshrc)
export CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6
```

**Permissions (`~/.claude/settings.json`):**
```json
{
  "permissions": {
    "allow": ["curl 127.0.0.1", "npm test", "git status", "npx tsc"],
    "deny": ["Read(**/.env)", "Read(**/secrets/**)"],
    "ask": ["Bash(rm *)"]
  }
}
```

**Plugins (aktiv):**
- `claude-mem` — projektübergreifendes Gedächtnis
- `frontend-design` — Frontend-Designrichtlinien
- `apple-skills` — iOS/Swift/App-Store-Workflows

**Hooks:** Ein Status-Script empfängt alle Claude-Code-Events (SessionStart/End, PreToolUse, PostToolUse, Stop, Notification) und zeigt den aktuellen Status in der Terminal-Statusleiste. Die Script-Datei muss manuell übertragen oder neu erstellt werden — sie liegt unter `~/.config/iterm2/`.

**Sicherheitseinstellungen:** `skipDangerousModePermissionPrompt` und `skipAutoPermissionPrompt` sind aktiv. Lies [docs/02-GAP-ANALYSE.md](02-GAP-ANALYSE.md) Befund A.17 für die Risikobewertung und den empfohlenen Mittelweg.

**CLAUDE.md (Subagent-Routing-Regeln):** `~/.claude/CLAUDE.md` enthält globale Routing-Regeln. Diese Datei wird vom Skript angelegt.

### Codex CLI

```bash
npm install -g @openai/codex

# ~/.codex/config.toml
# model = "gpt-5.6-terra"
# reasoning = "medium"
# service_tier = "fast"
# approval_mode: Empfehlung ist "suggest" statt "full-auto" — siehe Gap-Analyse A.17
```

MCP-Server für Codex: `basic-memory` (via `uvx`), `openaiDeveloperDocs`.

### Gemini CLI

```bash
brew install gemini-cli
# API Key: GEMINI_API_KEY via env-run (bw://gemini-api/password)
# ~/.gemini/settings.json: claude-mem-Hooks auf allen Events
```

Gemini CLI nutzt dasselbe claude-mem-Gedächtnissystem wie Claude — Sessions über verschiedene Agenten hinweg teilen Kontext.

### Ollama + lokale Modelle

```bash
# Nur die brew formula — kein Cask, kein Container (Doppelung vermeiden)
brew install ollama

# Dienst starten (bei Bedarf, nicht permanent)
ollama serve &

# Modelle ziehen — Speicherplatz prüfen vorher!
ollama pull llama3.2          # 2.0 GB — schnelles Allrounder-Modell
ollama pull deepseek-r1:14b   # 9.0 GB — Reasoning-Aufgaben
ollama pull glm-ocr           # 2.2 GB — OCR-Workflows
ollama pull aya-expanse:8b    # 5.1 GB — mehrsprachige Aufgaben
# Gesamt: ~18 GB

# Modelle bei Bedarf nutzen (via API oder direkt)
ollama run llama3.2 "hallo"
curl http://localhost:11434/api/generate -d '{"model":"llama3.2","prompt":"ping"}'
```

**Warum nativ statt Container:** Ollama nativ (brew) nutzt Metal-Beschleunigung auf Apple Silicon direkt. Ein Ollama-Container verliert GPU-Zugriff auf macOS und läuft reiner CPU — deutlich langsamer. Details: [04-ENTSCHEIDUNGEN.md](04-ENTSCHEIDUNGEN.md).

**Hinweis Speicherplatz:** Alle Modelle zusammen ~18 GB. Bei knappem Speicher zuerst aufräumen (siehe Gap-Analyse A.16), dann `ollama pull`.

### MCP-Server

MCP (Model Context Protocol) verbindet Claude mit externen Tools:
```bash
# basic-memory — lokales Dateigedächtnis
claude mcp add basic-memory -- uvx basic-memory

# Weitere Server nach Bedarf
claude mcp add <name> <command>
claude mcp list
```

### Verifikation

```bash
claude --version
codex --version
gemini --version
ollama list         # installierte Modelle
ollama run llama3.2 "ping"   # Antwort kommt in < 5 Sek
```

---

## Phase 9 — Editoren

**Ziel:** VS Code mit vollständigem Extension-Set, IntelliJ über JetBrains Toolbox, Xcode aus Phase 2.

**Skript:** `scripts/10-editors.sh`

### VS Code

```bash
brew install --cask visual-studio-code

# Extensions aus config/vscode-extensions.txt
cat config/vscode-extensions.txt | xargs -L1 code --install-extension
```

Extension-Set nach Bereichen:

| Bereich | Extensions |
|---|---|
| Python | ms-python.python, Pylance, debugpy, python-envs, environment-manager |
| Jupyter | Jupyter + 4 Begleiter |
| Java/Spring | redhat.java, vscjava ×7, Spring Boot ×3, gradle, maven |
| PHP | Devsense ×4, composer, phpserver |
| Container | docker.docker, remote-containers, ms-azuretools |
| KI/Pair | continue.continue |
| Diagramme | plantuml ×2, structurizr |
| Frontend | Prettier, **ESLint** (neu hinzugefügt — war auf bisheriger Maschine fehlend), liveserver |

### JetBrains Toolbox + IntelliJ

```bash
brew install --cask jetbrains-toolbox
# IntelliJ: in der Toolbox-UI installieren (kein CLI-Weg)
# Nach Installation: idea <projektpfad> aus dem Terminal
```

### Ghostty

Ghostty ist installiert und hat eine minimale Basis-Config (Font, Theme, Scrollback). Primärterminal bleibt iTerm2 mit dem Claude-Code-Statushook.

### Verifikation

```bash
code --version
code --list-extensions | wc -l   # ~70
idea --version   # falls JetBrains-PATH gesetzt
```

---

## Phase 10 — Die eigene Paved Road (`dev/base`)

**Ziel:** Den eigenen Qualitätsstandard für alle Repos sofort verfügbar machen.

**Skript:** `scripts/11-paved-road.sh`

### Warum zuerst

`dev/base` definiert die Standards für alle anderen Projekte — Templates, Qualitätsgates, pre-commit-Hooks, Sicherheitsregeln. Ohne `~/dev/base/bin` im PATH funktionieren eigene Kommandos (`base new`, `base sync`, `base doctor`) nicht.

```bash
# base klonen
git clone git@github-primary:<account>/base.git ~/dev/base

# PATH erweitern (in .zshrc)
export PATH="$HOME/dev/base/bin:$PATH"

# Verfügbarkeit prüfen
base list
```

### Was `dev/base` tut

| Kommando | Funktion |
|---|---|
| `base new <template> <name>` | Scaffoldet ein neues Repo nach Template (vite-react-pwa, python-service, book, …) |
| `base sync [repo]` | Ergänzt fehlende Standard-Dateien in bestehenden Repos (rein additiv, nie überschreibend) |
| `base doctor [repo]` | Prüft ob ein Repo den Standards entspricht |
| `base lesson "<text>"` | Fügt eine Lektion zur globalen `memory/LESSONS.md` hinzu |
| `base harvest [repo]` | Zieht Erkenntnisse aus einem Repo in die globale Wissensbasis |
| `base status` | Überblick über alle Repos |

### Struktur

```
dev/base/
  CONSTITUTION.md          Invarianten — was sich nie ändert
  memory/LESSONS.md        Gesammelte Erkenntnisse aus allen Projekten
  standards/               Code-Standards (ci, git, python, web, security …)
  backbone/                Shell-Skripte für Gates, Budgets, Sicherheitschecks
  hooks/                   Git-Hook-Templates
  skills/                  Claude-Skills (session-start, project-state, namen …)
  templates/               Starter-Templates für neue Repos
```

---

## Phase 11 — Erster Smoke-Test

**Ziel:** Prüfen ob alles zusammenspielt — von `base new` bis zum grünen Gate.

```bash
# 1 — Setup-Zustand prüfen
./doctor.sh   # in ~/dev/kickoff-ai: ~40 Punkte, alle PASS oder WARN

# 2 — Neues Projekt scaffolden
cd ~/dev
base new vite-react-pwa smoke-test-$(date +%Y%m%d)
cd smoke-test-*/

# 3 — Abhängigkeiten installieren
pnpm install

# 4 — Gate durchlaufen
npm run verify:ci   # Type-Check + Lint + Tests

# 5 — Dev-Server starten
pnpm dev   # Browser öffnet sich, keine Console-Errors

# 6 — Claude Code im Kontext
claude   # liest CLAUDE.md, erkennt Projekt

# 7 — Aufräumen
cd ~/dev && rm -rf smoke-test-*/
```

Alle 7 Schritte grün → Setup ist fertig.

---

## Cleanup-Modul für die bestehende Maschine

Auf einem **Neuaufbau** entstehen Altlasten gar nicht erst. Auf der **bestehenden Maschine** gibt es ein opt-in Cleanup-Skript das die akkumulierten Altlasten entfernt:

```bash
# Dry-Run: was würde entfernt?
./bootstrap.sh --only 90-cleanup-legacy --dry-run

# Ausführen (mit automatischem Backup nach ~/.setup-backups/<timestamp>/)
./bootstrap.sh --only 90-cleanup-legacy
```

Was das Skript erledigt:
1. Sichert relevante Konfigurationsdaten nach `~/.setup-backups/<timestamp>/`
2. Entfernt Legacy-Agent-Gateway (npm global + pnpm-Link + LaunchAgent + Config-Verzeichnis mit Credentials)
3. Bereinigt `.zshrc`: Altlast-Variablen, tote Aliase, doppelte Completion-Blöcke
4. Entfernt verwaiste LaunchAgents (z. B. für deinstallierte Pakete)
5. Entfernt zugehörige Homebrew-Taps

Das Skript läuft **nicht** automatisch in `bootstrap.sh`.
