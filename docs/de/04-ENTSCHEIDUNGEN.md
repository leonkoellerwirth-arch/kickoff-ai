# Entscheidungen — Warum genau so und nicht anders

> ⚠️ Archivierte deutsche Fassung — maßgeblich ist die englische Version unter [`../04-DECISIONS.md`](../04-DECISIONS.md). Diese Datei wird nicht mehr aktualisiert.

ADR-artige Begründungen für die Tool-Entscheidungen in diesem Setup. Jeder Eintrag: Kontext · Entscheidung · Warum nicht die Alternative · Preis.

Diese Dokumentation ist für zwei Leser gedacht: für dich selbst wenn du in zwei Jahren fragst "warum haben wir das damals so gemacht?" — und für Fremde die das Setup adaptieren wollen und bestimmte Entscheidungen nicht teilen.

---

## 1. uv statt conda-base als Python-Standardweg

**Kontext:** Der Python-Stack ist die größte Quelle von Wartungsaufwand in einer gemischten Entwicklungsumgebung. Eine Maschine mit conda-base hat schnell hunderte Pakete aus verschiedenen Projekten, alle in einer Umgebung, `python3` zeigt global darauf.

**Entscheidung:** `uv` ist das primäre Werkzeug für Python-Projekte. conda bleibt installiert, wird aber nicht automatisch aktiviert.

**Warum nicht conda-base als Standard:**
- conda-base ist per Konvention der "System-Python" von conda — er sollte minimal sein
- Hunderte Pakete in base führen zu Konflikten zwischen Projekten
- conda 22.x ist träge in der Abhängigkeitsauflösung; uv ist 10–100× schneller
- `uv.lock` ist deterministisch und commitfähig — conda `environment.yml` ist es nicht zuverlässig

**Warum nicht pip/venv:**
- uv ersetzt pip/venv vollständig und ist schneller
- `uv python install 3.13` verwaltet auch Python-Versionen — kein pyenv nötig

**Preis:**
- Bestehende conda-Projekte müssen nicht migriert werden, können weiter conda-Envs nutzen
- Teams mit conda-Workflows (Wissenschaft, ML) müssen angepasst werden
- `uvx ruff` statt `pipx run ruff` — kleine Umgewöhnung

**Wann conda trotzdem richtig ist:** Projekte die conda-forge-only-Pakete brauchen (z. B. SPSS-Bindings, spezifische MKL-Optimierungen, proprietäre Wissenschafts-Pakete).

---

## 2. nvm + Node 24 statt mise/asdf

**Kontext:** Node-Versionsmanagement ist ein tägliches Thema: 36 Frontend-Repos, teils mit `.nvmrc`, teils ohne.

**Entscheidung:** nvm bleibt das primäre Werkzeug für Node-Versionsmanagement. Node 24 als Default.

**Warum nicht mise oder asdf:**
- mise kann nvm, conda und uv *ersetzen* — aber eine Migration im laufenden Betrieb ist aufwändig
- mise `.mise.toml` ist ein zusätzlicher Config-Layer; bestehende `.nvmrc`-Dateien müssten erhalten bleiben
- mise ist die bessere langfristige Wahl für einen Neuaufbau von Grund auf; aber nicht für einen inkrementellen Wechsel

**Wann mise die bessere Wahl wäre:**
- Neuaufbau ohne Legacy-Projekte
- Team-Umgebung wo alle dieselbe Toolchain-Lösung haben sollen
- Wenn Python + Node + Go + Rust alle gleich versioniert sein müssen pro Projekt

**Preis:** Keine `.mise.toml`-Dateien in Repos → Toolchain-Version muss in `.nvmrc` und `pyproject.toml` separat dokumentiert werden.

---

## 3. pnpm als Default-Paketmanager, bun als Zweitweg

**Kontext:** npm, pnpm, bun, yarn — alle lösen dasselbe Problem, alle haben Stärken.

**Entscheidung:** pnpm ist der Standard-Paketmanager für alle neuen Projekte. Bun als Fallback für Performance-kritische Builds.

**Warum pnpm statt npm:**
- Symlink-basierter Store: `node_modules` ist kleiner, Installationen sind schneller
- Striktere Abhängigkeitsisolation: verhindert "phantom dependencies"
- Workspace-Unterstützung ist besser als npm
- `pnpm-lock.yaml` ist deterministischer

**Warum nicht bun als Standard:**
- Bun ist noch nicht vollständig kompatibel mit allen npm-Paketen
- Als Runtime für bestehende Node.js-Projekte braucht es manchmal Anpassungen
- Für schnelle Tooling-Skripte (`bun run`, `bun install`) ist es excellent

**Warum nicht yarn:**
- pnpm hat Yarn bei Performance und Disk-Effizienz überholt
- Yarn v1 (klassisch, im Einsatz) ist nicht mehr in aktiver Entwicklung

**Preis:** Bestehende Projekte mit `package-lock.json` müssen auf `pnpm-lock.yaml` migriert werden (oder laufen mit `pnpm import`).

---

## 4. Docker Desktop statt colima oder OrbStack

**Kontext:** Auf Apple Silicon läuft Docker nicht nativ — es braucht einen Linux-VM-Layer. Optionen: Docker Desktop (offiziell), colima (leichtgewichtig, open source), OrbStack (kommerziell, Performance-Fokus).

**Entscheidung:** Docker Desktop.

**Warum nicht colima:**
- colima hat kein GUI — für phpMyAdmin-Debugging aus dem Browser ist das kein Problem, aber für Docker-Desktop-Dashboard-Workflows schon
- Volume-Mounting hat unter colima gelegentlich Performance-Probleme
- docker compose v2 braucht manuelle Konfiguration unter colima

**Warum nicht OrbStack:**
- Kommerziell (kostenlos für Einzelentwickler, aber Lizenzänderungen möglich)
- Kleines Team hinter dem Produkt vs. Docker, Inc.

**Preis:** Docker Desktop ist Resource-intensiver als colima. Auf 32 GB RAM kein spürbares Problem.

---

## 5. Ollama nativ (brew formula) statt im Container

**Kontext:** Ollama kann nativ installiert werden (brew) oder als Docker-Container laufen.

**Entscheidung:** Ollama nativ via brew formula. Kein Cask (GUI-App), kein Container.

**Warum nicht Container:**
- Docker auf macOS hat keinen direkten Zugriff auf Metal (die Apple-GPU-API)
- Ein Ollama-Container läuft auf macOS als CPU-only — Inferenz ist 5–10× langsamer
- Auf Apple Silicon ist Metal-beschleunigte Inferenz einer der größten Vorteile; diesen per Container aufzugeben ergibt keinen Sinn

**Warum nicht Cask (ollama-app):**
- Das Cask ist eine native macOS-App mit Menüleistensymbol und Auto-Start-Logik
- Die formula gibt mehr Kontrolle über Start/Stop
- Cask + formula gleichzeitig installiert führt zu Port-Konflikten

**Preis:** Ollama startet nicht automatisch beim Login. Muss explizit gestartet werden (`ollama serve`) wenn es gebraucht wird — das ist eine bewusste Entscheidung (kein Dauerbetrieb).

---

## 6. zsh + oh-my-zsh + powerlevel10k trotz Startzeit-Kosten

**Kontext:** oh-my-zsh und powerlevel10k haben messbaren Einfluss auf Shell-Startzeit. Ohne Lazy-Loading: 300–600 ms pro neues Terminal-Fenster.

**Entscheidung:** zsh + oh-my-zsh + powerlevel10k, mit Lazy-Loading für nvm und conda.

**Warum nicht fish:**
- fish hat eine `~/.config/fish`-Konfiguration auf der Maschine — es wurde evaluiert
- fish-Skripte sind nicht POSIX-kompatibel; viele Copy-Paste-Skripte aus Dokumentation funktionieren nicht direkt
- oh-my-fish ist kleiner als oh-my-zsh; das Plugin-Ökosystem auch

**Warum nicht bare zsh ohne oh-my-zsh:**
- Plugins (zsh-autosuggestions, zsh-syntax-highlighting) sind genuiner Produktivitätsgewinn
- powerlevel10k mit git-Status, Python-Env und Node-Version im Prompt spart manuelle `git status`-Aufrufe

**Wie Lazy-Loading die Startzeit-Kosten reduziert:**
- nvm: lazy (lädt nur beim ersten `node`/`npm`/`nvm`-Aufruf) → spart ~300 ms
- conda: lazy (aktiviert sich nur bei `conda activate`) → spart ~100–200 ms
- Resultat: Shell-Start < 200 ms statt > 600 ms

**Preis:** Lazy-Loading bedeutet dass das erste `node`-Kommando in einer Session etwas langsamer ist (~300 ms einmalig). Akzeptabel.

---

## 7. VS Code + Xcode + IntelliJ nebeneinander statt einem Editor

**Kontext:** Drei Editoren gleichzeitig installiert und genutzt. Das klingt nach Overhead.

**Entscheidung:** Alle drei, für klar getrennte Anwendungsfälle.

| Editor | Anwendungsfall |
|---|---|
| VS Code | TypeScript/React, Python/FastAPI, PHP, alles was kein nativer IDE-Support braucht |
| Xcode | iOS/macOS Swift-Projekte — kein anderer Editor kann hier konkurrieren |
| IntelliJ IDEA | Java/Spring-Boot, Gradle/Maven — Red Hat Java in VS Code ist gut, aber IntelliJ ist besser |

**Warum nicht VS Code für alles:**
- Xcode-Simulatoren, iOS-Deployment, SwiftUI-Preview: technisch nur in Xcode
- IntelliJ Refactoring für Java (Extract Method, Change Signature über Modul-Grenzen) ist VS Code überlegen

**Preis:** Lizenz für IntelliJ. Diskspace (~3–4 GB). Mentaler Kontextwechsel zwischen Editoren — kein Problem weil die Anwendungsfälle trennscharf sind.

---

## 8. Selbstgebaute Paved Road (`dev/base`) statt Copier/Cookiecutter/Nx

**Kontext:** Template-/Scaffolding-Tools gibt es viele: Cookiecutter (Python), Copier (Python, mit Update-Support), Yeoman (JS), Nx (Monorepo).

**Entscheidung:** Eigenes `dev/base`-System mit `base new` / `base sync`.

**Warum nicht Copier oder Cookiecutter:**
- Diese Tools scaffolden einmalig — `base sync` kann bestehende Repos *inkrementell aktualisieren* (rein additiv, nie überschreibend)
- `base harvest` zieht projektspezifische Erkenntnisse zurück in die globale Wissensbasis — kein Standardtool macht das
- Der KI-Kontext (CLAUDE.md, AGENTS.md, HANDOFF.md, BIBLE.md) ist spezifisch genug dass Standardtemplates nicht passen

**Warum nicht Nx:**
- Nx ist ein Monorepo-Tool — hier sind es 58 separate Repos, kein Monorepo
- Nx-Overhead (eigene Task-Runner, Plugin-Ökosystem) für Einzel-Repos ist nicht gerechtfertigt

**Preis:** `dev/base` ist custom — neues Teammitglieder müssen es lernen. Updates an Standards müssen manuell per `base sync` in alle Repos ausgerollt werden (der Schritt ist halbautomatisch, aber nicht vollautomatisch).

---

## 9. Homebrew-PATH vor `/usr/bin`

**Kontext:** macOS liefert eigene Versionen von git, python3, curl, etc. unter `/usr/bin`. Homebrew installiert neuere Versionen unter `/opt/homebrew/bin`.

**Entscheidung:** `/opt/homebrew/bin` steht in der PATH-Reihenfolge vor `/usr/bin`.

**Warum:**
- Apple-System-Tools sind auf macOS-Kompatibilität optimiert, nicht auf aktuelle Features
- `git` in `/usr/bin`: Apple-Patched, nicht immer auf aktuellem Stand
- brew-git, brew-python, brew-curl haben aktuellere Versionen und mehr Features
- Homebrew ist das einzige Paketverwaltungssystem — alle installierten Tools sollen auch genutzt werden

**Risiko:** Selten bricht ein brew-Update etwas das auf Apple-System-Tools angewiesen war. In der Praxis: nie passiert in Jahren Nutzung.

**Preis:** Bei brew-Problemen kann man explizit auf `/usr/bin/git` zurückfallen. Das ist dokumentiert.

---

## 10. ed25519 statt RSA für SSH-Keys

**Kontext:** Der alte SSH-Key ist RSA, generiert 2024.

**Entscheidung:** Neuer ed25519-Key für alle neuen SSH-Verbindungen. RSA-Key nicht wiederverwenden.

**Warum ed25519:**
- Kürzere Schlüssellänge (~68 Zeichen Public Key vs. ~400 bei RSA-2048) — besser lesbar, schneller zu übertragen
- Schnellere Signierung (relevant bei vielen SSH-Verbindungen)
- Resistenter gegen timing-basierte Angriffe (durch konstante Zeitoperationen)
- Moderner Standard — alle aktuellen SSH-Implementierungen unterstützen es

**Warum nicht RSA kopieren:**
- Ein Neuaufbau ist der richtige Moment für einen neuen Key — frisch, ohne History
- Der alte Key kann nach Migration widerrufen werden (bei GitHub entfernen)
- Wenn der alte Key kompromittiert wäre (unwahrscheinlich, aber möglich), würde Kopieren das Problem übernehmen

**Preis:** Neuer Key muss bei allen Services hinterlegt werden (GitHub ×2, alle Server mit SSH-Zugang). Aufwand: 30–60 Minuten einmalig.

---

## 11. SSH-Commit-Signierung statt GPG

**Kontext:** Commit-Signierung beweist kryptografisch dass ein Commit von einem bestimmten Key stammt. Zwei Verfahren: GPG und SSH (seit git 2.34).

**Entscheidung:** SSH-Commit-Signierung (`gpg.format = ssh`).

**Warum nicht GPG:**
- GPG-Keymanagement ist komplex: Web of Trust, Ablaufdaten, Subkeys, Key-Server
- Der GPG-Agent ist ein häufiger Quell von Problemen (pinentry, Agent-Cache)
- SSH-Key ist ohnehin vorhanden — denselben Key auch für Signierung zu nutzen ist eleganter
- GitHub verifiziert SSH-Signaturen genauso wie GPG-Signaturen (grünes "Verified"-Badge)

**Warum nicht gar nicht signieren:**
- Bei öffentlichen Repos (dieses Repo ist öffentlich): Signierung gibt externen Lesern Vertrauen
- Bei Code-Reviews in Teams: verifizierte Commits geben Zuversicht dass der Autor tatsächlich der Autor ist

**Preis:** Geringfügig: ein zusätzlicher git-Config-Block. Einmaliger Aufwand.
