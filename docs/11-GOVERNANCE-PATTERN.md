# 11 — The Governance Pattern

A tool inventory that nobody reads is decoration. A tool inventory that is always wrong is
worse than decoration — it is a liability. This document explains the pattern that keeps this
repo's inventory honest, what that pattern is structurally analogous to in formal governance
frameworks, and where the analogy stops.

---

## 1. The Problem

Drift is unavoidable. The moment a setup is documented, the world continues to move without
it. Package managers release new versions. Tools are deprecated. Better tools appear. The
machine the documentation was written from diverges from the documentation, and then from
every machine provisioned from it.

The difference between a maintained inventory and an unmaintained one is not that one avoids
this drift. It is that one makes drift visible.

An invisible problem is not a solved problem. It is a problem waiting to become urgent at the
worst time: when a machine has to be reprovisioned, when a team member joins, or when someone
asks what version of a tool was in use on a given date.

Visibility alone is not enough. Visibility without accountability produces a dashboard nobody
acts on. The pattern described here connects detection to a decision, and every decision to a
record.

---

## 2. The Five Elements

### a. A declared inventory

**Principle:** before you can manage what changes, you must know what exists. A list of tools
written informally inside a README is not a registry. A registry has a schema, is
machine-readable, and is the single decision record: the reason every tool is present, when it
was added, when it was last reviewed.

**In this repo:** [`manifests/tools.yaml`](../manifests/tools.yaml) is a YAML list of 103
entries, each validated against a formal schema documented in
[`manifests/schema.md`](../manifests/schema.md). Every entry carries a unique identifier, a
category, an installation source, a lifecycle status, the last observed version, the method
used to check for newer versions upstream, a mandatory rationale (`why` — the schema rules
state it must not be empty), and dates for when it was added and last reviewed.

The implementation files — the Homebrew Brewfiles, the VS Code extension list, the Ollama
model list — are the execution layer. `manifests/tools.yaml` is the decision layer. INV-8 in
[`BIBLE.md`](../BIBLE.md) states the rule: "The registry is the single source of truth."

### b. Lifecycle states

**Principle:** a tool does not exist in a binary state of "installed" or "not installed." It
moves through a lifecycle: initial evaluation, active use, decline, and removal. A governance
system that cannot represent these states cannot document the transitions between them —
and undocumented transitions are invisible decisions.

**In this repo:** every entry in [`manifests/tools.yaml`](../manifests/tools.yaml) carries one
of four states: `candidate` (under evaluation), `active` (in use), `deprecated` (scheduled for
removal, with a sunset date set), or `sunset` (removal confirmed). The transitions between
states are controlled by [`automation/bin/sunset`](../automation/bin/sunset), which enforces a
90-day grace period between the `deprecated` and `sunset` states. A tool that reaches
`deprecated` continues to function during the grace period. Removal requires a second explicit
decision. Every transition is recorded in [`CHANGELOG.md`](../CHANGELOG.md). Of the 92
entries in the public registry, 83 are active, 1 is a candidate awaiting a decision, 2 are
deprecated (in the grace period), and 6 are sunset (removal confirmed, software not yet
removed). The counts are generated, not typed: `manifests/counts.json` is produced from the
sources, and the gate fails when the prose and the code disagree.

The schema in [`manifests/schema.md`](../manifests/schema.md) enforces the rules
mechanically: a `sunset` date is required for `deprecated` and `sunset` entries, and must be
absent for `candidate` and `active` entries. CI validates this on every push.

### c. Machine detection, human decision

**Principle:** automated detection and human judgment are not substitutes for each other. A
machine can read upstream package registries faster and more consistently than a person. But a
person understands whether a version upgrade carries a breaking change, whether a deprecated
tool is actually used in running projects, or whether a proposed successor fits the existing
workflow. These two capabilities belong on different sides of a clear boundary.

**In this repo:** INV-1 in [`BIBLE.md`](../BIBLE.md) draws this boundary as an invariant and
quotes it in full: "Nothing installs or retires itself. `up2date` reports drift; `sunset`
records a decision; installation and removal are always a deliberate human step. The weekly CI
may open a PR for `version_seen`/`reviewed` and an issue for rot, but never changes a
`status`."

[`automation/bin/up2date`](../automation/bin/up2date) runs weekly via
[`.github/workflows/up2date.yml`](../.github/workflows/up2date.yml), scheduled Monday 08:00
UTC. It checks every active and candidate entry against its upstream source — Homebrew, npm,
the GitHub Releases API, the Mac App Store — and classifies findings into four categories:
updates available, sunset candidates (tools deprecated or archived upstream), adoption
candidates (tools present on the machine but absent from the registry), and reviews overdue
(entries not reviewed in more than 180 days). It proposes; it never acts. The weekly job opens
a pull request for version metadata (`version_seen`, `reviewed`) and, separately, an issue
listing tools that need a human decision. The `status` field is never written by automation.

### d. Read-only verification

**Principle:** verification must be separate from installation. A check that also modifies
state cannot be trusted as a check — its output might reflect its own side effects rather than
the actual state of the system.

**In this repo:** [`doctor.sh`](../doctor.sh) runs 42 verification checks and exits with a
non-zero code if any fail. Its header describes it as read-only, and the implementation
contains no write operations. The checks cover the developer stack from the Command Line Tools
through shell configuration, Node, Python, Docker, Xcode, AI tooling, and the automation
layer. Each failed check prints a fix hint; nothing is hidden.

The Control Room, documented in [`10-APP.md`](10-APP.md), is the local browser application
launched by `./start.sh`. It surfaces `doctor.sh` output directly in the interface and states
explicitly that its own dashboard tiles are a probe, not a verdict — `./doctor.sh` and its 42
checks remain the authority.

The gate ([`scripts/gate.sh`](../scripts/gate.sh)) is a second layer of read-only
verification, run before any change is merged. It runs shell syntax checks, ShellCheck, YAML
schema validation, registry consistency checks, a sanitization scan, a secrets scan, and a
dead-links check across all tracked Markdown files. It must print `GATE: PASS` or the change
is not done. INV-6 in [`BIBLE.md`](../BIBLE.md) states: "A gate that passes vacuously is
worse than no gate."

### e. Traceability

**Principle:** a decision that leaves no record did not happen. If there is no evidence trail,
the process cannot be reviewed, relied upon, or explained to anyone other than the person who
made the decision at the moment they made it.

**In this repo:** lifecycle transitions are recorded in [`CHANGELOG.md`](../CHANGELOG.md) by
[`automation/bin/sunset`](../automation/bin/sunset) as part of each subcommand execution, not
as an optional afterthought. Version drift is surfaced as pull requests rather than silent
file edits, so each update has a diff, a timestamp, and a CI run identifier. Issues opened by
the weekly job carry the tool identifier and the suggested next command. The decision register
in [`BIBLE.md`](../BIBLE.md) records every architectural decision with a date, a rationale,
and a note of what it supersedes. This record is available to anyone with access to the
repository. It is not a database, and it is not auditor-ready evidence. But it is a record.

---

## 3. Why Agentic AI Is the Same Problem in a Sharper Form

The five elements above were built to manage a tool inventory. They apply without modification
to a more difficult problem: managing AI agents.

An AI agent that can execute shell commands on a machine has a larger blast radius than a
package manager. The governance questions are identical — what is the agent allowed to do,
who decides, what record exists — but the consequences of a silent decision are larger, the
execution is faster, and the boundary between "automated" and "agentic" is less obvious to a
casual observer.

This repo addresses the problem in two concrete ways.

**First Light (`scripts/12-first-light.sh`)** is a guided first contact with an AI agent,
currently under development. The script hard-wires the prompt the agent receives, hard-wires
the working folder the agent can write to, and passes no further context. The agent knows what
it was told; it does not have access to the rest of the machine. This is permission hygiene in
practice rather than in policy. The constraint is structural, not a convention that depends on
the agent choosing to comply. It applies the same logic as INV-1: the boundary is enforced by
design, and the human step — here, launching the script — is explicit and deliberate.

**The registry split** is the second example. The public `manifests/tools.yaml` is a curated
reference manifest. It describes what this setup contains and why each tool is present. It is
the record intended for sharing, reproducibility, and audit. Machine-specific findings — what
`up2date` observed on a particular run, personal notes about adoption decisions under
consideration — live in `local/manifests/tools.local.yaml`, which is gitignored. The public
manifest is a reference document. The machine's actual state is private by design. INV-3 in
[`BIBLE.md`](../BIBLE.md) states the underlying rule: "Machine-specific data lives in
`local/`, which is gitignored." A machine's actual state is an operational fact, not a
reference document. The two must not be conflated in a shared public repository.

**The operator playbook** is the third. [`docs/12-OPERATOR-PLAYBOOK.md`](12-OPERATOR-PLAYBOOK.md)
is written for a general-purpose agent that has been asked to set up someone's machine with this
repository. It sorts every action the agent could take into three classes — run freely, announce
and wait for a yes, never run — and the classes match the badges the Control Room shows a human,
because they describe the same boundary. Two properties are worth naming. First, the fence is
written down rather than assumed: an agent that has read only this repository knows what it may
not do here, without the person having to think of the prohibition themselves. Second, it is
enforced socially rather than technically — a playbook is a set of instructions, and an agent
that ignores it is not stopped by anything. That is a real and stated limitation, and it is why
the destructive commands are additionally gated in the scripts themselves rather than in prose
alone. Instructions raise the floor; they are not a control.

All three examples apply an existing repo principle — structural constraint over convention, and
separation of reference from machine state — to a context where the stakes of getting it wrong
are higher.

---

## 4. Standards Reference

The pattern described in this document is structurally analogous to control families in formal
governance frameworks. The table below maps each element. The third column is the important
one: it states explicitly what is not being claimed, because the analogy is useful only if its
limits are clear.

| Element | Analogous control family | What is explicitly NOT claimed here |
|---|---|---|
| Declared inventory (`manifests/tools.yaml`, schema validation in CI) | ISO/IEC 27001 A.8 — Asset Management; ISO/IEC 42001 §8.4 — AI system lifecycle documentation | This is not a conformity claim; it has not been audited. There is no assigned asset owner, no formal asset classification, and no asset management process beyond the registry itself. The registry documents one person's machine. |
| Lifecycle states and transition rules (`candidate → active → deprecated → sunset`, 90-day grace period, CHANGELOG) | ISO/IEC 42001 §6.1.2 — AI risk treatment; EU AI Act Article 9 — risk management for high-risk AI | This is not a conformity claim; it has not been audited. The lifecycle state machine documents tool decisions in a developer setup. It is not a risk register, does not classify tools by risk level, and does not map to any regulatory categorisation of AI systems. |
| Machine detection, human decision (INV-1; `up2date`, `sunset`, weekly CI job) | ISO/IEC 42001 §6.1 — consideration of human oversight; EU AI Act Article 14 — human oversight of high-risk AI systems | This is not a conformity claim; it has not been audited. INV-1 governs a tool registry on one developer machine. It is not a human oversight mechanism for an AI system in deployment, does not address real-time intervention capability, and has not been evaluated against any regulatory definition of "high-risk." |
| Read-only verification (`doctor.sh` 42 checks, the gate, the Control Room) | ISO/IEC 27001 A.8.8 — management of technical vulnerabilities; ISO/IEC 42001 §9 — performance evaluation | This is not a conformity claim; it has not been audited. These checks verify a developer environment on one machine. They are not a vulnerability management program, do not feed into a management review cycle, and produce no evidence trail usable in a third-party assessment. |
| Traceability (CHANGELOG, pull requests, issues, decision register in BIBLE.md) | ISO/IEC 27001 A.5.28 — collection of evidence; ISO/IEC 42001 §7.5 — documented information | This is not a conformity claim; it has not been audited. Records exist in the repository for the maintainer's use. They are not structured for third-party review, are not retained to any defined schedule, and carry no chain of custody independent of the repository host. |

---

## 5. Limits

This repo is a reference setup for one machine, maintained by one person. The governance
pattern it implements carries hard limits that no amount of additional tooling on this scale
can close.

**One machine.** The registry reflects one real machine, inventoried on a specific date. It is
not a fleet management system and does not aggregate observations across machines. A finding
from `up2date` on one machine is not a finding about any other machine.

**No separation of duties.** The person who decides to adopt a tool, writes the tool's entry
in the registry, and merges the change are the same person. The decision register in
[`BIBLE.md`](../BIBLE.md) records this openly: "No review requirement: a second reviewer does
not exist on a single-maintainer repo." Separation of duties is a control that requires more
than one person.

**No retention.** [`CHANGELOG.md`](../CHANGELOG.md) and the decision register are
version-controlled text files. They can be rewritten or deleted by the maintainer. There is
no retention policy, no immutable log, and no backup independent of the repository host.

**No evidence trail toward a third party.** The records in this repository are readable by
anyone with access to the public repository. They are not structured to satisfy an auditor,
do not carry timestamps that are independently verifiable, and have not been reviewed by
anyone other than the maintainer. A third-party conformity assessment of any formal standard
requires evidence of a different character.

The pattern in this document is the most a single-maintainer, single-machine project can
honestly implement. It is not a substitute for organisational governance, and it does not
close the distance between a personal reference setup and a regulated system.
