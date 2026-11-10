"""Verbs end to end: the real core and CLI, and a real view whose CoreHostCalls drive the fixture adapter.

Nothing real is actuated: the core uses the fixture host profile, the view uses FixtureAdapter (which only
records calls), Qt runs offscreen, and PipeWire, D-Bus and Hyprland are pointed at nonexistent paths.
"""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "tools/fart_next.py"
TREE = ("view", "adapters", "core", "tools", "assets")


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class VerbViewTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="fart-next-verbs-")
        base = Path(cls.temp.name)
        bundle = base / "bundle"
        bundle.mkdir()
        for name in TREE:
            shutil.copytree(ROOT / name, bundle / name, ignore=shutil.ignore_patterns("__pycache__"))
        entry = bundle / "VerbView.qml"
        shutil.copy2(ROOT / "tools/verbtest/VerbView.qml", entry)
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

    @classmethod
    def tearDownClass(cls):
        cls.cli("stop")
        cls.temp.cleanup()

    @classmethod
    def cli(cls, *args):
        return subprocess.run([sys.executable, "-I", str(CLI), *args], env=cls.env, capture_output=True, text=True, timeout=30)

    def states(self, domain):
        """Every VERB_STATE line printed for one domain, in order."""
        text = self.view_log.read_text() if self.view_log.exists() else ""
        prefix = f"VERB_STATE {domain} "
        return [json.loads(line.split(prefix, 1)[1]) for line in text.splitlines() if prefix in line]

    def settled(self, domain, predicate, timeout=3.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            states = self.states(domain)
            if states and predicate(states[-1]):
                return states
            time.sleep(0.05)
        self.fail(f"{domain} never settled: {self.states(domain)[-3:]}")

    def test_1_vol_spawns_a_closed_view_and_holds_the_mixer_briefly(self):
        out = self.cli("vol", "70")
        self.assertEqual((out.returncode, out.stdout.strip()), (0, "Fixture Speakers 70%"), out.stderr)
        status = json.loads(self.cli("--json", "status").stdout)
        self.assertEqual((status["view"]["state"], status["view"]["open"]), ("ready", False))
        states = self.settled("audio", lambda s: s["leases"].get("mixer") == [])
        self.assertEqual(states[-1]["calls"], [{"method": "setVolume", "args": ["1", 0.7]}])
        held = [s["leases"].get("mixer") for s in states]
        self.assertIn(["core:1"], held)
        # The harness defers audio (ADAPTER_CONTRACT §1): the call loaded it and followed the swap.
        self.assertEqual(self.view_log.read_text().count("VERB_DEFERRED audio"), 1)

    def test_2_relative_vol_keeps_the_sink_bound_between_read_and_set(self):
        before = len(self.states("audio"))
        out = self.cli("vol", "+5")
        self.assertEqual(out.stdout.strip(), "Fixture Speakers 45%", out.stderr)
        states = self.settled("audio", lambda s: s["leases"].get("mixer") == [])[before:]
        self.assertEqual(states[-1]["calls"][-1], {"method": "setVolume", "args": ["1", 0.45]})
        held = []
        for state in states:
            owners = state["leases"].get("mixer")
            if not held or held[-1] != owners:
                held.append(owners)
        # The set's owner joins while the read's owner lingers, so the lease never drops in between.
        self.assertEqual((held[0], held[-1]), (["core:2"], []))
        self.assertIn(["core:2", "core:3"], held)
        self.assertNotIn([], held[:-1])

    def test_3_usage_errors_exit_2_and_send_nothing(self):
        before = len(self.states("audio"))
        out = self.cli("vol", "loud")
        self.assertEqual(out.returncode, 2)
        self.assertIn("not a level", out.stderr)
        self.assertEqual(self.cli("frobnicate").returncode, 2)
        self.assertEqual(len(self.states("audio")), before)

    def test_4_every_host_verb_reaches_the_fixture_once_and_releases(self):
        expected = {
            ("bri", "30"): ("power", {"method": "setBrightness", "args": [0.3]}, "brightness 30%"),
            ("wifi", "off"): ("network", {"method": "setWifiEnabled", "args": [False]}, "Wi-Fi off"),
            ("bt", "on"): ("bluetooth", {"method": "setEnabled", "args": [True]}, "Bluetooth on"),
            ("power", "save"): ("power", {"method": "setProfile", "args": ["power-saver"]}, "power power-saver"),
            ("play",): ("media", {"method": "togglePlaying", "args": []}, "play/pause · Fixture Signal — Test Pattern"),
            ("next",): ("media", {"method": "next", "args": []}, "next track"),
            ("out", "fixture"): ("audio", {"method": "setDefault", "args": ["output", "1"]}, "output → Fixture Speakers"),
            ("wall",): ("hostActions", {"method": "open", "args": ["wallpapers"]}, "opened wallpapers"),
            ("lock",): ("power", {"method": "lock", "args": []}, "locked"),
        }
        for words, (domain, call, line) in expected.items():
            with self.subTest(words=words):
                out = self.cli(*words)
                self.assertEqual((out.returncode, out.stdout.strip()), (0, line), out.stderr)
                state = self.settled(domain, lambda s: call in s["calls"] and not any(s["leases"].values()))[-1]
                self.assertEqual(state["calls"][-1], call)
        held = [s["leases"].get("brightness") for s in self.states("power")]
        self.assertTrue(any(owners for owners in held if owners), "bri held the brightness lease")
        # Nothing was recorded by the core's own host profile: every action went through the view's adapter.
        recorded = self.fixture_log.read_text().splitlines() if self.fixture_log.exists() else []
        self.assertEqual(recorded, [])

    def lines(self, prefix):
        text = self.view_log.read_text() if self.view_log.exists() else ""
        return [json.loads(line.split(prefix + " ", 1)[1]) for line in text.splitlines() if prefix + " " in line]

    def test_5_an_alarm_reaches_the_view_as_a_cue_and_plays_once_in_the_core(self):
        with socket.socket(socket.AF_UNIX) as sock, sock.makefile("rw") as stream:
            sock.connect(str(Path(self.env["FART_RUNTIME_DIR"]) / "core.sock"))
            for n, (op, args) in enumerate((("hello", {"client": "cli", "protocol": 1}), ("timer.configure", {"sound": True})), 1):
                stream.write(json.dumps({"id": n, "op": op, "args": args}) + "\n")
                stream.flush()
                self.assertTrue(json.loads(stream.readline())["ok"])
        self.assertEqual(self.cli("tim", "1s").returncode, 0)
        deadline = time.time() + 5
        while time.time() < deadline and not self.lines("VERB_CUE"):
            time.sleep(0.05)
        [cue] = self.lines("VERB_CUE")
        self.assertEqual((cue["cue"], cue["audible"], cue["reason"]), ("timer.done", True, None))
        alerts = [c["enabled"] for c in self.lines("VERB_SFX")[-1]["cues"] if c["kind"] == "alert"]
        self.assertEqual(alerts, [True, True, True])
        recorded = [json.loads(line) for line in self.fixture_log.read_text().splitlines()]
        self.assertEqual([c for c in recorded if c[0] == "play"], [["play", "timer.done", "1.000"]])
        self.cli("tim", "stop")


if __name__ == "__main__":
    unittest.main()
