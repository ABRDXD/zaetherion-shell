"""The command line end to end: the real core, grammar and CLI, and the desktop fixture view offscreen.

tools/cmdtest/CmdView.qml drives the scenario (DAILY_DRIVER §7, "Verbs" and "Queued input") from inside
the view and prints one CMD_PASS or CMD_FAIL line per check. Nothing real is actuated: the core uses the
fixture host profile (sounds are recorded, not played), the view uses FixtureAdapter, Qt runs offscreen,
and PipeWire, D-Bus and Hyprland are pointed at nonexistent paths.
"""
import json
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
CHECKS = {
    "cmdline.focus.open", "queued.type.during.unfold", "queued.enter.at.once", "verb.tim.ran",
    "queued.enter.x5", "queued.enter.x5.order", "history.browse", "hint.usage", "ambiguous.candidates",
    "help.registry", "verb.error.tone", "escape.clear.then.fold", "open.focus.again", "origin.from.rect",
    "interactive.reported", "ignite.fold.idle", "ignite.plate", "escape.during.unfold", "fallthrough.launcher",
}


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class CommandLineViewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="fart-next-cmdline-")
        base = Path(cls.temp.name)
        bundle = base / "bundle"
        bundle.mkdir()
        for name in TREE:
            shutil.copytree(ROOT / name, bundle / name, ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copy2(ROOT / "tools/measure/FixtureView.qml", bundle)
        entry = bundle / "CmdView.qml"
        shutil.copy2(ROOT / "tools/cmdtest/CmdView.qml", entry)
        cls.view_log = base / "view.log"
        cls.fixture_log = base / "fixture.jsonl"
        home = base / "home"
        (home / "state/fart").mkdir(parents=True)
        cls.env = dict(os.environ, FART_RUNTIME_DIR=str(base / "run"), FART_HOST="fixture", FART_MIRROR="0",
                       FART_FIXTURE_LOG=str(cls.fixture_log), FART_VIEW_ENTRY=str(entry), FART_VIEW_STDOUT=str(cls.view_log),
                       XDG_STATE_HOME=str(home / "state"), XDG_CACHE_HOME=str(home / "cache"), XDG_CONFIG_HOME=str(home / "config"),
                       QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", PIPEWIRE_RUNTIME_DIR="/nonexistent/fart-fixture",
                       HYPRLAND_INSTANCE_SIGNATURE="", WAYLAND_DISPLAY="", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent/fart-fixture",
                       DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent/fart-fixture")
        opened = cls.cli("open")
        if opened.returncode != 0:
            raise RuntimeError(opened.stderr)
        deadline = time.time() + 60
        while time.time() < deadline and "CMD_DONE" not in cls.log():
            time.sleep(0.1)
        cls.results = {}
        for line in cls.log().splitlines():
            for mark in ("CMD_PASS", "CMD_FAIL"):
                if mark + " " in line:
                    name, _, detail = line.split(mark + " ", 1)[1].partition(" ")
                    cls.results[name] = (mark == "CMD_PASS", detail)

    @classmethod
    def tearDownClass(cls):
        cls.cli("stop")
        cls.temp.cleanup()

    @classmethod
    def cli(cls, *args):
        return subprocess.run([sys.executable, "-I", str(CLI), *args], env=cls.env, capture_output=True, text=True, timeout=30)

    @classmethod
    def log(cls):
        return cls.view_log.read_text() if cls.view_log.exists() else ""

    def test_scenario_finished(self):
        self.assertIn("CMD_DONE", self.log(), self.log()[-3000:])

    def test_every_check_ran_and_passed(self):
        for name in sorted(CHECKS):
            with self.subTest(check=name):
                self.assertIn(name, self.results, "did not run")
                passed, detail = self.results[name]
                self.assertTrue(passed, detail)
        self.assertEqual(set(self.results) - CHECKS, set(), "unlisted checks")

    def test_ui_cues_reach_the_core_gate(self):
        """Typing reports ui.key and a verb that ran reports cmd.run; the core's fixture profile records each play."""
        recorded = [json.loads(line) for line in self.fixture_log.read_text().splitlines()] if self.fixture_log.exists() else []
        cues = [c[1] for c in recorded if c[0] == "play"]
        self.assertIn("ui.key", cues)
        self.assertIn("cmd.run", cues)
        self.assertIn("ui.error", cues)  # tim banana


if __name__ == "__main__":
    unittest.main()
