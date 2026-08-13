# 10 — The Control Room (local app)

A dashboard, a step-by-step guide and the tool registry in one browser window, so setting up
a Mac stops being a matter of finding the right command in the right document.

```bash
./start.sh
```

That is the whole entry point. It opens `http://127.0.0.1:8787/` in your browser.

---

## Who this is for

Someone who has to set up a Mac and does not want to read a repository first. The app answers
three questions the documents answer slowly:

- **Where does this machine stand?** — what is installed, what level was reached.
- **What do I do next?** — one ordered list, each step saying whether it changes anything.
- **What is all this stuff?** — the tools in the registry, searchable, with a reason each.

Everything runs on the machine. Nothing is sent anywhere, and there is no account, no cloud,
and no telemetry.

---

## What it does not do

The app is a window onto the scripts that already exist. It adds no new automation, and it
takes no decisions away from you.

- **It never installs anything itself.** Steps that change the machine are handed to
  Terminal.app as a small generated script. You see the command before it runs, macOS asks you
  for your password there, and Ctrl-C stops it. This keeps INV-1 and INV-2 intact: nothing
  installs itself, nothing destructive happens by default.
- **It runs a fixed list of commands, nothing else.** The browser sends an action name, never a
  command line. Each name maps to a fixed argument list in `app/server.py`. The only value you
  can influence is the setup level, and it is checked against 0–3.
- **It never changes the registry.** The drift view reports; adopting, retiring and removing a
  tool stay manual, exactly as `docs/07-CURRENCY.md` describes.
- **Destructive commands are not in it at all.** `scripts/90-cleanup-legacy.sh` and
  `mac-clean --apply` have no button. They remain deliberate command-line steps.

---

## What you can do from it

| View | What it shows | Runs |
|---|---|---|
| Dashboard | macOS version, chip, which level looks installed, which marker tools were found, whether drift was detected | readiness check, verification |
| Guide | Every step from "is this Mac ready" to level 3, in order: preview → run → verify | preview (dry run), the real run via Terminal, `doctor.sh` |
| Tools | All registry entries with search and filters by category, level and status | — |
| Drift | The currency numbers, what is being retired, which candidates await a decision | `up2date check`, `up2date --consistency` |
| Migration | The old-Mac-to-new-Mac path in four steps | `status-quo.sh`, `migration-diff` |
| Docs | The repository's documents, rendered | — |

The dashboard tiles are a **probe, not a verdict**. They check whether a handful of marker
tools exist, which is fast enough to run on every page load. `./doctor.sh` and its 42 checks
remain the authority, and the app says so where it matters.

---

## Requirements

`python3` and nothing else. It ships with the Xcode Command Line Tools, which `prepare.sh`
installs as the first thing on a new machine. There is no Homebrew requirement, no Node, no
npm, and no build step — the interface under `app/ui/` is plain HTML, CSS and JavaScript served
straight from disk.

This is deliberate. An app that guides you through installing Node cannot itself need Node.

If `python3` is not available yet, `./start.sh` says so and names the one command that fixes
it.

---

## Options

```bash
./start.sh                # start it and open the browser
./start.sh --no-open      # start it, print the address, open nothing
./start.sh --port 9000    # use a specific port
./start.sh --stop         # stop a Control Room started earlier
./start.sh --dry-run      # print what would happen, start nothing
./start.sh --help
```

Without `--port` it takes 8787, or the next free port above it if that one is taken. It never
kills a process it did not start.

---

## How it is kept safe on your machine

It binds to `127.0.0.1` only, so nothing outside the machine can reach it. Beyond that, two
local threats get one answer each:

- **Another process on this Mac** — every request needs a session token that is generated fresh
  at startup and only ever placed in the page itself.
- **A web page you happen to have open** — a browser can post to `127.0.0.1`, so requests
  carrying a foreign `Origin` are refused, and the page's own token cannot be read across
  origins.

The request body is capped, one action runs at a time, and the server never passes anything
through a shell.

These measures make it safe on a shared machine. They are not a substitute for real
authentication: do not put this on a public host.

---

## Where it leaves traces

Only inside `local/`, which is gitignored:

- `local/.app-port` — the port in use, so `--stop` finds the right process. Removed on exit.
- `local/app-runs/` — the scripts handed to Terminal, kept as a record of what was started.
  Safe to read and safe to delete.
- `local/doctor-report.md`, `local/status-quo/`, `local/migration-diff.md` — written by the
  scripts themselves when you ask for them, exactly as on the command line.

---

## When something goes wrong

**The page does not load.** Check the Terminal window where you ran `./start.sh` — the address
is printed there. If the port was taken, it will have chosen a different one.

**A step fails.** The output pane shows the same text the command prints in a terminal,
including the fix hint every `doctor.sh` failure carries. Nothing is hidden or summarised.

**A run seems stuck.** Read-only runs can be stopped with the Stop button. A real setup run
lives in its own Terminal window — stop it there with Ctrl-C.

**You would rather use the command line.** Every button in the app corresponds to a command
shown next to it. `QUICKSTART.md` has the same path without the app.
