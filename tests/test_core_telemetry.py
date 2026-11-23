"""core/telemetry.py: the live counters behind interrupt rainfall (atlas #17) and the network letterpress (#73)."""
from pathlib import Path
import tempfile
import unittest

import core_fakes
from core.app import Core
from core.guards import SessionGuard
from core.telemetry import Telemetry, kind_of, read_disks, read_gpus, read_interrupts, read_swap, read_thermal, read_net, read_stat, read_switches

HEAD = "            CPU0       CPU1\n"


class FakeProc:
    def __init__(self, root: Path):
        self.root = root
        (root / "net").mkdir(parents=True)
        self.irq = {"0": ["IR-IO-APIC", "2-edge", "timer"], "69": ["amdgpu"], "82": ["rtw89_pci"], "120": ["nvme0q1"],
                    "LOC": ["Local", "timer", "interrupts"], "CAL": ["Function", "call", "interrupts"], "9": ["acpi"]}
        self.counts = {k: 100 for k in self.irq}
        self.rx = self.tx = 1000
        self.write()

    def add(self, line, n):
        self.counts[line] += n

    def write(self):
        rows = [HEAD] + [f"{k:>4}: {self.counts[k] // 2:>10} {self.counts[k] - self.counts[k] // 2:>10}  {' '.join(v)}\n" for k, v in self.irq.items()]
        rows.append(" ERR:          0\n")
        (self.root / "interrupts").write_text("".join(rows))
        (self.root / "net/dev").write_text("Inter-| Receive\n face |bytes\n    lo: 5000 1 0 0 0 0 0 0 5000 1 0 0 0 0 0 0\n"
                                           f" wlan0: {self.rx} 1 0 0 0 0 0 0 {self.tx} 1 0 0 0 0 0 0\n")


class TelemetryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.proc = FakeProc(Path(self.tmp.name))
        self.clock = core_fakes.FakeClock()
        self.on = True
        self.t = Telemetry(self.clock, active=lambda: self.on, proc=Path(self.tmp.name))

    def tearDown(self):
        self.tmp.cleanup()

    def tick(self, seconds=1.0, **adds):
        for line, n in adds.items():
            self.proc.add(line, n)
        self.proc.write()
        self.clock.advance(seconds)
        return self.t.sample()

    def test_kinds_and_reading(self):
        self.assertEqual([kind_of(n) for n in ("amdgpu", "rtw89_pci", "nvme0q1", "Local timer interrupts", "Function call interrupts", "acpi", "i8042")],
                         ["gpu", "net", "disk", "timer", "ipi", "other", "input"])
        self.assertEqual(read_interrupts(self.proc.root), {"timer": 200, "gpu": 100, "net": 100, "disk": 100, "ipi": 100, "other": 100})
        self.assertEqual(read_net(self.proc.root), (1000, 1000))

    def test_rates_since_the_last_sample(self):
        self.assertEqual(self.t.sample()["rain"], [])   # the first sample only reads
        self.proc.rx += 4000
        got = self.tick(2.0, **{"69": 600, "LOC": 2000})
        rain = {r["kind"]: r["rate"] for r in got["rain"]}
        self.assertEqual((rain["gpu"], rain["timer"], rain["net"]), (300, 1000, 0))
        self.assertEqual(got["net"], {"rx": 2000, "tx": 0})
        self.assertEqual(got["total"], 1300)

    def test_a_spike_is_three_times_a_class_own_average(self):
        self.t.sample()
        for _ in range(5):
            self.tick(**{"82": 100})
        quiet = self.tick(**{"82": 120})
        burst = self.tick(**{"82": 900})
        self.assertEqual((quiet["spikes"], burst["spikes"]), ([], ["net"]))
        small = self.tick(**{"120": 30})   # under the floor, never a spike
        self.assertNotIn("disk", small["spikes"])

    def test_nothing_is_read_outside_overdrive_and_gaps_start_over(self):
        self.on = False
        self.assertEqual(self.t.sample(), {"running": False})
        self.on = True
        self.t.sample()
        got = self.tick(10.0, **{"69": 50000})
        self.assertEqual(got["rain"], [])   # after a gap, it starts over rather than average across it


class SchedTests(unittest.TestCase):
    """The scheduler's reading behind Performance's plates and weave (atlas #15, #72)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.clock = core_fakes.FakeClock()
        self.on = True
        self.t = Telemetry(self.clock, active=lambda: self.on, proc=self.root)
        # Two cores: (user, nice, system, idle, iowait, irq, softirq, steal) jiffies.
        self.cores = [[100, 0, 0, 900, 0, 0, 0, 0], [500, 0, 0, 500, 0, 0, 0, 0]]
        self.ctxt, self.runnable = 1000, 3
        self.pids = {11: [100, 10], 12: [50, 5]}
        self.write()

    def tearDown(self):
        self.tmp.cleanup()

    def write(self):
        rows = ["cpu  0 0 0 0 0 0 0 0 0 0"] + [f"cpu{i} " + " ".join(map(str, c)) + " 0 0" for i, c in enumerate(self.cores)]
        rows += [f"ctxt {self.ctxt}", "btime 1", f"procs_running {self.runnable}", "procs_blocked 1"]
        (self.root / "stat").write_text("\n".join(rows) + "\n")
        for d in self.root.iterdir():
            if d.name.isdigit() and int(d.name) not in self.pids:
                (d / "status").unlink()
                d.rmdir()
        for pid, (v, n) in self.pids.items():
            (self.root / str(pid)).mkdir(exist_ok=True)
            (self.root / str(pid) / "status").write_text(f"Name:\tx\nvoluntary_ctxt_switches:\t{v}\nnonvoluntary_ctxt_switches:\t{n}\n")

    def test_reading_the_files(self):
        stat = read_stat(self.root)
        self.assertEqual(stat["cores"], [(100, 1000), (500, 1000)])
        self.assertEqual((stat["ctxt"], stat["runnable"], stat["blocked"]), (1000, 3, 1))
        self.assertEqual(read_switches(self.root), {11: (100, 10), 12: (50, 5)})

    def test_core_shares_and_switch_rates(self):
        self.assertEqual(self.t.sched()["cores"], [])   # the first reading only reads
        self.cores[0][0] += 50; self.cores[0][3] += 50     # core 0 half busy
        self.cores[1][0] += 100                           # core 1 fully busy
        self.ctxt += 4000
        self.pids[11][0] += 300; self.pids[11][1] += 40
        self.write()
        self.clock.advance(2.0)
        got = self.t.sched()
        self.assertEqual(got["cores"], [0.5, 1.0])
        self.assertEqual((got["ctxt"], got["voluntary"], got["involuntary"], got["runnable"]), (2000, 150, 20, 3))

    def test_processes_starting_or_ending_dont_count(self):
        self.t.sched()
        del self.pids[12]
        self.pids[13] = [99999, 99999]
        self.write()
        self.clock.advance(1.0)
        got = self.t.sched()
        self.assertEqual((got["voluntary"], got["involuntary"]), (0, 0))

    def test_nothing_outside_overdrive_and_forgotten(self):
        self.on = False
        self.assertEqual(self.t.sched(), {"running": False})
        self.on = True
        self.t.sched()
        self.assertTrue(self.t.sched_last)
        self.t.forget()
        self.assertEqual(self.t.sched_last, {})


class DiskTests(unittest.TestCase):
    """The disks behind Performance's tide (docs/OVERDRIVE.md §44): physical disks only."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.block = self.root / "block"
        for name, physical in (("nvme0n1", True), ("nvme0n1p1", False), ("zram0", False), ("dm-0", False)):
            (self.block / name).mkdir(parents=True)
            if physical:
                (self.block / name / "device").mkdir()
        self.clock = core_fakes.FakeClock()
        self.on = True
        self.t = Telemetry(self.clock, active=lambda: self.on, proc=self.root, sys_block=self.block)
        self.stats = {"nvme0n1": [1000, 2000, 100], "nvme0n1p1": [500, 500, 50], "zram0": [9999, 9999, 9999], "dm-0": [7, 7, 7]}
        self.write()

    def tearDown(self):
        self.tmp.cleanup()

    def write(self):
        rows = [f" 259 0 {n} 1 0 {r} 0 1 0 {w} 0 0 {ms} 0 0 0 0 0 0" for n, (r, w, ms) in self.stats.items()]
        (self.root / "diskstats").write_text("\n".join(rows) + "\n")

    def test_physical_disks_only(self):
        self.assertEqual(read_disks(self.root, self.block), {"nvme0n1": (1000, 2000, 100)})

    def test_bytes_and_busy_a_second(self):
        self.assertEqual(self.t.disk(), {"running": True, "read": 0, "written": 0, "busy": 0.0})
        self.stats["nvme0n1"] = [1000 + 4096, 2000 + 2048, 100 + 500]
        self.stats["zram0"] = [99999, 99999, 99999]
        self.write()
        self.clock.advance(2.0)
        self.assertEqual(self.t.disk(), {"running": True, "read": 4096 * 512 // 2, "written": 2048 * 512 // 2, "busy": 0.25})

    def test_nothing_outside_overdrive(self):
        self.on = False
        self.assertEqual(self.t.disk(), {"running": False})


class GpuTests(unittest.TestCase):
    """The cards behind Performance's chart recorder (docs/OVERDRIVE.md §45): a sleeping card is only asked if it sleeps."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.drm = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def card(self, name, files):
        d = self.drm / name / "device"
        (d / "power").mkdir(parents=True)
        for k, v in files.items():
            (d / k).write_text(v)

    def test_an_awake_amd_card_and_a_sleeping_nvidia_one(self):
        self.card("card0", {"vendor": "0x10de\n", "power/runtime_status": "suspended\n", "gpu_busy_percent": "99\n"})
        self.card("card1", {"vendor": "0x1002\n", "power/runtime_status": "active\n", "gpu_busy_percent": "37\n",
                            "pp_dpm_sclk": "0: 800Mhz \n1: 1100Mhz *\n2: 2700Mhz \n", "mem_info_vram_used": "100\n", "mem_info_vram_total": "400\n"})
        (self.drm / "card1-eDP-1").mkdir()
        self.assertEqual(read_gpus(self.drm), [
            {"card": "card0", "vendor": "NVIDIA", "awake": False},
            {"card": "card1", "vendor": "AMD", "awake": True, "busy": 0.37, "levels": [800, 1100, 2700], "level": 1, "vram": 100, "total": 400}])

    def test_the_op_reads_only_in_overdrive(self):
        on = [False]
        t = Telemetry(core_fakes.FakeClock(), active=lambda: on[0], drm=self.drm)
        self.assertEqual(t.gpu(), {"running": False})
        on[0] = True
        self.assertEqual(t.gpu(), {"running": True, "gpus": []})


class SwapTests(unittest.TestCase):
    """The swap behind Performance's silt (docs/OVERDRIVE.md §46)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.clock = core_fakes.FakeClock()
        self.t = Telemetry(self.clock, active=lambda: True, proc=self.root)
        self.write(100, 1000, 8192, 6144)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, pin, pout, total_kb, free_kb):
        (self.root / "vmstat").write_text(f"nr_free_pages 5\npswpin {pin}\npswpout {pout}\n")
        (self.root / "meminfo").write_text(f"MemTotal: 1 kB\nSwapTotal: {total_kb} kB\nSwapFree: {free_kb} kB\n")

    def test_reading_and_rates(self):
        self.assertEqual(read_swap(self.root), {"in": 100, "out": 1000, "used": 2048 * 1024, "total": 8192 * 1024})
        self.assertEqual(self.t.swap()["out"], 0)
        self.write(110, 1400, 8192, 4096)
        self.clock.advance(2.0)
        got = self.t.swap()
        self.assertEqual((got["in"], got["out"], got["used"]), (5, 200, 4096 * 1024))


class ThermalTests(unittest.TestCase):
    """The processor's temperature behind the cockled sheet (docs/OVERDRIVE.md §47)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def sensor(self, n, name, milli):
        d = self.root / f"hwmon{n}"
        d.mkdir()
        (d / "name").write_text(name + "\n")
        if milli is not None:
            (d / "temp1_input").write_text(f"{milli}\n")

    def test_the_processor_first_never_a_card(self):
        self.sensor(0, "acpitz", 51000)
        self.sensor(1, "amdgpu", 90000)
        self.sensor(2, "nvidia", 95000)
        self.sensor(3, "k10temp", 63500)
        self.sensor(4, "BAT0", None)
        self.assertEqual(read_thermal(self.root), {"temp": 63.5, "sensor": "k10temp"})

    def test_acpi_when_there_is_no_processor_sensor(self):
        self.sensor(0, "acpitz", 47000)
        self.assertEqual(read_thermal(self.root), {"temp": 47.0, "sensor": "acpitz"})
        self.assertEqual(read_thermal(self.root / "absent"), {"temp": None, "sensor": ""})


class CoreTelemetry(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, _, host = core_fakes.fakes()

        async def spawn():
            raise OSError("no view in this test")
        self.core = Core(self.clock, scheduler, host, Path(self.temp.name), spawn=spawn, guard_types=[SessionGuard])

    async def test_the_op_reads_only_under_an_active_lease_and_forgets_on_close(self):
        sample = self.core.server.ops["telemetry.sample"]
        self.assertEqual(sample(None), {"running": False})
        self.core.overdrive.request("sticky")
        self.assertTrue(sample(None)["running"])
        self.assertTrue(self.core.telemetry.last)
        for callback in self.core.view.on_closed:
            callback()
        self.assertEqual(self.core.telemetry.last, {})

    async def test_the_disk_op_reads_only_under_an_active_lease(self):
        disk = self.core.server.ops["telemetry.disk"]
        self.assertEqual(disk(None), {"running": False})
        self.core.overdrive.request("sticky")
        self.assertTrue(disk(None)["running"])

    async def test_the_sched_op_reads_only_under_an_active_lease(self):
        sched = self.core.server.ops["telemetry.sched"]
        self.assertEqual(sched(None), {"running": False})
        self.core.overdrive.request("sticky")
        got = sched(None)
        self.assertTrue(got["running"])
        self.assertIn("runnable", got)


if __name__ == "__main__":
    unittest.main()
