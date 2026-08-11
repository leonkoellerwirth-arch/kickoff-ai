# Secrets Management with Vaultwarden and the Bitwarden CLI

> [Deutsch](de/08-SECRETS.md)

This document describes the complete path from a plaintext `.env` file to clean
secrets management with a self-hosted Vaultwarden and `env-run`.

---

## 1. Why Self-Hosted?

**Why not 1Password or a SaaS vault?**

This setup uses Vaultwarden — an open-source implementation of the Bitwarden server —
for three reasons: data sovereignty (secrets live on your own infrastructure, not at a
SaaS provider), no subscription costs (no paid plan for families or teams), and
compatibility with the existing Docker pattern (every project gets its own stack;
Vaultwarden fits seamlessly).

**The honest cost:**

You operate the service yourself. Backup and availability are your responsibility.
If you lose the `vw-data` volume without a backup, every stored secret is gone
permanently. Plan your backups before entering any secrets.

---

## 2. Setting Up Vaultwarden with Docker Compose

The starting point is the ready-to-use template under `../templates/vaultwarden/`.

### 2.1 Copy the Template

```bash
cp -r ~/dev/kickoff-ai/templates/vaultwarden/ ~/dev/vaultwarden/
cd ~/dev/vaultwarden/
```

### 2.2 docker-compose.yml (reference)

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
      SIGNUPS_ALLOWED: "true"     # ONLY for initial setup — set to false afterwards!
      ADMIN_TOKEN: "${ADMIN_TOKEN}"   # loaded from .env
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

Notes:
- No `version:` field — ignored by current Docker Compose, removed in new specs.
- Port bound to `127.0.0.1` only, no external access.
- Do not set `WEBSOCKET_ENABLED` — deprecated since Vaultwarden 1.29, integrated into
  the main HTTP port since 1.31.

### 2.3 Generating the Admin Token Securely

The admin token must be stored as an Argon2 hash:

```bash
# Hash tool bundled with Vaultwarden
docker run --rm vaultwarden/server vaultwarden hash --preset owasp
# → outputs a hash: $argon2id$v=19$...

# Or directly via openssl + argon2 (if argon2 is installed)
brew install argon2
echo -n "my-long-password" | argon2 "$(openssl rand -hex 16)" -id -t 3 -m 15 -p 4 -l 32 -e
```

Write the hash to the `.env` file (local only, never in the repo):

```bash
echo 'ADMIN_TOKEN=$argon2id$v=19$...' > .env
```

Alternative: set a long random string as a plaintext token (easier to start with,
less secure if the server is exposed):

```bash
echo "ADMIN_TOKEN=$(openssl rand -base64 32)" > .env
```

### 2.4 Starting

```bash
cd ~/dev/vaultwarden/
docker compose up -d
docker compose ps   # check status
```

Vaultwarden is available at `http://localhost:8080`.

### 2.5 Create the First Account and Lock Registration

1. Open `http://localhost:8080` in a browser
2. Create an account (email + master password)
3. **Log in and verify everything works**
4. Set `SIGNUPS_ALLOWED` to `false`:

```bash
# In ~/dev/vaultwarden/docker-compose.yml:
#   SIGNUPS_ALLOWED: "false"
docker compose up -d   # restart container with new configuration
```

Alternative via the admin panel: `http://localhost:8080/admin` (enter admin token
→ "User Management" → disable "Allow new signups").

---

## 3. TLS — Which Path for Which Situation

The Bitwarden clients and CLI require HTTPS except on `localhost`. Two paths:

### 3.1 Local Only — `http://localhost:8080` (simplest start)

If Vaultwarden runs exclusively locally on the same Mac, HTTP on localhost is
sufficient. The CLI communicates directly via `bw config server http://localhost:8080`.

**Fits:** single-person setup, CLI-only use, no mobile device access.

**Limitation:** no HTTPS means no trusted certificate — Bitwarden mobile clients do
not accept `http://localhost`.

### 3.2 Caddy as Reverse Proxy (for server operation or mobile access)

Caddy automatically obtains a Let's Encrypt certificate when the domain is publicly
reachable. For purely local operation Caddy can also be configured with self-signed
certificates and `localhost.direct`.

**Caddyfile (reference for a public domain):**

```
vault.example.tld {
    reverse_proxy localhost:8080
    encode gzip
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
    }
}
```

The complete example lives at `../templates/vaultwarden/Caddyfile.example`.

```bash
brew install caddy
sudo caddy run --config ~/dev/vaultwarden/Caddyfile
```

**Fits:** server deployment, access from multiple devices, mobile clients.

---

## 4. Setting Up the Bitwarden CLI

### 4.1 Install

```bash
brew install bitwarden-cli
bw --version
```

### 4.2 Configure the Server

```bash
# Local Vaultwarden
bw config server http://localhost:8080

# Or with Caddy/HTTPS:
bw config server https://vault.example.tld

# Check current configuration:
bw config server
```

### 4.3 Log In and Unlock the Vault

```bash
# First-time login (email + master password)
bw login

# Open a session — returns a session token
export BW_SESSION=$(bw unlock --raw)

# Sync data
bw sync

# Check status
bw status
```

### 4.4 bw-unlock Helper Function for .zshrc

To quickly renew the session token, a shell function is recommended:

```zsh
# Add to ~/.zshrc:
bw-unlock() {
    local session
    session=$(bw unlock --raw 2>/dev/null)
    if [ -z "$session" ]; then
        echo "bw unlock failed." >&2
        return 1
    fi
    export BW_SESSION="$session"
    echo "BW_SESSION set. Vault open."
}
```

**Important:** Do not write `BW_SESSION` permanently to `.zshrc`. The token is
equivalent to a vault key — it belongs only in the current terminal session.

---

## 5. Creating and Reading Secrets

### 5.1 Create a New Item

**Via web UI (recommended for initial setup):**
`http://localhost:8080` → Add item → Type: Login or Secure Note.

**Via CLI:**
```bash
# Login item (name + password)
bw create item "$(bw get template item.login | jq '.name="my-service" | .login.password="secret-password" | .login.username="username"')"

# Password only (Secure Note)
bw create item "$(bw get template item.secureNote | jq '.name="api-key-service" | .notes="sk-abc123"')"
```

### 5.2 Reading Values

```bash
# Password of an item
bw get password my-service --session "$BW_SESSION"

# Username
bw get username my-service --session "$BW_SESSION"

# Notes
bw get notes api-key-service --session "$BW_SESSION"

# Custom field "url"
bw get item my-service --session "$BW_SESSION" | \
    jq -r '.fields[] | select(.name == "url") | .value'
```

### 5.3 Searching Items

```bash
bw list items --search "my-service" --session "$BW_SESSION" | jq '.[].name'
```

### 5.4 Creating Custom Fields

Via web UI: open an item → "Add custom field" → name and value.

Via CLI:
```bash
bw get item my-service --session "$BW_SESSION" | \
    jq '.fields += [{"name":"url","value":"https://api.example.tld","type":0}]' | \
    bw encode | \
    bw edit item <item-id> --session "$BW_SESSION"
```

---

## 6. Secret Injection with env-run

### 6.1 Why There Is No `bw run`

Occasionally you will find examples online describing `bw run --env-file` as the
equivalent of `op run --env-file`. This is wrong: the Bitwarden CLI (`bw`) has no
`run` subcommand. `bws run` does exist, but it belongs to the **Bitwarden Secrets
Manager** (proprietary license) — a different product line that Vaultwarden does not
implement (dani-garcia/vaultwarden Discussions #5702, #3368).

`env-run` solves the problem itself: references are resolved via `bw get` and injected
into a sub-shell via shell `export`. The target command replaces the sub-shell via
`exec`. Secrets therefore appear exclusively in the process environment — not in `ps`
output, not in temporary files.

That applies to the session token as well. `BW_SESSION` is exported into the
environment and never passed as `bw --session <value>`: command-line arguments are
world-readable through `ps`, and until 2026-08-11 every `bw` call in `env-run` —
including the long-lived `bw serve` in `--serve` mode — put the decrypted vault key
there. The environment is inherited by `bw` exactly the same way, with none of the
exposure.

Verify it yourself while a command is running:

```bash
ps -Ewwo args | grep -c -- '--session'   # expected: 0
```

### 6.2 Template Format

The template (`.env.template`) is a line-based file that can be checked into the repo —
it contains no secrets, only references:

```bash
# .env.template — references to Vaultwarden items
# Format: VARIABLE=bw://<item-name>/<field>
# Fields: password, username, notes, totp, or a custom field name

OPENAI_API_KEY=bw://openai-api/password
DATABASE_URL=bw://my-service/url
DB_USER=bw://my-service/username
DB_PASS=bw://my-service/password
REDIS_URL=bw://redis-local/notes
# Literal values are also permitted (for non-secret configuration):
LOG_LEVEL=info
```

### 6.3 Usage

```bash
# Open the vault
export BW_SESSION=$(bw unlock --raw)
bw sync

# Start a command with resolved secrets
env-run -- uvicorn app.main:app --port 8000
env-run --env-file config/.env.prod.template -- ./scripts/deploy.sh

# Faster with many secrets (bw serve as local REST API):
env-run --serve -- python scripts/seed.py

# Show which variables would be set (without values):
env-run --dry-run -- env

# Check all references in the template (without outputting values):
env-run check .env.template
```

### 6.4 Optional Fast Path: bw serve

With `--serve` (or `BW_SERVE=1`), `env-run` starts a local HTTP service (`bw serve`)
on `127.0.0.1` before resolving references. The vault is then decrypted only once
instead of once per variable — noticeably faster for templates with many entries.

**Trade-off:** `bw serve` is an additional local HTTP service on port 8087
(configurable via `BW_SERVE_PORT`). It is automatically shut down after the call.
For 1–3 variables the startup overhead is not worth it; from about 5+ variables
it is noticeably faster.

---

## 7. Migrating Existing .env Files

### Step by Step

```bash
# 1. Generate template from existing .env
env-run migrate .env
# → creates .env.template with bw:// references
# → prints all plaintext values to stderr for manual entry

# 2. Create items in Vaultwarden (web UI or bw create)
#    The output of step 1 shows: KEY → item-name → value

# 3. Verify references
export BW_SESSION=$(bw unlock --raw)
env-run check .env.template

# 4. Test the command
env-run --dry-run -- env | grep MY_KEY
env-run -- <command>

# 5. Delete the original file — do NOT just remove from git!
rm .env

# 6. Check the .env.template into the repo
git add .env.template
git commit -m "migrate: replace .env with .env.template"
```

### Critical: Secrets Already Committed

If a `.env` file was ever committed, deleting it from the working tree or removing it
from git is not enough. The secret is in the git history and is considered
**compromised** — it must be rotated (regenerated):

```bash
# 1. Rotate the secret at the provider (generate a new API key)
# 2. Enter the new key in Vaultwarden
# 3. Clean git history:
git filter-repo --path .env --invert-paths
# or:
bfg --delete-files .env
# 4. Force-push all remote branches (coordinate with your team!)
```

---

## 8. Backing Up the Vault

**The vault is only as secure as its backup.**

### 8.1 Back Up the Docker Volume

The `vw-data` volume contains the encrypted database:

```bash
# Export the volume as tar.gz
docker run --rm \
    -v vaultwarden_vw-data:/data \
    -v "$HOME/backups/vaultwarden":/backup \
    alpine tar czf /backup/vw-data-$(date +%Y%m%d).tar.gz -C /data .

mkdir -p "$HOME/backups/vaultwarden"
```

`automation/bin/db-backup` can take over this step in the future when its schema is
extended to cover Vaultwarden volumes — the current pattern fits.

### 8.2 Encrypted Export (Emergency Recovery)

The Bitwarden CLI can generate an encrypted JSON export:

```bash
bw export --format encrypted_json --session "$BW_SESSION" \
    --output "$HOME/backups/vaultwarden/export-$(date +%Y%m%d).json"
```

This export is encrypted with the master password. Without the master password it is
worthless — but the master password must **never** be stored digitally.
Write it on paper and keep it in a physically secure place.

### 8.3 Restoring

```bash
# Restore the volume
docker volume create vaultwarden_vw-data
docker run --rm \
    -v vaultwarden_vw-data:/data \
    -v "$HOME/backups/vaultwarden":/backup \
    alpine tar xzf /backup/vw-data-DATE.tar.gz -C /data

# Restart the stack
cd ~/dev/vaultwarden && docker compose up -d

# Restore from JSON export (alternative path)
bw import bitwardenjson export-DATE.json
```

---

## 9. Limits — What Deliberately Stays Manual

| Action | Rationale |
|---|---|
| **Creating items in Vaultwarden** | `env-run migrate` provides suggestions only — writing remains manual so no automated process transfers plaintext secrets |
| **Master password** | Never store digitally. Paper, in a physical safe |
| **Secret rotation** | Rotate at the provider, then enter the new value in Vaultwarden |
| **Auth operations** (`bw login`, `bw unlock`) | Require interactive context — cannot be automated in launchd |
| **BW_SESSION in .zshrc** | Do not export the session token permanently — current terminal session only |

---

## 10. SSH Agent via Bitwarden Desktop (optional)

The **Bitwarden Desktop app** (not the same as the CLI) can act as an SSH agent and
inject SSH keys from the vault — similar to the 1Password SSH agent.

```bash
brew install --cask bitwarden
```

Setup: Bitwarden Desktop → Settings → SSH Agent → enable "Store SSH keys in vault".
SSH clients then communicate with the Bitwarden SSH agent.

**Prerequisite:** The Bitwarden Desktop app must be running. For pure CLI use (without
the Desktop app) this path is not available. For the workflow of this setup (CLI-based,
no persistent GUI process), the CLI solution with `env-run` is the primary approach.
