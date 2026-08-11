# Sanitisierungsregeln — Was in öffentlichen Dateien stehen darf

> [English](../05-SANITIZATION.md)

Dieses Repo ist öffentlich veröffentlicht. Bevor du `git push` ausführst, prüfe diese Checkliste.

---

## Was nie in öffentliche Dateien gehört

### Identifizierende Informationen

| Was | Stattdessen |
|---|---|
| Benutzername in Pfaden (`/Users/<name>/`) | `~` oder `$HOME` |
| E-Mail-Adressen | `<deine@email.com>` oder weglassen |
| GitHub-Kontonamen | `<dein-github-username>`, `<zweiter-account>` |
| SSH-Key-Dateinamen mit Hinweis auf Herkunft | `~/.ssh/id_ed25519` (generisch) |
| Hostnamen der Maschine | weglassen |
| Lokale IP-Adressen | weglassen oder `127.0.0.1` |

### Projekt-Namen

| Was | Stattdessen |
|---|---|
| Private Kundenprojekte | "ein Kundenprojekt", "ein Web-Projekt", "ein SaaS-Projekt" |
| Private Repos (persönliche Websites, Buchmanuskripte, Freelance-Projekte) | weglassen oder aggregiert beschreiben |
| Open-Source-Klone und -Forks | dürfen beim echten Namen genannt werden (langfuse, Scrapling, Anki-Android, screenshot-to-code) |

**Faustregel:** Muster ja, Identität nein. Der Lernwert liegt im Muster.

### Secrets und Credentials

| Was | Nie vorkommen |
|---|---|
| API-Keys | Nie in Markdown, Code oder Config-Dateien |
| Passwörter | Nie |
| Tokens (GitHub PAT, Telegram-Bot-Token, Webhook-URLs) | Nie |
| Private SSH-Keys | Nie |
| Datenbankverbindungsstrings mit Passwort | Nie |

---

## Was erlaubt ist

- Hardware-Specs (M2 Max, 32 GB RAM, macOS-Version) — unkritisch, für Leser nützlich
- Versionsnummern von installierten Tools
- Aggregierte Statistiken über Repos ("36 von 58 Repos mit package.json")
- Stack-Entscheidungen und Begründungen
- Fehlermuster als allgemeine Muster ("ein Alias zeigt auf ein nicht existierendes Verzeichnis")

**Bewusst freigegebene Ausnahme:** Die Repo-URL `github.com/leonkoellerwirth-arch/kickoff-ai`
enthält zwangsläufig den GitHub-Kontonamen und muss im Repo stehen — ohne sie funktioniert
der `prepare.sh`-Einzeiler auf einer nackten Maschine nicht. Sie ist explizit in der
Ausnahmeliste (`.github/sanitize-allowlist.txt`) freigegeben.

---

## Wie der Scan funktioniert

Der `validate`-Workflow (`.github/workflows/validate.yml`, Schritt „Sanitisierungs-Scan")
prüft alle Textdateien des Repos mit einem zweistufigen System:

### Sperrliste (Denylist)

Zwei Dateien definieren verbotene Muster (eine reguläre Ausdrucks-Regex pro Zeile):

- **`.github/sanitize-denylist.txt`** — öffentlich, Kern-Muster (feste Regeln für
  `/Users/`, E-Mail-Adressen, GitHub-Tokens, SSH-Private-Keys, AWS-Keys)
- **`local/sanitize-denylist-private.txt`** — gitignoriert, optionale Erweiterung für
  private Begriffe (Kundennamen, private Projektnamen)

```bash
# Eigene private Begriffe hinzufügen (gitignoriert):
mkdir -p local
cat > local/sanitize-denylist-private.txt <<'EOF'
# Eigene private Begriffe (Regex, eine pro Zeile)
MeinKundenname
mein-privates-projekt
EOF
```

### Ausnahmeliste (Allowlist)

Manche Zeilen müssen ein Sperrlisten-Muster enthalten — die Ausnahmeliste verhindert
falsche Positive, ohne den Schutz überall sonst aufzuweichen:

- **`.github/sanitize-allowlist.txt`** — öffentlich, dokumentiert (inkl. die Repo-URL)
- **`local/sanitize-allowlist-private.txt`** — gitignoriert, optionale private Ausnahmen

```bash
# Private Ausnahme hinzufügen (z. B. für einen Alias der zufällig wie eine E-Mail aussieht):
cat >> local/sanitize-allowlist-private.txt <<'EOF'
# Zeilen die dieses Muster enthalten, nicht als Treffer werten
mein-spezieller-ausdruck
EOF
```

### Zeilenweise Prüfung

Der Scan arbeitet **zeilenweise**, nicht dateiweise. Das erlaubt feingranulare Ausnahmen:
eine einzelne Zeile (z. B. die Clone-URL) kann freigegeben werden, ohne die gesamte
Datei aus dem Scan herauszunehmen. Eine Fundzeile gilt als erlaubt, wenn sie auf
ein Muster in einer der Ausnahmelisten passt.

---

## Wo maschinenspezifische Rohdaten liegen

```
local/                     ← in .gitignore, wird nie gepusht
  inventory/               ← rohe Inventar-Ausgaben (brew list, docker ps, etc.)
  overrides/               ← maschinenspezifische Konfigurationsübersteuerungen
  notes/                   ← private Notizen zum Setup
```

Das `local/`-Verzeichnis ist in `.gitignore` eingetragen und existiert nur lokal. Wenn du
Inventar-Daten für Debugging brauchst, lege sie dort ab.

---

## Checkliste vor `git push`

```bash
# Nach Secrets suchen
gitleaks detect --source . --no-git

# Benutzernamen in Pfaden suchen
grep -r "/Users/" docs/ README.md

# E-Mail-Adressen suchen
grep -rE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' docs/ README.md

# GitHub-Kontonamen suchen (anpassen auf deine echten Namen)
grep -ri "<dein-echter-username>" docs/ README.md

# Dann push
git push
```

Der CI-Workflow führt den vollständigen Scan bei jedem Push automatisch durch.
Die manuelle Checkliste ist ein schneller Vorab-Check im Terminal.

---

## Warum dieser Aufwand

Dieses Repo soll für andere nützlich sein — als Referenz, nicht als Dossier über eine
Person. Anonymisierung schützt Privatsphäre und fokussiert den Lernwert: wer das Setup
adaptiert, interessiert sich für das Muster, nicht für den Namen der zugehörigen Person
oder ihrer Kunden.
