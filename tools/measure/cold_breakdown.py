#!/usr/bin/env python3
"""Where a cold open spends its time, phase by phase, on the fixture view (offscreen unless --desktop).

Each run starts a fresh private core, sends `view.open`, and waits for `FART_CMDLINE ready`, like
`desktop_nav.py --cold`. The phases come from wall-clock timestamps in three logs:

  core      sent → the core's "view spawned" line (the one-off foreign-instance check and the fork)
  exec      → Quickshell's "Launching config" (process start, Qt and Quickshell set-up)
  load      → FixtureView's Component.onCompleted (module scan, QML engine, compilation, creation)
  hello     → the queued view.command arrives (socket connect and the hello round trip; the core sends
              the command before its hello reply, so CoreClient.connected flips later and is not a phase)
  open      → handle() returns (Shell and the room built synchronously; "shell" is inside this)
  frame     → FART_CMDLINE ready (the first frame swapped with the command line focused)

`qs` runs through a PATH wrapper that adds --log-times; FixtureView prints FART_COLD markers only with
FART_COLD_PROBE=1. Offscreen uses the software renderer, so `frame` is not the desktop's. No host
action is taken: the fixture adapter has none.

`--real` measures the real view instead: Overlay's layer surface and the Serpantinum adapter, on the
caller's desktop and session (Hyprland, PipeWire, D-Bus), with a private core, runtime and state, so the
live fart-next core and view are untouched. Every UI sound cue is switched off in that private state and
the notification mirror is off. The one host action left is the core's before-open step: if a Serpantinum
calendar or music popup is showing, it is closed, as on any FART open. The panel maps on screen, so this
mode needs the user's go-ahead and a quiet desktop; runs touched by cursor, workspace or monitor
changes are reported as interrupted.
"""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import statistics
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from contextlib import ExitStack, contextmanager
import shutil
import subprocess

from tools.fart_next import try_connect
from tools.measure.fixture import ROOT, Fixture, private_core, stop
from tools.smoke import TREE
from core.sfx import CUES
from tools.measure.interaction import FOCUS, Interaction

PHASES = ("core", "exec", "load", "hello", "open", "frame")
SEEDED = ("settings.json", "preferences.json", "tasks.json")  # --real only
STAMP = r"(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d[.,]\d{3})"
LAUNCH = re.compile(STAMP + r".*Launching config")
SPAWNED = re.compile(STAMP + r" INFO fart\.view: view spawned")
COLD = re.compile(r"FART_COLD (\w+) (\d+)")
READY = re.compile(r"FART_CMDLINE ready (\d+)")


def stamp_ms(text: str) -> float:
    return datetime.strptime(text.replace(",", "."), "%Y-%m-%d %H:%M:%S.%f").timestamp() * 1000


def parse(sent: float, core_log: str, view_log: str) -> dict | None:
    """Phase durations in ms from the logs of one cold open, or None if a marker is missing."""
    marks = {"sent": sent}
    if m := SPAWNED.search(core_log):
        marks["spawned"] = stamp_ms(m[1])
    if m := LAUNCH.search(view_log):
        marks["launch"] = stamp_ms(m[1])
    for m in COLD.finditer(view_log):
        marks.setdefault(m[1], float(m[2]))
    if m := READY.search(view_log):
        marks["ready"] = float(m[1])
    order = ("sent", "spawned", "launch", "created", "command", "handled", "ready")
    if any(k not in marks for k in order):
        return None
    phases = {name: marks[b] - marks[a] for name, a, b in zip(PHASES, order, order[1:])}
    if "shell" in marks:
        phases["open.shell"] = marks["shell"] - marks["command"]
    # The frame phase, split (ColdProbe): each is ms after `handled`, so their order shows on its own.
    for sub in ("swap", "active", "focus", "room"):
        if sub in marks:
            phases["frame." + sub] = marks[sub] - marks["handled"]
    phases["total"] = marks["ready"] - sent
    return phases


WARM = ("relay", "handle", "frame")


def parse_warm(sent: float, view_log: str) -> dict | None:
    """Phase durations in ms of one warm open, from the view log written since it was sent: the view is
    up and Shell is kept, so only the relay, the open's handling and its first interactive frame remain."""
    marks = {}
    for m in COLD.finditer(view_log):
        marks.setdefault(m[1], float(m[2]))
    if m := READY.search(view_log):
        marks["ready"] = float(m[1])
    if any(k not in marks for k in ("command", "handled", "ready")):
        return None
    phases = dict(relay=marks["command"] - sent, handle=marks["handled"] - marks["command"], frame=marks["ready"] - marks["handled"])
    for sub in ("swap", "active", "focus"):
        if sub in marks:
            phases["frame." + sub] = marks[sub] - marks["handled"]
    phases["total"] = marks["ready"] - sent
    return phases


def summary(rows: list[dict]) -> dict:
    keys = [k for k in (*PHASES, *WARM, "open.shell", "frame.swap", "frame.active", "frame.focus", "frame.room", "total") if any(k in r for r in rows)]
    return {k: dict(median=round(statistics.median(v), 1), min=round(min(v), 1), max=round(max(v), 1))
            for k in keys if (v := [r[k] for r in rows if k in r])}


def qs_wrapper(directory: Path, binary: Path | None = None) -> Path:
    real = binary or next((Path(p) / "qs" for p in os.defpath.split(os.pathsep) if (Path(p) / "qs").exists()), None)
    if real is None:
        raise RuntimeError("qs is not on the default PATH")
    wrapper = directory / "qs"
    # Only the view's launch gets timestamps; `qs list` and `qs kill` pass through unchanged.
    wrapper.write_text(f'#!/bin/sh\ncase "$1" in -*) exec {real} --log-times "$@";; esac\nexec {real} "$@"\n')
    wrapper.chmod(0o755)
    return directory


def conditions() -> dict:
    """The CPU power state, read-only: a cold open is short enough that frequency ramp-up dominates it."""
    def read(path):
        try:
            return Path(path).read_text().strip()
        except OSError:
            return None
    supplies = Path("/sys/class/power_supply")
    online = [read(d / "online") for d in supplies.iterdir() if (d / "online").exists()] if supplies.exists() else []
    return dict(platform_profile=read("/sys/firmware/acpi/platform_profile"),
                epp=read("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"),
                governor=read("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"),
                ac_online="1" in online if online else None, loadavg=read("/proc/loadavg"))


@contextmanager
def real_core(source: Path, extra_env: dict, bundle_dir: Path | None = None):
    """A private core whose view is the real entry (shell.qml: Overlay + SerpantinumAdapter) in the
    caller's session. Only the core's runtime, FART state and FART cache are private."""
    source = Path(source).resolve()
    for name in ("WAYLAND_DISPLAY", "XDG_RUNTIME_DIR", "HYPRLAND_INSTANCE_SIGNATURE"):
        if not os.environ.get(name):
            raise RuntimeError(f"--real needs {name} (run it from the desktop session)")
    with ExitStack() as stack:
        base = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="fart-cold-real-")))
        # Its own path, so `qs -n` never meets the live view's instance. --bundle-dir is one fixed path,
        # copied once and then reused as it is, so a QML disk cache can hit and qmldir files can be added.
        bundle = Path(bundle_dir).resolve() if bundle_dir is not None else base / "bundle"
        if not (bundle / "shell.qml").exists():
            bundle.mkdir(parents=True, exist_ok=True)
            for name in TREE:
                path = source / name
                if path.is_dir():
                    shutil.copytree(path, bundle / name, ignore=shutil.ignore_patterns("__pycache__"))
                else:
                    shutil.copy2(path, bundle / name)
        state = base / "state"
        state.mkdir()
        # Copies (read only) of the live view's preferences and tasks, so Home opens as the user sees it.
        # Notifications are not copied; the copies go with the temporary directory.
        live = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "fart-next"
        for name in SEEDED:
            if (live / name).is_file():
                shutil.copy2(live / name, state / name)
        (state / "sfx.json").write_text(json.dumps({"version": 1, "cues": {n: False for n, c in CUES.items() if c.kind == "ui"}}))
        runtime = base / "run"
        runtime.mkdir(mode=0o700)
        env = dict(os.environ, FART_RUNTIME_DIR=str(runtime), FART_STATE_DIR=str(state), FART_CACHE_DIR=str(base / "cache"),
                   FART_HOST="serpantinum", FART_MIRROR="0", FART_VIEW_ENTRY=str(bundle / "shell.qml"),
                   FART_VIEW_STDOUT=str(base / "view.log"))
        env.pop("FART_CORE_SOCKET", None)
        env.update(extra_env)
        process = subprocess.Popen([sys.executable, "-I", str(source / "core/fartd.py")], env=env,
                                   stdin=subprocess.DEVNULL, cwd=base)
        stack.callback(stop, process)
        for _ in range(200):
            if connection := try_connect(runtime / "core.sock"):
                stack.callback(connection.close)
                yield Fixture(process, connection, env)
                return
            if process.poll() is not None:
                break
            time.sleep(0.02)
        raise RuntimeError("private core failed to start")


def run_once(args, source: Path, bindir: Path) -> dict | None:
    extra = dict(FART_COLD_PROBE="1", FART_MOTION=args.motion, FART_KEEP_MAPPED="0",
                 FART_KEEP_SHELL="0" if args.unload_shell else "1",
                 PATH=str(bindir) + os.pathsep + os.defpath)
    if args.real:
        extra["PATH"] = str(bindir) + os.pathsep + os.environ.get("PATH", os.defpath)
        core = real_core(source, extra, args.bundle_dir)
    else:
        core = private_core(source=source, desktop=args.desktop, cache_home=args.cache_home, extra_env=extra)
    with core as f:
        time.sleep(args.settle)
        # The desktop modes watch the cursor, workspace and monitor; the run maps its own surface, so
        # focus changes are not counted (as desktop_nav --cold).
        watch = Interaction(os.environ, ignore=FOCUS) if args.desktop or args.real else None
        with watch or ExitStack():
            sent = time.time() * 1000
            f.request("view.open", page="home")
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                text = f.log.read_text(errors="replace") if f.log.exists() else ""
                if READY.search(text):
                    break
                time.sleep(0.005)
            time.sleep(0.5)  # the first room loads after ready (Shell.roomsReleased); its marker must be in
            if args.real:  # an early focus grab that clears folds the panel: it must still be open
                stayed_open = bool(f.state()["open"])
        core_log = (Path(f.env["FART_RUNTIME_DIR"]) / "core.log").read_text(errors="replace")
        result = parse(sent, core_log, f.log.read_text(errors="replace"))
        if args.keep_logs:
            args.keep_logs.mkdir(parents=True, exist_ok=True)
            run = len(list(args.keep_logs.glob("*-view.log")))
            shutil.copy2(f.log, args.keep_logs / f"{run:02d}-view.log")
        if result is not None and args.real:
            result["stayed_open"] = stayed_open
        f.request("view.close")
        time.sleep(0.5)
        if result is not None and watch is not None:
            result["interrupted"] = watch.status != "quiet"
        return result


def run_warm(args, source: Path, bindir: Path) -> list[dict | None]:
    """One core and view: a first (cold, uncounted) open that settles, then `--warm` close/open pairs."""
    extra = dict(FART_COLD_PROBE="1", FART_MOTION=args.motion, FART_KEEP_MAPPED="0",
                 FART_KEEP_SHELL="0" if args.unload_shell else "1", PATH=str(bindir) + os.pathsep + os.defpath)
    if args.real:
        extra["PATH"] = str(bindir) + os.pathsep + os.environ.get("PATH", os.defpath)
        core = real_core(source, extra, args.bundle_dir)
    else:
        core = private_core(source=source, desktop=args.desktop, cache_home=args.cache_home, extra_env=extra)
    rows = []
    with core as f:
        time.sleep(args.settle)

        def open_until_ready(offset):
            sent = time.time() * 1000
            f.request("view.open", page="home")
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                with f.log.open("rb") as log:
                    log.seek(offset)
                    text = log.read().decode(errors="replace")
                if READY.search(text):
                    return sent, text
                time.sleep(0.005)
            return sent, None

        _, first = open_until_ready(0)
        if first is None:
            return [None] * args.warm
        time.sleep(1.5)  # the unfold settles, so the deferred host domains have loaded
        for _ in range(args.warm):
            f.request("view.close")
            time.sleep(args.closed)
            offset = f.log.stat().st_size
            watch = Interaction(os.environ, ignore=FOCUS) if args.desktop or args.real else None
            with watch or ExitStack():
                sent, text = open_until_ready(offset)
                time.sleep(0.3)
            row = parse_warm(sent, text) if text else None
            if row is not None:
                if args.real:
                    row["stayed_open"] = bool(f.state()["open"])
                if watch is not None:
                    row["interrupted"] = watch.status != "quiet"
            rows.append(row)
        f.request("view.close")
        time.sleep(0.5)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--runs", type=int, default=7, help="runs per source")
    parser.add_argument("--source", type=Path, default=ROOT, help="checkout to measure (default: this one)")
    parser.add_argument("--compare", type=Path, help="a second checkout, run alternately with --source (A/B under the same conditions)")
    parser.add_argument("--motion", default="serpantinum")
    parser.add_argument("--unload-shell", action="store_true")
    parser.add_argument("--cache-home", type=Path, help="a persistent XDG_CACHE_HOME (warm QML cache, if any)")
    parser.add_argument("--desktop", action="store_true", help="map the fixture view on the caller's Wayland display (not offscreen)")
    parser.add_argument("--real", action="store_true", help="the real view (Overlay + Serpantinum) on the desktop; see above")
    parser.add_argument("--settle", type=float, default=1.0,
                        help="seconds between the core's start and view.open (default 1: a running core, view reaped; 0: a fresh core)")
    parser.add_argument("--keep-logs", type=Path, metavar="DIR", help="copy each run's view log here (diagnostics, e.g. QSG_RENDER_TIMING=1)")
    parser.add_argument("--warm", type=int, default=0, metavar="N",
                        help="per run, one core and view: a settled first open, then N warm close/open pairs")
    parser.add_argument("--closed", type=float, default=1.0, help="--warm: seconds closed before each warm open (default 1)")
    parser.add_argument("--qs", type=Path, help="the Quickshell binary to run (default: qs on the default PATH), e.g. a scratch build")
    parser.add_argument("--bundle-dir", type=Path, help="--real: a fixed bundle path, copied once and reused (qmldir and disk-cache experiments)")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    sources = [args.source] + ([args.compare] if args.compare else [])
    rows = {str(src): [] for src in sources}
    before = conditions()
    with tempfile.TemporaryDirectory(prefix="fart-cold-") as tmp:
        bindir = qs_wrapper(Path(tmp), args.qs)
        for _ in range(args.runs):
            for src in sources:  # interleaved, so drifting load or clocks hit both alike
                if args.warm:
                    rows[str(src)].extend(run_warm(args, src, bindir))
                else:
                    rows[str(src)].append(run_once(args, src, bindir))
    report = dict(platform="wayland/real" if args.real else "wayland" if args.desktop else "offscreen/software", settle_s=args.settle, runs=args.runs,
                  mode=f"warm ×{args.warm}, closed {args.closed:g} s" if args.warm else "cold",
                  conditions_before=before, conditions_after=conditions(), sources={})
    for src, got in rows.items():
        # Interrupted runs are listed in the samples but never summarised.
        done = [r for r in got if r is not None and not r.get("interrupted")]
        report["sources"][src] = dict(complete=len(done), phases=summary(done) if done else {},
                                      samples=[{k: v if isinstance(v, bool) else round(v, 1) for k, v in r.items()} if r else None for r in got])
    if args.compare:
        a, b = rows.values()
        diffs = [y["total"] - x["total"] for x, y in zip(a, b) if x and y and not x.get("interrupted") and not y.get("interrupted")]
        report["paired_total_difference_ms"] = dict(median=round(statistics.median(diffs), 1), samples=[round(d, 1) for d in diffs]) if diffs else None
    if args.json:
        print(json.dumps(report, indent=1))
    else:
        c = report["conditions_before"]
        print(f"{report['platform']}, settle {args.settle:g} s; profile {c['platform_profile']}, EPP {c['epp']}, AC {c['ac_online']}, load {c['loadavg']}")
        for src, r in report["sources"].items():
            print(f"{src}: {r['complete']}/{len(rows[src])} complete runs (ms)")
            for name, ph in r["phases"].items():
                print(f"  {name:11s} median {ph['median']:7.1f}   min {ph['min']:7.1f}   max {ph['max']:7.1f}")
        if report.get("paired_total_difference_ms"):
            d = report["paired_total_difference_ms"]
            print(f"paired total, compare − source: median {d['median']} ms {d['samples']}")
    return 0 if all(r["complete"] for r in report["sources"].values()) else 3


if __name__ == "__main__":
    sys.exit(main())
