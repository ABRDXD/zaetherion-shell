"""view/rooms/Plates.js: Performance's scheduling fault lines (atlas #15) and context-switch weave (#72)."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Plates.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class PlatesTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_one_seed_per_core_inside_the_rect(self):
        got = self.js('seeds(12, 600, 300)')
        self.assertEqual(len(got["seeds"]), 12)
        self.assertTrue(all(0 < s["x"] < 600 and 0 < s["y"] < 300 for s in got["seeds"]))
        self.assertEqual(self.js('seeds(0, 600, 300)')["seeds"], [])

    def test_equal_loads_tile_the_rect(self):
        total = self.js('(() => { const s = seeds(12, 600, 300); return cells(s.seeds, weights(new Array(12).fill(0.3), s.cell), 600, 300)'
                        '.reduce((a, p) => a + area(p), 0); })()')
        self.assertAlmostEqual(total, 600 * 300, delta=1)

    def test_a_busy_core_pushes_its_faults_out(self):
        got = self.js('(() => { const s = seeds(4, 400, 400); const loads = [0.2, 0.2, 0.2, 0.2];'
                      ' const calm = cells(s.seeds, weights(loads, s.cell), 400, 400).map(area);'
                      ' loads[2] = 1; const busy = cells(s.seeds, weights(loads, s.cell), 400, 400).map(area);'
                      ' return [calm[2], busy[2], busy.reduce((a, b) => a + b, 0), largest(cells(s.seeds, weights(loads, s.cell), 400, 400))]; })()')
        self.assertGreater(got[1], got[0] * 1.3)
        self.assertAlmostEqual(got[2], 160000, delta=1)
        self.assertEqual(got[3], 2)

    def test_no_plate_is_squeezed_out(self):
        areas = self.js('(() => { const s = seeds(12, 600, 300); const l = new Array(12).fill(0); l[5] = 1; l[6] = 1;'
                        ' return cells(s.seeds, weights(l, s.cell), 600, 300).map(area); })()')
        self.assertTrue(all(a > 0 for a in areas), areas)

    def test_stress_and_throw(self):
        self.assertEqual(self.js('[stress(1, 12), stress(13, 12), stress(40, 12), stress(5, 0)]'), [0, 1, 1, 0])
        self.assertEqual(self.js('throwOf(0.1)'), 0)
        self.assertEqual(self.js('throwOf(1)'), 6)

    def test_scarps_are_kept_a_few_seconds_apart(self):
        got = self.js('(() => { let k = []; for (let t = 0; t < 60; t++) k = scarp(k, [t], t, 4); return k.map(s => s.at); })()')
        self.assertEqual(got, [36, 40, 44, 48, 52, 56])

    def test_the_weave_opens_with_preemption(self):
        calm = self.js('weave(5000, 50)')
        contended = self.js('weave(5000, 5000)')
        self.assertEqual(calm["angleV"], 78)
        self.assertGreater(calm["angleI"], contended["angleI"])
        self.assertEqual(contended["angleI"], 0)
        self.assertGreater(calm["voluntary"], calm["involuntary"])
        self.assertEqual(self.js('weave(0, 0)'), {"voluntary": 0, "involuntary": 0, "share": 0, "angleV": 78, "angleI": 66})
        self.assertEqual(self.js('weave(1e12, 0)')["voluntary"], 28)

    def test_threads_cross_the_rect(self):
        segs = self.js('threads(10, 78, 0, 400, 200)')
        self.assertEqual(len(segs), 10)
        for x1, y1, x2, y2 in segs:
            for x, y in ((x1, y1), (x2, y2)):
                self.assertTrue(-0.01 <= x <= 400.01 and -0.01 <= y <= 200.01)
        flat = self.js('threads(4, 0, 0, 400, 200)')
        self.assertEqual(len(flat), 4)
        self.assertTrue(all(abs(s[1] - s[3]) < 1e-6 and abs(abs(s[2] - s[0]) - 400) < 1e-6 for s in flat))
        self.assertEqual(self.js('threads(0, 78, 0, 400, 200)'), [])


if __name__ == "__main__":
    unittest.main()
