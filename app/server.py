"""app/server.py — the Control Room: kickoff-ai's local app.

A dashboard, a step-by-step guide and the tool registry in one browser window,
so a non-technical user never has to guess which command comes next.

Built on the Python standard library only. No framework, no Docker, no npm —
because this app has to work on a *fresh* Mac, before bootstrap.sh has
installed anything. The frontend under ``ui/`` is plain HTML/CSS/JS served
straight from disk; there is no build step to run first.

What it exposes:

* ``GET  /api/state``      — quick machine probe: macOS, chip, which level looks
                             installed, which core tools were found.
* ``GET  /api/guide``      — the ordered steps a new machine walks through.
* ``GET  /api/registry``   — manifests/tools.yaml as a table.
* ``GET  /api/currency``   — manifests/STATE.json (drift), read-only.
* ``GET  /api/docs``       — the documents surfaced in-app, plus one by id.
* ``POST /api/run``        — start one allow-listed action.
* ``GET  /api/job``        — poll the running/last job for new output.
* ``POST /api/job/stop``   — stop it.

Two boundaries this file exists to hold:

1. **Nothing changes the machine from the browser.** Actions that only read
   (``doctor.sh``, ``prepare.sh --check-only``, ``up2date``) stream their output
   into the page. Actions that install something are *never* run by this server
   — they are handed to Terminal.app as a generated, readable script, so the
   user watches it happen, answers the sudo prompt, and can stop it. That is
   INV-1 and INV-2 kept intact: nothing installs itself, nothing destructive
   happens by default.
2. **No arbitrary commands.** The browser sends an action *id*, never a command
   line. Every id maps to a fixed argv list in ``ACTIONS`` below, run without a
   shell. The only caller-supplied value is a setup level, validated to 0-3.

Local-access guards, in the same spirit as the rest of the repo: it binds to
127.0.0.1 only, requires a session token generated at startup (injected into the
page, so another local process cannot drive it), checks the Origin against a
localhost allow-list (so a web page the user has open cannot POST to it), and
caps the request body. Localhost-only means these are enough; they are not a
substitute for real auth. Do not put this on a public host.
"""

from __future__ import annotations

import json
import os
import platform
import re
import secrets
import shlex
import shutil
import subprocess
import threading
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
UI_DIR = Path(__file__).resolve().parent / "ui"
LOCAL_DIR = ROOT / "local"
HANDOFF_DIR = LOCAL_DIR / "app-runs"

HOST = "127.0.0.1"
PORT = int(os.environ.get("APP_PORT", "8787"))
API_TOKEN = os.environ.get("API_TOKEN") or secrets.token_urlsafe(24)

MAX_BODY = 64 * 1024
MAX_OUTPUT_LINES = 5000

# Homebrew is not on PATH until the shell config from module 03 is in place, so
# probing with the inherited PATH alone would report "not installed" on a Mac
# where it plainly is. Look where the installers actually put things.
PROBE_PATH = os.pathsep.join(
    [
        os.environ.get("PATH", ""),
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        str(Path.home() / ".local" / "bin"),
    ]
)


# =============================================================================
# Actions — the complete list of what the browser is allowed to start
# =============================================================================


class Action:
    """One allow-listed thing the app can run.

    ``mode`` is the whole safety story:

    ``inline``    the server runs it and streams the output into the page.
                  Reserved for commands that change nothing on the machine.
    ``terminal``  the server writes a script under ``local/app-runs/`` and opens
                  it in Terminal.app. Used for everything that installs, so the
                  run owns a real TTY (sudo prompts, Homebrew's own questions)
                  and the user can watch and interrupt it.
    """

    def __init__(
        self,
        label,
        argv,
        mode,
        blurb,
        changes,
        accepts_level=False,
        confirm=False,
        ok_codes=(0,),
    ):
        self.label = label
        self.argv = argv
        self.mode = mode
        self.blurb = blurb
        self.changes = changes
        self.accepts_level = accepts_level
        self.confirm = confirm
        # Which exit codes mean "this did its job". Not every non-zero exit is a
        # failure: bootstrap.sh exits 2 when doctor finds a problem on the
        # machine, which during a *preview* is the preview working correctly and
        # telling you something true. Showing that as "failed" would train people
        # to ignore the word.
        self.ok_codes = ok_codes


ACTIONS = {
    "check-readiness": Action(
        label="Check this Mac",
        argv=["./prepare.sh", "--check-only"],
        mode="inline",
        blurb="Asks whether this machine is ready for the setup: macOS version, chip, "
        "disk space, power, network. Answers only — it installs nothing.",
        changes="Nothing.",
    ),
    "list-levels": Action(
        label="Show the four levels",
        argv=["./bootstrap.sh", "--list-levels"],
        mode="inline",
        blurb="Prints what each setup level installs and roughly how long it takes.",
        changes="Nothing.",
    ),
    "bootstrap-preview": Action(
        label="Preview the run",
        argv=["./bootstrap.sh", "--dry-run"],
        mode="inline",
        blurb="Walks through every step of the level and prints what it *would* do. "
        "Read this before the real run.",
        changes="Nothing — a dry run executes no step.",
        accepts_level=True,
        ok_codes=(0, 2),
    ),
    "bootstrap-run": Action(
        label="Run the setup",
        argv=["./bootstrap.sh"],
        mode="terminal",
        blurb="The real installation for this level. Opens in Terminal so you can "
        "watch it, answer the password prompt, and stop it with Ctrl-C.",
        changes="Installs software and writes config files. This is the one step "
        "that changes your Mac.",
        accepts_level=True,
        confirm=True,
    ),
    "doctor": Action(
        label="Verify the setup",
        argv=["./doctor.sh", "--no-exit"],
        mode="inline",
        blurb="Runs every check and reports PASS / WARN / FAIL per item, each with "
        "a fix hint.",
        changes="Nothing — doctor is read-only.",
        accepts_level=True,
    ),
    "doctor-report": Action(
        label="Write a report",
        argv=["./doctor.sh", "--no-exit", "--report"],
        mode="inline",
        blurb="Same checks, plus a Markdown report you can keep or send on.",
        changes="Writes local/doctor-report.md. Nothing outside the repo.",
    ),
    "currency-check": Action(
        label="Check for tool drift",
        argv=["automation/bin/up2date", "check"],
        mode="inline",
        blurb="Compares the registry against upstream: which tools have newer "
        "versions, which look abandoned, which are due for review.",
        changes="Nothing — reports only. It never installs, removes, or changes a "
        "tool's status (INV-1).",
    ),
    "registry-consistency": Action(
        label="Check the registry",
        argv=["automation/bin/up2date", "--consistency", "--offline"],
        mode="inline",
        blurb="Verifies the tool registry still agrees with the Brewfiles and the "
        "other install lists. Works without network.",
        changes="Nothing.",
    ),
    "status-quo": Action(
        label="Export this machine",
        argv=["./status-quo.sh"],
        mode="inline",
        blurb="Captures what is installed here — versions, apps, repos, models — as a "
        "profile you carry to the new Mac. Never captures keys or passwords.",
        changes="Writes local/status-quo/. Nothing outside the repo.",
    ),
    "first-light": Action(
        label="Run First Light",
        argv=["./scripts/12-first-light.sh"],
        mode="terminal",
        blurb="Creates a small folder of sample files, has a locally available AI "
        "model read them and write a summary back, and opens the folder so you "
        "can read it. Under a minute.",
        changes="Creates ~/dev/first-light and the files in it. Nothing else, "
        "anywhere.",
        confirm=True,
    ),
    "migration-diff": Action(
        label="Compare against the old machine",
        argv=["automation/bin/migration-diff", "--markdown"],
        mode="inline",
        blurb="Reads the profile from the old Mac and lists what is still missing "
        "here, what differs, and what was dropped on purpose.",
        changes="Writes local/migration-diff.md. Nothing outside the repo.",
    ),
}


# =============================================================================
# The guide — the ordered path a new machine walks
# =============================================================================

LEVELS = [
    (
        0,
        "Emergency",
        "~15 min",
        "The smallest setup you can work with: developer tools, Homebrew, the "
        "shell, git and GitHub, Node, and Claude Code. Enough to clone a repo and "
        "start working.",
    ),
    (
        1,
        "Base",
        "~45 min",
        "The everyday machine: the full package list, Python via uv, the macOS "
        "settings, VS Code with its extensions, and the ~/dev folder structure.",
    ),
    (
        2,
        "Full",
        "~2 h",
        "Adds the heavy pieces: Docker, the full Xcode, and the rest of the AI "
        "tools including local models. This is the default when no level is given.",
    ),
    (
        3,
        "Maximum",
        "~3 h+",
        "Everything else: the optional package list (machine learning, security, "
        "media tools) and the scheduled background jobs.",
    ),
]


def build_guide():
    """The step list the UI walks top to bottom.

    Deliberately one shape per step — read, preview, run, verify — because the
    point of the app is that there is never a question of what comes next.
    """
    steps = [
        {
            "id": "readiness",
            "title": "Is this Mac ready?",
            "body": "Before anything is installed, check the machine itself: macOS "
            "version, Apple Silicon, free disk space, power, network. This "
            "changes nothing, so it is always safe to run.",
            "action": "check-readiness",
        },
        {
            "id": "levels",
            "title": "Understand the four levels",
            "body": "The setup comes in four cumulative levels. You do not have to "
            "pick the right one now — each level continues where the previous "
            "one stopped, and re-running one that is already done is safe.",
            "action": "list-levels",
        },
    ]
    for level, name, duration, body in LEVELS:
        steps.append(
            {
                "id": f"level-{level}-preview",
                "title": f"Level {level} · {name} — preview ({duration})",
                "body": body + " Start with the preview: it prints every step "
                "without doing any of them.",
                "action": "bootstrap-preview",
                "level": level,
            }
        )
        steps.append(
            {
                "id": f"level-{level}-run",
                "title": f"Level {level} · {name} — run it",
                "body": "This opens Terminal and starts the real installation. You "
                "will be asked for your Mac password once — that is macOS, not "
                "this app. Leave the window open until it finishes.",
                "action": "bootstrap-run",
                "level": level,
            }
        )
        steps.append(
            {
                "id": f"level-{level}-verify",
                "title": f"Level {level} · {name} — verify",
                "body": "Check what actually landed. WARN is tolerable; FAIL means "
                "something needs attention, and each line names its fix.",
                "action": "doctor",
                "level": level,
            }
        )
    steps.append(
        {
            "id": "final",
            "title": "Full check",
            "body": "Every check, no level filter. This is the honest answer to "
            "'is my machine set up?'",
            "action": "doctor",
        }
    )
    # The last step is the only one whose output is for the person rather than
    # for the setup. Everything above proves the machine works; this is the
    # first time it does something for you.
    steps.append(
        {
            "id": "first-light",
            "title": "First Light — watch an agent do something",
            "body": "This puts two small sample files in a new folder and has an AI "
            "model that is now installed on your Mac read them and write a "
            "summary back. The prompt and the folder are fixed, the model gets "
            "nothing else, and the folder opens when it is done.",
            "action": "first-light",
        }
    )
    return steps


DOCS = [
    ("quickstart", "Quickstart", ROOT / "QUICKSTART.md"),
    ("zero-to-hero", "Zero to Hero — the full walkthrough", ROOT / "docs" / "00-ZERO-TO-HERO.md"),
    ("manual", "What stays manual", ROOT / "docs" / "01-MANUAL.md"),
    ("currency", "Currency — how drift is tracked", ROOT / "docs" / "07-CURRENCY.md"),
    ("secrets", "Secrets", ROOT / "docs" / "08-SECRETS.md"),
    ("migration", "Machine migration", ROOT / "docs" / "09-MIGRATION.md"),
    ("app", "This app", ROOT / "docs" / "10-APP.md"),
    ("governance", "The pattern underneath", ROOT / "docs" / "11-GOVERNANCE-PATTERN.md"),
    ("assessment", "Example assessment", ROOT / "docs" / "02-EXAMPLE-ASSESSMENT.md"),
    ("readme", "Repository overview", ROOT / "README.md"),
    ("changelog", "Changelog", ROOT / "CHANGELOG.md"),
]


# =============================================================================
# Registry reader
# =============================================================================

_UNQUOTED_COMMENT = re.compile(r"\s+#.*$")


def _scalar(value: str):
    value = value.strip()
    if value.startswith(('"', "'")) and value.endswith(('"', "'")) and len(value) >= 2:
        return value[1:-1]
    value = _UNQUOTED_COMMENT.sub("", value).strip()
    if value in ("null", "~", ""):
        return None
    if value in ("true", "false"):
        return value == "true"
    if value.lstrip("-").isdigit():
        return int(value)
    return value


def read_registry(public_only=False):
    """The tool registry: the public manifest with the machine overlay on top.

    ``manifests/tools.yaml`` is a curated reference — the tools this setup
    installs or deliberately tracks. What one particular machine turned out to
    have is a different thing and is private by design, so it lives in
    gitignored ``local/manifests/tools.local.yaml``. An id in both is answered by
    the overlay; new ids are added. ``public_only`` skips the overlay, which is
    what the published counts must use.
    """
    entries = _read_registry_file(ROOT / "manifests" / "tools.yaml")
    if public_only:
        return entries
    overlay = _read_registry_file(LOCAL_DIR / "manifests" / "tools.local.yaml")
    if not overlay:
        return entries
    by_id = {e["id"]: e for e in entries}
    for entry in overlay:
        if entry["id"] in by_id:
            by_id[entry["id"]].update(entry)
        else:
            entries.append(entry)
    return entries


def _read_registry_file(path):
    """Read one registry file into a list of dicts.

    A narrow reader for exactly this file's shape (a flat list of entries, one
    ``key: value`` scalar per line) rather than a YAML library — PyYAML is not
    in the standard library and was deliberately removed from this repo, and yq
    does not exist yet on a fresh Mac. The gate already validates the registry's
    schema with yq (``scripts/checks/registry-schema.sh``), so shape drift is
    caught there, not here.
    """
    if not path.exists():
        return []
    entries = []
    current = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if raw.startswith("- "):
            current = {}
            entries.append(current)
            raw = "  " + raw[2:]
        if current is None or not raw.startswith("  "):
            continue
        key, sep, value = raw.strip().partition(":")
        if not sep:
            continue
        current[key.strip()] = _scalar(value)
    return [e for e in entries if e.get("id")]


def read_counts():
    """The repo's own headline numbers, generated from the code.

    Nothing in the app hard-codes "42 checks". Three places once claimed three
    different sizes for this repo because each was typed by hand on a different
    day; ``manifests/counts.json`` is generated by
    ``scripts/checks/counts.sh --write`` and the gate fails when it goes stale.
    """
    path = ROOT / "manifests" / "counts.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}
    return {k: v for k, v in data.items() if not k.startswith("_")}


def read_currency():
    path = ROOT / "manifests" / "STATE.json"
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}


# =============================================================================
# Machine probe
# =============================================================================


def _which(name):
    return shutil.which(name, path=PROBE_PATH)


def _run_quiet(argv, timeout=5):
    try:
        proc = subprocess.run(
            argv, capture_output=True, text=True, timeout=timeout, cwd=str(ROOT)
        )
    except (OSError, subprocess.SubprocessError):
        return None
    out = (proc.stdout or proc.stderr or "").strip()
    return out or None


def probe_machine():
    """A cheap snapshot for the dashboard.

    This is a *probe*, not a verdict: it looks for a handful of marker tools to
    guess how far the setup has come. ``doctor.sh`` is the authority, and the UI
    says so — a green tile here is a hint, not a pass.
    """
    tools = [
        ("clt", "Developer tools", bool(_run_quiet(["xcode-select", "-p"])), 0),
        ("brew", "Homebrew", bool(_which("brew")), 0),
        ("git", "git", bool(_which("git")), 0),
        ("node", "Node.js", bool(_which("node")), 0),
        ("claude", "Claude Code", bool(_which("claude")), 0),
        ("uv", "uv (Python)", bool(_which("uv")), 1),
        ("code", "VS Code", Path("/Applications/Visual Studio Code.app").exists(), 1),
        ("dev", "~/dev structure", (Path.home() / "dev").is_dir(), 1),
        ("docker", "Docker", Path("/Applications/Docker.app").exists(), 2),
        ("ollama", "Ollama", bool(_which("ollama")), 2),
        ("xcode", "Xcode (full)", Path("/Applications/Xcode.app").exists(), 2),
    ]

    reached = -1
    for level in range(0, 4):
        needed = [t for t in tools if t[3] == level]
        if needed and all(t[2] for t in needed):
            reached = level
        else:
            break

    # First Light needs a model to talk to. Claude Code arrives at level 0 and
    # Ollama at level 2, so on most machines this is true well before the last
    # level is done — which is the point: the proof moment should not be gated
    # behind three hours of installing.
    first_light_ready = bool(_which("claude")) or bool(_which("ollama"))

    return {
        "macos": platform.mac_ver()[0] or "unknown",
        "arch": platform.machine(),
        "repo_version": (ROOT / "VERSION").read_text(encoding="utf-8").strip()
        if (ROOT / "VERSION").exists()
        else "unknown",
        "tested_on": "26.5",
        "level_reached": reached,
        "first_light_ready": first_light_ready,
        "tools": [
            {"id": t[0], "name": t[1], "present": t[2], "level": t[3]} for t in tools
        ],
    }


# =============================================================================
# Job runner — one at a time, streamed
# =============================================================================


class Job:
    """A single running action. One at a time, on purpose.

    Two setups running at once is never what anyone wants, and a queue would
    only hide that. The UI shows the running job and refuses to start a second.
    """

    def __init__(self, action_id, label, argv, ok_codes=(0,)):
        self.action_id = action_id
        self.label = label
        self.argv = argv
        self.ok_codes = ok_codes
        self.lines = []
        self.state = "running"
        self.exit_code = None
        self.started = time.time()
        self.truncated = False
        self.proc = None
        self._lock = threading.Lock()

    def append(self, line):
        with self._lock:
            if len(self.lines) >= MAX_OUTPUT_LINES:
                self.truncated = True
                return
            self.lines.append(line)

    def snapshot(self, offset):
        with self._lock:
            return {
                "action": self.action_id,
                "label": self.label,
                "command": " ".join(self.argv),
                "state": self.state,
                "exit_code": self.exit_code,
                "truncated": self.truncated,
                "total": len(self.lines),
                "from": offset,
                "lines": self.lines[offset:],
                "elapsed": round(time.time() - self.started, 1),
            }

    def stop(self):
        proc = self.proc
        if proc and proc.poll() is None:
            proc.terminate()
            return True
        return False


CURRENT_JOB = None
JOB_LOCK = threading.Lock()


def start_job(action_id, action, argv):
    global CURRENT_JOB
    with JOB_LOCK:
        if CURRENT_JOB is not None and CURRENT_JOB.state == "running":
            return None
        job = Job(action_id, action.label, argv, action.ok_codes)
        CURRENT_JOB = job

    def worker():
        try:
            proc = subprocess.Popen(
                argv,
                cwd=str(ROOT),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
                env={**os.environ, "PATH": PROBE_PATH, "NO_COLOR": "1"},
            )
        except OSError as exc:
            job.append(f"Could not start: {exc}")
            job.state = "failed"
            job.exit_code = 127
            return
        job.proc = proc
        assert proc.stdout is not None
        for line in proc.stdout:
            job.append(line.rstrip("\n"))
        proc.wait()
        job.exit_code = proc.returncode
        job.state = "done" if proc.returncode in job.ok_codes else "failed"

    threading.Thread(target=worker, daemon=True).start()
    return job


def hand_to_terminal(action_id, action, argv):
    """Write the command as a readable script and open it in Terminal.app.

    Deliberately a file rather than an ``osascript`` one-liner: the user can read
    exactly what is about to run before allowing it, the quoting cannot go wrong,
    and ``local/app-runs/`` keeps a record of what this app handed over. That
    directory is gitignored.
    """
    HANDOFF_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    script = HANDOFF_DIR / f"{stamp}-{action_id}.command"
    command = shlex.join(argv)
    script.write_text(
        "#!/bin/bash\n"
        "# Written by the kickoff-ai Control Room. Safe to read, safe to delete.\n"
        "# Started from the app; running here so you can see it and stop it.\n"
        f"cd {shlex.quote(str(ROOT))} || exit 1\n"
        f"echo {shlex.quote('--> ' + command)}\n"
        f"{command}\n"
        'status=$?\n'
        'echo\n'
        'echo "--> finished with exit code $status"\n'
        'echo "You can close this window."\n'
        "exit $status\n",
        encoding="utf-8",
    )
    script.chmod(0o755)
    try:
        subprocess.run(["open", "-a", "Terminal", str(script)], check=True, timeout=15)
    except (OSError, subprocess.SubprocessError) as exc:
        return None, str(exc)
    return script, None


def resolve_argv(action, level):
    argv = list(action.argv)
    if action.accepts_level and level is not None:
        argv += ["--level", str(level)]
    if action.mode == "terminal":
        argv += ["--yes"]
    return argv


# =============================================================================
# HTTP
# =============================================================================

ALLOWED_ORIGINS = {
    f"http://127.0.0.1:{PORT}",
    f"http://localhost:{PORT}",
}

CONTENT_TYPES = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".svg": "image/svg+xml",
}


class Handler(BaseHTTPRequestHandler):
    server_version = "kickoff-control-room"
    protocol_version = "HTTP/1.1"

    # --- plumbing ------------------------------------------------------------

    def log_message(self, fmt, *args):  # noqa: A003 - stdlib signature
        pass

    def _send(self, code, body, content_type="application/json; charset=utf-8"):
        if isinstance(body, (dict, list)):
            body = json.dumps(body)
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def _error(self, code, message):
        self._send(code, {"error": message})

    def _authorised(self):
        """Token plus Origin: the two local threats, each with its own answer.

        The token stops another process on this Mac from driving the app; the
        Origin allow-list stops a web page the user happens to have open from
        POSTing to 127.0.0.1. A browser will not let that page read the token,
        and it cannot forge the header either.
        """
        origin = self.headers.get("Origin")
        if origin and origin not in ALLOWED_ORIGINS:
            return False
        return secrets.compare_digest(self.headers.get("X-API-Token", ""), API_TOKEN)

    def _body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length > MAX_BODY:
            return None
        if length == 0:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None

    # --- routes --------------------------------------------------------------

    def do_GET(self):  # noqa: N802 - stdlib signature
        path = urlparse(self.path).path
        query = dict(
            part.split("=", 1)
            for part in urlparse(self.path).query.split("&")
            if "=" in part
        )

        if path == "/":
            return self._serve_index()
        if path.startswith("/ui/"):
            return self._serve_static(path[len("/ui/") :])

        if not path.startswith("/api/"):
            return self._error(404, "not found")
        if not self._authorised():
            return self._error(403, "not authorised")

        if path == "/api/state":
            return self._send(
                200,
                {
                    "machine": probe_machine(),
                    "currency": read_currency(),
                    "registry_count": len(read_registry()),
                    "counts": read_counts(),
                },
            )
        if path == "/api/guide":
            return self._send(
                200,
                {
                    "steps": build_guide(),
                    "actions": {
                        key: {
                            "label": act.label,
                            "blurb": act.blurb,
                            "changes": act.changes,
                            "mode": act.mode,
                            "confirm": act.confirm,
                            "command": " ".join(act.argv),
                        }
                        for key, act in ACTIONS.items()
                    },
                },
            )
        if path == "/api/registry":
            return self._send(200, {"entries": read_registry()})
        if path == "/api/currency":
            return self._send(200, read_currency())
        if path == "/api/docs":
            doc_id = query.get("id")
            if doc_id is None:
                return self._send(
                    200,
                    {
                        "docs": [
                            {"id": i, "title": t, "available": p.exists()}
                            for i, t, p in DOCS
                        ]
                    },
                )
            for i, title, p in DOCS:
                if i == doc_id:
                    if not p.exists():
                        return self._error(404, "document not found on disk")
                    return self._send(
                        200,
                        {"id": i, "title": title, "markdown": p.read_text(encoding="utf-8")},
                    )
            return self._error(404, "unknown document")
        if path == "/api/job":
            job = CURRENT_JOB
            if job is None:
                return self._send(200, {"state": "idle"})
            try:
                offset = max(0, int(query.get("from", "0")))
            except ValueError:
                offset = 0
            return self._send(200, job.snapshot(offset))

        return self._error(404, "unknown endpoint")

    def do_POST(self):  # noqa: N802 - stdlib signature
        path = urlparse(self.path).path
        if not path.startswith("/api/"):
            return self._error(404, "not found")
        if not self._authorised():
            return self._error(403, "not authorised")

        payload = self._body()
        if payload is None:
            return self._error(413, "request body rejected")

        if path == "/api/job/stop":
            job = CURRENT_JOB
            if job is None or not job.stop():
                return self._error(409, "nothing is running")
            return self._send(200, {"stopped": True})

        if path != "/api/run":
            return self._error(404, "unknown endpoint")

        action_id = payload.get("action")
        action = ACTIONS.get(action_id)
        if action is None:
            return self._error(400, "unknown action")

        level = payload.get("level")
        if level is not None:
            if not isinstance(level, int) or level not in (0, 1, 2, 3):
                return self._error(400, "level must be 0, 1, 2 or 3")
            if not action.accepts_level:
                return self._error(400, "this action takes no level")

        if action.confirm and payload.get("confirm") is not True:
            return self._error(400, "this action needs an explicit confirmation")

        argv = resolve_argv(action, level)

        if action.mode == "terminal":
            script, err = hand_to_terminal(action_id, action, argv)
            if err:
                return self._error(500, f"could not open Terminal: {err}")
            return self._send(
                200,
                {
                    "mode": "terminal",
                    "script": str(script.relative_to(ROOT)),
                    "command": " ".join(argv),
                },
            )

        job = start_job(action_id, action, argv)
        if job is None:
            return self._error(409, "something is already running")
        return self._send(200, {"mode": "inline", "command": " ".join(argv)})

    # --- static --------------------------------------------------------------

    def _serve_index(self):
        index = UI_DIR / "index.html"
        if not index.exists():
            return self._error(500, "ui/index.html is missing")
        html = index.read_text(encoding="utf-8").replace("__API_TOKEN__", API_TOKEN)
        self._send(200, html, "text/html; charset=utf-8")

    def _serve_static(self, name):
        # Resolve and confirm the result is still inside ui/ — the one thing a
        # static handler must never get wrong.
        target = (UI_DIR / name).resolve()
        if not str(target).startswith(str(UI_DIR.resolve()) + os.sep) or not target.is_file():
            return self._error(404, "not found")
        ctype = CONTENT_TYPES.get(target.suffix, "application/octet-stream")
        self._send(200, target.read_bytes(), ctype)


def main():
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    url = f"http://{HOST}:{PORT}/"
    print(f"Control Room on {url}")
    print("Press Ctrl-C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
