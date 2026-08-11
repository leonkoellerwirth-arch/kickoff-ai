# Manuelle Schritte — was Handarbeit bleibt und warum

> ⚠️ Archivierte deutsche Fassung — maßgeblich ist die englische Version unter [`../01-MANUAL.md`](../01-MANUAL.md). Diese Datei wird nicht mehr aktualisiert.

Alles hier kann `bootstrap.sh` nicht erledigen: App Store, Logins, Secrets, Hardware, Lizenzen.
Hake jeden Punkt ab, bevor du zum nächsten gehst. Spalte "Blockierend?" bedeutet: kannst du ohne diesen Schritt sinnvoll arbeiten?

---

## 1. Apple-ID / iCloud / FileVault

| # | Aufgabe | Aufwand | Blockierend? |
|---|---|---|---|
| 1.1 | Apple-ID einloggen (Systemeinstellungen) | 2 Min | Ja — App Store, iCloud |
| 1.2 | FileVault aktivieren + Wiederherstellungsschlüssel in Vaultwarden speichern | 5 Min | Sicherheit |
| 1.3 | iCloud "Schreibtisch & Dokumente" deaktivieren | 1 Min | Empfehlung |
| 1.4 | Software-Update bis "Aktuell" durchlaufen | 10–30 Min | Empfehlung |
| 1.5 | Zwei-Faktor-Authentifizierung prüfen | 2 Min | Sicherheit |

---

## 2. App Store- und Nicht-Brew-Apps

Diese Apps können nicht per Homebrew installiert werden — entweder weil sie ausschliesslich im App Store vertrieben werden, oder weil es proprietäre Installer sind.

| App | Quelle | Aufwand | Blockierend? |
|---|---|---|---|
| **Xcode** | App Store (4–8 GB) | 20–45 Min | Ja — für iOS/Swift-Projekte |
| Adobe CC (Photoshop, Bridge, Acrobat) | adobe.com/creativecloud | 30–60 Min | Für Bildbearbeitung |
| IBM SPSS Statistics | ibm.com (Lizenz erforderlich) | 20 Min | Für Datenanalyse-Projekte |
| Topaz Labs (Gigapixel, DeNoise, Sharpen) | topazlabs.com | 15 Min | Für Fotobearbeitung |
| Luminar AI | skylum.com | 15 Min | Für Fotobearbeitung |
| Nik Collection | nikcollection.com | 10 Min | Für Fotobearbeitung |
| Goodnotes | App Store | 5 Min | Notizen/Handschrift |
| Enpass | App Store | 5 Min | Passwort-Manager |
| ExpressVPN | App Store | 5 Min | VPN |
| Muse Hub | musehub.com | 10 Min | Audio-Plugins |
| Guitar Pro | App Store / arobas-music.com | 10 Min | Noten-Editor |
| Blackmagic Design (DaVinci, etc.) | blackmagicdesign.com | 15 Min | Video-Bearbeitung |
| Sonos | App Store | 5 Min | Lautsprecher-Steuerung |
| Garmin Connect / Express | garmin.com | 10 Min | GPS-Gerätesync |
| TestFlight | App Store | 3 Min | iOS-Beta-Testing |
| Developer.app | App Store | 3 Min | Apple-Doku |
| Anki | ankiweb.net (Desktop) | 5 Min | Lernkarten |

---

## 3. Logins & Tokens

Alle API-Keys und Tokens in Vaultwarden — nie im Klartext auf dem Gerät ohne Vault-Schutz.

| Service | Wo den Key holen | Aufwand | Blockierend? |
|---|---|---|---|
| **Anthropic (Claude)** | console.anthropic.com | 5 Min | Ja — Claude Code |
| **OpenAI** | platform.openai.com | 5 Min | Ja — Codex CLI |
| **Google AI (Gemini)** | aistudio.google.com | 5 Min | Ja — Gemini CLI |
| GitHub Account 1 (primär) | github.com/settings/tokens | 5 Min | Ja — Repos |
| GitHub Account 2 (sekundär) | github.com/settings/tokens | 5 Min | Für Kunden-Repos |
| Apple Developer | developer.apple.com | 10 Min | Für App-Releases |
| Docker Hub (falls private Images) | hub.docker.com | 2 Min | Nein |
| Telegram Bot API (für Agenten-Notifications) | @BotFather in Telegram | 5 Min | Nein |
| Sonstige SaaS-Zugänge | Vaultwarden | Laufend | Je nach Projekt |

**Tokens nie dauerhaft in die Shell exportieren** — stattdessen `env-run` nutzen:
```bash
# .env.template (ins Repo einchecken):
ANTHROPIC_API_KEY=bw://anthropic-api/password
OPENAI_API_KEY=bw://openai-api/password
GEMINI_API_KEY=bw://gemini-api/password

# Befehl mit aufgelösten Secrets starten:
export BW_SESSION=$(bw unlock --raw)
env-run -- <befehl>
```

Vollständige Anleitung: [docs/08-SECRETS.md](08-SECRETS.md)

---

## 4. Lizenzen

| Produkt | Wo | Aufwand |
|---|---|---|
| Adobe CC | Creative Cloud App → Anmelden | 5 Min |
| JetBrains (IntelliJ) | JetBrains Toolbox → Lizenz | 5 Min |
| IBM SPSS | IBM License Center | 10 Min |
| Topaz Labs | Topaz-App → Aktivieren | 5 Min |
| Luminar / Nik | Skylum / DxO Konto | 5 Min |
| Guitar Pro | arobas-music.com Konto | 5 Min |

---

## 5. Secrets-Migration — kritischster Abschnitt

Das Ziel: Kein Secret wird jemals per AirDrop, iMessage, E-Mail oder unverschlüsselte Kopie übertragen.

### Was muss migriert werden

| Was | Sicherer Weg | Unsicherer Weg (NICHT) |
|---|---|---|
| API-Keys aus `.env`-Dateien | In Vaultwarden eintragen, per `env-run` nutzen | Datei direkt kopieren |
| SSH-Keys | Neu generieren ist besser; nur falls kopieren: per verschlüsseltem Archiv | AirDrop, E-Mail |
| Telegram-Bot-Tokens und Gateway-Credentials | In Vaultwarden, dann neu konfigurieren | Dateien kopieren |
| Datenbank-Passwörter aus docker-compose | In Vaultwarden, in neuem docker-compose als `env-run` | docker-compose.yml kopieren |
| `.env`-Dateien die im Repo-Verzeichnis liegen | Prüfen ob per gitleaks sauber, dann in Vaultwarden | Repo direkt kopieren |

### Inventarisierung vor der Migration

```bash
# Alle .env-Dateien finden (auf alter Maschine)
find ~/dev -name ".env" -o -name "*.env" -o -name ".env.*" 2>/dev/null | sort

# Auf Secrets prüfen
gitleaks detect --source ~/dev --no-git

# Deployments-Envs separat sichern
ls ~/dev/*.env 2>/dev/null   # Deploy-Env-Dateien auf Repo-Ebene
```

### Procedure

1. `gitleaks detect --source ~/dev` auf der alten Maschine: alle Funde in Vaultwarden übertragen.
2. Für jede `.env`-Datei: Keys in Vaultwarden eintragen, `.env.template` anlegen mit `env-run migrate`, Klartext-Datei entfernen.
3. SSH-Keys: neu generieren auf dem neuen Mac (ed25519), bei allen Services hinterlegen.
4. Auf dem neuen Mac: Keys nie im Klartext in `.zshrc`, sondern per `env-run`.

Vollständige Migrations-Anleitung: [docs/08-SECRETS.md](08-SECRETS.md)

---

## 6. Hardware & Peripherie

| Software | Quelle | Aufwand | Blockierend? |
|---|---|---|---|
| Logi Options+ | logitech.com | 10 Min | Für Logitech-Maus/Tastatur |
| MonitorControl | brew install --cask monitorcontrol | 2 Min | Externer Monitor-Helligkeit |
| eqMac | eqmac.app | 5 Min | System-Equalizer |
| Lunar | lunar.fyi / App Store | 5 Min | Display-Helligkeit |
| Alt-Tab | brew install --cask alt-tab (bereits in Brewfile) | 1 Min | Window-Switching |
| Raycast | raycast.com | 10 Min | Launcher (Extensions manuell) |

---

## 7. Daten-Migration

### Ollama-Modelle

**Nicht kopieren — neu ziehen.** Ollama-Modell-Dateien sind binär, groß, und können sich Pfad-Probleme einhandeln wenn man sie einfach kopiert.

```bash
# Auf neuem Mac: einfach neu laden
ollama pull llama3.2       # 2.0 GB
ollama pull deepseek-r1:14b  # 9.0 GB
ollama pull glm-ocr        # 2.2 GB
ollama pull aya-expanse:8b # 5.1 GB
```

**Speicherplatz vorher prüfen:** `df -h ~` — mindestens 25–30 GB frei haben.

### Docker-Volumes

Nur Volumes mit echten Daten (nicht Cache oder build-Artefakte) müssen migriert werden:

```bash
# Auf alter Maschine: Volume-Inhalt exportieren
docker run --rm -v <volume-name>:/data -v $(pwd):/backup \
  alpine tar czf /backup/<volume-name>.tar.gz -C /data .

# Auf neuer Maschine: importieren
docker volume create <volume-name>
docker run --rm -v <volume-name>:/data -v $(pwd):/backup \
  alpine tar xzf /backup/<volume-name>.tar.gz -C /data
```

Volumes die typischerweise migriert werden müssen: Datenbankdaten für aktive Projekte, Qdrant-Kollektionen, persistent gespeicherte Uploads.

### ~/dev-Repos

Alle Repos mit Remote: einfach `git clone` auf dem neuen Mac — das ist der sauberste Weg.

```bash
# Repos ohne Remote prüfen (auf alter Maschine)
for d in ~/dev/*/; do
  git -C "$d" remote -v 2>/dev/null || echo "KEIN REMOTE: $d"
done
```

Repos ohne Remote: entweder ein GitHub-Repo anlegen und pushen, oder per verschlüsseltem Archiv übertragen.

---

## 8. Nachher: doctor.sh ausführen

```bash
cd ~/dev/kickoff-ai
./doctor.sh
```

Ziel: alle ~40 Punkte auf PASS oder WARN, keine FAIL.
