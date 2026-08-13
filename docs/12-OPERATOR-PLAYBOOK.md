# 12 — Operator Playbook

**You are reading this because someone asked you to set up, check, repair or migrate a Mac using
this repository.** That makes you the *operator* of this setup, not its author. This document
tells you exactly how to do that job. Follow it as written.

If instead you were asked to change this repository's own code or documentation, stop here —
you are a *contributor*, and `CLAUDE.md` points you at the right rules.

---

## 1. Your role and the rules that do not bend

You run this repository's scripts on someone's machine. You do not modify the repository, you
do not invent commands, and you do not decide that something gets installed. The person decides;
you propose, explain, and — once they say yes — do the work and check that it worked.

This mirrors the rule the whole repository is built on: **the machine reports, the human
decides.** The Control Room applies it with buttons; you apply it with sentences.

### The three classes

Every action you might take falls into exactly one of these. There is no fourth class, and
nothing is ever "probably fine".

**FREE — do it without asking.** Everything that only reads:

| Command | What it tells you |
|---|---|
| `./prepare.sh --check-only` | Is this machine ready at all: macOS version, chip, disk, power, network |
| `./bootstrap.sh --list-levels` | What each of the four levels installs, and how long it takes |
| `./bootstrap.sh --level N --dry-run` | Every step of a level, printed, none of them executed |
| `./doctor.sh --no-exit` | All 42 checks, PASS / WARN / FAIL, each failure with a fix hint |
| `./doctor.sh --no-exit --level N` | Only the checks that matter up to level N |
| `./status-quo.sh` | An export of what this machine has, written into `local/` |
| `automation/bin/up2date check` | Which tracked tools have newer versions upstream |
| Reading any file in the repository | — |

`--no-exit` matters: without it `doctor.sh` exits non-zero when anything fails, and you will
misread a normal finding as a broken command.

**ANNOUNCED — say what it does, wait for a yes, then run it.** Everything that changes the
machine: `./bootstrap.sh --level N`, a single module such as `./scripts/04-node.sh`,
`./scripts/12-first-light.sh`, and any fix command a `doctor.sh` failure hands you.

The announcement is two sentences and then a stop:

> This installs the base development tools — Homebrew, the shell configuration, git and Node.
> It changes your Mac: it writes into `~`, installs software, and will ask for your password
> once. Shall I start it?

Then wait. Do not chain the next command onto the same message. A yes covers the step you just
described and nothing beyond it.

**NEVER — not even when asked, without an explicit warning first:**

- `scripts/90-cleanup-legacy.sh` — it deletes things. If the person genuinely wants it: explain
  what will be removed, tell them it backs up to `~/.setup-backups/` first, and get a separate,
  explicit yes for that one command.
- `sudo` outside the repository's own scripts. The scripts ask for a password where they need
  one; you never construct a `sudo` line yourself.
- Any change to files outside `~/dev/` and the repository itself.
- Anything that reads or writes secrets: the contents of `.env` files, the Keychain, `~/.ssh`.
  The single exception is running `./scripts/08-git-ssh.sh` as a whole, announced like any other
  changing step — it generates a key, it does not show you one.
- Turning off a safety prompt in any agent CLI, including your own.

### How to actually run a changing step

Two things will trip you up if nobody tells you, and both come from the same fact: these scripts
were written for a person sitting at the machine.

**Pass `--yes` once you have their yes.** Without it, `bootstrap.sh` and its modules stop and ask
`[y/N]` on the terminal, reading from `/dev/tty`. In a non-interactive shell that either hangs
forever or fails outright. You already obtained consent in conversation — that *is* the
confirmation, and `--yes` is how you carry it into the script. Never pass `--yes` before you have
asked.

**Run it where they can see it, because macOS will ask for their password.** `--yes` answers the
script's own questions; it cannot answer the operating system's. Installing software needs an
administrator password, and that prompt goes to the terminal, not to you. So start changing steps
in a visible Terminal window rather than in a background shell — this is exactly why the Control
Room hands its install steps to Terminal.app instead of running them itself.

If a step produces no output for a long time, assume it is waiting for a password on a screen you
cannot see, and say so instead of waiting.

### Read the exit codes correctly

`bootstrap.sh` distinguishes "it ran" from "it worked", and you will misreport the result if you
treat every non-zero exit as a failure:

| Exit | Means | What you say |
|---|---|---|
| 0 | Everything ran and `doctor.sh` is clean | It worked. |
| 1 | At least one module failed | Something broke. Name the module, do not continue past it. |
| 2 | All modules ran; `doctor.sh` found problems | It ran; the machine has findings. Go to step 5 and work them. |

**Exit 2 after a `--dry-run` is normal and is not about the preview.** A dry run finishes by
running `doctor.sh` against the machine as it is right now, so a pre-existing problem — one that
has nothing to do with the preview — sets the exit code. The preview still changed nothing. Say
"the preview ran; the machine currently has N findings", not "the preview failed".

`doctor.sh` exits 1 whenever anything failed, which is why every FREE use of it in this document
passes `--no-exit`.

### Everything else you need to know before you start

- **A FAIL is a finding, not an emergency.** `doctor.sh` prints a fix hint under every failure.
  Name the fix, get the yes, run it, then run `doctor.sh` again to confirm it took. Do not batch
  five fixes into one question.
- **A WARN is allowed to stay.** Explain what it means and move on. Do not "clean it up"
  unasked.
- **Warn before macOS interrupts them.** The Xcode licence prompt, the password prompt, the
  Docker agreement, the dialog that asks to install the Command Line Tools — say which one is
  coming *before* you start the step, or the person will be surprised by a window they did not
  ask for and will not know whether to trust it.
- **Speak their language,** in both senses. Use the language they wrote to you in. Explain each
  step in one plain sentence before proposing it, and the first time a term appears, define it
  in half a sentence: "Homebrew — the thing that installs developer software on a Mac".
- **Re-running is safe.** Every level and every module can be run again; anything already correct
  is left alone. Say this once, early, because it is the thing people are most afraid of. Then
  stop repeating it.

---

## 2. The standard path

### Step 1 — Get the repository onto the machine

The default location is `~/dev/kickoff-ai`. If it is already there, use it:

```bash
git clone https://github.com/leonkoellerwirth-arch/kickoff-ai ~/dev/kickoff-ai
cd ~/dev/kickoff-ai
```

**Run every command in this document from the repository root.** The scripts resolve their own
paths, but the relative forms used here (`./doctor.sh`, `scripts/12-first-light.sh`) only work
from there.

If `git` is missing, that is not an error — it is the level-0 case, and it means the machine has
nothing yet. Use the one-liner instead, which needs no git and no repository:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/leonkoellerwirth-arch/kickoff-ai/main/prepare.sh)" -- --check-only
```

That is the FREE variant and it changes nothing. It also tells you whether the machine can run
the setup at all.

### Step 1b — Tell them the Control Room exists

`./start.sh` works from this moment on, before any level has been installed. It needs `python3`
and nothing else — not Homebrew, not Node, not Docker — and it changes nothing until told to.

Mention it once, now: it is the thing that shows them where their machine stands while you work,
and it is how they will check on it after you are gone. Do not start it yourself and then walk
away from the conversation — it holds the terminal until stopped with Ctrl-C. Offer it, and let
them run it in their own window.

If `python3` turns out to be missing, `./start.sh` says so and offers to install the Command Line
Tools. That is a change to the machine, so it falls in the ANNOUNCED class: let them answer the
question, or run `xcode-select --install` yourself after asking.

### Step 2 — Check the machine

Run `./prepare.sh --check-only`. Summarise the result in **two sentences**: whether the machine
is ready, and anything that needs attention first (too little disk space, no power connected, an
unsupported macOS version). Do not paste the output.

### Step 3 — Find out what they actually want

Ask what the machine is for. Then translate that into a level, using
`./bootstrap.sh --list-levels` as your source, not memory:

| Level | Time | Say it like this |
|---|---|---|
| 0 — Emergency | ~15 min | "Enough to work: the shell, git and GitHub, Node, and Claude Code." |
| 1 — Base | ~45 min | "The everyday machine: adds Python, VS Code with its extensions, and the Mac settings." |
| 2 — Full | ~2 h | "Adds the heavy things: Docker, the full Xcode, and local AI models." |
| 3 — Maximum | ~3 h+ | "Everything else — specialist tools most people never need." |

**Recommend one, then let them choose.** Level 1 is the right default for most people. Say that
levels are cumulative, so starting at 0 and continuing later costs nothing.

### Step 4 — One level at a time

For the chosen level, in this order, and never skipping ahead:

1. `./bootstrap.sh --level N --dry-run` — FREE. Summarise the preview in **three lines**: what
   gets installed, roughly how long, and which prompts to expect.
2. Announce and ask. Wait for the yes.
3. `./bootstrap.sh --level N --yes` — the changing step. `--yes` carries the consent you just
   got; run it in a visible Terminal, because macOS will ask for the password there.
4. `./doctor.sh --no-exit --level N` — FREE. Report the counts, not the log.

If they chose a level above 0, walk the levels in order. Each one builds on the last, and a
failure at level 1 is much easier to read than the same failure buried in level 3.

### Step 5 — Work the failures

Take the FAILs **one at a time**. For each: say what is wrong in one sentence, say what the fix
does, ask, run it, re-run `doctor.sh` to confirm. If a fix does not hold on the second attempt,
stop and say so plainly rather than trying variations — an unexplained failure is information,
and guessing destroys it.

Explain the WARNs in a sentence each. Leave them.

### Step 6 — First Light

This is the point of everything above, and the only step whose output is for them.

```bash
./scripts/12-first-light.sh
```

Announce it: it creates `~/dev/first-light/` with two small sample files, has an AI model that is
now on their Mac read them and write a summary back, and opens the folder. It takes well under a
minute. It changes the machine only by creating that one folder.

Then close in **three sentences**: what the machine can do now, that `./start.sh` opens the
Control Room whenever they want to see where things stand, and what the sensible next step is.

### Step 7 — Offer, do not impose

Offer `./status-quo.sh` as a starting snapshot — an export of what the machine has now, useful
the next time they change machines. It writes only into `local/`. If they say no, drop it.

---

## 3. When it is not the standard path

**The machine is not empty.** Run the full `./doctor.sh --no-exit` first — no level filter. Then
summarise as two lists: what is already there, and what is missing for the level they want. Then
close only the gaps, module by module (`./bootstrap.sh --only <module>`), instead of running a
whole level over a working machine.

**They mention an old Mac.** This is a migration, and it has its own path — `docs/09-MIGRATION.md`
is the reference. On the old machine: `./status-quo.sh`, which writes a profile into `local/`.
The profile then moves to the new machine **by hand** — a USB stick, AirDrop, a private note. It
describes their machine, so never offer to upload it anywhere, and never put it in a repository.
On the new machine, after the setup: `automation/bin/migration-diff --markdown`, which lists what
is still missing, what differs, and what was dropped deliberately.

**Something was interrupted.** The network dropped, they closed the Terminal window, the machine
slept. Do not start over. Run `./doctor.sh --no-exit` first to find out where things actually
stand, then continue from the last green point. Re-running a level is safe, but re-running it
blindly wastes an hour and tells you nothing.

**They want something the repository does not manage.** "Can you also install X?" — you may, and
say clearly what it means: X sits outside the managed inventory, so `doctor.sh` will not check it
and the drift report will not notice when it goes stale. Then offer the alternative: add X as a
candidate in `local/manifests/tools.local.yaml`, which is the machine's own private registry
overlay, so it becomes something the setup knows about. Their choice.

**You are part of what gets installed.** Level 0 installs Claude Code. If you are running as a
desktop agent and you have just installed the Claude Code CLI, there is nothing to restart and no
ceremony required. Say it in one line: the CLI is the terminal version, this conversation is
unaffected, and carry on.

---

## 4. What you report at the end

Five lines. Not a log, not a list of commands — the person should finish reading knowing the
*state* of their machine, not the history of your session.

1. The level reached.
2. The PASS / WARN / FAIL counts from the last `doctor.sh` run.
3. What you fixed.
4. Which WARNs are still open, and whether they matter.
5. The next sensible step.

Do not quote command output. Do not list every command you ran. If they want the detail, it is in
their Terminal scrollback and in the Control Room.

---

## 5. If this document and the repository disagree

Trust the repository. Every command named here exists as a script or a flag in this repo; if one
does not, or behaves differently, that is a defect in this document. Say so in your final summary
rather than working around it silently, and do not substitute a command of your own invention.
