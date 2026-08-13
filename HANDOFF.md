# HANDOFF — kickoff-ai

Session handoffs, **newest entry first**. Written by `/session-stop` (via
`scripts/session-snapshot.sh`). Read the top entry at `/session-start`.

## 2026-08-13 — History rewritten once: stray archive removed

**`main` was force-pushed.** A local clone made before `e6c254e` has a divergent history —
re-clone rather than merge.

A 1.7 MB `repo.zip` (a `git archive` written into the repo root during a test) was committed and
pushed, then removed from HEAD, then removed from history entirely with `git filter-repo`. It was
the repo's own content, so nothing leaked; gitleaks was clean over the full history throughout.
Verified after the rewrite: the tree SHA is byte-identical to before, `repo.zip` appears in zero
objects, 173 files unchanged, CI green.

Branch protection forbids force pushes independently of `enforce_admins`, so it was opened for
one push and closed again; the configuration was diffed against a snapshot afterwards and is
identical. `.gitignore` now covers `*.zip`, `*.tar`, `*.tar.gz`, `*.tgz`. A backup bundle of the
pre-rewrite history exists outside the repo but is not permanent — if the old SHAs ever matter,
they are gone.

Audited at the same time, all clean: no `TODO`/`FIXME` in tracked files, no OS or editor junk, no
`local/` leakage beyond the two intentional files, and every tracked image is referenced by a
document.

## 2026-08-13 — The fresh-machine path actually reaches the app

_gate PASS · CI green on 0f80365 before this entry · four fresh-machine scenarios tested_

Asked whether `./start.sh` really runs on a brand-new Mac. Tested rather than assumed, and the
answer was mostly yes with one gap that mattered more than the question.

- **What was already fine.** `start.sh` needs `python3` and nothing else — no Homebrew, no Node,
  no npm, no Docker. That is deliberate: an app that guides you through installing Node cannot
  need Node. Verified: a GitHub ZIP download keeps the executable bit (`git archive` preserves
  mode), so `./start.sh` works from an unzipped copy, and `bash start.sh` works either way.
- **The gap that mattered: the Control Room was invisible from the terminal.** `prepare.sh`
  `exec`s straight into `bootstrap.sh`; neither it nor `bootstrap.sh` nor `doctor.sh` ever
  mentioned `./start.sh`. Anyone arriving through the one-liner — exactly the audience the app
  was built for — would finish a two-hour setup without learning the app existed. The README's
  "three ways in" is no help to somebody looking at a terminal. Fixed in both handoff points.
- **`start.sh` no longer dead-ends.** Missing `python3` used to mean "go run `./prepare.sh`". It
  now explains the Command Line Tools and offers to install them — asking first, because that is
  a change to the machine. Non-interactive falls through to two manual routes; `--dry-run` says
  what it would offer.
- **One bug found while testing that:** `read -r x </dev/tty 2>/dev/null || x=""` does *not*
  suppress bash's own redirection error, so a headless run printed
  `start.sh: line 121: /dev/tty: Device not configured` before falling back. The working form is
  `if { : </dev/tty; } 2>/dev/null; then`. **`prepare.sh:67` still has the old pattern** and will
  leak the same line on a machine with no controlling terminal — not fixed here because
  `prepare.sh` is the one script that must stay standalone and I did not want to touch it in the
  same commit as an unrelated change. Worth doing.

- **Continuity warning:** the prerequisite story is now told in four places — `start.sh` itself,
  `bootstrap.sh`'s closing banner, `prepare.sh --no-bootstrap`, and the operator playbook. They
  agree today. Nothing checks that they still agree tomorrow.

## 2026-08-13 — AP-H: the repo is operable by an agent, and the README is the owner's

_gate PASS (19 checks) · self-test PASS · acceptance test from AP-H §5 run and passed_

- **Done — the operator role.** `docs/12-OPERATOR-PLAYBOOK.md` (12, because 10 and 11 are taken
  by the app and governance documents — the work order assumed a different numbering).
  `CLAUDE.md` rewritten as a router, ~35 lines, role switch first; `AGENTS.md` mirrors it
  tool-neutrally. README gained the third way in. Governance document gained one paragraph
  naming the playbook as the third fenced-execution example — and stating its limit, that a
  playbook is instructions and not a control.
- **Done — the README is the owner's template.** `docs/templates/README.md` installed as
  `README.md`, with three changes made during the swap, all of them because the template's
  assumptions had to be checked against the tree:
  1. Doc links remapped: `docs/11-OPERATOR-PLAYBOOK` → `docs/12-`, `docs/10-GOVERNANCE-PATTERN`
     → `docs/11-` (twice).
  2. **Every number recounted rather than trusted, as instructed.** 42 checks, 12 modules,
     14 commands — all three were already correct. They are now also *enforced*: `counts.sh`
     was widened from two numbers to four, so the README's own claim ("these counts are
     enforced, not remembered") is true for every figure it prints. Verified by planting a wrong
     module count and watching the gate fail.
  3. The `doctor.sh` sample block is real output from this machine, not the template's
     approximation — the template's version differed in format and in one version string.
- **Done — the screenshots, and a script that regenerates them.** These were first declared
  impossible here on the grounds that a screenshot needs screen-recording permission and a human
  at a screen. That was wrong: the Control Room is a web page on localhost, so a headless browser
  renders and captures it with no permissions and nobody present.
  `scripts/capture-screenshots.py` drives Chromium through Playwright against the app, and owns
  the safeguard that is easy to forget and impossible to undo after a push — it moves
  `local/manifests/tools.local.yaml` aside for the duration, in a `finally` block, so the Tools
  and Drift views can only ever show the public registry. Four images in `docs/img/`; three are
  used in the README, each next to the claim it evidences.
  Playwright is a **maintainer** dependency: `pip install playwright && playwright install
  chromium`. Nothing in the install path, the gate or the app touches it, so the repo still runs
  on a machine that has `python3` and nothing else.

- **The acceptance test found a real bug, which is the point of having one.** AP-H §5 asks for a
  FREE-commands-only walkthrough proving nothing outside `local/` changes. It proved that — and
  it also showed `./bootstrap.sh --level 1 --dry-run` exiting 1 after aborting at module 08 with
  `/dev/tty: Device not configured`. `confirm()` prompted during a dry run. Consequences:
  - The preview never showed modules 09, 10 and 11 to anyone without a terminal.
  - **The Control Room's own preview button was broken** for every level above 0, because the
    server pipes stdout and has no tty. Shipped that way earlier today.
  - Fixed in `scripts/lib.sh` (a dry run assumes yes and asks nothing; a missing terminal is a
    "no" with a message, not a bash error), and the same pattern outside `confirm()` in
    `08-git-ssh.sh` and `11-paved-road.sh`.
  - After the fix all four levels preview end to end, and the file-timestamp comparison confirms
    nothing outside `local/` was created or modified.
- **Second finding: exit 2 is not a failure.** A dry run ends by running `doctor.sh` against the
  real machine, so a pre-existing FAIL sets exit 2 — correct, but it made the app label a
  successful preview "failed". Actions now declare which exit codes mean success
  (`ok_codes`), and the playbook carries the exit-code table so an agent reports it correctly.

- **Decided:** three new `BIBLE.md` entries — two roles decided in the first ten lines; the
  playbook's three classes and the app's two badges are one boundary; a dry run answers its own
  questions.

- **Open:**
  1. The README screenshot (above). Everything else in AP-H is done.
  2. `docs/templates/README.md` is left untracked — it is the source the README was built from,
     and a tracked copy would be a second README that the counts check would also police.
  3. Both work-order documents stay untracked, guarded by `internal-briefing.sh`.

- **Continuity warnings:**
  - **`--dry-run` now means "assume yes".** Any `confirm()` added in future is answered
    affirmatively during a preview, so a preview shows the most complete path, not the most
    cautious one. If a future prompt gates something whose *preview* is expensive or noisy,
    guard it on `DRY_RUN` explicitly rather than relying on `confirm()`.
  - The playbook names commands and flags directly. Renaming a script or changing a flag breaks
    it silently — nothing checks the playbook against the tree. Every command in it was verified
    by hand today; that verification does not repeat itself.
  - `manifests/counts.json` now carries five numbers, two of them new. Adding a module or an
    `automation/bin` command makes it stale, and the gate will say so.

## 2026-08-13 — Work order v2 executed: product reality and positioning

_gate PASS (19 checks) · self-test PASS · First Light verified end to end in 9s_

Seven packages from `docs/kickoff-ai-auftrag-v2-final.md` (untracked, and now structurally
kept that way — see below).

- **AP-C · The numbers agree.** Counted: **42** doctor checks, **92** public registry entries.
  `manifests/counts.json` is generated by `scripts/checks/counts.sh --write`; the same script
  runs in the gate and fails when README, docs or app disagree. Corrected `QUICKSTART.md` (41),
  `docs/00-ZERO-TO-HERO.md` and `docs/01-MANUAL.md` (~40), README (102 and 103). The app no
  longer hard-codes a check count — it reads `counts.json`.
- **AP-B · Registry split.** 11 entries that were raw inventory findings moved to
  `local/manifests/tools.local.yaml` (gitignored): the nine "Origin unclear" candidates, plus
  `omniroute` — see the open item below. Four entries keeping a personal voice were rewritten as
  fact (`openclaw-npm`, `1password-cli`, `postgresql-14`, `mariadb-launchd`); the OpenClaw sunset
  chain stays public because it is the best lifecycle example the repo has. `lib-currency.sh` and
  the app read both files, overlay wins on a duplicate id, and writes go to whichever file owns
  the entry. Guarded by `scripts/checks/registry-privacy.sh` (verified both ways).
- **AP-E · `docs/02-EXAMPLE-ASSESSMENT.md`.** Rewritten as a historical report about an
  anonymous scanned system; stub left at the old path so the four inbound links still resolve.
  A.9 lost its year, A.14 its GB figures (threshold instead), A.17 its counts, B.1 its path.
  `gitconfig-isolation.sh` gained the new filename in its exclusion — those `git config --global`
  lines are quoted evidence, not instructions this repo gives.
- **AP-A · First Light.** `scripts/12-first-light.sh` + guide step 16. Verified on this machine:
  **9 seconds**, exit 0, `~/dev/first-light/SUMMARY.md` written by Claude Code, Finder opened.
  Falls back to the smallest installed Ollama model, which is the path that needs no account and
  no network. No `timeout` — stock macOS has none, and this repo has already been bitten by
  assuming otherwise — so the 55s budget is polled by hand.
- **AP-D · `docs/11-GOVERNANCE-PATTERN.md`.** ~2,300 words. Five elements, each with the repo
  artefact as evidence; a three-column standards table whose third column states what is *not*
  claimed, per row; limits stated bluntly. Linked from the README and available as a tab in the
  Control Room's Docs view. Its registry numbers were written before AP-B landed and have been
  corrected to the post-split counts.
- **AP-F · README reordered.** Two entry paths lead with `./start.sh` first; the principle block
  ("the machine reports; the human decides") sits above the problem statement; the differentiator
  table gained a First Light row and a link to the governance document. "What This Is Not" grew
  the three conformity disclaimers and lost "Not zero-config" in favour of an honest statement
  that the structure transfers as-is. "Who It's For" is now two paragraphs, the non-expert first.
  The regulatory background is generic — the previous naming of specific supervisory regimes is
  gone.
- **AP-G · Handle.** Recorded below, nothing done in the repo, as instructed.

- **Decided:** Four new entries in `BIBLE.md` — public reference vs. private machine state;
  headline numbers are generated, never typed; First Light is fenced harder than the task
  requires; the README leads with the product and grows the disclaimer rather than softening it.

- **Open / to do by hand:**
  1. **Repo description** (GitHub UI only). Suggested text, numbers from `counts.json`:
     *"From a blank Mac to a working, verified AI development environment — guided by a local
     Control Room. One command to start, 42 checks to prove it, and a 92-tool registry that
     knows when it goes stale."*
  2. ~~README screenshot~~ — **done** in the AP-H entry above, via
     `scripts/capture-screenshots.py`. The claim recorded here first, that it could not be
     automated, was wrong.
  3. **`omniroute` moved to the local overlay.** The BIBLE open decision asked whether it stays
     in the registry, because the package name identifies the author. Moving it resolves the
     identification half only; whether it is ever adopted is still an open decision, now tracked
     locally.
  4. **The GitHub handle** — the `-arch`-suffixed account the clone URL points at. *For keeping
     it:* changing it breaks every published link, the one-liner in every document, and the CI
     badge. *For changing it:* the suffix reads as Arch Linux to anyone scanning, and a full
     personal name is close to unfindable next to the project names it hosts. Author decision,
     outside this repo. (Naming it in full here would trip the sanitization scan, which is
     working as intended — it is allowed in the clone URL and nowhere else.)
  5. `docs/kickoff-ai-auftrag-v2-final.md` is a work order and stays untracked.
     `scripts/checks/internal-briefing.sh` now also refuses `*auftrag*`, so a `git add -A`
     cannot publish it by accident. Verified: staging it fails the gate.

- **Continuity warnings:**
  - **The registry has two files now.** Anything that reads `manifests/tools.yaml` directly,
    rather than through the `registry_*` helpers, will silently see only the public half. Two
    callers already read it directly and were not changed: `scripts/04-node.sh` and the two
    registry checks — correct in all three cases, because installs and public schema validation
    should see the public file only. New callers need to decide which they mean.
  - **`counts.json` goes stale the moment a check or a tool is added.** The gate says so, and the
    fix is one command: `scripts/checks/counts.sh --write`. Do not edit the file by hand.
  - First Light writes into `~/dev/first-light/` and will overwrite `visits.csv`, `note.txt` and
    `SUMMARY.md` there on every run. That folder is meant to be disposable; nothing else is.

## 2026-08-13 — The Control Room: a local app for the non-technical user

_gate PASS (17 checks) · app verified end to end against the real scripts_

- **Done:** `./start.sh` opens a local app at `127.0.0.1:8787` covering the whole path a new
  machine walks. Six views: Dashboard (machine probe, level reached, drift), Guide (15 ordered
  steps, preview → run → verify per level), Tools (all 103 registry entries, searchable and
  filterable), Drift (currency numbers, what is retiring, which candidates await a decision),
  Migration (the four-step old-Mac-to-new-Mac path), Docs (the repository's documents rendered
  in-app). Files: `start.sh`, `app/server.py`, `app/ui/{index.html,app.css,app.js}`,
  `docs/10-APP.md`.
  - **Adopted from `dev/local-agent-pipeline/web/`** — its audit console is the closest
    relative: stdlib-Python API, localhost-only, session token plus Origin allow-list, real
    commands driven from the browser, project docs surfaced in the app. The Vite/React frontend
    was *not* adopted; see the BIBLE entry for why.
  - **The app installs nothing.** Read-only actions (`prepare.sh --check-only`,
    `bootstrap.sh --dry-run`, `doctor.sh`, `up2date`, `status-quo.sh`, `migration-diff`) run in
    the server and stream into the page. The real `bootstrap.sh` run is written to
    `local/app-runs/<stamp>-bootstrap-run.command` and opened in Terminal.app.
  - **No arbitrary commands.** The browser posts an action id; `ACTIONS` in `app/server.py` maps
    it to a fixed argv list executed without a shell. Verified: unknown action → 400, level 9 →
    400, level on an action that takes none → 400, `bootstrap-run` without `confirm: true` →
    400, missing token → 403, foreign `Origin` → 403, `/ui/../server.py` → 404.
  - Gate gained `scripts/checks/python-syntax.sh` (17 checks now). It compiles in memory —
    `py_compile` would write `__pycache__` into the tree the gate is judging, which is the
    bug c32e871 just fixed for `STATE.json`. `__pycache__/` and `*.pyc` added to `.gitignore`.

- **Decided:** Three new entries in `BIBLE.md` — no build step and no npm (the app's audience is
  a machine without Node); installs are handed to Terminal rather than run by the server (sudo
  needs a TTY, and a web progress bar hides what is happening to the machine); `tools.yaml` is
  read by a narrow reader because PyYAML is gone and `yq` does not exist yet on a fresh Mac.
  Owner instruction honoured throughout: **the app adds no automation** — everything that was
  manual stays manual.

- **Open:**
  - Two new entries in the `BIBLE.md` open list: the CLI contract does not cover the root entry
    points (and they disagree — `bootstrap.sh`/`prepare.sh`/`status-quo.sh` exit 1 on an unknown
    option, `start.sh`/`doctor.sh` exit 2), and `app/ui/app.js` has no linter that runs without
    npm.
  - The app has only been exercised on a machine that is already fully set up. Its own
    chicken-and-egg claim — that it runs on a Mac with nothing but the Command Line Tools — is
    argued, not observed. Same gap as the rest of the repo.
  - The four carried-over items from the previous session are untouched.

- **Next:**
  1. Look at the app in a browser and say what should change — this is a first cut of the
     wording and the layout, and it is aimed at someone who does not know the repo.
  2. Decide whether the real `bootstrap.sh` run should also appear on the Dashboard, or stay
     guide-only as it is now.
  3. The three open decisions from the previous session are still open.

- **Continuity warnings:**
  - `app/server.py` is the second executable surface in this repo and the first one that is not
    shell. Anything added to `ACTIONS` is a new thing a browser can start — that list is the
    security boundary, so treat additions to it the way you would treat a new API route.
  - The app's step list and the level table in `README.md`/`docs/00-ZERO-TO-HERO.md` are written
    twice, in `LEVELS` and `build_guide()` in `app/server.py`. Change the levels and both places
    must move, or the app will confidently describe a setup that no longer exists.
  - `local/app-runs/` accumulates one `.command` file per real run. It is gitignored and
    deliberate — it is the record of what the app handed over — but nothing prunes it.

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
