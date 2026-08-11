# HANDOFF — kickoff-ai

Session handoffs, **newest entry first**. Written by `/session-stop` (via
`scripts/session-snapshot.sh`). Read the top entry at `/session-start`.

## 2026-08-11 — Review remediation + v0.2.0 released

_gate PASS (16 checks) · self-test PASS · doctor 42 checks · CI green · v0.2.0 public_

- **Done:** Every finding from `docs/reviews/2026-08-11-public-repository-review.md` is
  addressed, one commit per concern. Per-finding answer with commits and re-check commands:
  `docs/reviews/2026-08-11-response.md`.
  - **K1** identity now goes to `~/.gitconfig.local`; `git config --global` appears nowhere in
    the executable surface. doctor check 31 + `gitconfig-isolation.sh` guard it.
  - **K2** `seq 0 -1` counts down on BSD — that was the zero-findings crash. Cask versions were
    unreachable code. Exit 2 now means "could not complete" and never "clean".
  - **H7** the gate died before `gitleaks`, the customer-name scan and the verdict on any
    machine without PyYAML. Rebuilt as `scripts/checks/*` run as subprocesses; CI calls the
    same scripts. `self-test.sh` proves it blocks.
  - **H1/H9** `timeout` does not exist on stock macOS, so every scan silently did nothing and
    reported ok. `BW_SESSION` no longer passed in argv (also fixed in `db-backup`).
  - **H2/H3/H10** actions pinned to SHAs, release notes via `--notes-file`, private
    vulnerability reporting enabled, `main` protected by required checks.
  - **H4/H5** levels gate on registry status and level; bootstrap exits 0/1/2 and no longer
    claims "complete" before doctor has run.
  - **H6** `--help` exits before any action, unknown options exit 2, four dry-run leaks closed.
  - **M1–M5** quarantine opt-in, backup rotation opt-in, full schema validation, npm scopes
    preserved, overstated claims corrected.
  - Released **v0.2.0**. Validate and Release workflows both green on a fresh macos runner,
    including the self-test. Release notes carry the level-1 behaviour change first.
  - Fixed while cutting the release: `release.yml` read its notes from `[Unreleased]`, which is
    empty by the time you roll the changelog to tag — a correctly prepared release would have
    published empty notes. Now reads the tag's section. Both paths verified locally before
    tagging (59 lines for 0.2.0, 0 lines for a non-existent version, so the fallback is
    reachable).

- **Decided:** See the eight new entries in `BIBLE.md`. Owner decisions taken this session:
  only macOS 26.5 claimed as tested; `candidate` never auto-installed; `LSQuarantine` opt-in;
  `main` one-liner stays primary with a pinned path documented alongside; `main` protected by
  required checks with `enforce_admins: false`.

- **Open:**
  - Dry-run purity is not statically enforced — four leaks fixed by hand, the rest needs a
    temp-HOME filesystem diff in CI.
  - Vaultwarden template still `:latest` with open registration — needs a decision.
  - `docs/reviews/` is German in an English-first repo — translate, move, or make it an
    explicit exception.
  - The 12 `candidate` registry entries still need adoption decisions (carried over).

- **Next:**
  1. `./scripts/gate.sh` must print `GATE: PASS`, then `./scripts/checks/self-test.sh`.
  2. Watch the first CI run on the protected branch — the required check is named
     "Quality gate"; if the context name does not match, merges will hang.
  3. Decide the three open items above.
  4. The two live `doctor.sh` FAILs on the author's machine are still unfixed: the OpenClaw
     LaunchAgent, and `/usr/bin/git` beating brew-git in `PATH`.
  5. Nothing here has run end to end on a clean machine. That is the single biggest gap and the
     precondition for ever calling this 1.0.0.

- **Continuity warnings:**
  - Still nothing in this repo has been executed against the owner's machine beyond dry runs.
  - `main` now has branch protection. Required status checks block direct pushes as well as
    merges; `enforce_admins: false` is what keeps the maintainer able to push. Do not turn
    that on without switching to a PR workflow first.
  - The registry levels for docker/ollama/gemini-cli were changed 1 → 2 to match the README.
    If the README level table is ever revised, `Brewfile.level1` must be regenerated from the
    registry or the two will drift apart again.
  - `yq` is now a hard dependency of the gate. A machine without it fails every YAML-based
    check by design — that is the fail-closed behaviour, not a bug.
  - Rolling the changelog is now part of cutting a release: `release.yml` reads the section
    matching the tag. Tag without rolling and you get the `[Unreleased]` fallback, which is
    survivable but not what you want.
  - `VERSION` must equal the tag or `release.yml` aborts before creating anything. That check is
    deliberate; do not work around it.

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
