#!/usr/bin/env python3
"""The orbit camera on the real desktop: frame cost per move (docs/ORBIT.md, docs/M6-SPLIT.md).

The fixture view (private core, fixture adapter, no host actions) opens on the caller's Wayland display
with the frame probe on, settles in Home, then runs a canvas script (FixtureView's FART_CANVAS_SCRIPT):
flights between rooms, the orbit opened and closed, and any call such as a pan, a zoom or an orbit move. Each
step is its own segment: sub-ms GUI frame intervals, misses over 1.5 refresh periods, polish, GPU and
render-thread time (frames.desktop_stats). After each step settles, the view prints the cue activity, so
a cue or idle loop still running at rest is listed by name.

    python3 tools/measure/desktop_canvas.py [--source TREE] [--rounds 2] [--script JSON] [--reduced] [--ambient off]

The default script, per round: flights near and far across the orbit, then the orbit opened and closed
over two rooms. A run touched by input is reported as interrupted and exits 2.
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.measure.budgets import BUDGETS
from tools.measure.desktop_nav import dgpu_status, refresh_hz
from tools.measure.fixture import ROOT, private_core
from tools.measure.frames import desktop_checks, desktop_stats
from tools.measure.interaction import Interaction

ROUND = ["timers", "home", "performance", "notifications", "workspaces", "tasks", "orbit", "back", "media", "orbit", "back", "home"]
SETTLED = re.compile(r"FART_CANVAS settled (\d+) (\d+) (\[.*\])")


def main():
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    parser.add_argument("--source", type=Path, default=ROOT, help="checkout whose view is measured")
    parser.add_argument("--rounds", type=int, default=2)
    parser.add_argument("--script", help="a JSON list of steps instead of the default rounds")
    parser.add_argument("--step-ms", type=int, default=1200, help="time per step, longer than the slowest move")
    parser.add_argument("--reduced", action="store_true", help="the user's reduced-motion preference on")
    parser.add_argument("--ambient", choices=("on", "off"), default="on", help="the user's ambient-detail preference")
    parser.add_argument("--motion", choices=("fart", "serpantinum"), default="fart")
    parser.add_argument("--gc", action="store_true", help="log the QML garbage collector, counted per step")
    parser.add_argument("--output", "-o", type=Path)
    args = parser.parse_args()
    script = json.loads(args.script) if args.script else ROUND * args.rounds
    before = dgpu_status()
    refresh, vrr = refresh_hz()
    delay = 2500
    extra = dict(FART_MOTION=args.motion, FART_KEEP_MAPPED="0", FART_KEEP_SHELL="1",
                 FART_CANVAS_SCRIPT=json.dumps(script), FART_CANVAS_STEP=str(args.step_ms), FART_CANVAS_DELAY=str(delay),
                 FART_REDUCED="1" if args.reduced else "0", FART_AMBIENT="0" if args.ambient == "off" else "1")
    if args.gc:
        extra["QT_LOGGING_RULES"] = "qt.scenegraph.time.renderloop=true;qt.qml.gc.statistics.debug=true"
    with private_core(source=args.source, desktop=True, extra_env=extra) as f:
        f.request("view.open", page="home")
        f.wait_state(True, "home")
        time.sleep(1.0)  # map and focus before observing; the script starts at `delay` after the open
        with Interaction(os.environ) as interaction:
            deadline = time.monotonic() + (delay / 1000) + args.step_ms / 1000 * (len(script) + 1) + 5
            while time.monotonic() < deadline and "FART_CANVAS done" not in f.log.read_text():
                time.sleep(0.2)
        finished = "FART_CANVAS done" in f.log.read_text()
        missing = [l.split()[-1] for l in f.log.read_text().splitlines() if "FART_CANVAS missing" in l]
        f.request("view.close")
        time.sleep(0.6)
        lines = f.log.read_text().splitlines()
    frames = desktop_stats(lines, BUDGETS["navigate"]["p99_ms"], refresh)
    checks = desktop_checks(frames, BUDGETS["desktop_navigate"])
    at_rest = [dict(step=int(m[1]), move=script[int(m[1])], active=int(m[2]), names=json.loads(m[3]))
               for m in map(SETTLED.search, lines) if m]
    commit = subprocess.run(["git", "-C", str(args.source), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "-C", str(args.source), "status", "--porcelain", "--", "view"], capture_output=True, text=True).stdout.strip())
    report = dict(schema=1, timestamp=datetime.now(timezone.utc).isoformat(),
                  source=str(args.source.resolve()).replace(str(Path.home()), "~", 1), source_commit=commit, source_view_dirty=dirty,
                  platform="wayland/opengl", gc_logged=args.gc, motion=args.motion, reduced=args.reduced, ambient=args.ambient,
                  script=script, step_ms=args.step_ms, finished=finished, missing_calls=missing,
                  interaction=interaction.status, refresh_hz=refresh, vrr=vrr, dgpu_before=before, dgpu_after=dgpu_status(),
                  checks=checks, still_moving_at_rest=[s for s in at_rest if s["active"]], frames=frames)
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered)
    else:
        print(rendered, end="")
    if interaction.status != "quiet":
        return 2 if interaction.status == "interrupted" else 3
    if not finished or missing:
        return 3
    return 1 if any(c["status"] == "fail" for c in checks.values()) else 0


if __name__ == "__main__":
    raise SystemExit(main())
