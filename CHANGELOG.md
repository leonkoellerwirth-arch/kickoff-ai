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

## [0.1.0] — 2026-08-11

### Added
- Initial commit: bootstrap system with modules 00–11 and 90
- Brewfile (core packages) and Brewfile.optional
- Configuration files (zshrc, gitconfig, vscode-extensions.txt)
- Documentation (docs/00 through docs/05 in German, QUICKSTART.md, README.md)
- Automation scripts (automation/bin/: dev-up, dev-down, mac-update, etc.)
- LaunchAgent templates (automation/launchd/)
- Ollama model manifest (automation/manifests/ollama-models.txt)
- `doctor.sh` for setup validation (41 checks)
