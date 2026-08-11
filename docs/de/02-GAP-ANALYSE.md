# Gap-Analyse — Ehrlicher Blick auf das Setup

> ⚠️ Archivierte deutsche Fassung — maßgeblich ist die englische Version unter [`../02-GAP-ANALYSIS.md`](../02-GAP-ANALYSIS.md). Diese Datei wird nicht mehr aktualisiert.

Dieses Dokument hat zwei Teile:

- **Teil A:** Konkrete, belegte Defekte im Ist-Setup — was kaputt ist oder suboptimal funktioniert.
- **Teil B:** Was professionelle KI-Entwickler mit ähnlichem Profil tun, das hier fehlt.

Am Ende: eine priorisierte Top-10-Liste — was bringt am meisten pro Stunde.

Die Befunde sind so formuliert, dass sie auf jede ähnlich gewachsene Maschine übertragbar sind — als Muster, nicht als persönliche Charakterisierung.

---

## Teil A — Konkrete Defekte im Ist-Setup

### A.1 — Legacy-Agenten-Gateway: vollständig deinstallieren

**Befund:** Eine Agenten-Gateway-Software (OpenClaw) ist dreifach registriert: als npm-Global-Package, als pnpm-Global-Link, und als LaunchAgent. Eine Umgebungsvariable `OPENCLAW_PATH` zeigt auf ein Verzeichnis (`~/dev/openclaw`) das **nicht mehr existiert**. Vier Shell-Aliase und zwei Completion-Blöcke in `.zshrc` laufen damit ins Leere. Der pnpm-Global-Link verweist auf denselben nicht existierenden Pfad.

Prüfbefehl:
```bash
ls ~/dev/openclaw 2>&1   # "No such file or directory"
npm list -g --depth=0 | grep openclaw
pnpm list -g | grep openclaw
cat ~/.zshrc | grep -n OPENCLAW
launchctl list | grep openclaw
```

**Auswirkung:** Jeder Shell-Start generiert potenziell stille Fehler. `pnpm` führt einen Link-Aufruf auf einen toten Pfad aus. Der LaunchAgent versucht bei jedem Login den Gateway zu starten — schlägt fehl.

**Fix:** `scripts/90-cleanup-legacy.sh` (opt-in, nicht Teil von `bootstrap.sh`) räumt vollständig auf. Vorher sichern:

Was zu entfernen ist:
- `npm uninstall -g openclaw clawhub`
- `pnpm remove -g openclaw`
- `launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist` + Datei löschen
- `rm -rf ~/.openclaw` — **aber erst nach Backup von `~/.openclaw/credentials/` und `~/.openclaw/telegram/` in 1Password**
- `brew untap openclaw/tap` (enthält auch das `goplaces`-Formula)
- In `.zshrc`: `OPENCLAW_PATH`, vier Aliase (`openclaw`, `openclaw-gateway`, `wakeup-clawy`, `clawrestart`), zwei Completion-Blöcke

**Priorität:** Hoch — sofort erledigen. Das Skript `scripts/90-cleanup-legacy.sh` tut das automatisch mit Backup.

---

### A.2 — Umgebungsvariable zeigt auf nicht existierendes Verzeichnis (M2_HOME)

**Befund:** `M2_HOME=$HOME/dev/maven` ist in `.zshrc` gesetzt. Das Verzeichnis existiert nicht — Maven läuft aus dem Homebrew-Prefix (`/opt/homebrew/bin/mvn`). `M2_HOME` ist auch für aktuelles Maven nicht mehr notwendig; der Wert wurde historisch für Maven-2-Projekte benötigt.

Prüfbefehl:
```bash
echo $M2_HOME && ls $M2_HOME 2>&1
mvn --version   # zeigt korrekt auf brew-maven
```

**Fix:** `M2_HOME`-Zeile aus `.zshrc` entfernen.
**Priorität:** Niedrig — kein akuter Schaden, nur Konfigurationsrauschen.

---

### A.3 — Framework-Completion für nicht installiertes Tool

**Befund:** `source <(ng completion script)` in `.zshrc` lädt die Angular-CLI-Completion. Angular CLI ist nicht installiert. Der Befehl schlägt still fehl (wird suppressed) aber verlangsamt den Shell-Start und ist irreführend für alle die die `.zshrc` lesen.

Prüfbefehl:
```bash
which ng 2>&1   # "ng not found"
```

**Fix:** Zeile aus `.zshrc` entfernen. Falls Angular später gebraucht wird: `npm install -g @angular/cli` und dann die Completion-Zeile wieder hinzufügen.
**Priorität:** Niedrig.

---

### A.4 — PATH-Duplikate und doppelte Dotfile-Einträge

**Befund:** Mehrere Shell-Dateien produzieren doppelte Einträge:
- `/usr/local/bin` erscheint mehrfach im PATH
- `/usr/bin` erscheint mehrfach im PATH
- `.local/bin` erscheint mehrfach im PATH (einmal in `.profile`, einmal in `.zshrc`)
- VS-Code-PATH-Block in `.zprofile` doppelt
- OpenClaw-Completion-Block in `.zshrc` doppelt

Prüfbefehl:
```bash
echo $PATH | tr ':' '\n' | sort | uniq -d
```

**Auswirkung:** PATH wird länger als nötig, Shell-Start langsamer, Debugging schwieriger.

**Fix:** `config/zshrc` aus diesem Repo verwenden — nutzt `typeset -U path` für automatische Deduplizierung. `config/zprofile` enthält VS-Code-PATH nur einmal.
**Priorität:** Mittel.

---

### A.5 — System-git gewinnt gegen Homebrew-git

**Befund:** `/usr/bin/git` (Apple CLT-Version) liegt in der PATH-Reihenfolge vor `/opt/homebrew/bin/git` (aktuellste git-Version). Das bedeutet: `which git` zeigt `/usr/bin/git`, und Features neuerer git-Versionen stehen nicht zur Verfügung. `git-lfs` und bestimmte Hooks können ebenfalls betroffen sein.

Prüfbefehl:
```bash
which git          # zeigt /usr/bin/git statt /opt/homebrew/bin/git
git --version      # zeigt Apple-Version (niedriger)
/opt/homebrew/bin/git --version   # zeigt brew-Version
```

**Fix:** `/opt/homebrew/bin` in der `.zshrc` vor `/usr/bin` in den PATH eintragen — das tut `config/zshrc` bereits.
**Priorität:** Mittel.

---

### A.6 — conda-base Anti-Pattern

**Befund:** `python3` in der Shell zeigt auf conda-base 3.10.9. Die conda-base-Umgebung enthält Pakete aus verschiedenen, nicht zusammenhängenden Projekten (maschinelles Lernen, wissenschaftliche Berechnung, Web-Scraping, Lernkarten-Software). conda selbst ist in Version 22.11.1 — zwei Major-Versionen veraltet (Stand 2026: 25.x).

Prüfbefehl:
```bash
python3 --version      # zeigt 3.10.9 statt brew-Python oder uv-verwaltetes Python
conda --version        # 22.11.1 vs. aktuell 25.x
conda list | wc -l     # zeigt die Anzahl installierter Pakete in base
which python3          # ~/miniforge3/bin/python3 statt /opt/homebrew/bin/python3
```

**Auswirkung:** Projektisolation ist faktisch nicht gegeben wenn `python3` global auf conda-base zeigt. Neu aufgesetzte Projekte erben unkontrolliert Pakete aus der base-Umgebung.

**Fix:** `config/zshrc` aktiviert conda-base nicht automatisch. `python3` zeigt dann auf Homebrew-Python oder wird per `uv python` projektisoliert verwaltet. `conda activate <env>` funktioniert weiter explizit. conda-base **nicht löschen** — bestehende Envs (`notebooklm` u. a.) bleiben erhalten.
**Priorität:** Hoch.

---

### A.7 — pre-commit installiert die Konfiguration, aber das Tool fehlt

**Befund:** `dev/base` enthält eine `.pre-commit-config.yaml` (mit gitleaks-Hook und weiteren Checks) und eine `.gitleaks.toml`. Das Tool `pre-commit` selbst ist auf der Maschine **nicht installiert** — weder via pip, pipx, noch brew. Die Hooks laufen daher nie.

Prüfbefehl:
```bash
pre-commit --version 2>&1   # "command not found"
ls ~/dev/base/.pre-commit-config.yaml   # Datei existiert
```

**Auswirkung:** Secret-Scanning und Code-Quality-Checks laufen bei keinem Commit. Das zentrale Sicherheitsnetz von `dev/base` ist unwirksam.

**Fix:**
```bash
brew install pre-commit
cd ~/dev/base && pre-commit install --install-hooks
```

Das Skript `scripts/02-homebrew.sh` installiert `pre-commit` ab jetzt als Pflichtpaket im `Brewfile`. `scripts/08-git-ssh.sh` führt `pre-commit install` in `dev/base` aus.
**Priorität:** Hoch — sofort.

---

### A.8 — Globale .gitignore leer und nicht registriert

**Befund:** `~/.gitignore_global` existiert, ist aber leer (0 Bytes). Außerdem ist sie nicht als `core.excludesfile` in der globalen git-Konfiguration registriert — sie wird von git also ignoriert.

Prüfbefehl:
```bash
git config --global core.excludesfile   # leer oder nicht gesetzt
wc -c ~/.gitignore_global               # 0 Bytes
```

**Auswirkung:** `.DS_Store`, `.env`, `node_modules`, `__pycache__`, `.idea`, `.vscode/` und andere systemspezifische Dateien werden nicht global ignoriert. Sie müssen in jedem einzelnen Repo-`.gitignore` eingetragen werden — oder landen versehentlich im Repo.

**Fix:** `config/gitignore_global` aus diesem Repo enthält sinnvolle globale Ignores. `scripts/08-git-ssh.sh` registriert sie:
```bash
git config --global core.excludesfile ~/.gitignore_global
```
**Priorität:** Hoch.

---

### A.9 — Veralteter SSH-Key-Typ, keine Commit-Signierung

**Befund:** Es gibt nur einen SSH-Key, generiert 2024, im RSA-Format. Keine GPG-Keys (gnupg ist installiert, trust-DB war bis zum Scan leer). Commits sind nicht signiert (`commit.gpgsign` nicht gesetzt).

Prüfbefehl:
```bash
ls -la ~/.ssh/*.pub          # zeigt id_rsa_*.pub
ssh-keygen -l -f ~/.ssh/*.pub  # zeigt RSA
git config --global commit.gpgsign   # leer
gpg --list-keys              # keine Keys
```

**Auswirkung:** RSA ist nicht unsicher, aber ed25519 ist der aktuelle Standard. Ohne Commit-Signierung ist kein kryptografischer Nachweis möglich, dass Commits tatsächlich von dir kommen — das ist besonders bei öffentlichen Repos und GitHub-Beiträgen relevant.

**Fix:** `scripts/08-git-ssh.sh` generiert einen neuen ed25519-Key und konfiguriert SSH-Commit-Signierung (kein GPG — einfacher, gleiche Sicherheit für diesen Anwendungsfall).
**Priorität:** Mittel.

---

### A.10 — git maintenance zeigt auf nicht existierenden Pfad

**Befund:** `git config --global maintenance.repo` zeigt auf einen Pfad, der nicht mehr existiert (ein Unternehmens-Repo-Pfad aus einer früheren Konfiguration). git-maintenance läuft täglich/stündlich/wöchentlich via LaunchAgents (`org.git-scm.git.daily/hourly/weekly`) — und schlägt still fehl.

Prüfbefehl:
```bash
git config --global maintenance.repo   # zeigt Pfad der nicht existiert
ls <der-gezeigte-pfad> 2>&1           # "No such file or directory"
```

**Fix:**
```bash
git config --global --unset maintenance.repo
# Dann bei Bedarf neu einrichten:
git maintenance register   # im aktuellen Repo
```
**Priorität:** Niedrig.

---

### A.11 — Verwaister LaunchAgent für deinstalliertes Paket

**Befund:** `~/Library/LaunchAgents/homebrew.mxcl.mariadb.plist` existiert, obwohl MariaDB nicht mehr installiert ist. Der Agent versucht bei jedem Login MariaDB zu starten — schlägt fehl.

Prüfbefehl:
```bash
ls ~/Library/LaunchAgents/ | grep mariadb   # plist vorhanden
brew list | grep mariadb                     # leer
```

**Fix:** `scripts/90-cleanup-legacy.sh` entfernt diesen LaunchAgent.
```bash
launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.mariadb.plist
rm ~/Library/LaunchAgents/homebrew.mxcl.mariadb.plist
```
**Priorität:** Niedrig.

---

### A.12 — Ollama dreifach installiert

**Befund:** Ollama ist auf drei Wegen gleichzeitig vorhanden: als brew Formula (`ollama`), als brew Cask (`ollama-app`), und als laufender Docker-Container (im Kontext eines KI-Projekts). Alle drei laufen möglicherweise nebeneinander. Brew Formula und Cask sind verschiedene Dinge — das Cask ist eine native macOS-App mit GUI-Menüleistensymbol, die Formula ist ein CLI-Dienst.

Prüfbefehl:
```bash
brew list | grep ollama           # ollama (formula) UND ollama-app (cask)?
docker ps | grep ollama           # Container?
ls /Applications/Ollama.app 2>/dev/null
```

**Auswirkung:** Potenziell laufen zwei Ollama-Instanzen auf Port 11434 — Race Condition bei `ollama serve`. Der Docker-Container hat auf macOS keinen Metal-GPU-Zugriff und läuft CPU-only.

**Fix:** Nur die brew Formula behalten:
```bash
brew uninstall --cask ollama   # GUI-App entfernen
# Docker-Container stoppen und nicht mehr starten
```
Das Modul `scripts/07-ai-stack.sh` installiert nur die Formula.
**Priorität:** Mittel.

---

### A.13 — 16 Container laufen dauerhaft

**Befund:** Zum Messzeitpunkt liefen 16 Docker-Container, teils seit Wochen, darunter fünf MySQL-Instanzen für verschiedene Projekte. Nur ein Container lief im Status `exited`. Das Muster: Docker-Compose-Stacks für verschiedene Projekte wurden gestartet und nie gestoppt.

Prüfbefehl:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"
docker ps | wc -l   # Anzahl laufender Container
```

**Auswirkung:** Mehrere GB RAM dauerhaft belegt, unnötiger Energieverbrauch, Ports belegt die andere Dienste brauchen könnten.

**Fix:** Konvention einhalten: `docker compose up -d` vor der Arbeit, `docker compose down` danach. Kein Autostart für Projekt-Container.
```bash
# Sofort: alle nicht-persistenten Container stoppen
docker compose down   # in jedem Projektverzeichnis
# oder global:
docker stop $(docker ps -q)
```
**Priorität:** Mittel.

---

### A.14 — 96 % Speicherplatz belegt

**Befund:** Bei 926 GB SSD sind nur ~43 GB frei (96 % belegt). Die größten Blöcke sind Docker-Images und -Volumes, die conda-base-Installation mit hunderten Paketen, und Ollama-Modelle (~18 GB kumuliert).

Prüfbefehl:
```bash
df -h ~
docker system df          # Docker-Speicher
du -sh ~/miniforge3/      # conda
du -sh ~/.ollama/models/  # Ollama-Modelle
```

**Auswirkung:** macOS beginnt bei <10 % freiem Speicher mit Performance-Degradation. Neue Ollama-Modelle ziehen schlägt fehl. Docker-Builds könnten fehlschlagen.

**Fix (nach Priorität):**
```bash
docker system prune -a       # nicht genutzte Images, Volumes, Container (VORSICHT: prüfen was weg soll)
conda clean --all            # conda-Caches
brew cleanup --prune=30      # Homebrew-Caches
rm -rf ~/Library/Caches/     # macOS-App-Caches (selektiv)
```

Und strukturell: conda-base-Packages aus base entfernen (nur Basis-conda in base, Pakete in projektspezifische Envs), Docker-Volumes für abgeschlossene Projekte löschen.
**Priorität:** Hoch — sofort, bevor neue Modelle gezogen werden.

---

### A.15 — Sicherheitseinstellungen der KI-CLIs: zu weitreichend

**Befund:** Claude Code ist mit `skipDangerousModePermissionPrompt`, `skipAutoPermissionPrompt` und `defaultMode: auto` konfiguriert. Codex CLI hat `approval_mode = "full-auto"` gesetzt und vertraut 17 Projekten auf dem Niveau "trusted" — darunter das gesamte Home-Verzeichnis (`~`).

Das bedeutet: Claude Code und Codex können in diesen Verzeichnissen Dateien schreiben, löschen und Befehle ausführen, ohne Bestätigungsdialog.

Prüfbefehl:
```bash
jq '.skipDangerousModePermissionPrompt, .skipAutoPermissionPrompt' ~/.claude/settings.json
grep approval_mode ~/.codex/config.toml
grep -A2 'trust_level = "trusted"' ~/.codex/config.toml
```

**Auswirkung:** Bei einem schlechten Prompt, einem Missverständnis, oder einer Prompt-Injection aus verarbeiteten Dateien kann ein Agent destruktive Aktionen ausführen ohne Rückfrage. Das Risiko ist real — nicht theoretisch.

**Empfohlener Mittelweg:**
- Claude Code: `skipAutoPermissionPrompt` auf `false` setzen für alle `Bash`-Kommandos ausser den explizit erlaubten. Die explizite Allow-Liste bleibt (curl, npm test, git status, tsc). `skipDangerousModePermissionPrompt` auf `false`.
- Codex: `approval_mode = "suggest"` statt `full-auto`. Das Home-Verzeichnis (`~`) aus der trusted-Liste entfernen — nur konkrete Projektpfade.
- Beide: `Read(**/.env)` bleibt in der deny-Liste, das ist gut.

Der Kompromiss: etwas mehr Bestätigungsklicks, aber kein unbeaufsichtigter Schreibzugriff aufs gesamte Home.
**Priorität:** Hoch.

---

### A.16 — `~/dev/scripts` enthält keine Skripte

**Befund:** Ein Verzeichnis ist als `~/dev/scripts` benannt, enthält aber kein allgemeines Skript-Sammlung sondern Dateien eines spezifischen Projekts (Prosa-Dateien + projektspezifische Hilfsskripte). Shell-Aliase verweisen auf eine Datei (`media-tools.sh`) in diesem Verzeichnis — das funktioniert, aber der Verzeichnisname ist irreführend für alle die nach Setup-Skripten suchen.

Prüfbefehl:
```bash
ls ~/dev/scripts/    # keine Setup-Skripte, sondern Manuskript-Dateien
```

**Auswirkung:** Namensverwirrung. Jemand der `~/dev/scripts` durchsucht erwartet Skripte, findet ein Buchmanuskript.

**Fix:** Verzeichnis umbenennen zu `~/dev/<buchname>` oder `~/dev/writing/<buchname>`. Aliase in `.zshrc` anpassen.
**Priorität:** Niedrig.

---

### A.17 — Zwei GitHub-Accounts ohne klar definierte Trennungsregel

**Befund:** Zwei GitHub-Accounts sind über `gh` eingeloggt — einer als default, einer als sekundär. Die `.ssh/config` kennt nur einen SSH-Host-Block (für `github.com`). Es gibt keine dokumentierte Regel, welcher Account für welche Repos genutzt wird.

Prüfbefehl:
```bash
gh auth status          # zeigt beide Accounts
cat ~/.ssh/config       # zeigt ob github.com einen oder zwei Einträge hat
```

**Auswirkung:** Ohne klare Trennung kann `git push` unbeabsichtigt den falschen Account verwenden. CI-Secrets und Deployment-Keys können sich mischen.

**Fix:** Zwei SSH-Host-Aliase in `~/.ssh/config` (z. B. `github-primary` und `github-secondary`). Repos des sekundären Accounts klonen mit `git clone git@github-secondary:<org>/<repo>.git`. Bestehende Repos ggf. Remote-URL anpassen:
```bash
git remote set-url origin git@github-secondary:<org>/<repo>.git
```
**Priorität:** Mittel.

---

## Teil B — Was professionelle KI-Entwickler mit ähnlichem Profil tun, das hier fehlt

Das Profil: 36 Frontend-Repos (Vite/React/TypeScript/Tailwind + vitest), 10 Python-Services (FastAPI/Pydantic/pytest/ruff), LangChain/LangGraph + Anthropic/OpenAI/Ollama für KI, iOS-Apps, 2 weitere KI-Agenten-CLIs neben Claude Code, eigene "paved road" (`dev/base`), 58 Repos insgesamt.

---

### B.1 — Secrets-Management im Alltag: .env-Dateien liegen im Klartext

**Befund:** `.env`-Dateien liegen als Klartextdateien auf der Festplatte — mindestens
eine davon in `~/dev/` direkt (als Deploy-Env-Datei). Es gibt kein Secret-Backend das
die Werte von der Festplatte fernhält.

**Lösung:** Vaultwarden (selbstgehosteter Bitwarden-Server als Docker-Stack) und
`env-run` (Wrapper der `bw://`-Referenzen auflöst und Secrets ausschließlich in die
Prozessumgebung des Zielkommandos injiziert, nie als Datei oder in `ps`-Argumenten).

```bash
# Statt .env mit Klartextwerten:
env-run -- uvicorn app.main:app

# .env.template enthält nur Referenzen (kann ins Repo):
# OPENAI_API_KEY=bw://openai-api/password
# DATABASE_URL=bw://my-service/url
```

**Hebelwirkung:** Hoch — schützt vor versehentlichen Commits, AirDrop-Leaks,
und Shoulder-Surfing.

**Aufwand:** 3–5 Stunden (Vaultwarden-Stack aufsetzen + Secret-Migration).
Der Vaultwarden-Setup-Aufwand entfällt bei reiner 1Password-Nutzung, fällt hier aber
einmalig an. Migrationshilfe: `env-run migrate .env`.

Vollständige Anleitung: [docs/08-SECRETS.md](08-SECRETS.md)

---

### B.2 — Dotfiles als eigenes versioniertes Repo

**Befund:** Backups der Shell-Config existieren (`~/.zshrc_bkp`, `~/.zshrc.save`), aber kein Dotfiles-Repo. Die Konfiguration ist damit nur lokal versioniert und nicht auf einfache Weise auf einer neuen Maschine einsetzbar — das ist einer der Hauptgründe für dieses Setup-Repo.

**Optionen:**
- **GNU Stow** (symlink-basiert): einfach, transparent, weit verbreitet
- **Bare-Repo-Ansatz**: kein Hilfstool nötig, etwas mehr Konfigurationsaufwand
- **chezmoi**: fortgeschrittener, unterstützt verschlüsselte Secrets und Templates

**Hebelwirkung:** Mittel — dieses kickoff-ai-Repo löst das für neue Maschinen; ein Dotfiles-Repo würde *inkrementelle Änderungen* zwischen Setup-Läufen versionieren.
**Aufwand:** 2–4 Stunden initial.

---

### B.3 — Kein einheitliches Toolchain-Versioning (mise/asdf)

**Befund:** Node wird über nvm verwaltet, Python über uv + conda, Java über brew-openjdk. Kein einzelnes Tool kennt den gesamten Versionsstand. `.nvmrc` ist nur in 2 von 36 Frontend-Repos vorhanden.

**Was fehlt:** Ein Tool wie `mise` (Nachfolger von `asdf`) kann Node, Python, Java, Go, Rust in einer `.mise.toml` pro Repo versionieren:
```toml
[tools]
node = "24"
python = "3.13"
```

**Kontraindikation:** `mise` wäre ein zusätzliches Tool neben nvm+uv. Der richtige Zeitpunkt für die Migration ist ein Neuaufbau — nicht inkrementell. Die aktuelle Entscheidung (nvm+uv) ist dokumentiert in [04-ENTSCHEIDUNGEN.md](04-ENTSCHEIDUNGEN.md).

**Hebelwirkung:** Mittel — hauptsächlich für reproduzierbare Projektsetups relevant.
**Aufwand:** 1–2 Stunden Migration, dann ongoing-Pflege.

---

### B.4 — LLM-Observability: langfuse geklont aber nicht produktiv genutzt

**Befund:** `langfuse` ist als Repository unter `~/dev/` vorhanden (Fork/Clone). Es gibt keinen Hinweis darauf, dass es für eigene Projekte instrumentiert ist.

**Was fehlt:**
```python
# In FastAPI/LangChain-Projekten:
from langfuse.callback import CallbackHandler

handler = CallbackHandler(
    public_key=os.getenv("LANGFUSE_PUBLIC_KEY"),
    secret_key=os.getenv("LANGFUSE_SECRET_KEY"),
)
chain.invoke({"input": "..."}, config={"callbacks": [handler]})
```

Langfuse gibt pro LLM-Aufruf: Latenz, Token-Verbrauch, Modell, Input/Output — und aggregiert über Projekte.

**Hebelwirkung:** Hoch für KI-Projekte in Produktion. Du hast LangChain in 4 Repos und LangGraph in 2 — genau der Anwendungsfall.
**Aufwand:** 2–4 Stunden für Integration in bestehende Projekte + Selbsthosting oder Langfuse Cloud.

---

### B.5 — Eval-Harness für Prompts und Agenten

**Befund:** Keine Hinweise auf systematisches Prompt-Testing oder Agent-Eval. Qualität von LLM-Outputs wird manuell beurteilt.

**Was professionelle KI-Entwickler tun:**
- `pytest` + `langchain/evaluation` für Unit-Tests von Prompt-Templates
- Snapshot-Tests: erwartete Outputs für Regessionstests fixieren
- LLM-als-Richter: ein günstiges Modell bewertet Output eines teureren Modells auf Korrektheit

```python
# Minimal: pytest-basierter Eval
def test_extraction_quality():
    result = extract_entities(sample_text)
    assert result["persons"] == expected_persons
    assert result["confidence"] > 0.8
```

**Hebelwirkung:** Hoch — verhindert Regressionen bei Prompt-Änderungen.
**Aufwand:** 4–8 Stunden initial, dann als Teil des Qualitätsgates.

---

### B.6 — Kostenkontrolle über alle Agent-CLIs

**Befund:** Claude Code hat eine Kostenbremse für Subagenten (`CLAUDE_CODE_SUBAGENT_MODEL=claude-sonnet-4-6`). Für die anderen CLIs (Codex, Gemini, ggf. weitere Agent-Tools) gibt es keine gemessene oder sichtbare Kostenkontrolle.

**Was fehlt:**
- Monatliche Token-Budgets in den API-Konsolen setzen (Anthropic, OpenAI, Google)
- Aggregiertes Dashboard: Kosten über alle Services pro Woche
- Warnschwellen per E-Mail/Webhook wenn Budget X% erreicht

**Hebelwirkung:** Mittel — wird wichtig wenn Agenten-Workflows automatisiert laufen (Cron, LaunchAgents).
**Aufwand:** 1 Stunde für Budgets in allen Konsolen.

---

### B.7 — CI-Gate entspricht nicht dem lokalen Gate

**Befund:** `dev/base` definiert ein lokales Qualitätsgate (`./scripts/gate.sh` bzw. `npm run verify:ci`). Es gibt keine CI-Pipeline (GitHub Actions o. ä.) die dasselbe Gate auf jedem Push ausführt.

**Was fehlt:**
```yaml
# .github/workflows/ci.yml (via dev/base/standards/ci)
jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run verify:ci   # Type-Check + Lint + Tests
```

**Kontext:** 15 von 58 Repos haben `docker-compose.yml`, 4 haben `Makefile` — viele haben also schon Build-Logik. Was fehlt ist die GitHub-Actions-Integration.

**Hebelwirkung:** Hoch für Repos mit mehr als einer Person. Mittel für Solo-Projekte.
**Aufwand:** 1–2 Stunden pro Repo-Kategorie, dann Template in `dev/base`.

---

### B.8 — Backup/Restore-Strategie: unklar

**Befund:** Kein Time Machine-Status sichtbar. Kein Hinweis auf Cloud-Backup (Backblaze, iCloud Drive für non-dev-Daten, o. ä.).

**Was zu klären ist:**
```bash
tmutil status   # läuft Time Machine?
tmutil latestbackup   # wann war das letzte Backup?
```

**Hebelwirkung:** Sehr hoch — bei 96 % vollem Speicher ist das Risiko eines Datenverlusts durch Speicherplatzmangel real.
**Aufwand:** 1 Stunde Setup, dann läuft Time Machine automatisch.

---

### B.9 — Speicherplatz-Hygiene als wiederkehrender Job

**Befund:** 96 % SSD-Auslastung ist ein systemischer Zustand, kein einmaliges Problem. Ohne regelmäßige Hygiene wird es sich wiederholen.

**Empfehlung: monatlicher Cronjob:**
```bash
# Homebrew-Caches
brew cleanup --prune=30

# Docker
docker system prune -f --filter "until=720h"   # Artefakte älter als 30 Tage

# Conda-Caches
conda clean --all -y

# Bericht
df -h ~ && docker system df && du -sh ~/.ollama/models/
```

**Hebelwirkung:** Hoch auf dieser Maschine.
**Aufwand:** 30 Minuten einmal, dann automatisch.

---

### B.10 — Repo-Sprawl: 58 Verzeichnisse, kein Lifecycle-Management

**Befund:** 58 Einträge in `~/dev/`, davon aktiv genutzt wahrscheinlich 10–15. Viele Repos (Open-Source-Klone: langfuse, Scrapling, Anki-Android, screenshot-to-code u. a.) wurden geklont, möglicherweise einmal genutzt, liegen aber auf der Festplatte.

**Was fehlt:**
```bash
base status   # zeigt welche Repos aktiv vs. inaktiv sind
```

Oder ein Lifecycle-Label: `active`, `archived`, `experiment`. Archive-Repos auf GitHub als "archived" markieren, lokal löschen (sie sind via git clone wiederherstellbar).

**Hebelwirkung:** Mittel — Speicherplatz + mentale Klarheit.
**Aufwand:** 1–2 Stunden Housekeeping, dann monatliche 15 Minuten.

---

## Top 10: Wenn du nur 10 Dinge machst, dann diese

Priorisiert nach Hebelwirkung pro investierter Stunde:

| # | Maßnahme | Teil | Aufwand | Nutzen |
|---|---|---|---|---|
| 1 | **pre-commit installieren + in dev/base einrichten** (A.7) | A | 30 Min | Sicherheitsnetz aktiv |
| 2 | **96 % Speicher bereinigen** (A.14) | A | 1–2 Std | Stabilität, neue Modelle möglich |
| 3 | **Legacy-Agenten-Gateway deinstallieren** via `scripts/90-cleanup-legacy.sh` (A.1) | A | 30 Min | Saubere Shell, kein toter Code |
| 4 | **Claude Code + Codex Sicherheitseinstellungen anpassen** (A.15) | A | 30 Min | Kein unbeaufsichtigter Vollzugriff |
| 5 | **Vaultwarden + env-run einrichten** (B.1) | B | 3–5 Std | Secrets nie mehr im Klartext |
| 6 | **conda-base aus dem default-python herausnehmen** + uv als Standard (A.6) | A | 1 Std | Projektisolation funktioniert |
| 7 | **Globale .gitignore füllen und registrieren** (A.8) | A | 30 Min | Keine Systemdateien im Repo |
| 8 | **Langfuse in LangChain/LangGraph-Projekte integrieren** (B.4) | B | 2–4 Std | Kosten- und Qualitätssichtbarkeit |
| 9 | **Backup-Strategie klären** (Time Machine oder Cloud) (B.8) | B | 1 Std | Datenverlustschutz |
| 10 | **Zwei GitHub-Accounts mit klarer SSH-Trennung** konfigurieren (A.17) | A | 1 Std | Kein falscher Account auf falsches Repo |
