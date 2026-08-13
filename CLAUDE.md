# CLAUDE.md — kickoff-ai

## Which role are you in? Decide this first.

**If the user asks you to set up, check, fix, or migrate a Mac using this repository, you are
the OPERATOR** — read [`docs/12-OPERATOR-PLAYBOOK.md`](docs/12-OPERATOR-PLAYBOOK.md) first and
follow it exactly. It is a complete instruction set: what you may run without asking, what needs
a confirmation first, and what you never run at all. Nothing below this section applies to you.

**If the user asks you to change this repository's own code or documentation, you are a
CONTRIBUTOR** — the rules below apply.

---

## Contributor rules

**Read order at session start** (highest precedence first): `dev/base/CONSTITUTION.md` →
`BIBLE.md` (invariants + decision register, wins on any in-repo conflict) → `HANDOFF.md` (newest
entry) → this file.

**What this repo is:** a reproducible macOS developer environment, distilled from a verified
inventory of one real machine. Four cumulative install levels, a verified check suite, a tool
registry with a sunset state machine, a migration path, and a local app. The headline numbers
live in `manifests/counts.json` and are generated — never type one by hand.

**Zone:** Bridge — MIT open source (CONSTITUTION §1). A reference setup, not a framework; never
overclaim it. **Before writing anything public, read [`docs/05-SANITIZATION.md`](docs/05-SANITIZATION.md).**
The scan blocks personal data, but only the patterns it has been told.

**Session protocol:** start with `/session-start`; do not begin substantive work while a
blocking `BIBLE` decision is open or the gate is red; end with `/session-stop`. Any decision that
exists only in the chat is lost unless it reaches `HANDOFF.md` or `BIBLE.md` first.

**The gate is law.** `./scripts/gate.sh` must print **GATE: PASS** before any change is called
done. CI runs the same scripts.

**Non-negotiables** are CONSTITUTION §7 — read them there, not here. The two that catch people
out in this repo: no customer-internal names anywhere (all examples fictive), and everything
documented must actually run.

**House rules:** Conventional Commits, one concern per commit. Default to inline work; subagents
are the exception (CONSTITUTION §9). Workflow and review rules for changes:
[`CONTRIBUTING.md`](CONTRIBUTING.md).

**Skills:** `/session-start` · `/session-stop` · `/project-state`
