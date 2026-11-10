#!/usr/bin/env python3
"""Open-idle and closed-idle cost of the fixture view on the real desktop (docs/CUES.md §10.5).

The fixture view (private core, fixture adapter, no host actions) opens in a FloatingWindow on the
caller's Wayland display with the frame probe off, so nothing but the view itself asks for frames.
It visits every room once, settles in Home, then samples `--seconds` open and `--seconds` closed:
RSS, PSS and private dirty separately, CPU ticks and context switches per thread set, the frames
the view rendered (Qt render-loop lines) and the cue activity count it prints. Each window has its
own interaction observer, so a phase touched by input is reported as interrupted on its own.

`--rooms home,tasks` (or `all`) samples each room open and at rest instead of Home alone: after each window
the view folds, printing the cues and idle loops still active, and the next room opens. `--reduced` and
`--ambient off` set the user's own preferences first (docs/M6-SPLIT.md: idle loops must stop under both).
The pseudo-room `orbit` is Home with the orbit overview open over it (docs/ORBIT.md; Shell.toggleOrbit).
Frames per second is what the view actually drew over the window, not the nominal refresh.
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
from tools.measure.fixture import PAGES, ROOT, private_core
from tools.measure.interaction import Interaction
from tools.measure.smaps import window

MOTION = re.compile(r"FART_MOTION (\w+) (\d+) (\[.*\])")
FRAME = re.compile(r"qt\.scenegraph\.time\.renderloop: .*frame rendered in")


def row(rows, role):
    found = next((r for r in rows if r["role"] == role), None)
    if not found:
        return None
    keep = ("coverage", "cpu_ticks", "cpu_percent", "voluntary_switches", "nonvoluntary_switches", "switches_per_minute", "thread_set_changed")
    return dict(rss_mib=found["memory_kib"]["Rss"] / 1024, pss_mib=found["memory_kib"]["Pss"] / 1024,
                private_dirty_mib=found["memory_kib"]["Private_Dirty"] / 1024, **{k: found.get(k) for k in keep})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, default=60)
    parser.add_argument("--motion", choices=("fart", "serpantinum"), default="serpantinum")
    parser.add_argument("--unload-shell", action="store_true", help="unload Shell on fold, as before M5 (the Q2 A/B)")
    parser.add_argument("--rooms", help="comma-separated rooms to sample open, or 'all'")
    parser.add_argument("--reduced", action="store_true", help="the user's reduced-motion preference on")
    parser.add_argument("--ambient", choices=("on", "off"), default="on", help="the user's ambient-detail preference")
    parser.add_argument("--idle-ms", type=int, help="the idle clock's interval (Motion.idleInterval; 0 = every frame, the default), for a rate sweep")
    parser.add_argument("--playing", action="store_true", help="the fixture player plays, with a 30 fps spectrum")
    parser.add_argument("--source", type=Path, default=ROOT, help="checkout whose view is measured")
    parser.add_argument("--output", "-o", type=Path)
    args = parser.parse_args()
    extra = dict(FART_MOTION=args.motion, FART_FRAME_PROBE="0", QSG_RHI_PROFILE="0", FART_KEEP_SHELL="0" if args.unload_shell else "1",
                 FART_REDUCED="1" if args.reduced else "0", FART_AMBIENT="0" if args.ambient == "off" else "1",
                 FART_FIXTURE_PLAYING="1" if args.playing else "0", FART_IDLE_MS=str(args.idle_ms or ""))
    rooms = list(PAGES) if args.rooms == "all" else [r for r in (args.rooms or "").split(",") if r]
    scenarios = {}

    def sample(f, view, name):
        before = len(f.log.read_text().splitlines())
        with Interaction(os.environ) as interaction:
            rows = window(f.process.pid, args.seconds, view)
        lines = f.log.read_text().splitlines()[before:]
        frames = sum(bool(FRAME.search(l)) for l in lines)
        scenarios[name] = dict(interaction=interaction.status, frames=frames, frames_per_second=round(frames / args.seconds, 2),
                               view=row(rows, "view"), core=row(rows, "core"))

    def motion_after(f, seen, kind):
        """The FART_MOTION <kind> line printed after line `seen`, as {active, names}."""
        for line in f.log.read_text().splitlines()[seen:]:
            if (m := MOTION.search(line)) and m[1] == kind:
                return dict(active=int(m[2]), names=json.loads(m[3]))
        return None

    if rooms:
        with private_core(source=args.source, desktop=True, extra_env=extra) as f:
            f.request("view.open", page="home")
            view = f.wait_state(True, "home")["pid"]
            time.sleep(1.5)
            f.navigate()  # compile and visit every room once, as the default run does
            for room in rooms:
                page = "home" if room == "orbit" else room
                f.request("view.open", page=page, **({"screen": "fart:orbit"} if room == "orbit" else {}))
                f.wait_state(True, page)
                time.sleep(1.5)  # past the travel and the room's entrance
                sample(f, view, "open_" + room)
                seen = len(f.log.read_text().splitlines())
                f.request("view.close")
                f.wait_state(False, page)
                time.sleep(0.8)
                scenarios["open_" + room]["motion"] = motion_after(f, seen, "open")
            time.sleep(0.7)
            sample(f, view, "closed_idle")
            lines = f.log.read_text().splitlines()
        closed = [m for m in map(MOTION.search, lines) if m and m[1] == "closed"]
        if closed:
            scenarios["closed_idle"]["motion"] = dict(active=int(closed[-1][2]), names=json.loads(closed[-1][3]))
        return report_and_exit(args, scenarios)

    with private_core(source=args.source, desktop=True, extra_env=extra) as f:
        f.request("view.open", page="home")
        view = f.wait_state(True, "home")["pid"]
        time.sleep(1.5)
        f.navigate()
        f.request("view.open", page="home")
        f.wait_state(True, "home")
        time.sleep(1.5)  # past the longest entrance
        sample(f, view, "open_idle")
        f.request("view.close")
        f.wait_state(False, "home")
        time.sleep(1.5)  # past the fold, the Shell unload and the closed report
        sample(f, view, "closed_idle")
        lines = f.log.read_text().splitlines()
    for m in map(MOTION.search, lines):
        if m:
            scenarios["open_idle" if m[1] == "open" else "closed_idle"]["motion"] = dict(active=int(m[2]), names=json.loads(m[3]))
    return report_and_exit(args, scenarios)


def report_and_exit(args, scenarios):
    commit = subprocess.run(["git", "-C", str(args.source), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "-C", str(args.source), "status", "--porcelain", "--", "view"], capture_output=True, text=True).stdout.strip())
    report = dict(schema=1, timestamp=datetime.now(timezone.utc).isoformat(), source=str(args.source.resolve()).replace(str(Path.home()), "~", 1),
                  source_commit=commit, source_view_dirty=dirty, platform="wayland/opengl", keep_shell=not args.unload_shell,
                  motion=args.motion, reduced=args.reduced, ambient=args.ambient, playing=args.playing, idle_ms=args.idle_ms, window_seconds=args.seconds, scenarios=scenarios)
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered)
    else:
        print(rendered, end="")
    statuses = {s["interaction"] for s in scenarios.values()}
    return 2 if "interrupted" in statuses else 0 if statuses == {"quiet"} else 3


if __name__ == "__main__":
    raise SystemExit(main())
