# Contributing

Contributions to this repo are welcome. Most of them will be registry changes, not code — and that distinction matters for how they are reviewed.

## What contributions look like here

This is a single-developer setup repo. The value it provides is structure and honesty, not breadth. Before opening a PR, ask whether your change makes the _structure_ better or just adds another tool to an already long list.

### Registry changes (most common)

A tool addition, deprecation, or registry field correction starts with an issue:

1. Open a [Propose Tool](.github/ISSUE_TEMPLATE/propose-tool.md) or [Deprecate Tool](.github/ISSUE_TEMPLATE/deprecate-tool.md) issue. Fill in every field — a complete issue moves faster.
2. Add or update the entry in `manifests/tools.yaml`. The schema is in `manifests/schema.md`. Every field is required; `why` is not a formality.
3. Run consistency check:
   ```bash
   automation/bin/up2date --consistency --offline
   ```
   This must exit 0. It validates that `tools.yaml` entries match `Brewfile`, `Brewfile.optional`, and `automation/manifests/ollama-models.txt`.
4. Open a PR. The CI (`validate.yml`) repeats the consistency check and runs ShellCheck and the sanitization scan.

### Script changes

Scripts in `scripts/` and `automation/bin/` must meet these requirements:

- **Bash 3.2 compatible.** macOS ships bash 3.2 as `/bin/bash`. No arrays-of-arrays, no `mapfile`, no `declare -A` unless you verify the bash version first.
- **`set -euo pipefail`** at the top of every script.
- **ShellCheck clean.** Run `shellcheck <script>` before committing. The CI blocks on ShellCheck warnings.
- **`--dry-run` and `--help` are mandatory** for any script that changes system state. A script that has no dry-run mode will not be merged.
- **Nothing destructive as default.** Deletions, uninstalls, and overwriting config files must require an explicit flag (`--apply`, `--force`, or equivalent) or interactive confirmation via `confirm()` from `scripts/lib.sh`.

### Documentation changes

When you change a tool entry or a script, update the relevant `docs/` file in the same PR. If the change affects both English and German, update only the English file — the German files under `docs/de/` are a frozen snapshot and are not kept in sync.

## How to test locally what CI tests

CI runs no check logic of its own. `validate.yml` calls `scripts/gate.sh`, which
calls the scripts in `scripts/checks/` — so running the gate locally runs
*exactly* what CI runs, not an approximation of it.

```bash
# Everything CI checks, in the same order, with one verdict at the end:
./scripts/gate.sh

# What that consists of:
./scripts/gate.sh --list

# A single check in isolation (each one is a standalone executable):
./scripts/checks/sanitize.sh
./scripts/checks/sanitize.sh --list      # which files are in scope
./scripts/checks/registry-schema.sh

# Proof that the gate still blocks — runs it against a deliberately broken
# copy of the tree and asserts it fails:
./scripts/checks/self-test.sh
```

Every check exits `0` (pass), `1` (violation) or `2` (cannot run — a required
tool is missing). Exit 2 fails the gate: a check that cannot run has not passed.
Install the declared dependencies with `brew install shellcheck yq jq gitleaks`.

## Sanitization rules

This repo is published. Before pushing, verify that your changes contain no:

- Email addresses
- Paths like `/Users/<name>/…` — use `~/` or a placeholder
- Tokens, API keys, or secrets in any form
- Names of private projects or clients

The full rules are in [docs/05-SANITIZATION.md](docs/05-SANITIZATION.md). The CI sanitization scan checks against `.github/sanitize-denylist.txt`. You can extend the deny list locally with `local/sanitize-denylist-private.txt` (gitignored).

## Code of Conduct

This project follows the [Contributor Covenant 2.1](CODE_OF_CONDUCT.md). By participating you agree to abide by its terms.
