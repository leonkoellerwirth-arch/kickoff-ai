# Sanitization Rules — What May Appear in Public Files

> [Deutsch](de/05-SANITISIERUNG.md)

This repository is publicly published. Before running `git push`, check this list.

---

## What Never Belongs in Public Files

### Identifying Information

| What | Instead |
|---|---|
| Username in paths (`/Users/<name>/`) | `~` or `$HOME` |
| Email addresses | `<your@email.com>` or omit |
| GitHub account names | `<your-github-username>`, `<second-account>` |
| SSH key filenames hinting at origin | `~/.ssh/id_ed25519` (generic) |
| Machine hostnames | omit |
| Local IP addresses | omit or use `127.0.0.1` |

### Project Names

| What | Instead |
|---|---|
| Private client projects | "a client project", "a web project", "a SaaS project" |
| Private repos (personal websites, book manuscripts, freelance projects) | omit or describe in aggregate |
| Open-source clones and forks | may use their real name (langfuse, Scrapling, Anki-Android, screenshot-to-code) |

**Rule of thumb:** Patterns yes, identity no. The learning value lies in the pattern.

### Secrets and Credentials

| What | Never appears |
|---|---|
| API keys | Never in Markdown, code, or config files |
| Passwords | Never |
| Tokens (GitHub PAT, Telegram bot token, webhook URLs) | Never |
| Private SSH keys | Never |
| Database connection strings with password | Never |

---

## What Is Permitted

- Hardware specs (M2 Max, 32 GB RAM, macOS version) — non-critical, useful for readers
- Version numbers of installed tools
- Aggregated statistics about repos ("36 of 58 repos with package.json")
- Stack decisions and rationale
- Error patterns as general patterns ("an alias points to a non-existent directory")

**Intentionally permitted exception:** The repository URL `github.com/leonkoellerwirth-arch/kickoff-ai`
necessarily contains the GitHub account name and must appear in the repo — without it the
`prepare.sh` one-liner cannot run on a bare machine. It is explicitly listed in the
allowlist (`.github/sanitize-allowlist.txt`).

---

## How the Scan Works

The `validate` workflow (`.github/workflows/validate.yml`, step "Sanitisierungs-Scan")
checks all text files in the repository using a two-tier system:

### Denylist

Two files define forbidden patterns (one extended regex per line):

- **`.github/sanitize-denylist.txt`** — public, core patterns (fixed rules for
  `/Users/`, email addresses, GitHub tokens, SSH private keys, AWS keys)
- **`local/sanitize-denylist-private.txt`** — gitignored, optional extension for
  private terms (client names, private project names)

```bash
# Add your own private terms (gitignored):
mkdir -p local
cat > local/sanitize-denylist-private.txt <<'EOF'
# Private terms (regex, one per line)
MyClientName
my-private-project
EOF
```

### Allowlist

Some lines must contain a denylist pattern — the allowlist prevents false positives
without weakening protection everywhere else:

- **`.github/sanitize-allowlist.txt`** — public, documented (including the repo URL)
- **`local/sanitize-allowlist-private.txt`** — gitignored, optional private exceptions

```bash
# Add a private exception (e.g. an alias that happens to look like an email):
cat >> local/sanitize-allowlist-private.txt <<'EOF'
# Lines matching this pattern are not treated as findings
my-special-expression
EOF
```

### Line-level Scanning

The scan operates **line by line**, not file by file. This allows fine-grained exceptions:
a single line (e.g. the clone URL) can be exempted without removing the entire file from
the scan. A found line is considered permitted if it matches a pattern in any of the
allowlist files.

---

## Where Machine-Specific Raw Data Lives

```
local/                     ← in .gitignore, never pushed
  inventory/               ← raw inventory output (brew list, docker ps, etc.)
  overrides/               ← machine-specific configuration overrides
  notes/                   ← private setup notes
```

The `local/` directory is listed in `.gitignore` and exists only locally. If you need
inventory data for debugging, put it there.

---

## Checklist Before `git push`

```bash
# Search for secrets
gitleaks detect --source . --no-git

# Search for usernames in paths
grep -r "/Users/" docs/ README.md

# Search for email addresses
grep -rE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' docs/ README.md

# Search for GitHub account names (adapt to your real names)
grep -ri "<your-real-username>" docs/ README.md

# Then push
git push
```

The CI workflow runs the full scan automatically on every push.
The manual checklist is a quick pre-check in the terminal.

---

## Why This Effort

This repository is meant to be useful to others — as a reference, not a dossier about a
person. Sanitization protects privacy and focuses the learning value: anyone adapting this
setup is interested in the pattern, not in the name of the person or their clients behind it.
