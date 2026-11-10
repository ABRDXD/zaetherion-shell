"""core/weather.py: the machine's weather since you last looked (atlas #75). Counters only, no timer, a report per
ten minutes at most, nothing across a reboot."""
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

import core_fakes
from core import weather
from core.app import Core
from core.guards import SessionGuard
from core.weather import SPAN_MIN, TICKS, Weather, read_counters, report

CPUS = 4


class FakeKernel:
    """A /proc and /sys tree whose counters the test advances."""

    def __init__(self, root: Path):
        self.proc, self.sys = root / "proc", root / "sys"
        (self.proc / "net").mkdir(parents=True)
        self.c = {"user": 1000, "idle": 9000, "ctxt": 1_000_000, "forks": 5000, "majfault": 100, "swap": 0, "net": 10_000}
        self.temp = 48.0
        self.battery, self.status = 80, "Discharging"
        for i, kind in enumerate(("acpitz", "x86_pkg_temp", "bogus")):
            (self.sys / f"class/thermal/thermal_zone{i}").mkdir(parents=True)
            (self.sys / f"class/thermal/thermal_zone{i}/type").write_text(kind)
        (self.sys / "class/power_supply/BAT0").mkdir(parents=True)
        self.write()

    def run(self, seconds, busy=0.1, wakes=10_000, faults=0.0, swap=0, net=1000):
        """`seconds` of the machine awake on CPUS cores at `busy` (share of all cores)."""
        ticks = seconds * TICKS * CPUS
        self.c["user"] += round(ticks * busy)
        self.c["idle"] += round(ticks * (1 - busy))
        self.c["ctxt"] += round(wakes * seconds)
        self.c["majfault"] += round(faults * seconds)
        self.c["swap"] += round(swap * seconds)
        self.c["net"] += round(net * seconds)
        self.write()

    def write(self):
        c = self.c
        (self.proc / "stat").write_text(f"cpu  {c['user']} 0 0 {c['idle']} 0 0 0 0 0 0\ncpu0 1 2 3 4 5 6 7 8\nintr 5 1 2\n"
                                        f"ctxt {c['ctxt']}\nbtime 1\nprocesses {c['forks']}\n")
        (self.proc / "vmstat").write_text(f"nr_free_pages 1\npgmajfault {c['majfault']}\npswpin {c['swap']}\npswpout 0\n")
        (self.proc / "net/dev").write_text("Inter-|   Receive\n face |bytes\n"
                                           "    lo: 999999 1 0 0 0 0 0 0 999999 1 0 0 0 0 0 0\n"
                                           f"  wlan0: {c['net']} 1 0 0 0 0 0 0 0 1 0 0 0 0 0 0\n")
        zones = sorted((self.sys / "class/thermal").glob("thermal_zone*"))
        (zones[0] / "temp").write_text(str(int(self.temp * 1000)))
        (zones[1] / "temp").write_text(str(int((self.temp - 6) * 1000)))
        (zones[2] / "temp").write_text("-273000")  # a broken sensor is ignored
        (self.sys / "class/power_supply/BAT0/capacity").write_text(f"{self.battery}\n")
        (self.sys / "class/power_supply/BAT0/status").write_text(self.status + "\n")


class WeatherTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.kernel = FakeKernel(root)
        self.state = root / "state"
        self.state.mkdir()
        self.clock = core_fakes.FakeClock()
        self.weather = self.make()

    def tearDown(self):
        self.tmp.cleanup()

    def make(self):
        return Weather(self.clock, self.state, proc=self.kernel.proc, sys=self.kernel.sys, cpus=CPUS)

    def wait(self, seconds, **load):
        self.clock.advance(seconds)
        self.kernel.run(seconds, **load)

    def test_counters_are_read_from_the_kernel_files_only(self):
        got = read_counters(self.kernel.proc, self.kernel.sys)
        self.assertEqual(got["ctxt"], 1_000_000)
        self.assertEqual(got["net"], 10_000)  # loopback left out
        self.assertEqual(got["temp"], 48.0)   # the hottest sane zone
        self.assertEqual((got["battery"], got["charging"]), (80, False))
        self.assertEqual(read_counters(Path("/nonexistent"), Path("/nonexistent")), {})

    def test_the_first_look_only_takes_a_reading(self):
        self.assertFalse(self.weather.observe())
        self.assertIsNone(self.weather.now()["latest"])
        self.assertTrue((self.state / "weather.json").exists())

    def test_a_report_once_ten_minutes_have_passed(self):
        self.weather.observe()
        self.wait(SPAN_MIN - 1, busy=0.05)
        self.assertFalse(self.weather.observe())
        self.wait(2, busy=0.05)
        self.assertTrue(self.weather.observe())
        latest = self.weather.now()["latest"]
        self.assertEqual(latest["span"], SPAN_MIN + 1)
        self.assertEqual(latest["sentence"], "fair, steady pressure / light airs / dry")
        self.assertEqual(latest["values"]["hpa"], 1036)
        # Straight after, nothing new: the next report is ten minutes on.
        self.wait(30)
        self.assertFalse(self.weather.observe())
        self.assertEqual(self.weather.now()["count"], 1)

    def test_storms_wind_and_rain_follow_the_counters(self):
        self.weather.observe()
        self.wait(1200, busy=0.8, wakes=90_000, faults=20)
        self.weather.observe()
        latest = self.weather.now()["latest"]
        self.assertEqual(latest["categories"], {"pressure": "a deep low", "wind": "a gale", "rain": "heavy rain"})
        self.assertEqual(latest["values"]["hpa"], 976)
        self.wait(1200, busy=0.3, wakes=20_000, swap=5)
        self.weather.observe()
        self.assertEqual(self.weather.now()["latest"]["sentence"], "low pressure, unsettled / a steady breeze / a downpour")

    def test_temperature_current_and_tide_make_the_second_line(self):
        self.weather.observe()
        self.kernel.temp, self.kernel.battery = 66.0, 76
        self.wait(1800, net=500_000)
        self.weather.observe()
        latest = self.weather.now()["latest"]
        self.assertEqual(latest["detail"], "warm and warming, a strong current, an ebbing tide")
        self.assertEqual(latest["values"]["drain"], 8.0)
        self.kernel.battery = 66
        self.wait(1800)
        self.weather.observe()
        self.assertTrue(self.weather.now()["latest"]["detail"].endswith("the tide going out fast"))
        self.kernel.status = "Charging"
        self.wait(1800)
        self.weather.observe()
        self.assertEqual(self.weather.now()["latest"]["detail"], "warm, still water, a rising tide")

    def test_rates_count_only_the_time_the_machine_was_awake(self):
        self.weather.observe()
        self.kernel.run(600, wakes=10_000)   # ten minutes awake…
        self.clock.advance(7200)              # …inside two hours of wall time (a suspend)
        self.weather.observe()
        self.assertEqual(self.weather.now()["latest"]["values"]["wakes"], 10_000)

    def test_a_reboot_starts_over_without_a_report(self):
        self.weather.observe()
        self.clock.reboot(3600)
        self.kernel.c.update(user=0, idle=10, ctxt=5)
        self.kernel.write()
        self.assertFalse(self.weather.observe())
        self.assertEqual(self.weather.now()["count"], 0)

    def test_reports_survive_a_restart_and_are_capped(self):
        self.weather.observe()
        for _ in range(weather.KEEP + 3):
            self.wait(SPAN_MIN)
            self.weather.observe()
        again = self.make()
        self.assertEqual(again.now()["count"], weather.KEEP)
        self.assertEqual(len(again.now()["barograph"]), 24)
        strata, ledger = again.now()["strata"], again.now()["ledger"]
        self.assertEqual((len(strata), len(ledger)), (24, 24))
        self.assertEqual(set(strata[-1]), {"at", "span", "temp"})
        self.assertEqual(set(ledger[-1]), {"at", "span", "battery", "drain"})
        self.assertEqual(strata[-1]["temp"], 48.0)
        saved = json.loads((self.state / "weather.json").read_text())
        text = json.dumps(saved)
        for forbidden in ("wlan0", "acpitz", "BAT0"):
            self.assertNotIn(forbidden, text)

    def test_junk_on_disk_starts_empty(self):
        (self.state / "weather.json").write_text("{not json")
        self.assertEqual(self.make().now()["count"], 0)
        (self.state / "weather.json").write_text(json.dumps({"reports": [5, {"sentence": 3}, {"sentence": "ok"}], "reading": []}))
        again = self.make()
        self.assertEqual(again.now()["count"], 1)
        self.assertIsNone(again.reading)

    def test_report_refuses_what_it_cannot_compare(self):
        self.assertIsNone(report({}, {}, 600, 4))
        self.assertIsNone(report({"cpuTotal": 10, "cpuIdle": 5}, {"cpuTotal": 10, "cpuIdle": 5}, 600, 4))


class CoreWeather(unittest.IsolatedAsyncioTestCase):
    """The core observes once per opening of the view, and serves the report on `weather.now`."""

    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, _, host = core_fakes.fakes()

        async def spawn():
            raise OSError("no view in this test")
        root = Path(self.temp.name)
        self.core = Core(self.clock, scheduler, host, root / "state", spawn=spawn, guard_types=[SessionGuard])
        self.kernel = FakeKernel(root)
        self.core.weather.proc, self.core.weather.sys, self.core.weather.cpus = self.kernel.proc, self.kernel.sys, CPUS
        self.peer = object()
        self.core.view.client = self.peer

    async def test_observed_on_each_opening_only(self):
        observed = []
        real = self.core.weather.observe
        self.core.weather.observe = lambda: observed.append(1) or real()
        self.core.view_state(self.peer, True, "home")
        self.core.view_state(self.peer, True, "tasks")   # still open: a room change is not an opening
        self.assertEqual(len(observed), 1)
        self.core.view_state(self.peer, False, "tasks")
        self.clock.advance(SPAN_MIN + 5)
        self.kernel.run(SPAN_MIN + 5, busy=0.02)
        self.core.view_state(self.peer, True, "home")
        self.assertEqual(len(observed), 2)
        now = self.core.server.ops["weather.now"](None)
        self.assertEqual(now["count"], 1)
        self.assertEqual(now["latest"]["categories"]["pressure"], "high pressure, settled")


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class ViewWeather(unittest.TestCase):
    """Performance's header shows it (tools/cuetest/PerformanceTest.qml, with the palimpsest's checks)."""

    def test_the_header_reads_the_latest_report(self):
        sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
        import cuetest
        output = cuetest.run("PerformanceTest.qml", timeout=120)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("weather.header", "weather.barograph", "weather.detail", "palimpsest.kept", "palimpsest.clears", "palimpsest.release", "voice.kernel", "strata.layers", "rain.drops"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertIn("CUE_ACTIVE 0 []", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Cannot assign") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
