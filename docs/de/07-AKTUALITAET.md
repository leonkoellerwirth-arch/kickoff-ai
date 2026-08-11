# 07 — Das Aktualitäts-System

> [English](../07-CURRENCY.md)

Ein Setup-Repo ist am Tag der Erstellung korrekt. Danach nicht mehr.

Werkzeuge ziehen weiter: neue Versionen erscheinen, manche werden deprecated,
neue kommen dazu die es damals noch nicht gab. Ohne ein System das diesen Drift
sichtbar macht und dokumentiert, ist die Repo in einem Jahr wertlos.

---

## Das Problem

```
Tag 0:   tools.yaml ← korrekt ← machine state
Tag 90:  tools.yaml ← ?       ← machine state (16 Updates, 2 deprecated)
Tag 365: tools.yaml ← falsch  ← machine state (irrelevant geworden)
```

Drei konkrete Konsequenzen:
1. Neue Maschinen werden mit veralteten Versionen aufgesetzt.
2. Werkzeuge die upstream deprecated oder archiviert wurden, bleiben unsichtbar installiert.
3. Das Repo verliert seinen Wert als Referenz.

---

## Die Antwort in vier Teilen

```
manifests/tools.yaml          ← 1. Registry: Einzige Wahrheit
        ↓
automation/bin/up2date        ← 2. Prüfer: liest Upstream, meldet Drift
        ↓
automation/bin/sunset         ← 3. Statusmaschine: dokumentiert Beschlüsse
        ↓
.github/workflows/            ← 4. CI: hält alles dauerhaft am Leben
```

### 1. Registry: `manifests/tools.yaml`

Die einzige Wahrheit über alle Werkzeuge dieses Setups. Schema: [manifests/schema.md](../../manifests/schema.md).

Jeder Eintrag hat:
- Eine klare Herkunft (`source`, `ref`)
- Einen ehrlichen Status (`candidate → active → deprecated → sunset`)
- Eine Begründung (`why`) — kein leeres Pflichtfeld
- Eine Versions-Prüfmethode (`version_check`, `check_ref`)

Die Umsetzungslisten (Brewfile, ollama-models.txt etc.) sind die **Ausführung**;
`tools.yaml` ist die **Entscheidung**. Beides muss übereinstimmen — CI prüft das.

### 2. Prüfer: `automation/bin/up2date`

Read-only gegenüber dem System. Prüft jeden active/candidate-Eintrag gegen Upstream
und meldet vier Kategorien:

| Kategorie | Was | Quelle des Signals |
|---|---|---|
| **Update verfügbar** | Upstream-Version > version_seen | brew/npm/GitHub API |
| **Sunset-Kandidat** | Upstream deprecated/disabled/archived | brew deprecated-Flag, npm deprecated-Feld, GitHub archived |
| **Aufnahme-Kandidat** | Lokal installiert, nicht in Registry | brew leaves, npm ls -g (nur lokal) |
| **Review fällig** | reviewed älter als 180 Tage | Registry-Feld |

Wichtig: Der Prüfer **installiert und deinstalliert nichts**. Er nennt den konkreten
Befehl für den nächsten Schritt — ausführen muss ihn der Mensch.

### 3. Statusmaschine: `automation/bin/sunset`

```
candidate ──► active ──► deprecated ──► sunset ──► (Eintrag entfernt)
    └──────── adopt ──┘     ↑ propose    ↑ confirm      ↑ manuell
                            └─── revive ─┘
                                  ↑
                               revive
```

- `propose`: Startet 90-Tage-Karenzzeit. Schreibt in CHANGELOG.
- `confirm`: Bestätigt Sunset nach Ablauf der Karenzzeit. Schreibt in CHANGELOG.
- `revive`: Reaktiviert. Begründung Pflicht. Schreibt in CHANGELOG.
- `adopt`: Übernimmt `candidate` in `active`.

**Jede Statusänderung ist eine menschliche Entscheidung** — nie automatisch.
Der Workflow macht sichtbar was fällig ist; der Mensch entscheidet.

### 4. CI: `.github/workflows/`

| Workflow | Auslöser | Was es tut |
|---|---|---|
| `validate.yml` | Push, PR | Shell-Syntax, ShellCheck, Sanitisierung, YAML-Schema, Konsistenz-Check |
| `up2date.yml` | Montag 08:00 UTC | Upstream-Check, PR für Versions-Updates, Issue für Befunde |
| `release.yml` | Tag v* | Validate, Release-Notes aus CHANGELOG, GitHub-Release |

---

## Der wöchentliche Zyklus

```
Montag 08:00 UTC
    ↓
up2date.yml startet
    ↓
automation/bin/up2date check --json --markdown
    ↓
automation/bin/up2date --apply-versions
    ↓
tools.yaml geändert?
    ├─ ja  → PR: "chore/up2date-<run-id>" (nur version_seen, reviewed, STATE.json)
    └─ nein → kein PR
    ↓
Sunset-Kandidaten oder Review-Fälligkeiten?
    ├─ ja  → Issue erstellen/aktualisieren (Titel konstant → kein Duplikat)
    └─ nein → kein Issue
    ↓
Mensch erhält:
    ├─ PR zum Mergen (Versions-Update) — kein Status geändert
    └─ Issue mit Befehlsvorschlägen — Entscheidung beim Mensch
```

**Was als PR kommt:** Nur `version_seen`, `reviewed`, `STATE.json`. Niemals `status`.

**Was als Issue kommt:** Liste der Sunset-Kandidaten und Review-Fälligkeiten,
mit dem jeweils vorgeschlagenen `sunset propose`- oder `sunset adopt`-Befehl.
Die Ausführung bleibt beim Menschen.

**Was nie automatisch passiert:** Statusänderungen, Installation, Deinstallation.

---

## Werkzeug aufnehmen

```bash
# 1. Eintrag in manifests/tools.yaml anlegen (status: candidate)
# 2. Umsetzungsliste ergänzen (Brewfile, ollama-models.txt, etc.)
# 3. Konsistenz prüfen
automation/bin/up2date --consistency --offline

# 4. Nach Evaluation: aufnehmen
automation/bin/sunset adopt <id>

# 5. Prüfen ob PR nötig
git diff manifests/tools.yaml
```

---

## Werkzeug stilllegen

```bash
# Phase 1: Stillegung vorschlagen (heute + 90 Tage)
automation/bin/sunset propose <id> --reason "Warum" [--replaced-by <nachfolger-id>]

# Zwischenzeit: tool bleibt installiert, im Review-Status
automation/bin/sunset list --due         # Wer ist fällig?

# Phase 2: Nach 90 Tagen — Sunset bestätigen
automation/bin/sunset confirm <id>

# Phase 3: Software entfernen (bewusster dritter Schritt)
./scripts/90-cleanup-legacy.sh  # oder jeweiliges Modul-Skript

# Phase 4: Eintrag aus Registry entfernen + CHANGELOG ergänzen
# → Zeile in tools.yaml löschen, unter [Unreleased] / Removed eintragen
```

### Integration mit `scripts/90-cleanup-legacy.sh`

Das Skript entfernt heute **hardkodiert** OpenClaw und den verwaisten MariaDB-LaunchAgent.
Die Registry (`tools.yaml`) hat beide Einträge als `status: sunset` dokumentiert.

**Geplante, aber bewusst noch nicht umgesetzte Integration:**
In einer zukünftigen Version würde `90-cleanup-legacy.sh` die `sunset`-Einträge aus
`tools.yaml` dynamisch lesen. Die Werkzeug-IDs im Skript wären dann nicht mehr hardkodiert,
sondern kämen aus der Registry. Diese Integration wird **nicht** automatisch umgesetzt,
weil Deinstallation immer eine explizite menschliche Entscheidung bleiben soll.

---

## Versionierung des Repos

Format: Semantic Versioning (SemVer, Start: `0.1.0`).
Changelog: Keep a Changelog (Kategorien: Added / Changed / Deprecated / Removed / Fixed).

| Änderungsart | Version |
|---|---|
| Setup nicht mehr abwärtskompatibel reproduzierbar (Stufenschnitt geändert, Modul entfernt) | MAJOR |
| Werkzeug aufgenommen oder Modul ergänzt (neues Skript, neue Kategorie) | MINOR |
| Versionen nachgezogen, Dokumentation, Bugfixes, Konsistenz | PATCH |

Release-Workflow:
```bash
# CHANGELOG.md: [Unreleased] → [0.2.0] — YYYY-MM-DD
# VERSION aktualisieren
echo "0.2.0" > VERSION

git add CHANGELOG.md VERSION
git commit -m "chore: Release 0.2.0"
git tag v0.2.0
git push origin main v0.2.0
# → release.yml übernimmt den Rest
```

---

## Prüfmethoden nach Quelle

| Quelle | Methode | Automatisch? | Anmerkung |
|---|---|---|---|
| `brew` (Formula) | `brew info --json=v2` | ja | Erkennt deprecated/disabled-Flag |
| `brew` (Cask) | `brew info --json=v2` | ja | Versionsnummer, kein deprecated-Flag |
| `npm` | `npm view <pkg> version` + `deprecated` | ja | deprecated-Feld = Sunset-Kandidat |
| `github-release` | GitHub Releases API | ja | archived=true = Sunset; `GITHUB_TOKEN` für Rate-Limit |
| `mas` | `mas info` + `mas outdated` | ja | Nur wenn mas installiert |
| `ollama` | Ollama Registry API | best effort | Kein stabiles Versions-Format; meldet `unknown` statt zu raten |
| `manual` | Nicht prüfbar | nein | Prüfung anhand `reviewed`-Alter (>180 Tage = Review fällig) |
| `curl`-installiert | via `version_check` = github-release/manual | je nach Tool | Fallback: github-release wenn Projekt auf GitHub |
| `uv`-Tool | `pip index versions` | manuell | uv-Tool-Versionen: `uv tool list`; Upstream-Version via PyPI |
| Ollama-Modelle | Ollama Registry | best effort | Modell-Tags ändern sich selten; `unknown` bei Fehlern |

### Fälle die nur `manual` gehen

- Desktop-Apps ohne Update-API (einige Casks)
- LaunchAgents und System-Konfiguration
- Werkzeuge aus privaten Quellen
- Ollama-Modelle mit unklarem Versionierungsschema
- Builtin-Tools (Xcode-Teile, Swift-Compiler via Xcode)

---

## Grenzen (was bewusst nicht automatisch passiert)

| Was | Warum |
|---|---|
| **Statusänderungen** | Jede Deprecated/Sunset-Entscheidung ist eine menschliche Abwägung |
| **Installation** | Neue Versionen werden gemeldet, nicht eingespielt; Installation ist ein Regressions-Risiko |
| **Deinstallation** | Entfernen von Software kann laufende Projekte brechen; immer explizit |
| **Secrets in CI** | Keine Tokens in der Registry; `GITHUB_TOKEN` ist automatisch vorhanden |
| **Extensions-Versionen** | VS-Code-Extensions haben kein stabiles Versionsschema in der Registry; Umsetzung über `config/vscode-extensions.txt` |

---

## Sperr- und Ausnahmeliste für Sanitisierung

Der `validate.yml`-Workflow verwendet zwei Datei-Paare für den Sanitisierungs-Scan:

**Sperrliste (Denylist):**
- `.github/sanitize-denylist.txt` (öffentlich, Kern-Muster)
- `local/sanitize-denylist-private.txt` (gitignoriert, eigene private Begriffe)

**Ausnahmeliste (Allowlist):**
- `.github/sanitize-allowlist.txt` (öffentlich, dokumentierte Ausnahmen inkl. Repo-URL)
- `local/sanitize-allowlist-private.txt` (gitignoriert, eigene private Ausnahmen)

```bash
# Private Sperrliste anlegen (gitignoriert):
mkdir -p local
cat > local/sanitize-denylist-private.txt <<'EOF'
# Eigene private Begriffe (Regex, eine pro Zeile)
MeinKundenname
mein-privates-projekt
EOF

# Private Ausnahmeliste anlegen (gitignoriert):
cat > local/sanitize-allowlist-private.txt <<'EOF'
# Zeilen die auf dieses Muster passen, nicht als Treffer werten
mein-spezieller-erlaubter-ausdruck
EOF
```

Vollständige Beschreibung des Scan-Mechanismus: [05-SANITISIERUNG.md](05-SANITISIERUNG.md)
