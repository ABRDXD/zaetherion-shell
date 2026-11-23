"""core/skywatch.py: the place, the view's `sky.now`, and sky events into discovery on the boottime scheduler."""
from pathlib import Path
import tempfile
import unittest

import core_fakes
from core import skywatch
from core.app import Core
from core.guards import SessionGuard


class FakeDiscovery:
    def __init__(self):
        self.counters = {}

    def bump(self, counter, by=1):
        self.counters[counter] = self.counters.get(counter, 0) + by


class Place(unittest.TestCase):
    def watch(self, host, zone=lambda: None):
        clock, scheduler, _, _ = core_fakes.fakes()
        return skywatch.SkyWatch(clock, scheduler, lambda: host, FakeDiscovery(), zone=zone)

    def test_the_host_s_place_first(self):
        self.assertEqual(self.watch({"lat": 10.0, "lon": 20.0, "name": "Somewhere"}).place(),
                         {"lat": 10.0, "lon": 20.0, "name": "Somewhere", "source": "host"})

    def test_a_bad_host_place_falls_back_to_the_time_zone_then_to_none(self):
        zone = {"lat": 22.5333, "lon": 88.3667, "name": "Kolkata", "source": "timezone"}
        for bad in (None, {}, {"lat": "x", "lon": 1}, {"lat": 91, "lon": 0}, {"lat": 0, "lon": 200}, "here"):
            with self.subTest(bad=bad):
                self.assertEqual(self.watch(bad, zone=lambda: zone).place(), zone)
        self.assertEqual(self.watch(None).place(), {"lat": 0.0, "lon": 0.0, "name": "", "source": "none"})

    def test_a_failing_host_profile_does_not_raise(self):
        clock, scheduler, _, _ = core_fakes.fakes()

        def broken():
            raise RuntimeError("profile bug")
        watch = skywatch.SkyWatch(clock, scheduler, broken, FakeDiscovery(), zone=lambda: None)
        with self.assertLogs("fart.sky", "ERROR"):
            self.assertEqual(watch.place()["source"], "none")

    def test_zone_tab(self):
        with tempfile.TemporaryDirectory() as temp:
            tab = Path(temp) / "zone1970.tab"
            tab.write_text("# comment\nIN\t+2232+08822\tAsia/Kolkata\nUS\t+404251-0740023\tAmerica/New_York\tEastern\n"
                           "XX\tbad\tEtc/Bad\n")
            self.assertEqual(skywatch.zone_place(tab, zone="Asia/Kolkata"),
                             {"lat": 22.5333, "lon": 88.3667, "name": "Kolkata", "source": "timezone"})
            ny = skywatch.zone_place(tab, zone="America/New_York")
            self.assertAlmostEqual(ny["lat"], 40.7142, places=3)
            self.assertAlmostEqual(ny["lon"], -74.0064, places=3)
            self.assertEqual(ny["name"], "New York")
            self.assertIsNone(skywatch.zone_place(tab, zone="Etc/Bad"))
            self.assertIsNone(skywatch.zone_place(tab, zone="Mars/Olympus"))
            self.assertIsNone(skywatch.zone_place(Path(temp) / "missing", zone="Asia/Kolkata"))
            # /etc/localtime resolved through its zoneinfo link.
            link = Path(temp) / "localtime"
            (Path(temp) / "zoneinfo/Asia").mkdir(parents=True)
            (Path(temp) / "zoneinfo/Asia/Kolkata").write_text("")
            link.symlink_to(Path(temp) / "zoneinfo/Asia/Kolkata")
            self.assertEqual(skywatch.zone_place(tab, link)["name"], "Kolkata")


class Events(unittest.TestCase):
    def setUp(self):
        self.clock, self.scheduler, _, _ = core_fakes.fakes()
        self.discovery = FakeDiscovery()
        self.watch = skywatch.SkyWatch(self.clock, self.scheduler, lambda: {"lat": 51.4769, "lon": 0.0, "name": "Greenwich"},
                                       self.discovery)

    def seconds_to_next(self):
        boot, _ = self.scheduler.pending["sky"]
        return boot - self.clock.now().boot

    def test_nothing_is_scheduled_before_start(self):
        self.assertNotIn("sky", self.scheduler.pending)

    def test_each_event_bumps_its_counter_and_arms_the_next(self):
        self.watch.start()
        first = self.watch.queue[0]
        wait = self.seconds_to_next()
        self.assertGreater(wait, 0)
        self.assertLess(wait, 86400)  # a sunrise or a sunset within a day at Greenwich
        self.clock.advance(wait + 1)
        self.assertEqual(self.discovery.counters, {"sky." + first["kind"]: 1})
        self.assertEqual(self.watch.last["kind"], first["kind"])
        self.assertIn("sky", self.scheduler.pending)
        # Two days of events in a row: one wake-up each, every one counted.
        fired, elapsed = 1, wait + 1
        while elapsed + self.seconds_to_next() < 2 * 86400:
            step = self.seconds_to_next() + 1
            self.clock.advance(step)
            elapsed += step
            fired += 1
        self.assertGreaterEqual(fired, 4)
        # A conjunction also counts its pair.
        kinds = {k: v for k, v in self.discovery.counters.items() if not k.startswith("sky.conjunction.")}
        self.assertEqual(sum(kinds.values()), fired)
        self.assertGreaterEqual(self.discovery.counters.get("sky.sun.rise", 0), 1)
        self.assertGreaterEqual(self.discovery.counters.get("sky.sun.set", 0), 1)

    def test_an_event_slept_through_is_not_counted(self):
        self.watch.start()
        self.clock.suspend(self.seconds_to_next() + skywatch.STALE + 60)
        self.assertEqual(self.discovery.counters, {})
        self.assertIsNone(self.watch.last)
        self.assertGreater(self.seconds_to_next(), 0)

    def test_a_wall_clock_jump_recomputes(self):
        self.watch.start()
        before = self.watch.queue[0]["jd"]
        self.clock.set_realtime(3 * 86400)
        self.assertGreater(self.watch.queue[0]["jd"], before + 2)
        self.assertGreater(self.seconds_to_next(), 0)

    def test_conjunctions_count_their_pair(self):
        event = {"kind": "conjunction", "body": "jupiter", "bodies": ["jupiter", "saturn"], "separation": 0.1,
                 "jd": skywatch.jd_of(self.clock.now().real)}
        self.watch._fire(event, self.clock.now())
        self.assertEqual(self.discovery.counters, {"sky.conjunction": 1, "sky.conjunction.jupiter-saturn": 1})

    def test_now_answers_the_clock(self):
        snap = self.watch.now()
        self.assertEqual(snap["place"]["source"], "host")
        self.assertEqual(set(snap["bodies"]), set(skywatch.sky.BODIES))
        self.assertIn(snap["moon"]["phase"], ("new", "waxing crescent", "first quarter", "waxing gibbous", "full",
                                              "waning gibbous", "last quarter", "waning crescent"))
        self.assertTrue(snap["next"])
        self.assertEqual([e["inSeconds"] for e in snap["next"]], sorted(e["inSeconds"] for e in snap["next"]))
        self.assertTrue(all(0 <= e["inSeconds"] < skywatch.SOON * 86400 for e in snap["next"]))
        self.assertTrue(all("jd" not in e and e["at"].endswith("+00:00") for e in snap["next"]))
        # Asking does not wake the core later: only start() schedules.
        self.assertNotIn("sky", self.scheduler.pending)
        self.assertNotIn("tracks", snap)
        self.assertEqual(len(self.watch.now(tracks=True)["tracks"]["paths"]["moon"]), 97)


class CoreOp(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, self.profile, host = core_fakes.fakes()

        async def spawn():
            raise OSError("no view in this test")
        self.core = Core(self.clock, scheduler, host, Path(self.temp.name), spawn=spawn, guard_types=[SessionGuard])

    async def test_sky_now_uses_the_host_location(self):
        snap = self.core.server.ops["sky.now"](None)
        self.assertEqual(snap["place"], {"lat": 51.4769, "lon": 0.0, "name": "Greenwich", "source": "host"})
        self.assertNotIn("tracks", snap)
        self.assertIn("tracks", self.core.server.ops["sky.now"](None, tracks=True))
        self.assertNotIn("tracks", self.core.server.ops["sky.now"](None, tracks="yes"))
        self.profile.place = None
        self.assertIn(self.core.sky.now()["place"]["source"], ("timezone", "none"))


if __name__ == "__main__":
    unittest.main()
