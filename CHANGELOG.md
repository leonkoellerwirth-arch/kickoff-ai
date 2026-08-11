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

_Nothing yet._

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
