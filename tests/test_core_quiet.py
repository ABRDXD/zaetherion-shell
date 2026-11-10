"""Quiet telemetry (core/quiet.py) with the fake clock: normal values are silent, departures sound once, Silent reads nothing."""
from pathlib import Path
import tempfile
import unittest

import core_fakes
from core.quiet import COOLDOWN, INTERVAL, QUIET_GAP, WARM, Deviation, Quiet, THRASH_FLOOR


class FakeMachine:
    def __init__(self, root: Path):
        self.proc, self.usb = root / "proc", root / "usb"
        (self.proc / "net").mkdir(parents=True)
        self.usb.mkdir()
        self.faults, self.rx, self.tx, self.lo = 0, 0, 0, 0
        self.write()

    def write(self):
        (self.proc / "vmstat").write_text(f"nr_free_pages 5\npgmajfault {self.faults}\npswpin 0\npswpout 0\n")
        row = lambda name, rx, tx: f"{name}: {rx} 0 0 0 0 0 0 0 {tx} 0 0 0 0 0 0 0\n"
        (self.proc / "net/dev").write_text("h1\nh2\n" + row("lo", self.lo, self.lo) + row("wlan0", self.rx, self.tx))


class DeviationTests(unittest.TestCase):
    def test_large_steady_values_are_normal(self):
        d = Deviation(THRASH_FLOOR)
        self.assertFalse(any(d.push(10000 + i % 5) for i in range(50)))

    def test_a_jump_is_reported_once_on_the_way_up(self):
        d = Deviation(THRASH_FLOOR)
        for i in range(WARM):
            d.push(1.0)
        self.assertEqual([d.push(v) for v in (900, 900, 1, 900)], [True, False, False, True])

    def test_nothing_is_reported_before_it_has_warmed_up(self):
        d = Deviation(THRASH_FLOOR)
        self.assertFalse(any(d.push(v) for v in [0.0] * (WARM - 1) + [9000.0]))

    def test_a_small_jump_stays_under_the_floor(self):
        d = Deviation(THRASH_FLOOR)
        for i in range(WARM):
            d.push(0.0)
        self.assertFalse(d.push(THRASH_FLOOR - 1))


class QuietTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.machine = FakeMachine(Path(temp.name))
        self.clock, self.scheduler, _, _ = core_fakes.fakes()
        self.on, self.cues = True, []
        self.quiet = Quiet(self.clock, self.scheduler, lambda: self.on, self.cues.append,
                           proc=self.machine.proc, usb=self.machine.usb)

    def run_for(self, ticks, change=lambda: None):
        for _ in range(ticks):
            change()
            self.machine.write()
            self.clock.advance(INTERVAL)

    def warm(self):
        self.quiet.sync()
        self.run_for(WARM + 2)

    def test_nothing_runs_in_silent(self):
        self.on = False
        self.quiet.sync()
        self.assertFalse(self.quiet.running)
        self.assertNotIn("quiet.sample", self.scheduler.pending)

    def test_steady_traffic_is_silent(self):
        self.quiet.sync()
        def steady():
            self.machine.rx += 50_000_000
        self.run_for(40, steady)
        self.assertEqual(self.cues, [])

    def test_a_network_burst_sounds_and_loopback_does_not(self):
        self.warm()
        def loop():
            self.machine.lo += 10_000_000_000
        self.run_for(2, loop)
        self.assertEqual(self.cues, [])
        def burst():
            self.machine.tx += 100_000_000
        self.run_for(1, burst)
        self.run_for(1)
        self.assertEqual(self.cues, ["quiet.burst"])

    def test_thrash_sounds(self):
        self.warm()
        def thrash():
            self.machine.faults += 5000
        self.run_for(1, thrash)
        self.run_for(1)
        self.assertEqual(self.cues, ["quiet.thrash"])

    def test_a_device_change_sounds_and_the_first_reading_does_not(self):
        (self.machine.usb / "1-1").mkdir()
        (self.machine.usb / "1-1:1.0").mkdir()
        self.quiet.sync()
        self.run_for(2)
        self.assertEqual(self.cues, [])
        (self.machine.usb / "1-2").mkdir()
        self.run_for(1)
        self.assertEqual(self.cues, ["quiet.device"])

    def test_cooldown_and_the_gap_between_kinds(self):
        self.warm()
        def spike():
            self.machine.tx += 100_000_000
        self.run_for(1, spike)
        self.run_for(1)
        (self.machine.usb / "1-3").mkdir()
        self.run_for(1)
        self.assertEqual(self.cues, ["quiet.burst"], "another kind waits for the gap")
        self.run_for(1, spike)
        self.run_for(1)
        self.assertEqual(self.cues, ["quiet.burst"], "the same kind waits for its cooldown")
        self.assertLess(QUIET_GAP, COOLDOWN)

    def test_a_suspend_is_not_a_burst(self):
        self.warm()
        self.machine.tx += 900_000_000_000
        self.machine.write()
        self.clock.suspend(3600)
        self.run_for(2)
        self.assertEqual(self.cues, [])

    def test_stopping_forgets_everything(self):
        self.warm()
        self.on = False
        self.clock.advance(INTERVAL)
        self.assertFalse(self.quiet.running)
        self.assertIsNone(self.quiet.last)
        self.assertEqual(len(self.quiet.burst.values), 0)
        self.assertNotIn("quiet.sample", self.scheduler.pending)
