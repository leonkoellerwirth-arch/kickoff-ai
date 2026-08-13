# Changelog

All notable changes to this setup repo are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Semantics for this repo:
- **MAJOR** — Setup no longer backwards-compatibly reproducible
  (level boundaries changed, core module removed, Brewfile structure broken)
- **MINOR** — Tool added or module supplemented
- **PATCH** — Versions updated, documentation, fixes

---

## [Unreleased]

### Added

- **The Control Room — a local app.** `./start.sh` opens a dashboard, an ordered
  step-by-step guide, the tool registry as a searchable table, the drift report,
  the migration path and the repository's documents in the browser, all on
  127.0.0.1. Built for the person who should not have to read a repository to set
  up a Mac. See `docs/10-APP.md`.
  - Standard-library Python and hand-written HTML/CSS/JS: no framework, no npm,
    no build step. An app that guides you through installing Node cannot itself
    need Node, so its only requirement is `python3` — which arrives with the
    Xcode Command Line Tools that `prepare.sh` installs first.
  - It never installs anything itself. Read-only commands stream into the page;
    anything that changes the machine is handed to Terminal.app as a generated,
    readable script, so the run owns a real TTY for the sudo prompt and the user
    can watch it and stop it. INV-1 and INV-2 unchanged.
  - The browser sends an action name, never a command line. Each name maps to a
    fixed argument list, run without a shell; the only caller-supplied value is
    the setup level, validated to 0–3. `90-cleanup-legacy.sh` and
    `mac-clean --apply` have no button at all.
  - Local-access guards mirroring the rest of the repo: 127.0.0.1 only, a
    session token generated at startup, an Origin allow-list, a capped request
    body, and one action at a time.
- `scripts/checks/python-syntax.sh` — the Python equivalent of `bash -n`, wired
  into the gate. Compiles in memory rather than via `py_compile`, because the
  gate must not write `__pycache__` into the tree it is judging.
- **First Light (`scripts/12-first-light.sh`)** — the last step of the guide and
  the first one whose output is for the person rather than for the setup. It
  creates `~/dev/first-light/` with two sample files, has Claude Code or the
  smallest installed Ollama model read them and write a summary back, and opens
  the folder. Runs in about ten seconds. The folder and the prompt are
  hard-wired and the model is given no tools, no shell and no reach beyond the
  two files — a first contact with an AI model should happen inside a fence that
  can be read in one file.
- **`manifests/counts.json`** — the repo's headline numbers, generated from the
  sources by `scripts/checks/counts.sh --write`. The README, the docs and the
  app read from it; the same script runs in the gate and fails when the prose
  and the code disagree.
- **`docs/11-GOVERNANCE-PATTERN.md`** — the pattern underneath the repo written
  up on its own: declared inventory, lifecycle states, machine detection with
  human decision, read-only verification, traceability. Includes a table naming
  what is *not* claimed for each element. Nothing here has been audited.
- `scripts/checks/registry-privacy.sh` — fails the gate when the public registry
  starts describing one specific machine again.
- **`docs/12-OPERATOR-PLAYBOOK.md`** — instructions for a general-purpose agent
  asked to set up someone's Mac with this repository. It sorts every action into
  three classes (run freely / announce and wait for a yes / never run), walks the
  standard path, covers the deviations, and says what to report at the end. The
  classes match the badges the Control Room shows a human — the same boundary,
  drawn twice.
- `CLAUDE.md` and `AGENTS.md` now open with a role switch: operator (using this
  repo on a machine) or contributor (changing this repo). An agent has to know
  which set of rules applies before it does anything, and the two were previously
  not distinguished at all.

- **`scripts/capture-screenshots.py`** — regenerates the Control Room images in
  `docs/img/` with headless Chromium, and moves the machine-specific registry
  overlay aside while it does, so a published screenshot can only ever show the
  public registry. Playwright is a maintainer dependency; the setup, the gate and
  the app remain free of it.

### Fixed

- **The Control Room was invisible from the terminal.** Nothing on the
  command-line path mentioned it: `prepare.sh` handed straight to `bootstrap.sh`,
  and neither `bootstrap.sh` nor `doctor.sh` ever named `./start.sh`. Someone
  arriving through the one-liner — the audience the app exists for — would never
  find out it was there. `bootstrap.sh` now closes by naming it, and
  `prepare.sh --no-bootstrap` offers it as the guided route before the
  command-line one.
- **`./start.sh` no longer dead-ends on a fresh Mac.** When `python3` is missing
  it used to say "run `./prepare.sh`" and exit. It now explains what the Command
  Line Tools are and offers to install them, asking first — installing is a
  change to the machine, and the app's promise is that it never makes one
  unasked. With no terminal to ask on, it prints both manual routes instead of
  hanging, and a `--dry-run` says what it would offer without offering it.
- **`--dry-run` no longer asks questions, and no longer aborts without a
  terminal.** `confirm()` read from `/dev/tty` even during a preview, so a level-1
  dry run stopped at module 08 with `/dev/tty: Device not configured` and never
  showed modules 09 to 11. Anything without a terminal hit this: the Control
  Room's own preview button, CI, and any agent driving the repo. A dry run now
  answers its own questions (it is previewing something that will not happen),
  and a missing terminal is treated as "no" with a clear message instead of a raw
  bash error. `08-git-ssh.sh` and `11-paved-road.sh` had the same pattern outside
  `confirm()` and were fixed the same way.
- The Control Room no longer reports a preview as failed when `bootstrap.sh`
  exits 2. Exit 2 means "modules ran, `doctor.sh` found something on the machine",
  which during a preview is the preview working correctly.
- The Control Room's "changes nothing" badge now reads "changes nothing on this
  Mac", which is what it always meant — some of those actions do write a report
  into `local/`.

### Changed

- **The tool registry is split.** `manifests/tools.yaml` is now a curated public
  reference of 92 entries. Eleven entries that were raw inventory findings from
  one machine ("Origin unclear — found in global npm packages") moved to
  `local/manifests/tools.local.yaml`, which is gitignored. Four remaining
  entries had personal decision notes rewritten as statements of fact. Every
  reader — `up2date`, `sunset`, `migration-diff`, the Control Room — reads the
  public file with the local one laid on top, so nothing is lost locally while
  the published manifest stops being a report on somebody's laptop. Rationale in
  `docs/07-CURRENCY.md`.
- **The numbers agree now.** Three places claimed three different sizes for the
  same repo (41/100, 42/102, 42/103). Counted: 42 doctor checks, 92 public
  registry entries. README, `QUICKSTART.md`, `docs/00-ZERO-TO-HERO.md` and
  `docs/01-MANUAL.md` corrected.
- **`docs/02-GAP-ANALYSIS.md` → `docs/02-EXAMPLE-ASSESSMENT.md`**, rewritten as a
  historical example report about an anonymous scanned system rather than a live
  self-disclosure. Findings A.9, A.14, A.17 and B.1 abstracted further. Structure
  and methodology unchanged; a stub remains at the old path.
- **README reordered around what the repo now is:** a guided start line with a
  verification underneath. The two entry paths lead, `./start.sh` first;
  "Who It's For" addresses the person the Control Room was built for before the
  reader who is here for the pattern. "What This Is Not" gained the conformity
  disclaimers.
- `scripts/checks/internal-briefing.sh` also refuses tracked work orders
  (`*auftrag*`), which arrive in `docs/` the same way briefings do.

## [0.2.0] — 2026-08-11

Remediation of the 2026-08-11 public repository review. All 15 findings
addressed; see `docs/reviews/2026-08-11-response.md` for the per-finding answer
with commits and re-check commands.

**Behaviour change:** level 1 now installs `Brewfile.level1` instead of the full
`Brewfile`. A level-1 run therefore installs 25 fewer packages than before — the
ones the README always placed at level 2 or 3. Re-run at the level you actually
want; levels remain cumulative and re-running is safe.

### Security
- Git identity and machine-local paths are written to `~/.gitconfig.local`, never through the
  `~/.gitconfig` symlink into the tracked `config/gitconfig`. A normal setup could previously
  stage the operator's name, email and absolute paths for commit in this public repo (K1)
- `secret-sweep` no longer reports "ok" for repos it could not scan: `timeout` is absent on
  stock macOS, so every gitleaks call failed silently. Scans run via a portable timeout,
  scanner failures exit 2, and reports carry rule/file/line instead of the matched value (H1)
- `BW_SESSION` is inherited from the environment instead of passed as `--session` in argv,
  where any local process could read it via `ps` — in `env-run` and `db-backup` (H9)
- Release notes are passed via `--notes-file`; CHANGELOG content is no longer interpolated
  into a shell step holding `contents: write`, and the `$GITHUB_OUTPUT` heredoc delimiter can
  no longer be closed from the changelog (H3)
- All third-party GitHub Actions pinned to commit SHAs (H2)
- Private vulnerability reporting enabled; `main` protected by a required `Quality gate` check
  (H2, H10)
- Download quarantine is no longer disabled by default — `--relax-download-quarantine` (M1)

### Fixed
- The hard gate ran under `eval` with a bare `exit`, so on any machine without PyYAML it died
  after four checks — skipping the secret scan, the customer-name scan and the verdict itself.
  Checks are now standalone scripts run as subprocesses, a missing tool fails instead of being
  skipped, and exactly one verdict is always printed (H7)
- The currency check crashed on zero findings (`seq 0 -1` counts down on BSD), never read cask
  versions (`jq` exits 0 with empty output, so the `||` fallback was dead code), and exited 0
  after unreachable upstreams. Exit 2 now means "could not complete" (K2)
- `bootstrap.sh` aggregates module and doctor failures and exits 0/1/2 instead of always 0;
  the completion banner no longer claims success before verification runs (H5)
- Levels are real boundaries: installs gate on registry `status=active` and `level<=selected`,
  so `candidate` entries are never installed by a default run, and level 1 uses the new
  `Brewfile.level1` instead of the full stack (H4)
- `--help` exits before any action and unknown options exit 2 in all 13 modules; four
  filesystem writes that ran even under `--dry-run` now go through the dry-run abstraction (H6)
- npm scopes survive snapshot, profile and diff — `@openai/codex` was becoming `codex` (M4)
- `db-backup` only reports what is past retention; deleting requires `--prune` (M2)
- The gate itself rewrote the tracked `manifests/STATE.json` on every run, because two of its
  checks invoke `up2date`. It promised to change nothing and dirtied the very tree it was
  judging. `STATE_JSON` is now overridable and both checks redirect it; `self-test.sh` compares
  the tree before and after and fails if the gate touched anything
- `release.yml` read its notes from the `[Unreleased]` section — the one you empty when rolling
  the changelog to cut a release — so a correctly prepared release would have shipped with empty
  notes. It now reads the section matching the tag and falls back to `[Unreleased]`. Found while
  cutting this release; the published v0.2.0 notes predate this line.

### Changed
- CI contains no check logic of its own: `validate.yml` calls `scripts/gate.sh`, which calls
  `scripts/checks/*`. Running the gate locally runs exactly what CI runs (H7, INV-7)
- Sanitization covers every tracked text file via git's binary detection instead of a
  file-extension allowlist, which had been skipping 31 files including `config/gitconfig`, all
  extension-less CLIs and `.env.example`. gitleaks now runs in CI (H8)
- Registry validation enforces all 15 required fields and all 12 documented rules; previously
  only `added` was date-checked (M3)
- `yq` is a declared dependency (Brewfile + registry); the undeclared PyYAML path is gone
- Corrected overstated claims: macOS badge 26+ → "26.5 tested" with untested versions named,
  "Pinned core packages" → "declared", "reproduced exactly one year from now" → structurally
  reproducible with visible drift (M5)
- `doctor.sh`: 41 → 42 checks (new check 31, tracked git config template unmodified)

### Added
- `scripts/checks/` — 16 gate checks, each a standalone executable with a 0/1/2 exit contract
- `scripts/checks/self-test.sh` — runs the gate against a deliberately broken tree and asserts
  it fails, including that an early failure does not stop the later security checks (INV-6)
- `Brewfile.level1` — level 1 stack derived from the registry
- `tests/fixtures/` — negative fixtures for the registry validator and the brew version parser

## [0.1.0] — 2026-08-11

### Added
- Paved-road adoption via `base sync`: backbone scripts (`gate.sh`, `secure.sh`, `budget.sh`, `session-snapshot.sh`, `state.sh`, `context.sh`), session skills under `.claude/skills/`, `.editorconfig`, `.pre-commit-config.yaml`, `.github/CODEOWNERS`
- `BIBLE.md` — repo invariants (INV-1 … INV-9) and decision register
- `HANDOFF.md` — session log, newest entry first
- `scripts/gate.sh` shell surface — bash syntax, shellcheck, plist lint, YAML parsing, workflow run-block syntax, and registry consistency; mirrors the CI so local and CI cannot drift
- `prepare.sh` — zero-dependency entry point for brand-new machines; checks readiness, installs CLT, clones repo, hands off to `bootstrap.sh`; supports `--check-only`, `--profile`, `--no-bootstrap`
- `status-quo.sh` — read-only export of current machine state to `local/status-quo/<date>/`; produces `profile.json`, `repos.md`, `STATUS-QUO.md`, `manuell.md`
- `automation/bin/migration-diff` — compares `profile.json` from old machine with current machine state; reports missing, new, version-different, and intentionally retired tools; exits 1 when gaps remain
- `docs/09-MIGRATION.md` — full migration workflow: export → transport → check → setup → diff
- English documentation layer: `docs/00-ZERO-TO-HERO.md` through `docs/09-MIGRATION.md`
- German documentation moved to `docs/de/`
- `QUICKSTART.md` (English) with `prepare.sh` one-liner for bare machines
- `README.md` rewritten as English pitch
- `README.de.md` — German equivalent of the new README
- `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md` — community files
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/propose-tool.md`, `deprecate-tool.md` (English)
- Secrets guide `docs/08-SECRETS.md`: full guide to Vaultwarden + Bitwarden CLI + env-run
- `bitwarden-cli` in `manifests/tools.yaml` (source: brew, status: active)
- `vaultwarden` in `manifests/tools.yaml` (source: manual/Docker, status: active)
- Template directory `templates/vaultwarden/` with docker-compose.yml, .env.example, Caddyfile.example, .env.template.example
- Tool registry `manifests/tools.yaml` with 102 entries from the verified inventory (2026-08-10)
- Schema documentation `manifests/schema.md`
- Registry documentation `manifests/README.md`
- State machine script `automation/bin/sunset` (propose/confirm/revive/adopt/list)
- Upstream checker `automation/bin/up2date` (check/consistency/apply-versions)
- Shared library `automation/lib-currency.sh`
- GitHub Actions workflow `validate.yml` (quality gate on push/PR)
- GitHub Actions workflow `up2date.yml` (weekly currency check — Monday 08:00 UTC)
- GitHub Actions workflow `release.yml` (versioning via tag)
- Dependabot configuration for GitHub Actions
- Sanitization deny list `.github/sanitize-denylist.txt`
- Currency system documentation `docs/07-CURRENCY.md` (English) / `docs/de/07-AKTUALITAET.md`
- `VERSION` file (SemVer, starting at 0.1.0)

### Changed
- `automation/bin/env-run`: fully migrated to Vaultwarden/Bitwarden CLI; own `bw://` reference resolution with subprocess injection replaces `op run`; new subcommands `check` and `--dry-run`; optional `--serve` fast path
- `docs/02-GAP-ANALYSIS.md` finding B.1: solution updated to Vaultwarden + env-run
- `docs/01-MANUAL.md`, `docs/00-ZERO-TO-HERO.md`: secrets migration updated to Vaultwarden workflow
- `docs/06-AUTOMATION.md`: env-run section updated to Vaultwarden workflow
- `Brewfile`: `1password-cli` replaced by `bitwarden-cli`
- `automation/bin/db-backup`: credential fallback switched from `op` to `bw`
- `automation/bin/secret-sweep`: recommendation updated to Vaultwarden + env-run
- `CHANGELOG.md`: converted from German to English

### Deprecated
- 2026-08-11: 1Password CLI (`1password-cli`): marked deprecated — replaced by bitwarden-cli + self-hosted Vaultwarden. Decision: data sovereignty, no SaaS subscription. Sunset: 2026-11-09
- 2026-08-11: OpenClaw npm package (`openclaw-npm`): marked deprecated — `OPENCLAW_PATH` points to non-existent directory; all aliases are dead ends; classified as legacy by owner. Sunset: 2026-08-08
- 2026-08-11: clawhub npm package (`clawhub`): marked deprecated — part of the OpenClaw ecosystem; removed together with OpenClaw. Sunset: 2026-08-08
- 2026-08-11: OpenClaw Gateway LaunchAgent (`openclaw-gateway-launchd`): marked deprecated — LaunchAgent for OpenClaw gateway daemon; removed with OpenClaw. Sunset: 2026-08-08
- 2026-08-11: Homebrew Tap openclaw/tap (`openclaw-tap`): marked deprecated — Homebrew tap for OpenClaw packages; removed with OpenClaw. Sunset: 2026-08-08
- 2026-08-11: goplaces (`goplaces`): marked deprecated — GPS/Maps tool from the OpenClaw tap; tap is being removed. Sunset: 2026-08-08
- 2026-08-11: MariaDB LaunchAgent (`mariadb-launchd`): marked deprecated — orphaned LaunchAgent; mariadb no longer installed. Sunset: 2026-08-08
- 2026-08-11: PostgreSQL 14 (`postgresql-14`): marked deprecated — Brewfile updated to @17. Sunset: 2026-11-09

---

## [0.0.1] — 2026-08-10 (pre-release scaffold, never tagged)

### Added
- Initial scaffold: bootstrap system with modules 00–11 and 90
- Brewfile (core packages) and Brewfile.optional
- Configuration files (zshrc, gitconfig, vscode-extensions.txt)
- Documentation (docs/00 through docs/05 in German, QUICKSTART.md, README.md)
- Automation scripts (automation/bin/: dev-up, dev-down, mac-update, etc.)
- LaunchAgent templates (automation/launchd/)
- Ollama model manifest (automation/manifests/ollama-models.txt)
- `doctor.sh` for setup validation (41 checks)
