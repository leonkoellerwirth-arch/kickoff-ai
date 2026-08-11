# Manual Steps — What Requires Human Hands and Why

Everything here is beyond what `bootstrap.sh` can handle: App Store, logins, secrets, hardware, licenses.
Check off each item before moving on to the next. The "Blocking?" column means: can you work meaningfully without this step?

---

## 1. Apple ID / iCloud / FileVault

| # | Task | Effort | Blocking? |
|---|---|---|---|
| 1.1 | Sign in with Apple ID (System Settings) | 2 min | Yes — App Store, iCloud |
| 1.2 | Enable FileVault + store recovery key in Vaultwarden | 5 min | Security |
| 1.3 | Disable iCloud "Desktop & Documents" sync | 1 min | Recommended |
| 1.4 | Run Software Update until "Up to Date" | 10–30 min | Recommended |
| 1.5 | Verify two-factor authentication is active | 2 min | Security |

---

## 2. App Store and Non-Brew Apps

These apps cannot be installed via Homebrew — either because they are distributed exclusively through the App Store, or because they use proprietary installers.

| App | Source | Effort | Blocking? |
|---|---|---|---|
| **Xcode** | App Store (4–8 GB) | 20–45 min | Yes — for iOS/Swift projects |
| Adobe CC (Photoshop, Bridge, Acrobat) | adobe.com/creativecloud | 30–60 min | For image editing |
| IBM SPSS Statistics | ibm.com (license required) | 20 min | For data analysis projects |
| Topaz Labs (Gigapixel, DeNoise, Sharpen) | topazlabs.com | 15 min | For photo editing |
| Luminar AI | skylum.com | 15 min | For photo editing |
| Nik Collection | nikcollection.com | 10 min | For photo editing |
| Goodnotes | App Store | 5 min | Notes/handwriting |
| Enpass | App Store | 5 min | Password manager |
| ExpressVPN | App Store | 5 min | VPN |
| Muse Hub | musehub.com | 10 min | Audio plugins |
| Guitar Pro | App Store / arobas-music.com | 10 min | Score editor |
| Blackmagic Design (DaVinci, etc.) | blackmagicdesign.com | 15 min | Video editing |
| Sonos | App Store | 5 min | Speaker control |
| Garmin Connect / Express | garmin.com | 10 min | GPS device sync |
| TestFlight | App Store | 3 min | iOS beta testing |
| Developer.app | App Store | 3 min | Apple documentation |
| Anki | ankiweb.net (desktop) | 5 min | Flashcards |

---

## 3. Logins & Tokens

All API keys and tokens go into Vaultwarden — never stored in plaintext on the device without vault protection.

| Service | Where to get the key | Effort | Blocking? |
|---|---|---|---|
| **Anthropic (Claude)** | console.anthropic.com | 5 min | Yes — Claude Code |
| **OpenAI** | platform.openai.com | 5 min | Yes — Codex CLI |
| **Google AI (Gemini)** | aistudio.google.com | 5 min | Yes — Gemini CLI |
| GitHub Account 1 (primary) | github.com/settings/tokens | 5 min | Yes — repos |
| GitHub Account 2 (secondary) | github.com/settings/tokens | 5 min | For client repos |
| Apple Developer | developer.apple.com | 10 min | For app releases |
| Docker Hub (if using private images) | hub.docker.com | 2 min | No |
| Telegram Bot API (for agent notifications) | @BotFather in Telegram | 5 min | No |
| Other SaaS access | Vaultwarden | Ongoing | Depends on project |

**Never export tokens permanently into the shell** — use `env-run` instead:
```bash
# .env.template (check this into the repo):
ANTHROPIC_API_KEY=bw://anthropic-api/password
OPENAI_API_KEY=bw://openai-api/password
GEMINI_API_KEY=bw://gemini-api/password

# Start a command with resolved secrets:
export BW_SESSION=$(bw unlock --raw)
env-run -- <command>
```

Full guide: [docs/08-SECRETS.md](08-SECRETS.md)

---

## 4. Licenses

| Product | Where | Effort |
|---|---|---|
| Adobe CC | Creative Cloud app → sign in | 5 min |
| JetBrains (IntelliJ) | JetBrains Toolbox → license | 5 min |
| IBM SPSS | IBM License Center | 10 min |
| Topaz Labs | Topaz app → activate | 5 min |
| Luminar / Nik | Skylum / DxO account | 5 min |
| Guitar Pro | arobas-music.com account | 5 min |

---

## 5. Secrets Migration — Most Critical Section

The goal: no secret is ever transmitted via AirDrop, iMessage, email, or unencrypted copy.

### What Needs to Be Migrated

| What | Secure method | Insecure method (DO NOT) |
|---|---|---|
| API keys from `.env` files | Enter in Vaultwarden, use via `env-run` | Copy the file directly |
| SSH keys | Regenerating is better; if copying: use an encrypted archive | AirDrop, email |
| Telegram bot tokens and gateway credentials | Into Vaultwarden, then reconfigure | Copy the files |
| Database passwords from docker-compose | Into Vaultwarden, use `env-run` in new docker-compose | Copy docker-compose.yml |
| `.env` files in repo directories | Check clean with gitleaks, then move to Vaultwarden | Copy the repo directly |

### Inventory Before Migration

```bash
# Find all .env files (on the old machine)
find ~/dev -name ".env" -o -name "*.env" -o -name ".env.*" 2>/dev/null | sort

# Check for secrets
gitleaks detect --source ~/dev --no-git

# Back up deployment envs separately
ls ~/dev/*.env 2>/dev/null   # deploy env files at repo level
```

### Procedure

1. Run `gitleaks detect --source ~/dev` on the old machine: transfer all findings to Vaultwarden.
2. For each `.env` file: enter keys in Vaultwarden, create `.env.template` with `env-run migrate`, remove the plaintext file.
3. SSH keys: regenerate on the new Mac (ed25519), register with all services.
4. On the new Mac: never put keys in plaintext in `.zshrc` — use `env-run`.

Full migration guide: [docs/08-SECRETS.md](08-SECRETS.md)

---

## 6. Hardware & Peripherals

| Software | Source | Effort | Blocking? |
|---|---|---|---|
| Logi Options+ | logitech.com | 10 min | For Logitech mouse/keyboard |
| MonitorControl | brew install --cask monitorcontrol | 2 min | External monitor brightness |
| eqMac | eqmac.app | 5 min | System equalizer |
| Lunar | lunar.fyi / App Store | 5 min | Display brightness |
| Alt-Tab | brew install --cask alt-tab (already in Brewfile) | 1 min | Window switching |
| Raycast | raycast.com | 10 min | Launcher (extensions manual) |

---

## 7. Data Migration

### Ollama Models

**Do not copy — pull fresh.** Ollama model files are binary, large, and can run into path problems when copied directly.

```bash
# On the new Mac: simply re-download
ollama pull llama3.2       # 2.0 GB
ollama pull deepseek-r1:14b  # 9.0 GB
ollama pull glm-ocr        # 2.2 GB
ollama pull aya-expanse:8b # 5.1 GB
```

**Check free space first:** `df -h ~` — have at least 25–30 GB free.

### Docker Volumes

Only volumes with real data (not caches or build artifacts) need to be migrated:

```bash
# On the old machine: export volume contents
docker run --rm -v <volume-name>:/data -v $(pwd):/backup \
  alpine tar czf /backup/<volume-name>.tar.gz -C /data .

# On the new machine: import
docker volume create <volume-name>
docker run --rm -v <volume-name>:/data -v $(pwd):/backup \
  alpine tar xzf /backup/<volume-name>.tar.gz -C /data
```

Volumes that typically need migration: database data for active projects, Qdrant collections, persistently stored uploads.

### ~/dev Repos

All repos with a remote: simply `git clone` on the new Mac — that is the cleanest approach.

```bash
# Check for repos without a remote (on the old machine)
for d in ~/dev/*/; do
  git -C "$d" remote -v 2>/dev/null || echo "NO REMOTE: $d"
done
```

Repos without a remote: either create a GitHub repo and push, or transfer via an encrypted archive.

---

## 8. Afterward: Run doctor.sh

```bash
cd ~/dev/kickoff-ai
./doctor.sh
```

Target: all ~40 checks at PASS or WARN, no FAIL.
