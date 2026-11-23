#!/usr/bin/env python3
"""The command line on the real desktop: missed presentations while typing and while the hint and log change.

The fixture view (private core, fixture adapter) opens Home in a FloatingWindow on the caller's Wayland
display. After it settles, the read-only Hyprland observer starts and the view types SCRIPT itself at
30 ms per character (TextInput.insert, so this measures rendering, not key latency), pressing Enter after
each line. Only verbs that act on the private core or open rooms are typed; nothing reaches the host.
The budget (DAILY_DRIVER §1): 0 missed presentations in the "cmdline" segment, and GPU and render-thread
p99 ≤ 6.9 ms. Exit codes as desktop_nav.py.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.measure.budgets import BUDGETS
from tools.measure.desktop_nav import dgpu_status, refresh_hz
from tools.measure.fixture import private_core
from tools.measure.frames import desktop_stats
from tools.measure.interaction import Interaction

# Grows the hint (usage, candidates), the log (ok, info, error, multi-line help) and history.
SCRIPT = ["tim 25", "task measure the command line", "se", "?", "tim banana", "? tim", "tim stop", "task second line !tomorrow"]


def checks(stats, budget):
    """The command-line budget against the cmdline segment (its first interval included: no room loads there)."""
    segment = stats["rooms"].get("cmdline")
    if not segment:
        return {key: dict(measured=None, limit=limit, status="insufficient") for key, limit in budget.items()}
    measured = dict(missed=segment["missed_steady"] + segment["missed_per_load_max"],
                    gpu_p99_ms=segment["gpu_ms"]["p99"], render_thread_p99_ms=segment["render_thread_work_ms"]["p99"])
    return {key: dict(measured=measured[key], limit=limit,
                      status="insufficient" if measured[key] is None else "pass" if measured[key] <= limit else "fail")
            for key, limit in budget.items()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--motion", choices=("fart", "serpantinum"), default="serpantinum")
    parser.add_argument("--output", "-o", type=Path)
    args = parser.parse_args()
    before = dgpu_status()
    refresh, vrr = refresh_hz()
    delay = 3000
    extra = dict(FART_MOTION=args.motion, FART_CMDLINE_SCRIPT=json.dumps(SCRIPT), FART_CMDLINE_DELAY=str(delay))
    with private_core(desktop=True, extra_env=extra) as f:
        f.request("view.open", page="home")
        f.wait_state(True, "home")
        time.sleep(1.5)  # map, focus and settle; typing starts at 3 s after Home loaded
        with Interaction(os.environ) as interaction:
            deadline = time.time() + 30
            while time.time() < deadline and "FART_CMDLINE done" not in f.log.read_text():
                time.sleep(0.1)
            time.sleep(1.0)  # the last replies and the log fade
        f.request("view.close")
        time.sleep(0.5)
        lines = f.log.read_text().splitlines()
    commit = subprocess.run(["git", "-C", str(Path(__file__).resolve().parents[2]), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    frames = desktop_stats(lines, BUDGETS["navigate"]["p99_ms"], refresh)
    result = checks(frames, BUDGETS["desktop_cmdline"])
    report = dict(schema=1, timestamp=datetime.now(timezone.utc).isoformat(), source_commit=commit, platform="wayland/opengl",
                  motion=args.motion, script=SCRIPT, typed_ms_per_character=30, interaction=interaction.status,
                  dgpu_before=before, dgpu_after=dgpu_status(), vrr=vrr, checks=result,
                  cmdline=frames["rooms"].get("cmdline"), refresh_hz=frames["refresh_hz"])
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered)
    else:
        print(rendered, end="")
    if interaction.status != "quiet":
        return 2 if interaction.status == "interrupted" else 3
    statuses = {c["status"] for c in result.values()}
    return 1 if "fail" in statuses else 3 if "insufficient" in statuses else 0


if __name__ == "__main__":
    raise SystemExit(main())
