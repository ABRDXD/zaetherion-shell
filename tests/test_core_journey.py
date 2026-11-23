"""The journey (core/journey.py) with the fake clock: what is counted, what fades, what is kept on disk."""
import json
from pathlib import Path
import tempfile
import unittest

import core_fakes
from core.app import Core
from core.guards import SessionGuard
from core.journey import DECAY, SAVE_AFTER, SESSION_GAP, Journey, clean, resonance


class Rooms(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.clock, self.scheduler, _, _ = core_fakes.fakes()
        self.journey = Journey(self.clock, self.scheduler, self.dir)
        self.changes = 0
        self.journey.on_change = self.changed

    def changed(self):
        self.changes += 1

    def go(self, *rooms, stay=10):
        for room in rooms:
            self.journey.report(True, room)
            self.clock.advance(stay)

    def test_moves_make_links_and_time_is_counted(self):
        self.go("tasks", "timers", "tasks")
        self.journey.report(False, "tasks")
        state = self.journey.state
        self.assertEqual(state["edges"], {"tasks>timers": 1.0, "timers>tasks": 1.0})
        self.assertEqual(state["visits"], {"tasks": 2, "timers": 1})
        self.assertAlmostEqual(state["seconds"]["tasks"], 20, delta=0.5)
        self.assertEqual(self.journey.snapshot()["pairs"], [{"a": "tasks", "b": "timers", "weight": 2.0}])

    def test_the_false_room_reads_the_last_hops_and_the_directed_counts(self):
        # W1 (docs/OVERDRIVE.md §53): room ids, times and counts only; the last twelve stops.
        self.go(*(["tasks", "timers"] * 8))
        snapshot = self.journey.snapshot()
        self.assertEqual(len(snapshot["recent"]), 12)
        self.assertTrue(all(len(r) == 2 and r[0] in ("tasks", "timers") and isinstance(r[1], float) for r in snapshot["recent"]))
        self.assertEqual(snapshot["recent"][-1][0], "timers")
        self.assertEqual(snapshot["edges"], {"tasks>timers": 8.0, "timers>tasks": 7.0})

    def test_the_same_room_reported_again_is_one_visit(self):
        self.go("media")
        self.journey.report(True, "media")
        self.assertEqual(self.journey.state["visits"], {"media": 1})

    def test_rooms_it_does_not_know_are_ignored(self):
        self.journey.report(True, "")
        self.journey.report(True, "secret-window-title")
        self.assertEqual((self.journey.state["visits"], self.changes), ({}, 0))

    def test_home_makes_no_shelf(self):
        self.go("home", "media")
        self.assertEqual(self.journey.state["edges"], {"home>media": 1.0})
        self.assertEqual(self.journey.snapshot()["pairs"], [])

    def test_a_short_close_keeps_the_journey_and_a_long_one_breaks_it(self):
        self.go("tasks")
        self.journey.report(False, "tasks")
        self.clock.advance(SESSION_GAP - 5)
        self.go("timers")
        self.assertEqual(self.journey.state["edges"], {"tasks>timers": 1.0})
        self.journey.report(False, "timers")
        self.clock.advance(SESSION_GAP + 5)
        self.go("media")
        self.assertNotIn("timers>media", self.journey.state["edges"])

    def test_links_fade_by_the_day(self):
        self.go("tasks", "timers")
        self.clock.advance(86400 * 3)
        self.go("media")
        self.assertAlmostEqual(self.journey.state["edges"]["tasks>timers"], DECAY ** 3, places=3)

    def test_the_favourite_needs_real_time(self):
        self.go("tasks", stay=30)
        self.journey.closed()
        self.assertIsNone(self.journey.snapshot()["favourite"])
        self.go("tasks", stay=700)
        self.journey.closed()
        self.assertEqual(self.journey.snapshot()["favourite"], "tasks")

    def test_hours_are_normalised_to_the_busiest_hour(self):
        self.go("tasks")
        snapshot = self.journey.snapshot()
        self.assertEqual(max(snapshot["hours"]["tasks"]), 1.0)
        self.assertEqual(len(snapshot["hours"]["tasks"]), 24)

    def test_trend_compares_this_week_with_the_last(self):
        self.go("tasks")
        self.clock.advance(86400 * 8)
        self.go("media", "media")
        self.go("workspaces")
        trend = self.journey.snapshot()["trend"]
        self.assertEqual((trend["tasks"], trend["media"]), (-1.0, 1.0))

    def test_it_is_saved_once_after_a_pause_and_survives_a_restart(self):
        self.go("tasks", "timers", stay=1)
        self.assertFalse((self.dir / "journey.json").exists())
        self.clock.advance(SAVE_AFTER + 0.1)
        self.assertEqual(json.loads((self.dir / "journey.json").read_text())["edges"], {"tasks>timers": 1.0})
        again = Journey(self.clock, self.scheduler, self.dir)
        self.assertEqual(again.state["visits"], {"tasks": 1, "timers": 1})

    def test_only_rooms_and_numbers_are_ever_written(self):
        self.go("tasks", "timers", stay=1)
        self.journey.flush()
        saved = json.loads((self.dir / "journey.json").read_text())
        self.assertEqual(set(saved), {"version", "edges", "seconds", "visits", "hours", "days", "recent", "decayed"})
        self.assertEqual({r[0] for r in saved["recent"]}, {"tasks", "timers"})

    def test_forget_wipes_memory_and_disk(self):
        self.go("tasks", "timers")
        self.journey.forget()
        self.assertEqual(self.journey.state["visits"], {})
        self.assertEqual(json.loads((self.dir / "journey.json").read_text())["edges"], {})
        self.assertEqual(self.journey.snapshot()["pairs"], [])

    def test_a_corrupt_file_starts_fresh(self):
        (self.dir / "journey.json").write_text("{not json")
        with self.assertLogs("fart.journey", "WARNING"):
            self.assertEqual(Journey(self.clock, self.scheduler, self.dir).state["visits"], {})

    def test_clean_drops_what_it_cannot_use(self):
        kept = clean({"edges": {"tasks>timers": 2, "x>y": 3, "tasks": 1, "media>home": -1}, "visits": {"tasks": True, "media": 2},
                      "hours": {"tasks": [0] * 3, "media": [1] * 24}, "recent": [["tasks", 5], ["nope", 5], "x"], "days": {"d": {"media": 1, "x": 2}}})
        self.assertEqual(kept["edges"], {"tasks>timers": 2})
        self.assertEqual(kept["visits"], {"media": 2})
        self.assertEqual(list(kept["hours"]), ["media"])
        self.assertEqual(kept["recent"], [["tasks", 5]])
        self.assertEqual(kept["days"], {"d": {"media": 1}})


class Resonance(unittest.TestCase):
    def loop(self, *rooms, at=1000.0):
        return [[room, at + i] for i, room in enumerate(rooms)]

    def test_a_loop_three_times_round_locks(self):
        found = resonance(self.loop("tasks", "timers", "media", "tasks", "timers", "media", "tasks", "timers", "media"), 1100)
        self.assertEqual(sorted(found), ["media", "tasks", "timers"])

    def test_too_few_repeats_do_not(self):
        self.assertEqual(resonance(self.loop("tasks", "timers", "media", "tasks", "timers"), 1100), [])

    def test_ping_pong_is_not_a_loop(self):
        self.assertEqual(resonance(self.loop(*["tasks", "timers"] * 8), 1100), [])

    def test_only_the_last_hour_counts(self):
        rooms = self.loop("tasks", "timers", "media", "tasks", "timers", "media", "tasks", "timers", "media")
        self.assertEqual(resonance(rooms, 1000.0 + 3700), [])


class FakeClient:
    def __init__(self):
        self.pid, self.topics, self.sent, self.closed, self.kind = 0, {"journey"}, [], False, "view"

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

    async def test_the_view_s_reports_feed_it_and_it_publishes(self):
        self.core.view_state(self.view, True, "tasks")
        self.core.view_state(self.view, True, "timers")
        self.assertEqual(self.core.journey.state["edges"], {"tasks>timers": 1.0})
        self.assertTrue([m for m in self.view.sent if m.get("event") == "journey"])

    async def test_the_op_and_topic_are_registered(self):
        self.assertIn("journey.forget", self.core.server.ops)
        self.assertIn("journey", self.core.server.snapshots)

    async def test_a_dead_view_ends_the_visit(self):
        self.core.view_state(self.view, True, "tasks")
        self.clock.advance(30)
        for callback in self.core.view.on_closed:
            callback()
        self.assertIsNone(self.core.journey.current)
        self.assertAlmostEqual(self.core.journey.state["seconds"]["tasks"], 30, delta=0.5)


if __name__ == "__main__":
    unittest.main()
