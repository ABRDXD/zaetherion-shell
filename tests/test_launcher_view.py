"""The launcher end to end (S6): the real core (fixture host) and the island offscreen with the fixture apps.

tools/launchertest/LauncherView.qml drives it from inside the view; nothing real starts (the fixture adapter
records launches), Qt runs offscreen, and Hyprland, PipeWire and D-Bus point at nothing.
"""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "tools/fart_next.py"
TREE = ("view", "adapters", "core", "tools", "assets")
CHECKS = ("apps.indexed", "open.rows", "open.focus", "island.wants.keyboard", "window.deep.enough", "type.ranks",
          "select.wraps", "launch.terminal", "launch.closes", "launch.recorded", "blocked.marked", "blocked.refused",
          "blocked.stays.open", "toggle.closes", "no.match", "inline.calc.row", "inline.calc", "inline.convert.row",
          "inline.convert", "inline.command.row", "inline.command", "inline.search.row", "inline.search", "inline.verb.row",
          "inline.verb", "inline.verb.ran", "inline.empty.waits", "orbit.symmetric", "orbit.pick.at.perigee",
          "orbit.wraps.back", "orbit.settles", "engine.rows", "engine.opened", "engine.executes", "engine.closes", "long.sum", "long.sum.labels.fit")


def scene(base: Path, shots: str = "") -> str:
    """Runs the scenario in a private core and returns the view's log."""
    bundle = base / "bundle"
    bundle.mkdir()
    for name in TREE:
        shutil.copytree(ROOT / name, bundle / name, ignore=shutil.ignore_patterns("__pycache__"))
    entry = bundle / "LauncherView.qml"
    shutil.copy2(ROOT / "tools/launchertest/LauncherView.qml", entry)
    view_log = base / "view.log"
    home = base / "home"
    (home / "state").mkdir(parents=True)
    env = {k: v for k, v in os.environ.items() if not k.startswith(("FART_", "DMS_"))}
    env.update(FART_RUNTIME_DIR=str(base / "run"), FART_STATE_DIR=str(home / "state/fart"), FART_HOST="fixture",
               FART_MIRROR="0", FART_FIXTURE_LOG=str(base / "fixture.jsonl"), FART_VIEW_ENTRY=str(entry),
               FART_VIEW_STDOUT=str(view_log), LAUNCHER_SHOTS=shots,
               XDG_STATE_HOME=str(home / "state"), XDG_CACHE_HOME=str(home / "cache"), XDG_CONFIG_HOME=str(home / "config"),
               QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", PIPEWIRE_RUNTIME_DIR="/nonexistent/fart-fixture",
               HYPRLAND_INSTANCE_SIGNATURE="", WAYLAND_DISPLAY="", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent/fart-fixture",
               DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent/fart-fixture")
    cli = lambda *args: subprocess.run([sys.executable, "-I", str(CLI), *args], env=env, capture_output=True, text=True, timeout=30)
    try:
        opened = cli("open")
        if opened.returncode != 0:
            raise RuntimeError(opened.stderr)
        deadline = time.time() + 60
        log = ""
        while time.time() < deadline and "LAUNCHER_DONE" not in log and "LAUNCHER_FAIL" not in log:
            time.sleep(0.1)
            log = view_log.read_text() if view_log.exists() else ""
        time.sleep(0.2)
        return view_log.read_text() if view_log.exists() else ""
    finally:
        cli("stop")


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class LauncherViewTests(unittest.TestCase):
    def test_scenario(self):
        with tempfile.TemporaryDirectory(prefix="zaetherion-launcher-") as tmp:
            log = scene(Path(tmp), os.environ.get("LAUNCHER_SHOTS", ""))
        self.assertNotIn("LAUNCHER_FAIL", log, log[-4000:])
        for name in CHECKS:
            self.assertIn("LAUNCHER_PASS " + name, log, log[-4000:])
        self.assertIn("LAUNCHER_DONE", log)
        for error in ("Binding loop", "ReferenceError", "TypeError", "Unable to assign"):
            self.assertNotIn(error, log, log[-4000:])


if __name__ == "__main__":
    unittest.main()
