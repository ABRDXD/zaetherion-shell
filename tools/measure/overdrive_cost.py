#!/usr/bin/env python3
"""Overdrive's cost, on and off (docs/OVERDRIVE.md §9, the ledger for the optimisation pass at the end).

The fixture view (private core, fixture adapter, no host actions) opens in a FloatingWindow on the caller's
Wayland display, so the GPU strata (the fabric, the shockwave) really draw. For each place (Home, the orbit),
it samples `--seconds` in Silent, then asks the private core for a sticky Overdrive lease and samples again
once the engine has spun up, then releases and samples once more after `--settle` seconds (M8's test: back to
the Silent-open baseline ±10 MiB within 5 s). Each window reports RSS, PSS and private dirty separately, CPU as a
share of one core, context switches, and the frames the view actually drew per second. `--playing` makes the
fixture player play with a 30 fps spectrum, which the orbit leases in Overdrive. Nothing real is actuated:
the private core plays its sounds through the fixture profile, which records them. A window touched by input
is reported as interrupted (the user's own interaction), not as a result.

    python3 tools/measure/overdrive_cost.py [--seconds 20] [--playing] [-o out.json]
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
from tools.measure.fixture import ROOT, private_core
from tools.measure.gpu import GpuWatch
from tools.measure.interaction import Interaction
from tools.measure.smaps import window
from tools.measure.desktop_idle import FRAME, row

STATUS = re.compile(r"FART_OVERDRIVE (\{.*\})")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, default=20)
    parser.add_argument("--settle", type=float, default=5, help="seconds after a release before its sample")
    parser.add_argument("--spin", type=float, default=3, help="seconds after a request before its sample")
    parser.add_argument("--playing", action="store_true", help="the fixture player plays, with a 30 fps spectrum")
    parser.add_argument("--places", default="home,orbit")
    parser.add_argument("--cycles", type=int, default=1, help="ignite and release this many times per place: memory that "
                        "stops growing after the first is a one-off cache, memory that keeps growing is a leak")
    parser.add_argument("--build", type=float, default=2.5, help="seconds after opening before the Silent sample")
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
        frames = sum(bool(FRAME.search(l)) for l in lines)
        lease = f.request("status").get("overdrive", {})
        scenarios[name] = dict(interaction=interaction.status, gpu=gpu.result, frames=frames, frames_per_second=round(frames / args.seconds, 2),
                               lease=dict(mode=lease.get("requested", {}).get("mode"), effective=lease.get("effective"), reasons=lease.get("reasons")),
                               view=row(rows, "view"), core=row(rows, "core"))
        print(name, json.dumps({k: scenarios[name][k] for k in ("interaction", "frames_per_second", "lease", "gpu")}),
              "view RSS %.1f PSS %.1f MiB, CPU %.2f %%" % (scenarios[name]["view"]["rss_mib"], scenarios[name]["view"]["pss_mib"],
                                                           scenarios[name]["view"].get("cpu_percent") or 0), file=sys.stderr)

    with private_core(source=args.source, desktop=True, extra_env=extra) as f:
        f.request("view.open", page="home")
        view = f.wait_state(True, "home")["pid"]
        time.sleep(1.5)
        f.navigate()
        for place in [p for p in args.places.split(",") if p]:
            f.request("view.open", page="home", **({"screen": "fart:orbit"} if place == "orbit" else {}))
            f.wait_state(True, "home")
            time.sleep(args.build)  # past the flight, the systems' build and the room's entrance
            sample(f, view, place + "_silent")
            for cycle in range(args.cycles):
                tag = "" if cycle == 0 else str(cycle + 1)
                f.request("overdrive.request", mode="sticky")
                time.sleep(args.spin)
                sample(f, view, place + "_overdrive" + tag)
                f.request("overdrive.release")
                time.sleep(args.settle)
                sample(f, view, place + "_released" + tag)
            f.request("view.close")
            f.wait_state(False, "home")
            time.sleep(1.0)
    commit = subprocess.run(["git", "-C", str(args.source), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    dirty = bool(subprocess.run(["git", "-C", str(args.source), "status", "--porcelain", "--", "view"], capture_output=True, text=True).stdout.strip())
    for place in [p for p in args.places.split(",") if p]:
        silent, released = scenarios.get(place + "_silent"), scenarios.get(place + "_released")
        if silent and released:
            scenarios[place + "_release_delta"] = dict(rss_mib=round(released["view"]["rss_mib"] - silent["view"]["rss_mib"], 2),
                                                       pss_mib=round(released["view"]["pss_mib"] - silent["view"]["pss_mib"], 2))
    report = dict(schema=1, timestamp=datetime.now(timezone.utc).isoformat(), source=str(args.source.resolve()).replace(str(Path.home()), "~", 1),
                  source_commit=commit, source_view_dirty=dirty, platform="wayland/opengl", playing=args.playing,
                  window_seconds=args.seconds, settle_seconds=args.settle, scenarios=scenarios)
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered)
    else:
        print(rendered, end="")
    statuses = {s["interaction"] for s in scenarios.values() if "interaction" in s}
    return 2 if "interrupted" in statuses else 0 if statuses == {"quiet"} else 3


if __name__ == "__main__":
    raise SystemExit(main())
