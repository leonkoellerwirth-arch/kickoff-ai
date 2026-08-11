# Secrets-Management mit Vaultwarden und Bitwarden CLI

> [English](../08-SECRETS.md)

Dieses Dokument beschreibt den vollständigen Weg von der Klartext-`.env`-Datei zu
sauberem Secrets-Management mit selbstgehostetem Vaultwarden und `env-run`.

---

## 1. Warum selbstgehostet?

**Warum kein 1Password, kein SaaS-Vault?**

Dieses Setup setzt auf Vaultwarden — eine quelloffene Implementierung des Bitwarden-
Servers — aus drei Gründen: Datensouveränität (Secrets liegen auf deiner eigenen
Infrastruktur, nicht bei einem SaaS-Anbieter), Kostenfreiheit (kein Abomodell für
Familien- oder Team-Pläne), und Kompatibilität mit dem vorhandenen Docker-Muster
(jedes Projekt bekommt seinen eigenen Stack; Vaultwarden passt nahtlos hinein).

**Der ehrliche Preis dafür:**

Du betreibst den Dienst selbst. Backup und Verfügbarkeit liegen bei dir. Verlierst du
das `vw-data`-Volume ohne Backup, sind alle gespeicherten Secrets unwiederbringlich
verloren. Plane Backups bevor du Secrets eintragst.

---

## 2. Vaultwarden per Docker Compose aufsetzen

Startpunkt ist das sofort einsetzbare Template unter `../../templates/vaultwarden/`.

### 2.1 Template kopieren

```bash
cp -r ~/dev/kickoff-ai/templates/vaultwarden/ ~/dev/vaultwarden/
cd ~/dev/vaultwarden/
```

### 2.2 docker-compose.yml (Referenz)

```yaml
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    volumes:
      - vw-data:/data
    environment:
      DOMAIN: "http://localhost:8080"
      SIGNUPS_ALLOWED: "true"     # NUR für Ersteinrichtung — danach auf false setzen!
      ADMIN_TOKEN: "${ADMIN_TOKEN}"   # aus .env laden
    ports:
      - "127.0.0.1:8080:80"
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:80/alive"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  vw-data:
    driver: local
```

Hinweise:
- Kein `version:`-Feld — von aktuellem Docker Compose ignoriert, in neuen Specs entfallen.
- Port nur auf `127.0.0.1` gebunden, kein Zugriff von außen.
- `WEBSOCKET_ENABLED` nicht setzen — seit Vaultwarden 1.29 deprecated, seit 1.31
  in den Haupt-HTTP-Port integriert.

### 2.3 Admin-Token sicher erzeugen

Der Admin-Token muss als Argon2-Hash gespeichert werden:

```bash
# Vaultwarden mitgeliefertes Hash-Tool
docker run --rm vaultwarden/server vaultwarden hash --preset owasp
# → gibt einen Hash aus: $argon2id$v=19$...

# Oder direkt per openssl + argon2 (falls argon2 installiert)
brew install argon2
echo -n "mein-langes-passwort" | argon2 "$(openssl rand -hex 16)" -id -t 3 -m 15 -p 4 -l 32 -e
```

Den Hash in die `.env`-Datei (nur lokal, nicht ins Repo):

```bash
echo 'ADMIN_TOKEN=$argon2id$v=19$...' > .env
```

Alternativ: einen langen zufälligen String als Klartext-Token setzen (einfacher für
den Einstieg, unsicherer bei Server-Exponierung):

```bash
echo "ADMIN_TOKEN=$(openssl rand -base64 32)" > .env
```

### 2.4 Starten

```bash
cd ~/dev/vaultwarden/
docker compose up -d
docker compose ps   # Status prüfen
```

Vaultwarden ist unter `http://localhost:8080` erreichbar.

### 2.5 Erstkonto anlegen und Registrierung sperren

1. `http://localhost:8080` im Browser öffnen
2. Konto anlegen (E-Mail + Master-Passwort)
3. **Einloggen und prüfen ob alles funktioniert**
4. `SIGNUPS_ALLOWED` auf `false` setzen:

```bash
# In ~/dev/vaultwarden/docker-compose.yml:
#   SIGNUPS_ALLOWED: "false"
docker compose up -d   # Container neu starten mit neuer Konfiguration
```

Alternativ über das Admin-Panel: `http://localhost:8080/admin` (Admin-Token eingeben
→ "User Management" → "Allow new signups" deaktivieren).

---

## 3. TLS — wann welcher Weg

Die Bitwarden-Clients und die CLI verlangen HTTPS außer bei `localhost`. Zwei Wege:

### 3.1 Nur lokal — `http://localhost:8080` (einfachster Einstieg)

Wenn Vaultwarden ausschließlich lokal auf demselben Mac läuft, reicht HTTP auf
localhost. Die CLI kommuniziert über `bw config server http://localhost:8080` direkt.

**Passt für:** Einzelperson-Setup, nur CLI-Nutzung, kein Zugriff vom Mobilgerät.

**Nachteil:** Kein HTTPS bedeutet kein sicheres Zertifikat — Bitwarden-Mobilclients
akzeptieren `http://localhost` nicht.

### 3.2 Caddy als Reverse Proxy (für Server-Betrieb oder Mobilzugriff)

Caddy beschafft automatisch ein Let's-Encrypt-Zertifikat wenn die Domain öffentlich
erreichbar ist. Für rein lokalen Betrieb kann Caddy auch mit self-signed Zertifikaten
und `localhost.direct` konfiguriert werden.

**Caddyfile (Referenz für öffentliche Domain):**

```
vault.beispiel.tld {
    reverse_proxy localhost:8080
    encode gzip
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
    }
}
```

Das vollständige Beispiel liegt unter `../../templates/vaultwarden/Caddyfile.example`.

```bash
brew install caddy
sudo caddy run --config ~/dev/vaultwarden/Caddyfile
```

**Passt für:** Server-Deployment, Zugriff von mehreren Geräten, Mobilclients.

---

## 4. Bitwarden CLI einrichten

### 4.1 Installieren

```bash
brew install bitwarden-cli
bw --version
```

### 4.2 Server konfigurieren

```bash
# Lokales Vaultwarden
bw config server http://localhost:8080

# Oder mit Caddy/HTTPS:
bw config server https://vault.beispiel.tld

# Aktuelle Konfiguration prüfen:
bw config server
```

### 4.3 Anmelden und Tresor öffnen

```bash
# Erstmalig anmelden (E-Mail + Master-Passwort)
bw login

# Session öffnen — gibt einen Session-Token zurück
export BW_SESSION=$(bw unlock --raw)

# Daten synchronisieren
bw sync

# Status prüfen
bw status
```

### 4.4 bw-unlock Hilfsfunktion für die .zshrc

Um den Session-Token schnell zu erneuern, empfiehlt sich eine Shell-Funktion:

```zsh
# In ~/.zshrc einfügen:
bw-unlock() {
    local session
    session=$(bw unlock --raw 2>/dev/null)
    if [ -z "$session" ]; then
        echo "bw unlock fehlgeschlagen." >&2
        return 1
    fi
    export BW_SESSION="$session"
    echo "BW_SESSION gesetzt. Tresor offen."
}
```

**Wichtig:** `BW_SESSION` nicht dauerhaft in die `.zshrc` schreiben. Der Token
entspricht einem Tresor-Schlüssel — er gehört nur in die aktuelle Terminal-Sitzung.

---

## 5. Secrets anlegen und lesen

### 5.1 Neues Item anlegen

**Via Web-UI (empfohlen für Ersteinrichtung):**
`http://localhost:8080` → Eintrag hinzufügen → Typ: Login oder Secure Note.

**Via CLI:**
```bash
# Login-Eintrag (Name + Passwort)
bw create item "$(bw get template item.login | jq '.name="my-service" | .login.password="geheimes-passwort" | .login.username="nutzername"')"

# Nur Passwort (Secure Note)
bw create item "$(bw get template item.secureNote | jq '.name="api-key-service" | .notes="sk-abc123"')"
```

### 5.2 Werte lesen

```bash
# Passwort eines Eintrags
bw get password my-service --session "$BW_SESSION"

# Benutzername
bw get username my-service --session "$BW_SESSION"

# Notizen
bw get notes api-key-service --session "$BW_SESSION"

# Benutzerdefiniertes Feld "url"
bw get item my-service --session "$BW_SESSION" | \
    jq -r '.fields[] | select(.name == "url") | .value'
```

### 5.3 Items suchen

```bash
bw list items --search "my-service" --session "$BW_SESSION" | jq '.[].name'
```

### 5.4 Benutzerdefinierte Felder anlegen

Über die Web-UI: Eintrag öffnen → "Benutzerdefinierten Felder hinzufügen" → Name und Wert.

Via CLI:
```bash
bw get item my-service --session "$BW_SESSION" | \
    jq '.fields += [{"name":"url","value":"https://api.beispiel.tld","type":0}]' | \
    bw encode | \
    bw edit item <item-id> --session "$BW_SESSION"
```

---

## 6. Secret-Injektion mit env-run

### 6.1 Warum es kein `bw run` gibt

Online findet man gelegentlich Beispiele die `bw run --env-file` als Äquivalent zu
`op run --env-file` beschreiben. Das ist falsch: die Bitwarden CLI (`bw`) kennt kein
`run`-Subkommando. `bws run` existiert, gehört aber zum **Bitwarden Secrets Manager**
(proprietär lizenziert) — einer anderen Produktlinie, die Vaultwarden nicht
implementiert (dani-garcia/vaultwarden Discussions #5702, #3368).

`env-run` löst das Problem selbst: Referenzen werden über `bw get` aufgelöst und per
Shell-`export` in eine Subshell injiziert. Der Zielbefehl ersetzt die Subshell via
`exec`. Secrets erscheinen so ausschließlich im Prozess-Environment — nicht in
`ps`-Ausgaben, nicht in temporären Dateien.

### 6.2 Template-Format

Das Template `(.env.template)` ist eine zeilenbasierte Datei die ins Repo eingecheckt
werden kann — sie enthält keine Secrets, nur Referenzen:

```bash
# .env.template — Referenzen auf Vaultwarden-Items
# Format: VARIABLE=bw://<item-name>/<feld>
# Felder: password, username, notes, totp oder benutzerdefinierter Feldname

OPENAI_API_KEY=bw://openai-api/password
DATABASE_URL=bw://my-service/url
DB_USER=bw://my-service/username
DB_PASS=bw://my-service/password
REDIS_URL=bw://redis-local/notes
# Literalwerte sind ebenfalls erlaubt (für nicht-geheime Konfiguration):
LOG_LEVEL=info
```

### 6.3 Verwendung

```bash
# Tresor öffnen
export BW_SESSION=$(bw unlock --raw)
bw sync

# Befehl mit aufgelösten Secrets starten
env-run -- uvicorn app.main:app --port 8000
env-run --env-file config/.env.prod.template -- ./scripts/deploy.sh

# Schneller bei vielen Secrets (bw serve als lokale REST-API):
env-run --serve -- python scripts/seed.py

# Zeigen welche Variablen gesetzt würden (ohne Werte):
env-run --dry-run -- env

# Alle Referenzen im Template prüfen (ohne Werte auszugeben):
env-run check .env.template
```

### 6.4 Optionaler Schnellpfad: bw serve

Mit `--serve` (oder `BW_SERVE=1`) startet `env-run` vor dem Auflösen einen lokalen
HTTP-Dienst (`bw serve`) auf `127.0.0.1`. Der Tresor wird dabei nur einmal
entschlüsselt statt pro Variable einmal — bei Templates mit vielen Einträgen
deutlich schneller.

**Kompromiss:** `bw serve` ist ein zusätzlicher lokaler HTTP-Dienst auf Port 8087
(konfigurierbar via `BW_SERVE_PORT`). Er wird nach dem Aufruf automatisch beendet.
Für 1–3 Variablen lohnt sich der Start-Overhead nicht; ab etwa 5+ Variablen ist es
merklich schneller.

---

## 7. Migration bestehender .env-Dateien

### Schritt für Schritt

```bash
# 1. Template aus bestehender .env generieren
env-run migrate .env
# → erstellt .env.template mit bw://-Referenzen
# → gibt alle Klartext-Werte auf stderr aus für die manuelle Eingabe

# 2. Werte in Vaultwarden anlegen (Web-UI oder bw create)
#    Die Ausgabe von Schritt 1 zeigt: KEY → item-name → Wert

# 3. Referenzen prüfen
export BW_SESSION=$(bw unlock --raw)
env-run check .env.template

# 4. Befehl testen
env-run --dry-run -- env | grep MY_KEY
env-run -- <befehl>

# 5. Original-Datei löschen — NICHT nur aus git entfernen!
rm .env

# 6. .env.template ins Repo einchecken
git add .env.template
git commit -m "migrate: .env durch .env.template ersetzen"
```

### Kritisch: bereits committete Secrets

Wenn eine `.env`-Datei jemals committed war, reicht es nicht, sie aus dem Working
Tree zu löschen oder aus git zu entfernen. Das Secret ist in der Git-History und
gilt als **kompromittiert** — es muss rotiert (neu generiert) werden:

```bash
# 1. Secret beim Anbieter rotieren (neuen API-Key generieren)
# 2. Neuen Key in Vaultwarden eintragen
# 3. Git-History bereinigen:
git filter-repo --path .env --invert-paths
# oder:
bfg --delete-files .env
# 4. Alle Remote-Branches force-pushen (Rücksprache mit Team!)
```

---

## 8. Backup des Tresors

**Der Tresor ist nur so sicher wie sein Backup.**

### 8.1 Docker-Volume sichern

Das `vw-data`-Volume enthält die verschlüsselte Datenbank:

```bash
# Volume als tar.gz exportieren
docker run --rm \
    -v vaultwarden_vw-data:/data \
    -v "$HOME/backups/vaultwarden":/backup \
    alpine tar czf /backup/vw-data-$(date +%Y%m%d).tar.gz -C /data .

mkdir -p "$HOME/backups/vaultwarden"
```

Diesen Schritt kann `automation/bin/db-backup` in Zukunft übernehmen wenn das
Schema auf Vaultwarden-Volumes ausgeweitet wird — das aktuelle Muster passt.

### 8.2 Verschlüsselter Export (Notfall-Wiederherstellung)

Bitwarden CLI kann einen verschlüsselten JSON-Export erzeugen:

```bash
bw export --format encrypted_json --session "$BW_SESSION" \
    --output "$HOME/backups/vaultwarden/export-$(date +%Y%m%d).json"
```

Dieser Export ist mit dem Master-Passwort verschlüsselt. Ohne Master-Passwort ist er
wertlos — aber das Master-Passwort darf **nirgends** digital gespeichert werden.
Schreibe es auf Papier und verwahre es sicher.

### 8.3 Wiederherstellung

```bash
# Volume wiederherstellen
docker volume create vaultwarden_vw-data
docker run --rm \
    -v vaultwarden_vw-data:/data \
    -v "$HOME/backups/vaultwarden":/backup \
    alpine tar xzf /backup/vw-data-DATUM.tar.gz -C /data

# Stack neu starten
cd ~/dev/vaultwarden && docker compose up -d

# Aus JSON-Export wiederherstellen (Alternativweg)
bw import bitwardenjson export-DATUM.json
```

---

## 9. Grenzen — was bewusst manuell bleibt

| Aktion | Begründung |
|---|---|
| **Einträge in Vaultwarden anlegen** | `env-run migrate` liefert nur Vorschläge — das Schreiben bleibt manuell, damit kein automatischer Prozess Klartext-Secrets überträgt |
| **Master-Passwort** | Nie digital speichern. Auf Papier, in einem Tresor |
| **Secret-Rotation** | Manuell beim Anbieter rotieren, dann neuen Wert in Vaultwarden eintragen |
| **Auth-Vorgänge** (`bw login`, `bw unlock`) | Erfordern interaktiven Kontext — nicht automatisierbar in launchd |
| **BW_SESSION in .zshrc** | Session-Token nicht dauerhaft exportieren — nur für die aktuelle Sitzung |

---

## 10. SSH-Agent via Bitwarden Desktop (optional)

Die **Bitwarden Desktop-App** (nicht identisch mit der CLI) kann als SSH-Agent dienen
und SSH-Keys aus dem Tresor injizieren — ähnlich wie der 1Password SSH-Agent.

```bash
brew install --cask bitwarden
```

Einrichten: Bitwarden Desktop → Einstellungen → SSH-Agent → "SSH-Keys im Tresor
speichern" aktivieren. SSH-Clients sprechen dann den Bitwarden SSH-Agent an.

**Voraussetzung:** Bitwarden Desktop-App muss laufen. Für reine CLI-Nutzung (ohne
Desktop-App) ist dieser Weg nicht verfügbar. Für den Workflow dieses Setups (CLI-
basiert, kein dauerhafter GUI-Prozess) ist die CLI-Lösung mit `env-run` der primäre
Weg.
