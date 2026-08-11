# Vaultwarden — Ready-to-Use Template

<!-- Technical reference. Maintained in English only; no separate German version. -->

Full guide: [docs/08-SECRETS.md](../../docs/08-SECRETS.md)

## Quick Start

```bash
# 1. Copy the template
cp -r ~/dev/kickoff-ai/templates/vaultwarden/ ~/dev/vaultwarden/
cd ~/dev/vaultwarden/

# 2. Create configuration
cp .env.example .env
# → edit .env: set ADMIN_TOKEN (Argon2 hash, see .env.example)

# 3. Start
docker compose up -d

# 4. Create account
open http://localhost:8080

# 5. Set SIGNUPS_ALLOWED in .env to false, then:
docker compose up -d

# 6. Configure the Bitwarden CLI
brew install bitwarden-cli
bw config server http://localhost:8080
bw login
export BW_SESSION=$(bw unlock --raw)

# 7. Use secrets (env-run)
export BW_SESSION=$(bw unlock --raw)
env-run --env-file /path/to/.env.template -- <command>
```

## Files in This Directory

| File | Purpose |
|---|---|
| `docker-compose.yml` | Vaultwarden stack (no `version:`, no deprecated WebSocket setting) |
| `.env.example` | Template for the local `.env` (do not check into the repo) |
| `Caddyfile.example` | Caddy reverse proxy with HTTPS (for server operation) |
| `.env.template.example` | Example of the env-run template format (safe to check into the repo) |
