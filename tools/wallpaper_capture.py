#!/usr/bin/env python3
"""Nested-only captures of the wallpaper section (Z177) against an inert fixture. Start nested_hypr.py first.

    python3 tools/wallpaper_capture.py OUT_DIR [FOLDER]

FOLDER (default ~/Pictures/Wallpapers) is only listed and its images only read; nothing is set anywhere.
"""
import json
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

import nested_hypr

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from core.wallpaper import Wallpaper  # noqa: E402

ERRORS = ("ReferenceError", "TypeError", "Binding loop", "Unable to assign", "is not defined")


def capture(output: Path, folder: str):
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="wallpaper-capture-") as directory:
        base = Path(directory)
        for name in ("home", "config", "state", "cache", "data", "run", "bundle"):
            (base / name).mkdir(mode=0o700)
        for name in ("core", "view", "adapters", "assets", "tools"):
            (base / "bundle" / name).symlink_to(ROOT / name, target_is_directory=True)
        (base / "bundle/shell.qml").write_text((ROOT / "tests/fixtures/wallpaper/Shell.qml").read_text())
        scanner = Wallpaper(base / "state")
        scanner.folder = folder
        listing = scanner.listing()
        (base / "listing.json").write_text(json.dumps(listing))
        images = [e for e in listing["entries"] if e["kind"] == "image"]
        current = images[0]["path"] if images else ""
        env = {k: v for k, v in nested_hypr.env_for(nested_hypr.state()).items()
               if not k.startswith(("FART_", "DMS_", "MALLOC_", "QT_QUICK", "QSG_"))}
        env.update(HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"),
                   XDG_CACHE_HOME=str(base / "cache"), XDG_DATA_HOME=str(base / "data"), FART_STATE_DIR=str(base / "state"),
                   FART_CACHE_DIR=str(base / "cache"), FART_CORE_SOCKET="", WALLPAPER_FIXTURE_LISTING=str(base / "listing.json"),
                   WALLPAPER_FIXTURE_CURRENT=current, PIPEWIRE_RUNTIME_DIR=str(base / "run"),
                   DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent/wallpaper-fixture",
                   DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent/wallpaper-fixture")
        with (base / "view.log").open("w") as log:
            process = subprocess.Popen(["qs", "-n", "--no-color", "-p", str(base / "bundle/shell.qml")],
                                       env=env, stdout=log, stderr=subprocess.STDOUT)

        def ipc(*args):
            return subprocess.check_output(["qs", "ipc", "--pid", str(process.pid), "call", "wallpaper-fixture", *args],
                                           env=env, text=True, stderr=subprocess.STDOUT).strip()

        def shot(label):
            path = output / (label + ".png")
            subprocess.run([sys.executable, str(ROOT / "tools/nested_hypr.py"), "shot", str(path)], check=True,
                           stdout=subprocess.DEVNULL)
            print("Captured", path, flush=True)

        try:
            time.sleep(1.5)
            ipc("open", "wallpaper"); time.sleep(2.5)
            assert json.loads(ipc("state"))["open"]
            shot("1-wallpaper-current")
            if len(images) > 5:
                ipc("preview", str(listing["entries"].index(images[5]))); time.sleep(1.5)
                shot("2-wallpaper-preview")
            ipc("host", "false", "DMS is not running"); time.sleep(.5)
            shot("3-host-unavailable")
            ipc("host", "true", "")
            ipc("open", "palette"); time.sleep(1.2)
            shot("4-palette-tab")
            ipc("empty", "~/Pictures/Gone")
            ipc("open", "wallpaper"); time.sleep(1.2)
            shot("5-no-folder")
            state = json.loads(ipc("state"))
            assert state["calls"] == [], state["calls"]  # nothing was set
        finally:
            process.send_signal(signal.SIGTERM)
            try:
                process.wait(5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        text = (base / "view.log").read_text()
        (output / "view.log").write_text(text)
        bad = [line for line in text.splitlines() if any(error in line for error in ERRORS)]
        print(f"{len(bad)} QML errors", *bad[:20], sep="\n")


if __name__ == "__main__":
    capture(Path(sys.argv[1]), sys.argv[2] if len(sys.argv) > 2 else "~/Pictures/Wallpapers")
