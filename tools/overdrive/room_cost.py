#!/usr/bin/env python3
"""Overdrive's cost per room, on and off (docs/OVERDRIVE.md §9, B's rows): A's overdrive_cost.py, room by room.

The same measurement as tools/measure/overdrive_cost.py (the fixture view on the caller's Wayland display, a private
core, the fixture adapter, nothing real actuated), but each place is a room opened by name, so B's room features are
measured where they live: Media (the kinetic stage, the wedge, the spectral architecture), Performance (the orrery,
the palimpsest), Home (the sky, the day ruler), Inbox, Tasks, Devices. For each room: Silent, Overdrive once the engine
has spun up, and released after `--settle` seconds. RSS, PSS and private dirty separately, CPU as a share of one core,
context switches, frames drawn per second and GPU load. A window touched by input is reported as interrupted, not as a
result; the exit code is 2 then.

    python3 tools/overdrive/room_cost.py [--rooms media,performance,home] [--playing] [--seconds 15] [-o out.json]
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
from tools.measure.fixture import ROOT, private_core  # noqa: E402
from tools.measure.gpu import GpuWatch  # noqa: E402
from tools.measure.interaction import Interaction  # noqa: E402
from tools.measure.smaps import window  # noqa: E402
from tools.measure.desktop_idle import FRAME, row  # noqa: E402


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rooms", default="media,performance,home,notifications,tasks,devices")
    parser.add_argument("--seconds", type=float, default=15)
    parser.add_argument("--settle", type=float, default=5)
    parser.add_argument("--spin", type=float, default=3)
    parser.add_argument("--build", type=float, default=2.5)
    parser.add_argument("--playing", action="store_true", help="the fixture player plays, with a 30 fps spectrum")
    parser.add_argument("--source", type=Path, default=ROOT)
    parser.add_argument("--output", "-o", type=Path)
    args = parser.parse_args()
    extra = dict(FART_MOTION="serpantinum", FART_FRAME_PROBE="0", QSG_RHI_PROFILE="0", FART_KEEP_SHELL="1",
                 FART_REDUCED="0", FART_AMBIENT="1", FART_FIXTURE_PLAYING="1" if args.playing else "0", FART_IDLE_MS="")
    scenarios = {}

    def sample(f, view, name):
        before = len(f.log.read_text().splitlines())
        with Interaction(os.environ) as interaction, GpuWatch(view) as gpu:
            rows = window(f.process.pid, args.seconds, view)
        lines = f.log.read_text().splitlines()[before:]
        frames = sum(bool(FRAME.search(line)) for line in lines)
        lease = f.request("status").get("overdrive", {})
        scenarios[name] = dict(interaction=interaction.status, gpu=gpu.result, frames=frames,
                               frames_per_second=round(frames / args.seconds, 2),
                               lease=dict(mode=lease.get("requested", {}).get("mode"), effective=lease.get("effective"),
                                          reasons=lease.get("reasons")),
                               view=row(rows, "view"), core=row(rows, "core"))
        v = scenarios[name]["view"]
        print(name, scenarios[name]["interaction"], scenarios[name]["lease"]["effective"],
              "fps %.1f, view RSS %.1f PSS %.1f MiB, CPU %.1f %%" % (scenarios[name]["frames_per_second"], v["rss_mib"], v["pss_mib"],
                                                                   v.get("cpu_percent") or 0), file=sys.stderr)

    rooms = [r for r in args.rooms.split(",") if r]
    with private_core(source=args.source, desktop=True, extra_env=extra) as f:
        f.request("view.open", page="home")
        view = f.wait_state(True, "home")["pid"]
        time.sleep(1.5)
        for room in rooms:
            f.request("view.open", page=room)
            f.wait_state(True, room)
            time.sleep(args.build)
            sample(f, view, room + "_silent")
            f.request("overdrive.request", mode="sticky")
            time.sleep(args.spin)
            sample(f, view, room + "_overdrive")
            f.request("overdrive.release")
            time.sleep(args.settle)
            sample(f, view, room + "_released")
        f.request("view.close")
    for room in rooms:
        silent, on, released = (scenarios.get(room + s) for s in ("_silent", "_overdrive", "_released"))
        if silent and on and released:
            scenarios[room + "_delta"] = dict(
                on_rss_mib=round(on["view"]["rss_mib"] - silent["view"]["rss_mib"], 2),
                on_pss_mib=round(on["view"]["pss_mib"] - silent["view"]["pss_mib"], 2),
                on_cpu_percent=round((on["view"].get("cpu_percent") or 0) - (silent["view"].get("cpu_percent") or 0), 2),
                release_rss_mib=round(released["view"]["rss_mib"] - silent["view"]["rss_mib"], 2),
                release_pss_mib=round(released["view"]["pss_mib"] - silent["view"]["pss_mib"], 2))
    commit = subprocess.run(["git", "-C", str(args.source), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    report = dict(schema=1, tool="tools/overdrive/room_cost.py", timestamp=datetime.now(timezone.utc).isoformat(),
                  source=str(args.source.resolve()).replace(str(Path.home()), "~", 1), source_commit=commit,
                  platform="wayland/opengl", playing=args.playing, window_seconds=args.seconds, settle_seconds=args.settle,
                  scenarios=scenarios)
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered)
    else:
        print(rendered, end="")
    statuses = {s["interaction"] for s in scenarios.values() if "interaction" in s}
    return 2 if "interrupted" in statuses else 0 if statuses == {"quiet"} else 3


if __name__ == "__main__":
    raise SystemExit(main())
