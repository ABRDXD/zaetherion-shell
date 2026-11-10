"""Sessions (core/sessions.py, M11) with the fake clock: presets, the debrief, the streak and the host's focus tracker."""
from datetime import datetime, timedelta
import json
from pathlib import Path
import shutil
import sqlite3
import sys
import tempfile
import unittest

import core_fakes
from core.errors import OpError
from core.sessions import PRESETS, STREAK_SECONDS, Sessions, streak
from core.host import load_profile


class Presets(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.clock, self.scheduler, _, self.host = core_fakes.fakes()
        self.sessions = Sessions(self.clock, self.scheduler, self.host, self.dir)

    def test_a_preset_brings_its_own_length(self):
        snap = self.sessions.start("focus")
        self.assertEqual(snap["active"]["seconds"], PRESETS["focus"])
        self.assertEqual([p["name"] for p in snap["presets"]], list(PRESETS))

    def test_any_other_name_needs_a_length(self):
        with self.assertRaises(OpError):
            self.sessions.start("pyq")
        self.assertEqual(self.sessions.start("pyq", 3600)["active"]["preset"], "pyq")

    def test_the_debrief_after_a_full_session(self):
        self.host.profile.focus_spans = [["code", 1800], ["firefox", 600], ["Desktop", 0]]
        self.sessions.tasks_done = lambda start, end: 2
        self.sessions.start("focus")
        self.clock.advance(PRESETS["focus"] + 1)
        last = self.sessions.snapshot()["last"]
        self.assertEqual((last["preset"], last["completed"], last["seconds"], last["planned"], last["tasks"]),
                         ("focus", True, PRESETS["focus"], PRESETS["focus"], 2))
        self.assertEqual(last["apps"], [["code", 1800], ["firefox", 600]])
        self.assertIsNone(self.sessions.snapshot()["active"])

    def test_ended_early_is_said_so_and_the_apps_never_reach_disk(self):
        self.host.profile.focus_spans = [["code", 300]]
        self.sessions.start("read")
        self.clock.advance(600)
        self.sessions.end()
        last = self.sessions.snapshot()["last"]
        self.assertEqual((last["completed"], last["seconds"]), (False, 600))
        saved = json.loads((self.dir / "session.json").read_text())
        self.assertNotIn("apps", saved["last"])
        self.assertNotIn("code", (self.dir / "session.json").read_text() + (self.dir / "sessions.jsonl").read_text())

    def test_no_tracker_no_apps(self):
        self.sessions.start("read")
        self.clock.advance(120)
        self.sessions.end()
        self.assertIsNone(self.sessions.snapshot()["last"]["apps"])

    def test_dismiss_and_a_new_start_put_the_debrief_away(self):
        self.sessions.start("read")
        self.clock.advance(120)
        self.sessions.end()
        self.assertIsNone(self.sessions.dismiss()["last"])
        self.sessions.start("read")
        self.clock.advance(120)
        self.sessions.end()
        self.assertIsNotNone(self.sessions.snapshot()["last"])
        self.assertIsNone(self.sessions.start("focus")["last"])

    def test_the_debrief_survives_a_restart_without_its_apps(self):
        self.host.profile.focus_spans = [["code", 300]]
        self.sessions.start("read")
        self.clock.advance(120)
        self.sessions.end()
        again = Sessions(self.clock, self.scheduler, self.host, self.dir)
        last = again.snapshot()["last"]
        self.assertEqual((last["preset"], last["seconds"]), ("read", 120))
        self.assertNotIn("apps", last)
        self.assertEqual(len(again.entries), 1)


class QuietAndMusic(unittest.TestCase):
    """Do Not Disturb on for the session and back off after, only if the session turned it on; music unless reading."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, self.scheduler, _, self.host = core_fakes.fakes()
        self.sessions = Sessions(self.clock, self.scheduler, self.host, Path(self.temp.name))
        self.played = 0
        self.sessions.music = lambda: setattr(self, "played", self.played + 1)

    def test_dnd_on_then_back_off(self):
        self.sessions.start("focus")
        self.assertTrue(self.host.profile.dnd_on)
        self.clock.advance(PRESETS["focus"] + 1)
        self.assertFalse(self.host.profile.dnd_on)
        self.assertEqual([c for c in self.host.profile.calls if c[0] != "notify"], [["dnd", "on"], ["dnd", "off"]])

    def test_dnd_already_on_is_left_on(self):
        self.host.profile.dnd_on = True
        self.sessions.start("focus")
        self.sessions.end()
        self.assertTrue(self.host.profile.dnd_on)
        self.assertEqual([c for c in self.host.profile.calls if c[0] == "dnd"], [])

    def test_dnd_survives_a_restart_mid_session(self):
        self.sessions.start("focus")
        again = Sessions(self.clock, self.scheduler, self.host, Path(self.temp.name))
        again.end()
        self.assertFalse(self.host.profile.dnd_on)

    def test_music_except_when_reading(self):
        self.sessions.start("focus")
        self.sessions.end()
        self.sessions.start("read")
        self.sessions.end()
        self.assertEqual(self.played, 1)


class SerpantinumDnd(unittest.TestCase):
    """The Serpantinum profile writes notifications.dnd as Serpantinum does, keeping every other setting."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        import os
        from unittest import mock
        patcher = mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": self.temp.name})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.profile = load_profile("serpantinum")
        self.path = Path(self.temp.name) / "serpantinum/settings.json"
        self.path.parent.mkdir()

    def test_on_and_off_keeping_the_rest(self):
        self.path.write_text(json.dumps({"general": {"muteSfx": False}, "notifications": {"dnd": False, "position": "top right"}}))
        self.assertTrue(self.profile.set_dnd(True))
        saved = json.loads(self.path.read_text())
        self.assertEqual(saved, {"general": {"muteSfx": False}, "notifications": {"dnd": True, "position": "top right"}})
        self.assertTrue(self.profile.dnd())
        self.assertTrue(self.profile.set_dnd(False))
        self.assertFalse(self.profile.dnd())
        self.assertEqual(sorted(p.name for p in self.path.parent.iterdir()), ["settings.json"])

    def test_an_unreadable_file_is_left_alone(self):
        self.path.write_text("{broken")
        self.assertFalse(self.profile.set_dnd(True))
        self.assertEqual(self.path.read_text(), "{broken")
        self.path.unlink()
        self.assertFalse(self.profile.set_dnd(True))
        self.assertFalse(self.path.exists())


class Streak(unittest.TestCase):
    def at(self, day, seconds):
        return {"preset": "focus", "start": datetime.combine(day, datetime.min.time()).timestamp() * 1000 + 3600_000,
                "seconds": seconds}

    def test_runs_of_days(self):
        today = datetime(2026, 11, 10).date()
        days = [today - timedelta(days=d) for d in (0, 1, 2, 5, 6, 7, 8)]
        s = streak([self.at(d, STREAK_SECONDS) for d in days], today)
        self.assertEqual((s["current"], s["best"]), (3, 4))
        self.assertEqual(len(s["minutes"]), 14)
        self.assertEqual(s["minutes"][-1], STREAK_SECONDS // 60)

    def test_today_still_empty_keeps_yesterday_s_run(self):
        today = datetime(2026, 11, 10).date()
        s = streak([self.at(today - timedelta(days=d), 3600) for d in (1, 2)], today)
        self.assertEqual(s["current"], 2)

    def test_short_days_do_not_count(self):
        today = datetime(2026, 11, 10).date()
        s = streak([self.at(today, STREAK_SECONDS - 1)], today)
        self.assertEqual((s["current"], s["best"]), (0, 0))

    def test_a_damaged_log_is_skipped_line_by_line(self):
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "sessions.jsonl").write_text('{"preset": "x", "start": 1, "seconds": 60}\nnot json\n{"preset": 3}\n')
            clock, scheduler, _, host = core_fakes.fakes()
            self.assertEqual(len(Sessions(clock, scheduler, host, Path(tmp)).entries), 1)


class SerpantinumFocus(unittest.TestCase):
    """The Serpantinum profile reads Digital Wellbeing's database read-only, minute by minute, titles untouched."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.db = Path(self.temp.name) / "focustime.db"
        self.profile = load_profile("serpantinum")
        import os
        from unittest import mock
        patcher = mock.patch.dict(os.environ, {"QS_STATE_FOCUSTIME": self.temp.name})
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_missing_is_none(self):
        self.assertIsNone(self.profile.focus(0, 1000))

    def test_the_span_s_minutes_summed_by_app(self):
        db = sqlite3.connect(self.db)
        db.execute("CREATE TABLE focus_minutes (log_date TEXT, minute_idx INTEGER, app_class TEXT, seconds INTEGER, PRIMARY KEY (log_date, minute_idx, app_class))")
        db.execute("CREATE TABLE focus_log (log_date TEXT, app_class TEXT, seconds INTEGER, app_title TEXT)")
        start = datetime(2026, 11, 10, 23, 50)
        for i in range(20):   # 23:50 to 00:09, across midnight
            t = start + timedelta(minutes=i)
            db.execute("INSERT INTO focus_minutes VALUES (?, ?, ?, ?)", (t.date().isoformat(), t.hour * 60 + t.minute, "code" if i % 2 else "kitty", 30))
        db.execute("INSERT INTO focus_minutes VALUES (?, ?, ?, ?)", ("2026-11-10", 0, "outside", 60))   # before the span
        db.commit()
        db.close()
        end = start + timedelta(minutes=19)
        found = self.profile.focus(start.timestamp() * 1000, end.timestamp() * 1000)
        self.assertEqual(sorted(found), [["code", 300], ["kitty", 300]])

    def test_a_broken_file_is_none(self):
        self.db.write_text("not a database")
        self.assertIsNone(self.profile.focus(0, 120_000))



class FakeView:
    def __init__(self):
        self.pid, self.topics, self.sent, self.closed, self.kind = 0, set(), [], False, "view"

    def send(self, message):
        self.sent.append(message)


class MusicInCore(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        import asyncio
        from core.app import Core
        from core.guards import SessionGuard
        self.asyncio = asyncio
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, _, host = core_fakes.fakes()

        async def no_spawn():
            raise OSError("no view in this test")
        self.core = Core(self.clock, scheduler, host, Path(self.temp.name), spawn=no_spawn, guard_types=[SessionGuard])

    def host_calls(self, view):
        return [m["data"] for m in view.sent if m.get("event") == "view.host"]

    async def test_a_live_view_is_asked_for_the_player(self):
        view = FakeView()
        self.core.server.clients.add(view)
        self.core.view.client, self.core.view.state = view, "ready"
        self.core.sessions.start("focus")
        for _ in range(5):
            await self.asyncio.sleep(0)
        calls = self.host_calls(view)
        self.assertEqual([(c["domain"], c["method"], c["read"]) for c in calls], [("media", None, "active")])
        # The adapter answers: paused, so it is played.
        self.core.hostcalls.done(view, calls[0]["token"], True, {"read": {"playing": False}})
        for _ in range(5):
            await self.asyncio.sleep(0)
        self.assertEqual([c["method"] for c in self.host_calls(view)], [None, "togglePlaying"])

    async def test_no_view_no_music_and_no_spawn(self):
        self.core.view.state = "absent"
        self.core.sessions.start("focus")
        await self.asyncio.sleep(0)
        self.assertEqual(self.core.view.state, "absent")


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class SessionsInTheTimersRoom(unittest.TestCase):
    """The Session tab of the real Timers room (tools/cuetest/SessionTest.qml), offscreen: nothing reaches a core."""

    def test_idle_running_debrief(self):
        sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
        import cuetest
        output = cuetest.run("SessionTest.qml", timeout=150)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("session.idle", "session.running", "session.debrief", "session.restarted", "session.other.tabs"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
