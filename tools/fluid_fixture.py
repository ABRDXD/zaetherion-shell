#!/usr/bin/env python3
"""Run inert Fluid integration fixtures only inside an already running nested Hyprland.

Usage: python tools/fluid_fixture.py [--capture DIRECTORY] [--baseline]
The baseline option renders the original Angular Media from this branch's parent revision.
"""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

import nested_hypr

ROOT = Path(__file__).resolve().parents[1]


def run(capture=None, baseline=False, fixture="tests/fixtures/fluid/MediaSwitch.qml", integrated=False):
    nested = nested_hypr.state()
    with tempfile.TemporaryDirectory(prefix="fluid-fixture-") as directory:
        base = Path(directory)
        for name in ("home", "runtime", "config", "state", "cache", "data", "bundle"):
            (base / name).mkdir(mode=0o700)
        bundle = base / "bundle"
        for name in ("core", "view", "adapters", "assets"):
            (bundle / name).symlink_to(ROOT / name, target_is_directory=True)
        if baseline:
            import shutil
            (bundle / "view").unlink()
            shutil.copytree(ROOT / "view", bundle / "view")
            original = subprocess.check_output(["git", "show", "e6c86ea:view/rooms/Media.qml"], cwd=ROOT)
            (bundle / "view/rooms/Media.qml").write_bytes(original)
        (bundle / "shell.qml").write_text((ROOT / fixture).read_text())
        env = {k:v for k,v in nested_hypr.env_for(nested).items()
               if not k.startswith(("FART_", "DMS_", "MALLOC_", "QT_QUICK", "QSG_", "ZAETHERION_"))}
        socket = Path(env["XDG_RUNTIME_DIR"]) / nested["wayland"]
        env.update(HOME=str(base / "home"), XDG_RUNTIME_DIR=str(base / "runtime"),
                   XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"),
                   XDG_CACHE_HOME=str(base / "cache"), XDG_DATA_HOME=str(base / "data"),
                   WAYLAND_DISPLAY=str(socket), QT_QPA_PLATFORM="wayland", QSG_RHI_BACKEND="opengl",
                   DBUS_SESSION_BUS_ADDRESS="unix:path="+str(base / "runtime/no-bus"),
                   DBUS_SYSTEM_BUS_ADDRESS="unix:path="+str(base / "runtime/no-system-bus"),
                   PIPEWIRE_RUNTIME_DIR=str(base / "runtime"), PULSE_SERVER="unix:"+str(base / "runtime/no-pulse"),
                   FART_STATE_DIR=str(base / "state"), FART_CACHE_DIR=str(base / "cache"),
                   MALLOC_CONF="thp:never,narenas:4,dirty_decay_ms:3000", QT_LOGGING_RULES="qml.debug=true",
                   FLUID_AUTOTEST="0" if capture else "1", FLUID_FORM="angular",
                   FLUID_INTEGRATED="1" if integrated else "0")
        log = base / "fixture.log"
        with log.open("w") as stream:
            process = subprocess.Popen(["qs", "-n", "--no-color", "-p", str(bundle / "shell.qml")],
                                       env=env, stdout=stream, stderr=subprocess.STDOUT)
            try:
                if capture:
                    capture.mkdir(parents=True, exist_ok=True)
                    deadline=time.monotonic()+15
                    while "FLUID_READY" not in log.read_text():
                        if process.poll() is not None or time.monotonic()>deadline:
                            raise RuntimeError(log.read_text())
                        time.sleep(.1)
                    def ipc(*args):
                        return subprocess.check_output(["qs","ipc","--pid",str(process.pid),"call","fluid-fixture",*args],env=env,text=True).strip()
                    def shot(name):
                        time.sleep(1)
                        subprocess.run([sys.executable,str(ROOT / "tools/nested_hypr.py"),"shot",str(capture / (name+".png"))],check=True)
                    shot("angular-baseline" if baseline else "angular")
                    if not baseline:
                        initial = json.loads(ipc("state"))
                        ipc("style","fluid"); shot("fluid-media")
                        switched = json.loads(ipc("state"))
                        assert switched["form"] == "fluid" and switched["page"] == initial["page"] == "media"
                        assert switched["controller"] == initial["controller"]
                        ipc("settings","true"); ipc("preview"); shot("fluid-settings-preview")
                        preview = json.loads(ipc("state"))
                        assert preview["settings"] and preview["palette"]["preview"]
                        ipc("settings","false"); ipc("playing","true"); ipc("overdrive","true")
                        shot("fluid-media-overdrive")
                        assert not json.loads(ipc("state"))["palette"]["preview"]
                        ipc("catalogue"); shot("fluid-player-catalogue")
                        ipc("settings","true"); shot("fluid-settings-overdrive")
                        (capture / "state.json").write_text(ipc("state")+"\n")
                else:
                    process.wait(timeout=120)
                    if process.returncode:
                        raise RuntimeError(log.read_text())
            finally:
                if process.poll() is None:
                    process.send_signal(signal.SIGTERM)
                    try: process.wait(timeout=5)
                    except subprocess.TimeoutExpired: process.kill(); process.wait()
        output=log.read_text()
        if capture: (capture / ("baseline.log" if baseline else "fixture.log")).write_text(output)
        return output


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--integrated", action="store_true", help="Capture the native Shell and its Settings")
    parser.add_argument("--fixture", default="tests/fixtures/fluid/MediaSwitch.qml")
    args=parser.parse_args()
    if args.integrated and not args.capture: parser.error("--integrated requires --capture")
    output=run(args.capture,args.baseline,args.fixture,args.integrated)
    print(output)
    if not args.capture:
        prefix = "FLUID" if args.fixture.endswith("MediaSwitch.qml") else "CUE"
        if prefix + "_DONE" not in output or prefix + "_FAIL" in output: sys.exit(1)
    if any(e in output for e in ("ReferenceError", "TypeError", "Binding loop", "Unable to assign", "Cannot assign", "Failed to load configuration")): sys.exit(1)
