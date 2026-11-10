"""core/orrery.py: the telemetry orrery's sampler (M12). What it reads, what it reports, and when it reads nothing."""
import os
from pathlib import Path
import tempfile
import unittest

import core_fakes
from core import orrery
from core.app import Core
from core.guards import SessionGuard
from core.orrery import KEEP, SHOW, TICKS, Orrery, Process, Reading, parse_stat, read_proc

MIB = 1.0


class FakeProc:
    """A process table the test edits between samples: pid → Process; `forks` is the kernel's counter."""

    def __init__(self):
        self.table: dict[int, Process] = {}
        self.forks = 1000
        self.uptime = 5000.0
        self.reads = 0

    def add(self, pid, name, rss, ticks=0, start=None):
        self.table[pid] = Process(name, ticks, int((self.uptime if start is None else start) * TICKS), rss)

    def run(self, pid, ticks=0, rss=None):
        p = self.table[pid]
        self.table[pid] = p._replace(ticks=p.ticks + ticks, rss=p.rss if rss is None else rss)

    def __call__(self):
        self.reads += 1
        return Reading(dict(self.table), self.forks, self.uptime)


class Sampling(unittest.TestCase):
    def setUp(self):
        self.clock, _, _, _ = core_fakes.fakes()
        self.proc = FakeProc()
        self.on = True
        self.orrery = Orrery(self.clock, active=lambda: self.on, reader=self.proc)

    def tick(self, seconds=1.0):
        self.clock.advance(seconds)
        self.proc.uptime += seconds
        return self.orrery.sample()

    def bodies(self, sample):
        return {b["name"]: b for b in sample["bodies"]}

    def test_nothing_is_read_unless_overdrive_is_in_effect(self):
        self.on = False
        self.assertEqual(self.orrery.sample(), {"running": False})
        self.assertEqual(self.proc.reads, 0)

    def test_cpu_is_the_share_of_one_core_since_the_last_sample(self):
        self.proc.add(10, "busy", 100, start=10)
        self.proc.add(11, "idle", 100, start=10)
        first = self.orrery.sample()
        self.assertFalse(first["warm"])
        self.assertEqual(self.bodies(first)["busy"]["cpu"], 0.0)
        self.proc.run(10, ticks=TICKS)  # a whole second of CPU…
        second = self.tick(2.0)  # …over two seconds
        self.assertTrue(second["warm"])
        self.assertEqual(self.bodies(second)["busy"]["cpu"], 50.0)
        self.assertEqual(self.bodies(second)["idle"]["cpu"], 0.0)
        self.proc.run(10, ticks=3 * TICKS)  # three threads busy for a second
        self.assertEqual(self.bodies(self.tick())["busy"]["cpu"], 300.0)

    def test_memory_growth_is_smoothed_and_signed(self):
        self.proc.add(10, "leak", 100, start=10)
        self.proc.add(11, "frees", 500, start=10)
        self.orrery.sample()
        for i in range(30):
            self.proc.run(10, rss=100 + 2 * (i + 1))  # 2 MiB a second
            self.proc.run(11, rss=500 - (i + 1))  # 1 MiB a second back
            sample = self.tick()
        leak, frees = self.bodies(sample)["leak"], self.bodies(sample)["frees"]
        # Thirty seconds at τ = 15 s: most of the way to the real rate, never past it.
        self.assertGreater(leak["growth"], 1.6)
        self.assertLess(leak["growth"], 2.0)
        self.assertLess(frees["growth"], -0.8)
        self.assertEqual(leak["rss"], 160.0)

    def test_heavy_and_busy_rank_first_and_the_set_holds_at_its_edge(self):
        for pid in range(1, 41):
            self.proc.add(pid, f"p{pid:02}", rss=float(pid), start=10)
        first = self.orrery.sample()
        self.assertEqual(len(first["bodies"]), SHOW)
        self.assertEqual(first["bodies"][0]["name"], "p40")
        # A small process that turns busy outranks the heavy ones: 1 % of a core weighs 40 MiB.
        self.proc.run(1, ticks=TICKS // 10)
        second = self.tick()
        self.assertEqual(second["bodies"][0]["name"], "p01")
        # p25 was shown and now ranks 17th or so: it stays, within KEEP; nothing new is added below SHOW.
        names = [b["name"] for b in second["bodies"]]
        self.assertIn("p25", names)
        self.assertLessEqual(len(names), KEEP)
        # Pushed far down (by 30 busier processes), a shown body leaves without being reported as ended.
        for pid in range(2, 32):
            self.proc.run(pid, ticks=TICKS)
        third = self.tick()
        self.assertNotIn("p40", [b["name"] for b in third["bodies"]])
        self.assertEqual(third["exits"], [])

    def test_an_ended_shown_process_is_reported_once_with_its_name(self):
        self.proc.add(10, "editor", 300, start=10)
        self.proc.add(11, "shell", 50, start=10)
        self.orrery.sample()
        del self.proc.table[10]
        ended = self.tick()
        self.assertEqual(ended["exits"], [{"id": f"10:{10 * TICKS}", "name": "editor"}])
        self.assertEqual(self.tick()["exits"], [])

    def test_a_reused_pid_is_a_new_process(self):
        self.proc.add(10, "old", 300, ticks=500, start=10)
        self.orrery.sample()
        self.proc.add(10, "new", 300, ticks=50, start=self.proc.uptime + 0.5)
        sample = self.tick()
        self.assertEqual(sample["exits"], [{"id": f"10:{10 * TICKS}", "name": "old"}])
        new = self.bodies(sample)["new"]
        self.assertEqual(new["cpu"], 0.0)  # no CPU measured against the old process's counter
        self.assertTrue(new["born"])

    def test_born_means_young_not_just_newly_heavy(self):
        self.proc.add(10, "base", 10, start=10)
        self.orrery.sample()
        self.proc.add(20, "fresh", 400, start=self.proc.uptime + 0.5)
        self.proc.add(21, "veteran", 400, start=100)  # readable only now, but old
        sample = self.bodies(self.tick())
        self.assertTrue(sample["fresh"]["born"])
        self.assertFalse(sample["veteran"]["born"])
        self.assertFalse(self.bodies(self.tick())["fresh"]["born"])

    def test_the_first_sample_bears_nothing(self):
        self.proc.add(20, "fresh", 400, start=self.proc.uptime - 0.2)
        sample = self.orrery.sample()
        self.assertFalse(self.bodies(sample)["fresh"]["born"])
        self.assertEqual(sample["forks"], 0)

    def test_forks_are_the_kernels_count_between_samples(self):
        self.orrery.sample()
        self.proc.forks += 37  # a build: most of them gone again before the next sample
        self.assertEqual(self.tick()["forks"], 37)

    def test_a_gap_or_a_release_starts_fresh(self):
        self.proc.add(10, "busy", 100, start=10)
        self.orrery.sample()
        self.proc.run(10, ticks=TICKS)
        stale = self.tick(orrery.STALE + 1)
        self.assertFalse(stale["warm"])
        self.on = False
        self.assertEqual(self.orrery.sample(), {"running": False})
        self.assertEqual(self.orrery.last, {})
        self.on = True
        self.assertFalse(self.tick()["warm"])

    def test_totals_count_every_process_not_just_the_shown(self):
        for pid in range(1, 31):
            self.proc.add(pid, f"p{pid}", rss=10, start=10)
        sample = self.orrery.sample()
        self.assertEqual(sample["total"], {"cpu": 0.0, "rss": 300.0, "count": 30})


class Parsing(unittest.TestCase):
    def test_a_name_with_spaces_and_parentheses(self):
        fields = ["S", "1", "1", "1", "0", "-1", "4194304", "0", "0", "0", "0", "120", "30"] + ["0"] * 6 + ["9876", "0", "0"]
        self.assertEqual(parse_stat("42 (Web (Content) 1) " + " ".join(fields)), ("Web (Content) 1", 150, 9876, 4194304))
        self.assertIsNone(parse_stat("garbage"))
        self.assertIsNone(parse_stat("42 (short) S 1"))

    def test_the_real_proc_has_this_process_by_name_only(self):
        reading = read_proc()
        me = reading.processes[os.getpid()]
        self.assertTrue(me.name.startswith("python"))
        self.assertGreater(me.rss, 1)
        self.assertGreater(reading.forks, 0)
        self.assertGreater(reading.uptime, 0)
        # Kernel threads (no memory of their own) are not bodies.
        self.assertNotIn(2, reading.processes)

    def test_only_names_are_read(self):
        source = Path(orrery.__file__).read_text()
        for private in ("cmdline", "environ", "/fd", "maps"):
            self.assertNotIn(f'"{private}', source.replace("never `cmdline`", ""))


class CoreOp(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, _, host = core_fakes.fakes()

        async def spawn():
            raise OSError("no view in this test")
        self.core = Core(self.clock, scheduler, host, Path(self.temp.name), spawn=spawn, guard_types=[SessionGuard])
        self.proc = FakeProc()
        self.proc.add(10, "busy", 100, start=10)
        self.core.orrery.reader = self.proc

    async def test_the_op_reads_only_under_an_active_lease(self):
        sample = self.core.server.ops["orrery.sample"]
        self.assertEqual(sample(None), {"running": False})
        self.assertEqual(self.proc.reads, 0)
        self.core.overdrive.request("sticky")
        self.assertTrue(sample(None)["running"])
        self.assertEqual(self.proc.reads, 1)
        self.core.overdrive.release()
        self.assertEqual(sample(None), {"running": False})
        self.assertEqual(self.proc.reads, 1)

    async def test_closing_the_view_forgets(self):
        self.core.overdrive.request("sticky")
        self.core.server.ops["orrery.sample"](None)
        self.assertTrue(self.core.orrery.last)
        for callback in self.core.view.on_closed:
            callback()
        self.assertEqual(self.core.orrery.last, {})


if __name__ == "__main__":
    unittest.main()
