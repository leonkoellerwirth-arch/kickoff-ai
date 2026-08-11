# BIBLE — kickoff-ai

The stable mind of this repo: invariants and the decision register. Public-safe (no business
internals). Wins on any in-repo conflict. Change it deliberately, with a commit.

## Zone

Bridge — MIT open source, published at `github.com/leonkoellerwirth-arch/kickoff-ai`.
See `dev/base/CONSTITUTION.md` §1.

## What this repo is

A reproducible macOS developer environment, distilled from a verified inventory of one real
machine (Apple M2 Max, macOS 26.5, 58 repos, mixed AI/web/iOS stack). It installs in four
cumulative levels, verifies itself, tracks whether its own tool list is still true, and carries
a machine-to-machine migration path.

## Invariants

The rules that must never quietly break. Each is checked by `scripts/gate.sh` or
`.github/workflows/validate.yml` where possible.

- **INV-1 — Nothing installs or retires itself.** `up2date` reports drift; `sunset` records a
  decision; installation and removal are always a deliberate human step. The weekly CI may open
  a PR for `version_seen`/`reviewed` and an issue for rot, but never changes a `status`.
- **INV-2 — Nothing destructive by default.** Every command that can delete requires an explicit
  opt-in (`mac-clean --apply`, `scripts/90-cleanup-legacy.sh` never runs from `bootstrap.sh`).
  All launchd jobs carry `RunAtLoad=false`. Anything removable is backed up to
  `~/.setup-backups/<timestamp>/` first.
- **INV-3 — No personal data in the public repo.** Enforced by the sanitization scan
  (`.github/sanitize-denylist.txt` + `local/sanitize-denylist-private.txt`, with narrow
  exceptions in the allowlists). Machine-specific data lives in `local/`, which is gitignored.
  The only permitted identifying string is this repo's own clone URL.
- **INV-4 — Idempotence.** Re-running any module, any level, or the whole bootstrap changes
  nothing that is already correct. Existing dotfiles are backed up, never silently overwritten.
- **INV-5 — bash 3.2 compatibility.** macOS ships bash 3.2. No associative arrays, no `mapfile`,
  no `${var,,}`. `set -euo pipefail` everywhere; `--help` and `--dry-run` on every command.
- **INV-6 — The gate is not decorative.** `scripts/gate.sh` must actually fail on a broken repo.
  A gate that passes vacuously is worse than no gate. Verified by deliberately breaking a file.
- **INV-7 — Local gate and CI check the same things.** `scripts/gate.sh` and
  `.github/workflows/validate.yml` run the same shell surface so they cannot drift apart.
- **INV-8 — The registry is the single source of truth.** `manifests/tools.yaml` decides which
  tools belong to this setup. `Brewfile*`, `automation/manifests/*.txt` and
  `config/vscode-extensions.txt` are its implementation; `up2date --consistency` enforces
  agreement, and a `sunset` entry appearing in any install list is a hard error.
- **INV-9 — Secrets never touch the disk in plaintext.** `env-run` resolves references through
  the Bitwarden CLI and injects them into the target process environment only — never a file,
  never visible in `ps`.

## Decision register

Newest first. Each: date · decision · why · (superseded by …).

- **2026-08-11 — Adopted the `base` paved road.** `base sync` added the backbone scripts, session
  skills, `.editorconfig`, pre-commit config and CODEOWNERS. `scripts/gate.sh` was extended with
  a shell surface, because base's gate auto-detects only python and web repos and would have
  passed this repo without checking anything.
- **2026-08-11 — English is the repo language; German docs are a frozen archive.** The audience
  for a macOS setup repo is global, and the author's other public repos are English. The German
  originals stay under `docs/de/` and are explicitly not kept in sync.
- **2026-08-11 — Positioning: "setups rot, this one reports it".** The currency system is the
  differentiator, not the AI stack and not the dotfiles. Chosen over an AI-first and an
  audit-first framing.
- **2026-08-11 — Vaultwarden + Bitwarden CLI replace 1Password.** Owner wants an open-source,
  self-hosted secrets backend. `bw run --env-file` does not exist and `bws run` belongs to the
  proprietary Secrets Manager that Vaultwarden does not implement, so `env-run` performs the
  injection itself. `1password-cli` is `deprecated` in the registry with a sunset date.
- **2026-08-11 — OpenClaw is sunset.** Owner classified it as obsolete. Its npm packages, pnpm
  link, `~/.openclaw`, LaunchAgent, Homebrew tap and shell aliases are removed by
  `scripts/90-cleanup-legacy.sh` (opt-in, backs up `~/.openclaw` first — it contains credentials
  and workspaces).
- **2026-08-11 — uv replaces conda as the Python default.** The inventory found conda base at
  Python 3.10.9 with hundreds of packages installed into it. Miniforge stays optional for
  notebook work.
- **2026-08-11 — Levels 0–3 instead of one monolithic run.** Owner needs to be productive in
  ~15 minutes on a new machine; the rest can follow incrementally. Levels are cumulative and
  re-runnable.
- **2026-08-11 — The GitHub account name is a permitted exception** in the sanitization scan.
  The clone URL must appear in the repo or the one-liner on a fresh machine cannot work.
  Scoped to the URL pattern only; every other use of the name is still blocked.

## Open decisions

- **Social preview image.** `local/github-metadata.md` proposes a terminal screenshot of
  `bootstrap.sh --list-levels`. Can only be set through the GitHub web UI.
- **Website field** in the repo About panel is empty. Candidates: the owner's site, or
  `docs/07-CURRENCY.md` as a "read more" target.
- **Whether `omniroute` stays in the registry.** It is the owner's own published npm package;
  the name identifies him. Currently `candidate`.
- **Whether `mac-snapshot`'s findings get acted on.** It currently reports 253 installed formulae
  absent from the Brewfile and 124 the other way round. Nobody has decided which side is right.

## Continuity warnings

- The two `doctor.sh` FAILs on the author's own machine are real and unfixed: the OpenClaw
  LaunchAgent still exists, and `/usr/bin/git` still precedes brew-git in `PATH`. Nothing in this
  repo has been executed against that machine beyond dry runs.
- `manifests/tools.yaml` carries 12 `candidate` entries whose purpose could not be determined
  from the inventory. They are honest placeholders, not oversights — they need a human decision.
- The registry's `version_seen` values are a snapshot from 2026-08-10. The first weekly `up2date`
  run will surface drift as a PR.
