"""Discovery (core/discovery.py, M15): the fragment files, the declarative triggers and what reaches disk."""
from datetime import datetime
import json
import shutil
import sys
from pathlib import Path
import tempfile
import unittest

import core_fakes
from core.app import Core
from core.guards import SessionGuard
from core.discovery import FRAGMENTS, KEYS, Discovery, holds, load


def facts(**over):
    base = {"counters": {}, "hour": 12, "streak": 0, "uptime": 0, "listening": False, "visits": {}}
    base.update(over)
    return base


class Triggers(unittest.TestCase):
    def test_each_condition(self):
        self.assertTrue(holds({"counter": "sky.moon.full"}, facts(counters={"sky.moon.full": 1})))
        self.assertFalse(holds({"counter": "core.starts", "atLeast": 100}, facts(counters={"core.starts": 99})))
        self.assertTrue(holds({"hours": [3, 4]}, facts(hour=3)))
        self.assertFalse(holds({"hours": [3, 4]}, facts(hour=4)))
        self.assertTrue(holds({"hours": [22, 2]}, facts(hour=1)))      # across midnight
        self.assertFalse(holds({"hours": [22, 2]}, facts(hour=12)))
        self.assertTrue(holds({"streak": 3}, facts(streak=3)))
        self.assertFalse(holds({"uptime": 72}, facts(uptime=71 * 3600)))
        self.assertFalse(holds({"listening": True}, facts()))
        self.assertTrue(holds({"visits": {"codex": 25}}, facts(visits={"codex": 25})))

    def test_every_condition_must_hold_at_once(self):
        when = {"listening": True, "hours": [0, 4]}
        self.assertFalse(holds(when, facts(listening=True, hour=5)))
        self.assertTrue(holds(when, facts(listening=True, hour=0)))


class Fragments(unittest.TestCase):
    def test_the_shipped_fragments_all_load(self):
        names = sorted(p.stem for p in FRAGMENTS.glob("*.json"))
        self.assertGreaterEqual(len(names), 12)
        self.assertEqual(sorted(load()), names)
        for fid, f in load().items():
            self.assertLessEqual(set(f["when"]), KEYS, fid)
            self.assertTrue(f["whisper"] == f["whisper"].lower() and len(f["whisper"]) <= 48, fid)   # one faint neutral line

    def test_a_bad_file_is_left_out_alone(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            (d / "good.json").write_text(json.dumps({"when": {"streak": 1}, "whisper": "w", "text": "t"}))
            (d / "broken.json").write_text("{nope")
            (d / "odd.json").write_text(json.dumps({"when": {"weather": "rain"}, "whisper": "w", "text": "t"}))
            with self.assertLogs("fart.discovery", "WARNING"):
                self.assertEqual(list(load(d)), ["good"])


class Finding(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.clock, _, _, _ = core_fakes.fakes()
        self.registry = {"a": {"when": {"counter": "x"}, "whisper": "a", "text": "A"},
                         "b": {"when": {"counter": "x", "atLeast": 1}, "whisper": "b", "text": "B"},
                         "c": {"when": {"streak": 3}, "whisper": "c", "text": "C"}}
        self.d = Discovery(self.dir, self.clock, self.registry)
        self.changes = 0
        self.d.on_change = lambda: setattr(self, "changes", self.changes + 1)

    def test_one_find_per_check(self):
        self.d.bump("x")
        self.assertEqual(list(self.d.found), ["a"])
        self.d.check()
        self.assertEqual(list(self.d.found), ["a", "b"])
        self.assertIsNone(self.d.check())
        self.assertEqual(self.changes, 2)
        snap = self.d.snapshot()
        self.assertEqual((snap["latest"]["id"], snap["total"], [f["text"] for f in snap["found"]]), ("b", 3, ["A", "B"]))

    def test_whispered_one_at_a_time_until_seen(self):
        self.d.bump("x")
        self.d.check()
        self.assertEqual(self.d.snapshot()["whisper"], {"id": "a", "text": "a"})
        self.assertEqual(self.d.seen("a")["whisper"], {"id": "b", "text": "b"})
        self.d.flush()
        self.assertEqual(Discovery(self.dir, self.clock, self.registry).unseen, ["b"])
        self.assertIsNone(self.d.seen("b")["whisper"])

    def test_sources_set_by_the_core(self):
        self.d.streak = lambda: 3
        self.assertEqual(self.d.check(), "c")

    def test_only_counters_and_found_ids_reach_disk(self):
        self.d.track_at = lambda: self.clock.now().real * 1000
        self.d.bump("x")
        self.d.flush()
        saved = json.loads((self.dir / "discovery.json").read_text())
        self.assertEqual(set(saved), {"counters", "found", "unseen"})
        self.assertEqual(set(saved["found"]), {"a"})
        again = Discovery(self.dir, self.clock, self.registry)
        self.assertEqual((again.counters, list(again.found)), ({"x": 1}, ["a"]))

    def test_a_fragment_gone_from_the_registry_is_forgotten(self):
        self.d.bump("x")
        self.d.flush()
        self.assertEqual(Discovery(self.dir, self.clock, {"c": self.registry["c"]}).found, {})

    def test_listening_is_a_recent_track(self):
        now = self.clock.now().real
        self.d.track_at = lambda: (now - 60) * 1000
        self.assertTrue(self.d.facts()["listening"])
        self.d.track_at = lambda: (now - 3600) * 1000
        self.assertFalse(self.d.facts()["listening"])
        self.assertEqual(self.d.facts()["hour"], datetime.fromtimestamp(now).hour)

    def test_a_broken_source_never_stops_a_bump(self):
        self.d.streak = lambda: 1 / 0
        with self.assertLogs("fart.discovery", "ERROR"):
            self.assertEqual(self.d.bump("y")["value"], 1)



class FakeClient:
    def __init__(self):
        self.pid, self.topics, self.sent, self.closed, self.kind = 0, {"discovery"}, [], False, "view"

    def send(self, message):
        self.sent.append(message)


class InCore(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, _, host = core_fakes.fakes()

        async def no_spawn():
            raise OSError("no view in this test")
        self.core = Core(self.clock, scheduler, host, Path(self.temp.name), spawn=no_spawn, guard_types=[SessionGuard])
        self.view = FakeClient()
        self.core.server.clients.add(self.view)
        self.core.view.client, self.core.view.state = self.view, "ready"

    async def test_opening_the_panel_is_counted_and_the_topic_is_there(self):
        self.core.view_state(self.view, True, "home")
        self.core.view_state(self.view, True, "tasks")
        self.core.view_state(self.view, False, "tasks")
        self.core.view_state(self.view, True, "tasks")
        self.assertEqual(self.core.discovery.counters.get("view.opens"), 2)
        self.assertIn("discovery", self.core.server.snapshots)

    async def test_a_session_streak_finds_its_fragment(self):
        self.core.discovery.registry = {"s": {"when": {"streak": 1}, "whisper": "s", "text": "S"}}
        self.core.sessions.start("focus")
        self.clock.advance(50 * 60 + 1)
        self.assertIn("s", self.core.discovery.found)
        self.assertTrue([m for m in self.view.sent if m.get("event") == "discovery"])



@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class DiscoveryInTheShell(unittest.TestCase):
    """The whisper and the archive's margins in the real Shell (tools/cuetest/DiscoveryTest.qml), offscreen."""

    def test_whisper_once_then_the_archive(self):
        sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
        import cuetest
        output = cuetest.run("DiscoveryTest.qml", timeout=200)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("whisper.shown", "whisper.gone", "archive.margins", "whisper.waits.for.open"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
