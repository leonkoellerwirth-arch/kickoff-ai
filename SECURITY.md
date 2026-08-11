# Security Policy

## Reporting a vulnerability

Do not open a public GitHub issue for security vulnerabilities.

Report via **GitHub Security Advisories**: go to the [Security tab](https://github.com/leonkoellerwirth-arch/kickoff-ai/security/advisories) of this repo and click "Report a vulnerability". You will receive a response within 7 days.

Include:
- A description of the vulnerability and what it allows an attacker to do
- Steps to reproduce (exact commands or config)
- The affected files or scripts

## Threat model

This repo runs scripts on your own machine. The primary threat surface is:

1. **The bootstrap one-liner itself.** `curl | bash` is trust by definition. You are executing code from a remote URL with your credentials. That is the intended usage, but it is not zero-risk.

2. **A compromised repo or CDN.** If this repository or GitHub's raw content delivery is compromised, the one-liner delivers attacker-controlled code.

3. **Supply chain.** The scripts call `brew install`, `npm install -g`, and `ollama pull`. Each of those introduces dependencies that this repo does not control.

This is not a corporate deployment tool. The intended user is a single developer running this on their own machine for their own setup. Fleet deployment, CI/CD integration, or any use in production infrastructure is explicitly out of scope and not supported.

## How to verify before running

```bash
# Read prepare.sh before executing it:
curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/kickoff-ai/main/prepare.sh | less

# Check readiness only — changes nothing:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/kickoff-ai/main/prepare.sh)" -- --check-only

# Clone and inspect before running:
git clone https://github.com/leonkoellerwirth-arch/kickoff-ai ~/dev/kickoff-ai
cd ~/dev/kickoff-ai && ./bootstrap.sh --dry-run
```

`--dry-run` prints every action bootstrap.sh would take without executing any of them. Use it to audit before committing.

## Built-in safeguards

- **Nothing destructive by default.** Scripts that delete files or uninstall tools require an explicit `--apply` flag or interactive confirmation. The default is always a dry run or a read-only check.
- **`RunAtLoad=false` on all launchd jobs.** Jobs in `automation/launchd/` do not start at login unless you explicitly enable them.
- **No secrets in the repository.** API keys, tokens, SSH keys, and passwords are excluded from the repo by `.gitignore`. The sanitization scan in `validate.yml` blocks PRs that accidentally include them.
- **Sanitization CI.** Every push runs a scan against `.github/sanitize-denylist.txt`. The deny list covers common secret patterns (tokens, private paths, email addresses).
- **`scripts/90-cleanup-legacy.sh` is opt-in.** The legacy cleanup script, which removes software, is never called automatically by `bootstrap.sh`. It must be invoked explicitly.

## Supported versions

This repo tracks a single moving setup. There is no long-term support for older versions. Security fixes are applied to `main`.
