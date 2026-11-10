"""Timers on boottime anchors: drift across simulated suspend, reboot fallback, migration (docs/CORE.md §3.7)."""
import json
from pathlib import Path
import tempfile
import unittest

from core_fakes import fakes
from core.timers import Timers


class TimerTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.state = Path(temp.name)
        self.clock, self.scheduler, self.profile, self.host = fakes()
        self.changes = 0

    def timers(self):
        timers = Timers(self.clock, self.scheduler, self.host, self.state)
        timers.on_change = self.count
        return timers

    def count(self):
        self.changes += 1

    def notifications(self):
        return [call for call in self.profile.calls if call[0] == "notify"]

    def sounds(self):
        return [call for call in self.profile.calls if call[0] == "play"]

    def test_countdown_across_suspend_has_no_drift(self):
        timers = self.timers()
        timers.start("countdown", 1500)
        self.clock.advance(300)
        self.clock.suspend(600)  # boottime keeps counting; monotonic would not
        self.assertAlmostEqual(timers.snapshot()["countdown"]["elapsed"], 900)
        self.assertAlmostEqual(self.scheduler.next(), self.clock.boot + 600)
        self.clock.advance(600)
        snap = timers.snapshot()["countdown"]
        self.assertFalse(snap["running"])
        self.assertEqual(snap["done"]["late"], 0)
        self.assertEqual(len(self.notifications()), 1)

    def test_countdown_finished_during_long_suspend_is_silent(self):
        timers = self.timers()
        timers.configure(sound=True)
        timers.start("countdown", 1500)
        self.clock.suspend(3600)
        done = timers.snapshot()["countdown"]["done"]
        self.assertEqual(done["late"], 2100)
        self.assertEqual(done["at"], round((self.clock.real - 2100) * 1000))
        self.assertEqual(len(self.notifications()), 1)
        self.assertIn("35 min ago", self.notifications()[0][2])
        self.assertEqual(self.sounds(), [])

    def test_sound_plays_only_when_enabled_and_host_allows(self):
        timers = self.timers()
        timers.start("countdown", 10)
        self.clock.advance(10)
        self.assertEqual(self.sounds(), [])
        timers.configure(sound=True)
        timers.start("countdown", 10)
        self.clock.advance(10)
        self.assertEqual(self.sounds(), [["play", "timer.done", "1.000"]])
        self.profile.muted = True
        timers.start("countdown", 10)
        self.clock.advance(10)
        self.profile.muted, self.profile.dnd_on = False, True
        timers.start("countdown", 10)
        self.clock.advance(10)
        self.assertEqual(len(self.sounds()), 1)
        self.assertEqual(len(self.notifications()), 4)

    def test_realtime_jump_changes_nothing_but_republishes(self):
        timers = self.timers()
        timers.start("stopwatch")
        self.clock.advance(100)
        before = self.changes
        for delta in (3600, -7200):
            self.clock.set_realtime(delta)
            self.assertAlmostEqual(timers.snapshot()["stopwatch"]["elapsed"], 100)
        self.assertEqual(self.changes, before + 2)

    def test_reboot_falls_back_to_realtime_and_rebases_once(self):
        timers = self.timers()
        timers.start("stopwatch")
        self.clock.advance(100)
        self.clock.reboot(300)
        again = self.timers()
        self.assertAlmostEqual(again.snapshot()["stopwatch"]["elapsed"], 400)
        self.clock.advance(50)
        self.assertAlmostEqual(again.snapshot()["stopwatch"]["elapsed"], 450)
        self.clock.set_realtime(3600)
        self.assertAlmostEqual(self.timers().snapshot()["stopwatch"]["elapsed"], 450)

    def test_pomodoro_boundaries_accumulate_no_drift(self):
        timers = self.timers()
        timers.configure(pomodoro={"focus": 60, "break": 60, "longBreak": 60, "cycles": 4})
        timers.start("pomodoro")
        start = self.clock.boot
        for k in range(1, 101):
            # The core notices each boundary 0.8 s late; the next phase is anchored at the boundary.
            late = start + 60 * k + 0.8 - self.clock.boot
            self.clock.advance(late)
        snap = timers.snapshot()["pomodoro"]
        self.assertTrue(snap["running"])
        self.assertAlmostEqual(snap["elapsed"], 0.8, places=6)  # not 100 × 0.8
        self.assertEqual(len(self.notifications()), 100)

    def test_pomodoro_phase_order_matches_timer_service(self):
        timers = self.timers()
        timers.configure(pomodoro={"focus": 60, "break": 60, "longBreak": 120, "cycles": 2})
        timers.start("pomodoro")
        seen = []
        for _ in range(5):
            self.clock.advance(timers.snapshot()["pomodoro"]["duration"])
            snap = timers.snapshot()["pomodoro"]
            seen.append((snap["phase"], snap["cycle"]))
        self.assertEqual(seen, [("break", 0), ("focus", 1), ("longBreak", 1), ("focus", 0), ("break", 0)])

    def test_pomodoro_late_after_suspend_pauses_at_next_phase(self):
        timers = self.timers()
        timers.configure(sound=True)
        timers.start("pomodoro")
        self.clock.suspend(1500 + 14 * 60)
        snap = timers.snapshot()["pomodoro"]
        self.assertEqual((snap["phase"], snap["running"], snap["elapsed"]), ("break", False, 0))
        self.assertEqual(len(self.notifications()), 1)
        self.assertIn("Focus ended 14 min ago · paused", self.notifications()[0][2])
        self.assertEqual(self.sounds(), [])
        self.assertIsNone(self.scheduler.next())

    def test_configure_keeps_running_phase_length(self):
        timers = self.timers()
        timers.start("pomodoro", focus=3000)
        timers.configure(pomodoro={"focus": 600, "break": 120})
        snap = timers.snapshot()["pomodoro"]
        self.assertEqual(snap["duration"], 3000)
        self.clock.advance(3000)
        self.assertEqual(timers.snapshot()["pomodoro"]["duration"], 120)

    def test_stopwatch_toggle_lap_reset(self):
        timers = self.timers()
        timers.toggle("stopwatch")
        self.clock.advance(5)
        timers.lap()
        timers.toggle("stopwatch")
        self.clock.advance(100)
        snap = timers.snapshot()["stopwatch"]
        self.assertEqual((snap["running"], snap["elapsed"], snap["laps"]), (False, 5, [5]))
        timers.reset("stopwatch")
        self.assertEqual(timers.snapshot()["stopwatch"]["laps"], [])

    def test_countdown_add_ack_and_reset(self):
        timers = self.timers()
        timers.add("countdown", 60)
        timers.toggle("countdown")
        self.clock.advance(30)
        timers.add("countdown", 60)
        self.clock.advance(89)
        self.assertTrue(timers.snapshot()["countdown"]["running"])
        self.clock.advance(1)
        self.assertIsNotNone(timers.snapshot()["countdown"]["done"])
        timers.ack()
        snap = timers.snapshot()["countdown"]
        self.assertEqual((snap["done"], snap["elapsed"], snap["duration"]), (None, 0, 120))
        timers.reset("countdown")
        self.assertEqual(timers.snapshot()["countdown"]["duration"], 0)

    def test_pomodoro_done_marks_each_phase_end_until_acknowledged(self):
        timers = self.timers()
        timers.configure(pomodoro={"focus": 60, "break": 60, "longBreak": 60, "cycles": 4})
        timers.start("pomodoro")
        self.assertIsNone(timers.snapshot()["pomodoro"]["done"])
        self.clock.advance(61)
        done = timers.snapshot()["pomodoro"]["done"]
        self.assertEqual((done["phase"], done["next"], done["late"]), ("focus", "break", 1))
        self.assertEqual(done["at"], round((self.clock.real - 1) * 1000))
        self.assertTrue(timers.summary()["pomodoroDone"])
        self.assertIsNotNone(self.timers().snapshot()["pomodoro"]["done"])  # persisted: survives a core restart
        timers.ack("countdown")
        self.assertIsNotNone(timers.snapshot()["pomodoro"]["done"])  # another kind's ack leaves it
        timers.ack("pomodoro")
        snap = timers.snapshot()["pomodoro"]
        self.assertEqual((snap["done"], snap["running"], snap["phase"]), (None, True, "break"))  # the break keeps running
        self.clock.advance(60)
        self.assertEqual(timers.snapshot()["pomodoro"]["done"]["phase"], "break")
        timers.add("countdown", 1)
        timers.toggle("countdown")
        self.clock.advance(2)
        timers.ack()  # no kind: both
        snap = timers.snapshot()
        self.assertEqual((snap["pomodoro"]["done"], snap["countdown"]["done"]), (None, None))
        self.clock.advance(60)
        timers.reset("pomodoro")
        self.assertIsNone(timers.snapshot()["pomodoro"]["done"])
        with self.assertRaises(Exception):
            timers.ack("kettle")

    def test_nothing_running_disarms_the_scheduler(self):
        timers = self.timers()
        timers.start("countdown", 100)
        timers.toggle("countdown")
        timers.start("stopwatch")
        self.assertIsNone(self.scheduler.next())

    def test_state_survives_a_core_restart(self):
        timers = self.timers()
        timers.start("countdown", 600)
        self.clock.advance(100)
        again = self.timers()
        self.assertAlmostEqual(again.snapshot()["countdown"]["elapsed"], 100)
        self.assertEqual((self.state / "timers.json").stat().st_mode & 0o777, 0o600)

    def test_bad_arguments_are_rejected(self):
        timers = self.timers()
        for call in (lambda: timers.start("egg"), lambda: timers.start("countdown", 0),
                     lambda: timers.start("countdown", "5"), lambda: timers.configure(pomodoro={"cycles": 0}),
                     lambda: timers.add("stopwatch", 5)):
            with self.assertRaises(Exception) as caught:
                call()
            self.assertEqual(caught.exception.code, "bad-args")


class MigrationTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.state = Path(temp.name)
        self.clock, self.scheduler, self.profile, self.host = fakes()

    def migrate(self, timer, settings=None):
        (self.state / "timers.json").write_text(json.dumps({"timer": timer}))
        if settings:
            (self.state / "settings.json").write_text(json.dumps(settings))
        return Timers(self.clock, self.scheduler, self.host, self.state)

    def test_current_live_file_migrates_paused(self):
        live = {"countdown": {"duration": 300, "running": False, "start": 1793845786},
                "pomodoro": {"cycle": 0, "isBreak": False, "running": False, "start": 1793802408},
                "stopwatch": {"laps": [], "running": False, "start": -1004045786}}
        timers = self.migrate(live, {"time": {"pomodoro": {"focus": 3000, "breakTime": 600, "longBreak": 900,
                                                           "cyclesBeforeLongBreak": 3}}, "sounds": {"pomodoro": True}})
        snap = timers.snapshot()
        self.assertEqual(snap["config"], {"pomodoro": {"focus": 3000, "break": 600, "longBreak": 900, "cycles": 3}, "sound": True})
        self.assertEqual((snap["countdown"]["duration"], snap["countdown"]["running"], snap["countdown"]["elapsed"]), (300, False, 0))
        self.assertEqual((snap["pomodoro"]["duration"], snap["pomodoro"]["running"]), (3000, False))
        self.assertEqual(snap["stopwatch"]["elapsed"], 0)
        self.assertEqual(json.loads((self.state / "timers.json").read_text())["version"], 2)
        self.assertEqual(json.loads((self.state / "timers.v1.json").read_text()), {"timer": live})

    def test_running_timers_keep_their_elapsed_time(self):
        now = self.clock.real
        timers = self.migrate({
            "countdown": {"duration": 300, "running": True, "start": now - 120},
            "pomodoro": {"cycle": 1, "isBreak": True, "running": True, "start": now - 60},
            "stopwatch": {"laps": [150, 300], "running": True, "start": now * 100 - 4500, "elapsed": 0}})
        snap = timers.snapshot()
        self.assertAlmostEqual(snap["countdown"]["elapsed"], 120)
        self.assertEqual((snap["pomodoro"]["phase"], snap["pomodoro"]["cycle"]), ("break", 1))
        self.assertAlmostEqual(snap["pomodoro"]["elapsed"], 60)
        self.assertAlmostEqual(snap["stopwatch"]["elapsed"], 45)
        self.assertEqual(snap["stopwatch"]["laps"], [1.5, 3.0])
        self.clock.advance(180)
        self.assertIsNotNone(timers.snapshot()["countdown"]["done"])

    def test_paused_stopwatch_converts_centiseconds(self):
        timers = self.migrate({"stopwatch": {"laps": [], "running": False, "start": 0, "elapsed": 12345}})
        self.assertAlmostEqual(timers.snapshot()["stopwatch"]["elapsed"], 123.45)

    def test_version_2_is_never_migrated_again(self):
        Timers(self.clock, self.scheduler, self.host, self.state).start("countdown", 60)
        before = (self.state / "timers.json").read_text()
        Timers(self.clock, self.scheduler, self.host, self.state)
        self.assertEqual((self.state / "timers.json").read_text(), before)
        self.assertFalse((self.state / "timers.v1.json").exists())


class TimerfdTests(unittest.TestCase):
    def test_real_boottime_timerfd_fires_earliest_and_disarms(self):
        import asyncio
        from core.clock import SystemClock, TimerfdScheduler

        async def run():
            loop = asyncio.get_running_loop()
            clock = SystemClock()
            scheduler = TimerfdScheduler(clock, loop)
            fired = []
            done = loop.create_future()
            now = clock.now().boot
            scheduler.at("late", now + 0.2, lambda _: (fired.append("late"), done.set_result(True)))
            scheduler.at("early", now + 0.05, lambda _: fired.append("early"))
            scheduler.at("cancelled", now + 0.1, lambda _: fired.append("cancelled"))
            scheduler.cancel("cancelled")
            await asyncio.wait_for(done, 2)
            self.assertEqual(fired, ["early", "late"])
            self.assertIsNone(scheduler.next())
            self.assertEqual(os.timerfd_gettime(scheduler.fd), (0.0, 0.0))
            loop.remove_reader(scheduler.fd)
            loop.remove_reader(scheduler.realtime)
            os.close(scheduler.fd)
            os.close(scheduler.realtime)

        import os
        asyncio.run(run())


if __name__ == "__main__":
    unittest.main()
