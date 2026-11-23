"""view/rooms/DayTime.js: Home's day ruler (atlas #65 day-length compression, #63 the sidereal margin, W4 misregistration).

Run under Node with the QML `.pragma` line stripped; every hour is passed in."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/DayTime.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class DayRulerTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_the_day_takes_the_same_share_whatever_its_length(self):
        for rise, set_ in ((6.75, 17.25), (4.5, 21.5), (7.9, 16.1)):
            a, b = self.js(f"[x({rise}, {rise}, {set_}), x({set_}, {rise}, {set_})]")
            self.assertAlmostEqual(b - a, 0.6, places=9)
        self.assertEqual(self.js("[x(0, 6, 18), x(24, 6, 18)]"), [0, 1])

    def test_winter_hours_are_wide_and_summer_hours_packed(self):
        winter = self.js("x(13, 8, 16) - x(12, 8, 16)")     # an 8-hour day
        summer = self.js("x(13, 4, 22) - x(12, 4, 22)")     # an 18-hour day
        self.assertAlmostEqual(winter, 0.6 / 8)
        self.assertAlmostEqual(summer, 0.6 / 18)
        self.assertGreater(winter, 2 * summer)

    def test_it_is_monotonic_and_linear_without_a_sun(self):
        xs = self.js("Array.from({length: 97}, (_, i) => x(i / 4, 6.5, 18.2))")
        self.assertTrue(all(b > a for a, b in zip(xs, xs[1:])))
        self.assertEqual(self.js("[x(6, NaN, NaN), x(12, -1, 30)]"), [0.25, 0.5])

    def test_ticks_label_civil_hours_every_six(self):
        ticks = self.js("ticks(6.5, 18.2)")
        self.assertEqual(len(ticks), 25)
        self.assertEqual([t["label"] for t in ticks if t["label"]], ["00", "06", "12", "18"])

    def test_sidereal_ticks_are_a_sidereal_hour_apart_and_one_reads_now(self):
        ticks = self.js("siderealTicks(10, 3.5, 6.5, 18.2)")
        self.assertEqual(sorted(t["k"] for t in ticks), list(range(24)))
        spacing = sorted(t["h"] for t in ticks)
        gaps = [b - a for a, b in zip(spacing, spacing[1:])]
        # A sidereal hour apart, but for one seam where today's ruler folds: a sidereal day is four minutes short of a
        # civil one, so the seam is a sidereal hour and those four minutes.
        regular = [g for g in gaps if abs(g - 0.99727) < 1e-3]
        seam = [g for g in gaps if abs(g - 0.99727) >= 1e-3]
        self.assertEqual(len(regular), 22)
        self.assertEqual(len(seam), 1)
        self.assertAlmostEqual(seam[0], 24 - 23 * 0.9972695663, places=6)
        k4 = next(t for t in ticks if t["k"] == 4)
        self.assertAlmostEqual(k4["h"], 10 + 0.5 / 1.0027379, places=6)   # LST 3.5 → 4 in half a sidereal hour

    def test_the_moment_in_three_frames(self):
        frames = self.js("frames(14.0, 20.25, 6.0, 18.5)")
        self.assertEqual([f["frame"] for f in frames], ["CIVIL", "SOLAR", "SIDEREAL"])
        self.assertEqual(frames[0]["h"], 14.0)
        self.assertAlmostEqual(frames[1]["h"], 13.75)          # solar noon at 12:15
        self.assertEqual(frames[2]["h"], 20.25)
        self.assertEqual(self.js("solar(9, NaN, NaN)"), 9)
        self.assertEqual(self.js('[hhmm(7.7), hhmm(23.999), hhmm(-0.5)]'), ["07:42", "00:00", "23:30"])


    def test_recurrence_windows_show_habits_only(self):
        day = [0.1] * 24
        tasks = day[:9] + [1.0, 0.8] + day[11:]
        timers = day[:21] + [0.9] + day[22:]
        journey = {"hours": {"tasks": tasks, "timers": timers, "media": [1.0] * 24, "nowhere": [1.0] * 24},
                   "visits": {"tasks": 12, "timers": 7, "media": 3, "nowhere": 50}}
        got = self.js(f"recurrence({json.dumps(journey)})")
        self.assertEqual(got, [{"room": "tasks", "number": "05", "h": 9}, {"room": "timers", "number": "06", "h": 21},
                               {"room": "tasks", "number": "05", "h": 10}])
        self.assertEqual(self.js("recurrence(null)"), [])
        busy = {"hours": {"tasks": [1.0] * 24}, "visits": {"tasks": 99}}
        self.assertEqual(len(self.js(f"recurrence({json.dumps(busy)})")), 6)

@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class HomeRuler(unittest.TestCase):
    """The ruler under Home's clock (tools/cuetest/HomeTest.qml)."""

    def test_the_ruler_in_silent_overdrive_and_three_frames(self):
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("HomeTest.qml", timeout=120)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("ruler.silent", "ruler.overdrive", "ruler.misregistered", "ruler.recurrence", "ruler.release"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertIn("CUE_ACTIVE 0 []", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Cannot assign") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
