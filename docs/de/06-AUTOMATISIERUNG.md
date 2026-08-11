# Automatisierungsebene — Übersicht und Betriebsanleitung

> [English](../06-AUTOMATION.md)

Dieses Dokument beschreibt die 14 Skripte in `automation/bin/`
und die zugehörigen Launchd-Hintergrundjobs. Jede Automatisierung löst ein im Inventar
belegtes Problem. Probleme ohne Beleg aus dem Inventar wurden nicht automatisiert.

Alle Kommandos sind shell-first, macOS-only, bash 3.2-kompatibel, verwenden
`scripts/lib.sh` (Logging, Dry-Run, Bestätigung) und prüfen ihre Voraussetzungen
vor dem Start.

**Quellen:** INVENTORY.md §0–§15, docs/02-GAP-ANALYSE.md A.1–A.17, B.1–B.10.

---

## Übersichtstabelle

| Kommando | Problem (Inventar-Beleg) | Standard-Häufigkeit | Destruktiv? |
|---|---|---|---|
| `dev-up / dev-down / dev-ps` | 16 Container dauerhaft, 5× MySQL (§5, A.13) | manuell / täglich (down-idle) | nein (down stoppt nur) |
| `mac-clean` | 96 % SSD voll, 43 GB frei (§0, A.14) | wöchentlich (Report) | ja — nur mit `--apply` |
| `mac-update` | 6+ Werkzeuge manuell einzeln (§2-§7) | wöchentlich (Dry-Run) | ja — Updates |
| `mac-snapshot` | Setup-Repo veraltet ab Tag 1 | manuell | nein (local/ gitignoriert) |
| `repo-sweep` | 58 Repos ohne Lifecycle (§13, B.10) | manuell / wöchentlich | nein |
| `secret-sweep` | gitleaks ohne Hook, .env Klartext (A.7, B.1) | wöchentlich | nein (install-hooks: schreibt Hooks) |
| `db-backup` | DB-Volumes ohne Dump-Routine (§5) | täglich | nein (schreibt nur neu) |
| `ollama-sync` | Ollama 3× installiert, 4 Modelle (§6, A.12) | manuell / --sync | ja — nur mit `--sync` |
| `env-run` | .env Klartext, kein Secret-Backend (§9, B.1) | manuell | migrate: schreibt .template |
| `up2date` | Versions-Drift zwischen Registry und Upstream | wöchentlich (launchd) | nein |
| `sunset` | Statusübergänge in der Werkzeug-Registry | manuell | nein |
| `migration-diff` | Alt-Neu-Abgleich nach Maschinenumzug | manuell | nein |

---

## 1. Container-Lifecycle: `dev-up` / `dev-down` / `dev-ps`

### Problem

16 Docker-Container laufen dauerhaft, darunter 5 MySQL-Instanzen für verschiedene
Projekte (INVENTORY §5). Muster: Docker-Compose-Stacks wurden gestartet und nie
gestoppt. Mehrere GB RAM dauerhaft belegt, Ports belegt.

### Was die Kommandos tun

**`dev-up [<projekt>]`**: Findet `docker-compose.yml`/`compose.yaml` in `~/dev/<projekt>`
und startet den Stack. Ohne Argument: listet alle verfügbaren Stacks.

**`dev-down [<projekt>] [--all] [--idle 4h]`**: Stoppt einen oder alle Stacks.
`--idle 4h` stoppt Container mit ~0 % CPU, die seit ≥4 Stunden laufen.

**`dev-ps [<filter>]`**: Kompakte Tabelle aller Container mit Laufzeit, CPU, Speicher.

### Aufruf

```bash
dev-up                     # Listet verfügbare Stacks
dev-up mein-projekt        # Startet ~/dev/mein-projekt/docker-compose.yml
dev-down mein-projekt      # Stoppt diesen Stack
dev-down --all             # Stoppt alle Stacks
dev-down --idle 4h --dry-run  # Zeigt inaktive Container
dev-ps                     # Alle laufenden Container
dev-ps mysql               # Gefiltert nach "mysql"
```

### Zeitplan (launchd)

`dev.kickoff.dev-down-idle`: täglich 02:30 — stoppt Container mit ~0 % CPU nach ≥4 h.

### Was es bewusst NICHT tut

Volumes werden nie gelöscht. `dev-down` stoppt nur Container, nicht `docker compose down -v`.
Volumes bleiben erhalten bis ein explizites `docker volume rm` ausgeführt wird.

### Aufwand / Risiko

Risiko: minimal (Container stoppen, keine Datenlöschung). Aufwand: 0 — sofort nutzbar.

---

## 2. Speicherhygiene: `mac-clean`

### Problem

43 GB von 926 GB frei — 96 % belegt (INVENTORY §0, Gap-Analyse A.14). Docker-Images,
Xcode DerivedData, Homebrew-Caches, conda-base-Pakete füllen die SSD dauerhaft auf.

### Was das Kommando tut

Räumt in fester Reihenfolge, mit Größenangabe vorher/nachher:
Docker (system prune, Volumes nur mit Bestätigung), Xcode DerivedData + iOS DeviceSupport +
Simulator-Runtimes, Homebrew cleanup, npm/pnpm/bun/uv-Caches, conda clean,
verwaiste `node_modules` auflisten (nie löschen), Papierkorb.

**Standard ist Dry-Run** — kein einziges Byte wird gelöscht ohne `--apply`.

### Aufruf

```bash
mac-clean                        # Dry-Run: zeigt Einsparpotenzial
mac-clean --apply                # Tatsächlich bereinigen
mac-clean --only docker          # Nur Docker (Dry-Run)
mac-clean --apply --only brew    # Nur Homebrew wirklich bereinigen
```

### Zeitplan (launchd)

`dev.kickoff.mac-clean`: wöchentlich Samstag 10:00 — Dry-Run-Report, kein Löschen.

### Was es bewusst NICHT tut

- Volumes werden nur mit expliziter Bestätigung gelöscht (`confirm()`).
- `node_modules` werden nur aufgelistet, nie gelöscht.
- conda-Environments werden nicht gelöscht (nur Caches).

### Aufwand / Risiko

Risiko ohne `--apply`: null. Mit `--apply`: Docker-Volumes könnten Daten enthalten
(daher Bestätigung). Empfehlung: zuerst `--dry-run`, dann selektiv `--apply --only <gruppe>`.

---

## 3. System-Updates: `mac-update`

### Problem

Brew (~275 Formulae), 11 globale npm-Pakete, 4 KI-CLIs, 4 Ollama-Modelle, VS-Code-
Extensions werden alle einzeln von Hand aktualisiert (INVENTORY §2-§7). Kein einheitlicher
Ablauf, kein Protokoll.

### Was das Kommando tut

Aktualisiert in fester Reihenfolge: brew, npm global, pnpm/bun self-update, uv,
Claude Code, Codex CLI, Gemini CLI, Ollama + Modelle, VS-Code-Extensions, App-Store (mas),
Xcode CLT. Schreibt Protokoll nach `../../local/updates/<datum>.md`.

### Aufruf

```bash
mac-update                        # Alle Gruppen aktualisieren
mac-update --dry-run              # Nur prüfen, was veraltet ist
mac-update --only brew            # Nur Homebrew
mac-update --skip mas --skip vscode
```

Gruppen: `brew npm pnpm bun uv claude codex gemini ollama vscode mas xcode`

### Zeitplan (launchd)

`dev.kickoff.mac-update`: wöchentlich Sonntag 09:00 — Dry-Run (nur prüfen, nicht installieren).

### Was es bewusst NICHT tut

Der launchd-Job installiert nie automatisch — nur `--dry-run`. Tatsächliche Updates
bleiben bewusst manuell (`mac-update` ohne Flags, ohne launchd).

### Aufwand / Risiko

Risiko: Updates können Breaking Changes enthalten — deshalb launchd nur im Dry-Run.

---

## 4. Repo-Aktualisierung: `mac-snapshot`

### Problem

Ein Setup-Repo veraltet ab dem Tag seiner Erstellung. Neue Tools werden lokal
installiert, Extensions hinzugefügt, aber nie ins Repo eingecheckt. Kein Überblick
über den Drift zwischen Ist (Maschine) und Soll (Repo).

### Was das Kommando tut

Dumpt den Ist-Zustand (`brew bundle dump`, `npm ls -g`, `code --list-extensions`,
Ollama-Modelle, Versionsstände) nach `../../local/snapshot/` und diffet ihn gegen die
eingecheckten Soll-Stände (`Brewfile`, `config/vscode-extensions.txt`,
`automation/manifests/ollama-models.txt`).

Mit `--write`: schreibt Vorschläge als `../../local/snapshot/vorschlag-*.diff`.

### Aufruf

```bash
mac-snapshot                  # Diff anzeigen
mac-snapshot --write          # Diffs auch als Dateien speichern
```

### Was es bewusst NICHT tut

Repo-Dateien werden **niemals automatisch überschrieben**. Vorschläge sind nur in
`local/` (gitignoriert). Der Entwickler entscheidet bewusst, was ins Repo kommt.

### Aufwand / Risiko

Kein Risiko — rein lesend. `local/` ist gitignoriert.

---

## 5. Repo-Überblick: `repo-sweep`

### Problem

58 Repos unter `~/dev/` ohne Lifecycle-Management (INVENTORY §13, Gap-Analyse B.10).
Kein schneller Überblick über Drift, veraltete Branches, fehlende Standarddateien.

### Was das Kommando tut

Prüft pro Repo — ergänzend zu `base status` (gate/CI/BIBLE/agent-Status) — :
Branch ≠ main/master, Branches ohne Remote-Tracking, letzter Commit >N Tage,
fehlende Standarddateien (README/CHANGELOG/HANDOFF), .env-Dateien im Verzeichnis,
Repo-Größe. Sortierbar, Markdown-Output für `../../local/repo-sweep.md`.

### Aufruf

```bash
base status               # Erst das ausführen: gate/CI/BIBLE/agent
repo-sweep                # Ergänzender Check
repo-sweep --sort age     # Älteste Repos zuerst
repo-sweep --sort size --markdown  # Größte Repos + Report schreiben
repo-sweep --age-days 60  # Grenze auf 60 Tage setzen
```

### Was es bewusst NICHT tut

Überschneidet sich absichtlich nicht mit `base status`. Kein Löschen, kein Archivieren,
kein Branch-Delete.

---

## 6. Secret-Scanning: `secret-sweep`

### Problem

`gitleaks` ist installiert, läuft aber ohne Hook (Gap-Analyse A.7). `.pre-commit-config.yaml`
existiert in `base`, aber `pre-commit` ist nicht installiert (Gap-Analyse A.7).
`.env`-Dateien liegen im Klartext, mindestens eine außerhalb eines Repos (Gap-Analyse B.1).

### Was das Kommando tut

Führt `gitleaks detect` über alle Repos unter `~/dev/` aus (mit Timeout, Fortschritt).
Findet alle `.env*`-Dateien (auch außerhalb von Repos), prüft ob gitignoriert, prüft
ob `.env` in der Git-History auftaucht (kritischster Fall). Report nach `../../local/secret-sweep.md`.

Subkommando `secret-sweep install-hooks`: installiert `pre-commit` (via uv/pipx/brew)
und führt `pre-commit install --install-hooks` in allen Repos mit `.pre-commit-config.yaml` aus.

### Aufruf

```bash
secret-sweep               # Vollständiger Scan
secret-sweep --dry-run     # Zeigt was geprüft wird
secret-sweep install-hooks # pre-commit in allen passenden Repos einrichten
```

### Zeitplan (launchd)

`dev.kickoff.secret-sweep`: wöchentlich Mittwoch 04:00 — read-only Scan, schreibt Report.

### Was es bewusst NICHT tut

Löscht keine Dateien. Schreibt nichts in Vaultwarden. Bereinigt keine Git-History
(dafür `git-filter-repo` oder BFG — bewusst manuell, da destructive und repo-spezifisch).

---

## 7. Datenbank-Backup: `db-backup`

### Problem

5 MySQL-Container + Postgres + Qdrant + Valkey laufen mit Volumes, ohne erkennbare
Dump-Routine (INVENTORY §5). Datenverlust bei `docker system prune` wäre unwiederbringlich.

### Was das Kommando tut

Erkennt laufende MySQL/MariaDB/PostgreSQL-Container automatisch, zieht `mysqldump`
bzw. `pg_dump` von innen heraus, komprimiert nach `~/backups/db/<container>/<datum>.sql.gz`,
rotiert (behält N Tage), prüft Plausibilität (Größe > 0, Abschluss-Marker).

Credentials werden NICHT im Skript gespeichert — aus Container-Env-Variablen gelesen
(`MYSQL_ROOT_PASSWORD`, `POSTGRES_PASSWORD`), dann Bitwarden CLI (bw), dann interaktive Abfrage.

### Aufruf

```bash
db-backup                         # Alle laufenden DB-Container sichern
db-backup --dry-run               # Zeigen was gesichert würde
db-backup --container my-mysql    # Nur diesen Container
db-backup --keep-days 30          # 30 Tage Rotation
```

### Zeitplan (launchd)

`dev.kickoff.db-backup`: täglich 03:00 — schreibt Dumps, löscht Alte (Rotation).

### Was es bewusst NICHT tut

Keine Volumes-Löschung. Kein Backup von Qdrant/Valkey (kein Standard-Dump-Tool via
Docker exec — diese erfordern project-spezifische Backup-Strategien).

---

## 8. Ollama-Modelle: `ollama-sync`

### Problem

Ollama ist dreifach installiert: brew Formula, brew Cask, Docker-Container (INVENTORY §6,
Gap-Analyse A.12). Kein deklarativer Überblick über welche Modelle gewünscht sind.
4 Modelle (~18 GB). Docker-Container hat auf macOS keinen Metal-GPU-Zugriff (CPU-only).

### Was das Kommando tut

Vergleicht installierte Modelle mit `../../automation/manifests/ollama-models.txt`.
Meldet fehlende, überzählige und veraltete Modelle mit Speicherverbrauch.
Warnt vor Mehrfachinstallation mit Auflösungsanleitung.
Mit `--sync`: pullt fehlende, aktualisiert vorhandene.

### Aufruf

```bash
ollama-sync               # Nur prüfen (kein Pull)
ollama-sync --sync        # Fehlende Modelle pullen + aktualisieren
ollama-sync --sync --dry-run
```

### Manifest bearbeiten

```bash
# Modell hinzufügen:
echo "mistral:7b  # Für Code-Hilfe" >> automation/manifests/ollama-models.txt
ollama-sync --sync

# Modell entfernen:
ollama rm llama3.2  # Manuell (Sicherheit)
# Dann aus Manifest entfernen
```

### Was es bewusst NICHT tut

Löscht keine Modelle automatisch (überzählige nur anzeigen, nie löschen).
Löst die Mehrfachinstallation nicht automatisch auf — das ist ein einmaliger,
manueller Schritt.

---

## 9. Vaultwarden-Integration: `env-run`

### Problem

`.env`-Dateien liegen als Klartextdateien auf der Festplatte (INVENTORY §9, Gap-Analyse B.1).
Mindestens eine `.env` außerhalb eines Repos gefunden. Kein Secret-Backend vorhanden.

### Was das Kommando tut

**`env-run [--env-file .env.template] [--serve] [--dry-run] -- <befehl>`**: Löst
`bw://`-Referenzen über die Bitwarden CLI auf und startet den Befehl mit den Secrets
ausschließlich in der Prozessumgebung — nie als ps-sichtbare Argumente, nie als Datei.

**`env-run migrate <.env>`**: Schreibt eine bestehende `.env` in eine `.env.template`
mit `bw://`-Referenzvorschlägen um — schreibt **nichts** in Vaultwarden (bewusst manuell).

**`env-run check <.env.template>`**: Prüft ob alle Referenzen auflösbar sind, ohne
Werte auszugeben.

### Aufruf

```bash
# Tresor öffnen
export BW_SESSION=$(bw unlock --raw)

# 1. Bestehende .env migrieren:
env-run migrate .env
# → erstellt .env.template mit bw://-Vorschlägen
# → gibt Werte auf stderr aus für manuelle Eingabe in Vaultwarden

# 2. Einträge manuell in Vaultwarden anlegen (Web-UI oder bw create)
# 3. Referenzen prüfen:
env-run check .env.template

# 4. Befehl mit aufgelösten Secrets ausführen:
env-run -- uvicorn app.main:app --port 8000
env-run --env-file config/.env.prod.template -- ./scripts/deploy.sh

# Schneller bei vielen Secrets:
env-run --serve -- python scripts/seed.py

# Was würde gesetzt? (ohne Werte)
env-run --dry-run -- env
```

### Was es bewusst NICHT tut

Schreibt **nichts** in Vaultwarden — das bleibt bewusst manuell. Kein automatisches
Rotieren von Secrets. Kein Löschen der Original-`.env` (bleibt als Backup bis manuell
geprüft und gelöscht).

Vollständige Anleitung: [08-SECRETS.md](../08-SECRETS.md)

---

## 10. Aktualitäts-Check: `up2date`

### Problem

Installierte Werkzeuge driften gegenüber Upstream — neue Versionen erscheinen, manche
werden deprecated. Ohne regelmäßigen Check veraltert die Registry still.

### Was das Kommando tut

Prüft jeden `active`/`candidate`-Eintrag in `manifests/tools.yaml` gegen Upstream
(brew, npm, GitHub API, mas, Ollama Registry). Meldet vier Kategorien:
Update verfügbar, Sunset-Kandidat, Aufnahme-Kandidat, Review fällig.

Schreibt gefundene Versions-Updates mit `--apply-versions` in die Registry zurück.
Prüft mit `--consistency` ob Registry und Umsetzungslisten (Brewfile etc.) konsistent sind.

### Aufruf

```bash
up2date                          # Prüft alle active/candidate-Einträge
up2date --consistency --offline  # Nur Konsistenz, kein Netzwerk
up2date --apply-versions         # Versions-Updates in tools.yaml schreiben
up2date check --json --markdown  # Maschinenlesbare Ausgabe für CI
```

### Zeitplan (launchd)

`dev.kickoff.up2date`: wöchentlich Montag 08:00 — via `up2date.yml` als GitHub Action.
Öffnet PR für Versions-Updates und Issue für Sunset-Kandidaten.

### Was es bewusst NICHT tut

Installiert und deinstalliert nichts. Ändert keinen `status`-Wert.
Vollständige Dokumentation: [07-AKTUALITAET.md](07-AKTUALITAET.md)

---

## 11. Statusmaschine: `sunset`

### Problem

Ohne formalisierte Stillegung bleiben veraltete Werkzeuge still in der Registry und
in den Umsetzungslisten — unsichtbar installiert, nicht gepflegt.

### Was das Kommando tut

Dokumentiert Statusübergänge in `manifests/tools.yaml` und schreibt den Beschluss
in `CHANGELOG.md`. Nie automatisch — jeder Schritt ist ein menschlicher Befehl.

### Aufruf

```bash
sunset propose <id> --reason "Warum"  # deprecated, Karenzzeit 90 Tage
sunset confirm <id>                    # sunset (nach Karenzzeit)
sunset revive <id> --reason "Warum"   # Reaktivierung
sunset adopt <id>                      # candidate → active
sunset list --due                      # Fällige Sunsets anzeigen
```

### Was es bewusst NICHT tut

Deinstalliert nichts. Entfernt keinen Eintrag aus der Registry.
Vollständige Dokumentation: [07-AKTUALITAET.md](07-AKTUALITAET.md)

---

## 12. Migrations-Abgleich: `migration-diff`

### Problem

Nach einem Maschinenumzug fehlt ein systematischer Abgleich: Was war auf der alten
Maschine, was fehlt noch auf der neuen?

### Was das Kommando tut

Vergleicht `local/status-quo/<DATUM>/profile.json` (Export der alten Maschine) mit
dem aktuellen Zustand der neuen Maschine. Gibt für jeden offenen Punkt den konkreten
Nachinstallations-Befehl aus. Exit-Code 1 wenn offene Positionen vorhanden.

### Aufruf

```bash
migration-diff                   # Interaktiver Abgleich
migration-diff --markdown        # Report nach local/migration-diff.md schreiben
```

### Was es bewusst NICHT tut

Installiert nichts. Entscheidet nicht, was übernommen werden soll.
Vollständige Dokumentation: [09-UMZUG.md](09-UMZUG.md)

---

## Installation

### Schritt 1: Brewfile.automation installieren

```bash
cd ~/dev/kickoff-ai
brew bundle --file=Brewfile.automation
```

### Schritt 2: automation/bin/ in den PATH

```bash
# In ~/.zshrc ergänzen (oder über bootstrap.sh):
export PATH="$HOME/dev/kickoff-ai/automation/bin:$PATH"

# Sofort aktivieren:
source ~/.zshrc
```

### Schritt 3: Launchd-Jobs installieren (optional)

```bash
cd ~/dev/kickoff-ai
bash automation/launchd/install-launchd.sh --dry-run  # Erst prüfen
bash automation/launchd/install-launchd.sh            # Dann installieren

# Status prüfen:
launchctl list | grep dev.kickoff
```

### Launchd-Jobs deaktivieren / einzelne Jobs abschalten

```bash
# Alle deinstallieren:
bash automation/launchd/uninstall-launchd.sh

# Einzelnen Job deaktivieren:
launchctl bootout gui/$(id -u)/dev.kickoff.db-backup
# oder:
launchctl unload ~/Library/LaunchAgents/dev.kickoff.db-backup.plist
```

### Wo liegen die Logs?

```bash
ls ~/Library/Logs/kickoff/

# Einzelnen Log verfolgen:
tail -f ~/Library/Logs/kickoff/db-backup.log
```

---

## Log-Übersicht

| Job | Log | Zeitplan |
|---|---|---|
| dev-down-idle | `~/Library/Logs/kickoff/dev-down-idle.log` | täglich 02:30 |
| db-backup | `~/Library/Logs/kickoff/db-backup.log` | täglich 03:00 |
| secret-sweep | `~/Library/Logs/kickoff/secret-sweep.log` | wöchentl. Mi 04:00 |
| doctor | `~/Library/Logs/kickoff/doctor.log` | wöchentl. Mo 08:00 |
| mac-update | `~/Library/Logs/kickoff/mac-update.log` | wöchentl. So 09:00 |
| mac-clean | `~/Library/Logs/kickoff/mac-clean.log` | wöchentl. Sa 10:00 |

---

## Bewusst NICHT automatisiert

Diese Aktionen wurden bewusst aus dem Automatismus herausgelassen:

| Aktion | Begründung |
|---|---|
| **Werte nach Vaultwarden schreiben** | Erfordert manuelles Review; `env-run migrate` liefert nur Vorschläge |
| **Repo-Dateien überschreiben** (mac-snapshot) | Drift kann gewollte Abweichung sein; manuelles Review Pflicht |
| **Docker-Volumes löschen** | Datenverlust-Risiko; nur mit expliziter Bestätigung |
| **node_modules löschen** | Zu viele Abhängigkeiten; `repo-sweep` listet nur |
| **Git-History bereinigen** | Destruktiv und repo-spezifisch; BFG/git-filter-repo manuell |
| **Auth-Vorgänge** (GitHub, `bw login`, `bw unlock`) | Erfordert interaktiven Kontext |
| **macOS System-Updates** | `softwareupdate` erfordert Neustart; nicht unbeaufsichtigt |
| **conda-Environments löschen** | `notebooklm`-Env könnte aktiv sein; nur Caches bereinigen |
| **Ollama-Modelle löschen** | Herunterladung kann Stunden dauern; nur in `ollama-sync` melden |
| **Statusänderungen in der Registry** | Jede Deprecated/Sunset-Entscheidung ist menschlich |
