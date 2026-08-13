"""Regenerate the Control Room screenshots in docs/img/.

    python3 scripts/capture-screenshots.py

Headless Chromium against the app on localhost — no screen recording, no window
manager, no human at a screen. The images are published, so this script owns the
one thing that is easy to forget and impossible to undo once pushed: it moves
``local/manifests/tools.local.yaml`` aside for the duration, so the Tools and
Drift views show the public registry only and no machine-specific candidate ends
up in a picture on the internet. It puts the overlay back even if the run fails.

Requires ``playwright`` and its Chromium build:

    pip install playwright && playwright install chromium

That is a maintainer dependency, not a setup dependency. Nothing in the install
path, the gate, or the app needs it — the repo still runs on a machine that has
python3 and nothing else, which is the whole point of the Control Room.

Re-run this whenever the app's layout or copy changes. A screenshot that no
longer matches the app is the same failure mode as a number that no longer
matches the code, and this repo is supposed to notice those.
"""

from __future__ import annotations

import os
import subprocess
import sys
import time
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "docs" / "img"
OVERLAY = ROOT / "local" / "manifests" / "tools.local.yaml"
PARKED = OVERLAY.with_suffix(".yaml.capturing")

PORT = os.environ.get("APP_PORT", "8799")
VIEWPORT = {"width": 1760, "height": 1000}

VIEWS = [
    ("dashboard", "control-room.png"),
    ("guide", "control-room-guide.png"),
    ("registry", "control-room-tools.png"),
    ("currency", "control-room-drift.png"),
]


@contextmanager
def overlay_parked():
    """Hide the machine-specific registry overlay for the duration.

    The public images must show the public registry. Restored in a finally
    block, so an exception or a Ctrl-C cannot leave the machine's own overlay
    renamed.
    """
    moved = False
    if OVERLAY.exists():
        OVERLAY.rename(PARKED)
        moved = True
        print(f"  parked {OVERLAY.relative_to(ROOT)}")
    try:
        yield
    finally:
        if moved:
            PARKED.rename(OVERLAY)
            print(f"  restored {OVERLAY.relative_to(ROOT)}")


@contextmanager
def app_running():
    proc = subprocess.Popen(
        [sys.executable, str(ROOT / "app" / "server.py")],
        cwd=str(ROOT),
        env={**os.environ, "APP_PORT": PORT},
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        time.sleep(3)
        if proc.poll() is not None:
            raise SystemExit(f"the app exited immediately — is port {PORT} taken?")
        yield
    finally:
        proc.terminate()
        proc.wait(timeout=10)


def main():
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        raise SystemExit(
            "playwright is not installed.\n"
            "  pip install playwright && playwright install chromium"
        )

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    with overlay_parked(), app_running():
        with sync_playwright() as pw:
            browser = pw.chromium.launch()
            page = browser.new_page(viewport=VIEWPORT, device_scale_factor=2)
            page.goto(f"http://127.0.0.1:{PORT}/", wait_until="networkidle")
            # The dashboard renders from an API call; wait for real content
            # rather than a fixed sleep, or the first shot catches an empty page.
            page.wait_for_selector(".tile-value", timeout=15000)

            for view, filename in VIEWS:
                page.click(f'.nav-item[data-view="{view}"]')
                page.wait_for_timeout(900)
                target = OUT_DIR / filename
                page.screenshot(path=str(target))
                print(f"  {filename}  {target.stat().st_size // 1024} KB")

            browser.close()


if __name__ == "__main__":
    main()
