#!/usr/bin/env python3
"""Nine-room navigation on the real desktop, with sub-millisecond frame intervals per room.

The fixture view (private core, fixture adapter, no host actions) opens in a FloatingWindow on the
caller's Wayland display. After Home settles, the read-only Hyprland observer starts. `--unfolds`
folds and unfolds the panel that many times first (the window stays mapped, so only the body animates),
then `--passes` walks through every room. A run touched by focus, workspace or cursor changes is reported as
interrupted. See frames.desktop_stats for the units and frames.desktop_checks for the budget.

`--cold N` and `--warm N` measure opening to an interactive command line instead (DAILY_DRIVER §1):
the time from sending `view.open` to the view's `FART_CMDLINE ready` marker, both wall-clock ms.
Cold: each run starts a fresh private core, so the view is absent and the run includes the `qs` start
(and, without --cache-home, QML compilation). `--core-settle S` waits S seconds after the core starts,
so its start-up checks finish first and the run is the daily case: the core up, the view reaped. Warm: one view; close, wait 1 s, open. Each run is
observed on its own; these runs map their own window, so focus changes are not counted as input
(the cursor, workspace and monitor still are). Budget: every run ≤ 450 ms cold, ≤ 1 frame warm.
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
from tools.measure.fixture import PAGES, ROOT, private_core
from tools.measure.frames import cmdline_markers, desktop_checks, desktop_stats, open_checks, open_stats
from tools.measure.interaction import FOCUS, Interaction

DGPU = Path("/sys/bus/pci/devices")


def dgpu_status():
    """runtime_status of every NVIDIA PCI function (read-only; never nvidia-smi)."""
    return {d.name: (d / "power/runtime_status").read_text().strip()
            for d in sorted(DGPU.iterdir())
            if (d / "vendor").read_text().strip() == "0x10de" and (d / "power/runtime_status").exists()}


def refresh_hz():
    """The focused monitor's refresh rate, read-only from Hyprland."""
    monitors = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, check=True).stdout)
    focused = next(m for m in monitors if m.get("focused"))
    return float(focused["refreshRate"]), bool(focused.get("vrr"))


def wait_marker(fixture, seen: int, timeout: float = 10.0) -> float:
    """The (seen + 1)-th FART_CMDLINE ready marker in the view's log, in wall-clock ms."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        markers = cmdline_markers(fixture.log.read_text().splitlines()) if fixture.log.exists() else []
        if len(markers) > seen:
            return markers[seen]
        time.sleep(0.005)
    raise RuntimeError("the view never reported an interactive command line (FART_CMDLINE ready)")


def marker_count(fixture) -> int:
    return len(cmdline_markers(fixture.log.read_text().splitlines())) if fixture.log.exists() else 0


def timed_open(fixture) -> tuple[float | None, str]:
    """(latency, observer status). An open that never becomes interactive counts as interrupted: the
    marker needs keyboard focus, and these runs do not watch focus, so input that takes focus away shows
    up only as the missing marker. The marker count is taken now, so a late one is never credited to the
    next open."""
    seen = marker_count(fixture)
    with Interaction(os.environ, ignore=FOCUS) as interaction:
        sent = time.time() * 1000
        fixture.request("view.open", page="home")
        try:
            ready = wait_marker(fixture, seen)
        except RuntimeError:
            return None, "interrupted"
    return ready - sent, interaction.status


def measure_open(args):
    """(cold latencies, warm latencies, per-run observer statuses)."""
    extra = dict(FART_MOTION=args.motion, FART_KEEP_MAPPED="0", FART_KEEP_SHELL="0" if args.unload_shell else "1")
    cold, warm, statuses = [], [], []
    for _ in range(args.cold):
        with private_core(source=args.source, desktop=True, cache_home=args.cache_home, extra_env=extra) as f:
            time.sleep(args.core_settle)  # 0: a fresh core; > 0: a running core with the view reaped
            latency, status = timed_open(f)
            statuses.append(status)
            if latency is not None:
                cold.append(latency)
            f.wait_state(True, "home")
            f.request("view.close")
            time.sleep(0.5)
    if args.warm:
        with private_core(source=args.source, desktop=True, cache_home=args.cache_home, extra_env=extra) as f:
            f.request("view.open", page="home")
            try:
                wait_marker(f, 0)
            except RuntimeError:
                return cold, warm, statuses + ["interrupted"]  # the uncounted first open never got focus
            f.wait_state(True, "home")
            time.sleep(1.5)  # map, focus and settle; the first open is cold and is not counted
            for _ in range(args.warm):
                f.request("view.close")
                f.wait_state(False, "home")
                time.sleep(1.0)
                latency, status = timed_open(f)
                statuses.append(status)
                if latency is not None:
                    warm.append(latency)
                f.wait_state(True, "home")
            f.request("view.close")
            time.sleep(0.5)
    return cold, warm, statuses


def combined(statuses) -> str:
    return "interrupted" if "interrupted" in statuses else "unknown" if "unknown" in statuses or not statuses else "quiet"


def open_main(args, before, refresh, vrr):
    cold, warm, statuses = measure_open(args)
    commit = subprocess.run(["git", "-C", str(args.source), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    cold_stats = open_stats(cold, refresh) if args.cold else None
    warm_stats = open_stats(warm, refresh) if args.warm else None
    checks = open_checks(cold_stats, warm_stats, BUDGETS["desktop_open"])
    report = dict(schema=1, timestamp=datetime.now(timezone.utc).isoformat(),
                  source=str(args.source.resolve()).replace(str(Path.home()), "~", 1), source_commit=commit,
                  platform="wayland/opengl", motion=args.motion, warm_cache=args.cache_home is not None,
                  core_settle_s=args.core_settle if args.cold else None, interaction=combined(statuses), runs=statuses, refresh_hz=refresh, vrr=vrr,
                  dgpu_before=before, dgpu_after=dgpu_status(), checks=checks, cold=cold_stats, warm=warm_stats)
    return report, checks


def exit_code(status, checks) -> int:
    if status != "quiet":
        return 2 if status == "interrupted" else 3
    statuses = {c["status"] for c in checks.values()}
    return 1 if "fail" in statuses else 3 if "insufficient" in statuses or not statuses else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--passes", type=int, default=4)
    parser.add_argument("--dwell", type=float, default=0.25, help="seconds on each loaded room")
    parser.add_argument("--source", type=Path, default=ROOT, help="checkout whose view is measured")
    parser.add_argument("--cache-home", type=Path, help="persistent XDG_CACHE_HOME (warm QML compile cache)")
    parser.add_argument("--motion", choices=("fart", "serpantinum"), default="fart", help="motion profile (docs/CUES.md §15)")
    parser.add_argument("--unfolds", type=int, default=0, help="fold/unfold cycles before navigating")
    parser.add_argument("--unload-shell", action="store_true", help="unload Shell on fold, as before M5 (the Q2 A/B)")
    parser.add_argument("--cold", type=int, default=0, metavar="N", help="N cold opens to an interactive command line")
    parser.add_argument("--core-settle", type=float, default=0.0, metavar="S",
                        help="seconds between a cold run's core start and view.open (default 0: a fresh core)")
    parser.add_argument("--warm", type=int, default=0, metavar="N", help="N warm opens to an interactive command line")
    parser.add_argument("--output", "-o", type=Path)
    args = parser.parse_args()
    before = dgpu_status()
    refresh, vrr = refresh_hz()
    if args.cold or args.warm:
        report, checks = open_main(args, before, refresh, vrr)
        rendered = json.dumps(report, indent=2) + "\n"
        if args.output:
            args.output.write_text(rendered)
        else:
            print(rendered, end="")
        return exit_code(report["interaction"], checks)
    extra = dict(FART_MOTION=args.motion, FART_KEEP_MAPPED="1" if args.unfolds else "0", FART_KEEP_SHELL="0" if args.unload_shell else "1")
    with private_core(source=args.source, desktop=True, cache_home=args.cache_home, extra_env=extra) as f:
        f.request("view.open", page="home")
        f.wait_state(True, "home")
        time.sleep(1.5)  # let the window map, take focus and settle before observing
        with Interaction(os.environ) as interaction:
            for _ in range(args.unfolds):
                f.request("view.close")
                f.wait_state(False, "home")
                time.sleep(0.6)  # past the longest fold (160 ms), then a closed idle stretch
                f.request("view.open", page="home")
                f.wait_state(True, "home")
                time.sleep(1.4)  # past the longest unfold (1000 ms)
            for _ in range(args.passes):
                for page in PAGES:
                    f.request("view.open", page=page)
                    f.wait_state(True, page)
                    time.sleep(args.dwell)
        f.request("view.close")
        f.wait_state(False, PAGES[-1])
        time.sleep(0.5)
        lines = f.log.read_text().splitlines()
    commit = subprocess.run(["git", "-C", str(args.source), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    source = str(args.source.resolve()).replace(str(Path.home()), "~", 1)
    frames = desktop_stats(lines, BUDGETS["navigate"]["p99_ms"], refresh)
    checks = desktop_checks(frames, BUDGETS["desktop_navigate"])
    report = dict(schema=1, timestamp=datetime.now(timezone.utc).isoformat(), source=source, source_commit=commit,
                  platform="wayland/opengl", motion=args.motion, keep_shell=not args.unload_shell, unfolds=args.unfolds, passes=args.passes, warm_cache=args.cache_home is not None, dwell_s=args.dwell, interaction=interaction.status,
                  dgpu_before=before, dgpu_after=dgpu_status(), vrr=vrr,
                  checks=checks, frames=frames)
    rendered = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered)
    else:
        print(rendered, end="")
    return exit_code(interaction.status, checks)


if __name__ == "__main__":
    raise SystemExit(main())
