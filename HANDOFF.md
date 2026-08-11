# HANDOFF — kickoff-ai

Session handoffs, **newest entry first**. Written by `/session-stop` (via
`scripts/session-snapshot.sh`). Read the top entry at `/session-start`.

## 2026-08-11 — Public repository review

- **Done:** An independent high-rigor review of the public GitHub repository is
  available at `docs/reviews/2026-08-11-public-repository-review.md`. It first
  establishes the intended outcome and non-goals, then records 15 verified,
  evidence-backed findings with counter-checks and scoped actions. The review
  treats deliberate limits as decisions rather than defects.
- **Decided:** No implementation or policy decision was made from the review.
  Its prioritisation is input for a separate maintainer decision.
- **Open:** Address the release-blocking publication and execution-path risks
  (K1/K2), then choose the public trust-boundary, lifecycle and macOS-support
  decisions listed in the report.
- **Next:** Convert only approved review actions into narrowly scoped changes;
  use the report's acceptance criteria and rerun the gate after each change.
- **Continuity warnings:** `scripts/gate.sh` currently aborts before its
  promised `GATE: PASS`/`GATE: FAIL` verdict; the review captures the evidence
  and it must not be treated as a successful gate run.

## 2026-08-11 — Session 1 (repo built from zero and published)

_HEAD 9b59f9c · gate PASS · CI green · published public_

- **Done:**
  - Inventoried the owner's machine end to end (hardware, Xcode, ~275 brew formulae, Node/Python
    toolchains, 16 running containers, 4 AI CLIs, 58 repos under `~/dev`) and wrote it to
    `local/IST-INVENTAR.md` plus `local/rohdaten/` — private, gitignored.
  - Built the setup system: `bootstrap.sh` with cumulative levels 0–3, 14 single-runnable modules,
    `doctor.sh` with 41 level-filterable checks, `Brewfile{,.level0,.optional,.automation}`,
    `config/` dotfiles that fix the defects found in the live `.zshrc`.
  - Built the automation layer: 14 commands in `automation/bin/` (container lifecycle, disk
    hygiene, update sweep, snapshot drift, repo sweep, secret sweep, DB backup, ollama sync,
    env-run, up2date, sunset, migration-diff) plus 6 launchd jobs, all `RunAtLoad=false`.
  - Built the currency system: `manifests/tools.yaml` with 102 entries, the
    candidate→active→deprecated→sunset state machine, and 3 CI workflows.
  - Built the migration chain: `status-quo.sh` (export old machine) → `prepare.sh` (bare machine,
    curl one-liner, works with only macOS built-ins) → `migration-diff` (what is still missing).
  - Replaced 1Password with self-hosted Vaultwarden + Bitwarden CLI; rewrote `env-run` (631 lines)
    to do the env injection itself.
  - Wrote 10 English documents plus the German archive under `docs/de/`, the public pitch, and the
    community files. Translated all script output and comments to English.
  - Published: 106 files, ~23k lines, description + 15 topics set, CI green.
  - Adopted the `base` paved road via `base sync`; extended `scripts/gate.sh` with a shell surface.

- **Decided:** See the decision register in `BIBLE.md` — English-first, currency-system
  positioning, Vaultwarden over 1Password, OpenClaw sunset, uv over conda, levels 0–3, and the
  GitHub-account-name exception in the sanitization scan.

- **Open:**
  - Social preview image and the About website field (both GitHub web UI only).
  - 12 `candidate` registry entries need a human decision on whether they stay.
  - `mac-snapshot` reports 253 formulae installed but not in the Brewfile, and 124 the reverse —
    undecided which side to correct.

- **Next:**
  1. Run `./scripts/gate.sh` — it must print `GATE: PASS` before anything else.
  2. Decide the 12 `candidate` entries: `automation/bin/sunset list --status candidate`, then
     `sunset adopt <id>` or `sunset propose <id> --reason "..."`.
  3. If the machine is to be cleaned: `./scripts/90-cleanup-legacy.sh --dry-run` first — it backs
     up `~/.openclaw` (credentials, telegram, workspaces) before removing anything.
  4. Fix the two live `doctor.sh` FAILs: the OpenClaw LaunchAgent, and brew-git losing to
     `/usr/bin/git` in `PATH`.

- **Continuity warnings:**
  - **Nothing in this repo has been executed against the owner's machine** beyond dry runs and
    read-only checks. The machine is unchanged; every finding in `docs/02-GAP-ANALYSIS.md` is
    still open there.
  - `local/` holds the unsanitized inventory, raw command output, the private denylist and the
    migration profile. It is gitignored — verify with `git check-ignore` before ever changing
    `.gitignore`.
  - The sanitization scan only catches what the denylists know. When a new private project or
    client name enters the vocabulary, add it to `local/sanitize-denylist-private.txt` **before**
    writing about it.
  - Bugs found and fixed this session that could recur: `eval`-based `check()` in `gate.sh` will
    terminate the whole script if a check body calls bare `exit` (use a subshell); indented
    heredoc delimiters inside YAML `run:` blocks silently break the entire CI step; the registry
    consistency check must match tap-qualified *and* short cask names.
