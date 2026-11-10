"""view/ui/TitleType.js: the room titles under load (atlas #41–44): glyph loads, weights, the bearing, pressure,
tracking, the phase's hysteresis and front, the session's crossings and the counters found in drawn type."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/ui/TitleType.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class TitleTypeTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_band_load_is_the_covered_share(self):
        rects = '[{x: 0, y: 0, width: 50, height: 10}, {x: 0, y: 20, width: 100, height: 5}]'
        self.assertAlmostEqual(self.js(f'bandLoad({rects}, 0, 10, 100)'), 0.5)
        self.assertAlmostEqual(self.js(f'bandLoad({rects}, 30, 20, 100)'), 0.5)   # either order
        self.assertEqual(self.js(f'bandLoad({rects}, 40, 60, 100)'), 0)
        self.assertEqual(self.js('bandLoad([{x: 0, y: 0, width: 999, height: 999}], 0, 10, 100)'), 1)

    def test_heavier_and_compressed_under_load(self):
        self.assertEqual(self.js('[0, 0.1, 0.2, 0.9].map(weightFor)'), [300, 400, 500, 700])
        s = self.js('squash(1)')
        self.assertGreater(s["along"], 1)
        self.assertLess(s["across"], 1)
        self.assertEqual(self.js('squash(0)'), {"along": 1, "across": 1})

    def test_the_bearing_is_the_most_loaded_glyph(self):
        self.assertEqual(self.js('bearing([0.1, 0.4, 0.2])'), 1)
        self.assertEqual(self.js('bearing([0, 0.01, 0])'), -1)

    def test_pressure_from_overflow_and_ink(self):
        self.assertEqual(self.js('pressure(500, 1000, 0)'), 0)
        self.assertEqual(self.js('pressure(3000, 1000, 0.42)'), 1)
        self.assertAlmostEqual(self.js('pressure(2000, 1000, 0)'), 0.25)
        self.assertEqual(self.js('pressure(0, 0, 0)'), 0)

    def test_tracking_tightens_with_pressure(self):
        open_, tight = self.js('[tracking(0, 100), tracking(1, 100)]')
        self.assertEqual(open_, 8)
        self.assertEqual(tight, -4)

    def test_phase_has_hysteresis(self):
        self.assertEqual(self.js('[phase(false, 0.7), phase(false, 0.72), phase(true, 0.6), phase(true, 0.57)]'),
                         [False, True, True, False])

    def test_the_front_runs_out_from_the_bearing(self):
        self.assertEqual(self.js('[0, 1, 2, 3, 4].map(i => delay(i, 2))'), [90, 45, 0, 45, 90])
        self.assertEqual(self.js('delay(3, -1)'), 135)

    def test_crossings_are_remembered_per_room(self):
        self.assertEqual(self.js('[crossings("tasks"), cross("tasks"), cross("tasks"), cross("media"), crossings("tasks")]'),
                         [0, 1, 2, 1, 2])

    def test_places_and_length(self):
        self.assertEqual(self.js('places([10, 20, 30], 2)'), [0, 12, 34])
        self.assertEqual(self.js('length([10, 20, 30], 2)'), 64)

    def test_counters_are_the_enclosed_holes(self):
        # An "O": a 9 × 9 ring with a 3 × 3 hole, beside a "C" whose hole opens to the outside, in a 22 × 11 field.
        script = '''(() => {
            const w = 22, h = 11, a = new Array(w * h).fill(0);
            const ink = (x, y) => { a[y * w + x] = 255; };
            for (let y = 1; y < 10; y++) for (let x = 1; x < 10; x++)
                if (!(x >= 4 && x <= 6 && y >= 4 && y <= 6)) ink(x, y);
            for (let y = 1; y < 10; y++) for (let x = 12; x < 21; x++)
                if (!(x >= 15 && y >= 4 && y <= 6)) ink(x, y);
            a[0] = 0;
            const inside = counters(a, w, h, 4);
            return [Array.from(inside).reduce((s, v) => s + v, 0), count(inside, w, h), inside[5 * w + 5], inside[5 * w + 17]];
        })()'''
        self.assertEqual(self.js(script), [9, 1, 1, 0])

    def test_specks_are_not_counters(self):
        script = '''(() => {
            const w = 5, h = 5, a = new Array(25).fill(255);
            for (let y = 0; y < 5; y++) { a[y * 5] = 0; a[y * 5 + 4] = 0; }
            a[12] = 0;
            return count(counters(a, w, h, 2), w, h);
        })()'''
        self.assertEqual(self.js(script), 0)


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class TitleInTheRoom(unittest.TestCase):
    """The title under load on the real RoomSheet (tools/cuetest/TitleTest.qml), offscreen."""

    def test_load_kerning_phase_and_release(self):
        import sys
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("TitleTest.qml", timeout=180)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("title.silent", "title.load", "title.kerning", "title.phase", "title.front", "title.hysteresis",
                     "title.editorial", "title.release", "title.mask", "sheet.wear", "sheet.sundial", "sheet.cockle"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertIn("CUE_ACTIVE 0 []", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
