#!/usr/bin/env python3
"""The heavy layer's cost on the NVIDIA card (docs/OVERDRIVE.md §9 and §33), on the real screen.

A private core on the fixture host (nothing real is actuated) opens the real Overlay on the caller's Wayland display;
Overdrive starts the heavy process (`shell-heavy.qml`, the Medium and, on the orbit, the hole) on the NVIDIA card by
PRIME offload, as in daily use. For each scenario it samples `--seconds`: the NVIDIA card's load and power
(`nvidia-smi`, asked only once the card is awake for the heavy layer, and after the release to see it fall), the AMD
chip's load (sysfs), and CPU and RSS of the view and of the heavy process. Scenarios: Silent on Home; Overdrive on
Home, Media and Performance; Overdrive while switching rooms every 1.5 s (flights); released. Run it only when the
user has said the screen is free.

    python3 tools/measure/heavy_cost.py [--seconds 15] [-o out.json]
"""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))
from tools.fart_next import try_connect  # noqa: E402
from tools.smoke import TREE  # noqa: E402

TICK = os.sysconf("SC_CLK_TCK")


def amd_busy() -> float | None:
    for card in Path("/sys/class/drm").glob("card[0-9]"):
        busy = card / "device/gpu_busy_percent"
        if (card / "device/vendor").exists() and (card / "device/vendor").read_text().strip() == "0x1002" and busy.exists():
            try:
                return float(busy.read_text())
            except (OSError, ValueError):
                return None
    return None


def nvidia_status() -> str:
    for card in Path("/sys/class/drm").glob("card[0-9]"):
        if (card / "device/vendor").exists() and (card / "device/vendor").read_text().strip() == "0x10de":
            try:
                return (card / "device/power/runtime_status").read_text().strip()
            except OSError:
                return "?"
    return "absent"


def nvidia_sample() -> tuple[float, float] | None:
    try:
        out = subprocess.run(["nvidia-smi", "--query-gpu=utilization.gpu,power.draw", "--format=csv,noheader,nounits"],
                             capture_output=True, text=True, timeout=5).stdout.strip().splitlines()[0]
        load, watts = (float(x) for x in out.split(","))
        return load, watts
    except (OSError, ValueError, IndexError, subprocess.TimeoutExpired):
        return None


def proc(pid: int) -> tuple[float, float] | None:
    """(cpu seconds, RSS MiB)"""
    try:
        stat = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
        rss = next(int(l.split()[1]) for l in Path(f"/proc/{pid}/status").read_text().splitlines() if l.startswith("VmRSS:"))
        return (int(stat[11]) + int(stat[12])) / TICK, rss / 1024
    except (OSError, StopIteration, IndexError, ValueError):
        return None


def pids(pattern: str) -> list[int]:
    out = subprocess.run(["pgrep", "-f", pattern], capture_output=True, text=True).stdout.split()
    return [int(p) for p in out]


def sample(seconds: float, view_pattern: str, heavy_pattern: str, ask_nvidia: bool, during=None) -> dict:
    views, heavies = pids(view_pattern), pids(heavy_pattern)
    start = {p: proc(p) for p in views + heavies}
    amd, nv, statuses = [], [], set()
    t0 = time.monotonic()
    next_switch = 0
    while time.monotonic() - t0 < seconds:
        if during and time.monotonic() - t0 >= next_switch:
            during()
            next_switch += 1.5
        a = amd_busy()
        if a is not None:
            amd.append(a)
        status = nvidia_status()
        statuses.add(status)
        if ask_nvidia and status == "active":
            s = nvidia_sample()
            if s:
                nv.append(s)
        time.sleep(0.5)
    took = time.monotonic() - t0
    end = {p: proc(p) for p in views + heavies}

    def usage(group):
        cpu = sum(end[p][0] - start[p][0] for p in group if start.get(p) and end.get(p))
        rss = sum(end[p][1] for p in group if end.get(p))
        return {"cpu_percent": round(100 * cpu / took, 1), "rss_mib": round(rss, 1), "processes": len(group)}

    mean = lambda xs: round(sum(xs) / len(xs), 1) if xs else None
    return {"amd_busy_mean": mean(amd), "amd_busy_peak": max(amd) if amd else None,
            "nvidia_load_mean": mean([x[0] for x in nv]), "nvidia_load_peak": max([x[0] for x in nv]) if nv else None,
            "nvidia_watts_mean": mean([x[1] for x in nv]), "nvidia_runtime": sorted(statuses),
            "view": usage(views), "heavy": usage(heavies)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, default=15)
    parser.add_argument("--output", "-o", type=Path)
    args = parser.parse_args()
    report = {"date": datetime.now(timezone.utc).isoformat(timespec="seconds"),
              "commit": subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip(),
              "seconds": args.seconds, "scenarios": {}}
    with tempfile.TemporaryDirectory(prefix="fart-heavy-cost-") as tmp:
        base = Path(tmp)
        bundle = base / "bundle"
        bundle.mkdir()
        for name in TREE:
            p = ROOT / name
            if p.is_dir():
                shutil.copytree(p, bundle / name, ignore=shutil.ignore_patterns("__pycache__"))
            else:
                shutil.copy2(p, bundle / name)
        shutil.copy2(ROOT / "shell-fixture.qml", bundle / "shell.qml")
        run = base / "run"
        run.mkdir(mode=0o700)
        runtime = os.environ["XDG_RUNTIME_DIR"]
        env = dict(PATH=os.environ["PATH"], LANG="C.UTF-8", HOME=str(base), XDG_RUNTIME_DIR=str(run), XDG_CONFIG_HOME=str(base / "config"),
                   XDG_CACHE_HOME=str(base / "cache"), XDG_STATE_HOME=str(base / "state"), XDG_DATA_HOME=str(base / "data"),
                   FART_RUNTIME_DIR=str(run / "core"), FART_STATE_DIR=str(base / "state/fixture"), FART_CACHE_DIR=str(base / "cache/fixture"),
                   FART_MIRROR="0", FART_HEAVY="1", QML_XHR_ALLOW_FILE_READ="1", FART_HOST="fixture", FART_FIXTURE_LOG=str(base / "actions"),
                   FART_VIEW_ENTRY=str(bundle / "shell.qml"), FART_VIEW_STDOUT=str(base / "view.log"), FART_AMBIENT="1", FART_REDUCED="0",
                   QT_QPA_PLATFORM="wayland", WAYLAND_DISPLAY=os.path.join(runtime, os.environ["WAYLAND_DISPLAY"]),
                   DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(base / "no-bus"))
        # The system bus stays reachable: the battery guard must see the charger, as it does in daily use.
        if "DBUS_SYSTEM_BUS_ADDRESS" in os.environ:
            env["DBUS_SYSTEM_BUS_ADDRESS"] = os.environ["DBUS_SYSTEM_BUS_ADDRESS"]
        core = subprocess.Popen([sys.executable, "-I", str(ROOT / "core/fartd.py")], env=env, stdin=subprocess.DEVNULL, cwd=base)
        view_pattern, heavy_pattern = str(bundle / "shell.qml"), str(bundle / "shell-heavy.qml")
        try:
            conn = None
            for _ in range(250):
                conn = try_connect(run / "core/core.sock")
                if conn:
                    break
                time.sleep(0.02)
            r = conn.request

            def scenario(name, ask_nvidia=True, during=None):
                result = sample(args.seconds, view_pattern, heavy_pattern, ask_nvidia, during)
                st = r("status")["overdrive"]
                result["lease"] = {"effective": st.get("effective"), "suspended": st.get("suspended")}
                report["scenarios"][name] = result
                print(name, json.dumps(result), file=sys.stderr, flush=True)

            r("view.open", page="home")
            time.sleep(3)
            scenario("home_silent", ask_nvidia=False)
            r("overdrive.request", mode="sticky")
            time.sleep(6)
            for room in ("home", "media", "performance"):
                r("view.open", page=room)
                time.sleep(3)
                scenario(room + "_overdrive")
            rooms = iter(["tasks", "timers", "devices", "workspaces", "home", "media", "codex", "clipboard", "notifications", "performance", "home"] * 3)
            scenario("flights_overdrive", during=lambda: r("view.open", page=next(rooms)))
            r("overdrive.release")
            time.sleep(5)
            scenario("released", ask_nvidia=False)
            r("view.close")
        finally:
            core.terminate()
            core.wait(8)
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
