"""view/rooms/Silt.js: the swap as silt (B's idea, docs/OVERDRIVE.md §46)."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Silt.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class SiltTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_grains_and_depth(self):
        self.assertEqual(self.js('[0, 1, 16, 1000, 1e9].map(grains)'), [0, 1, 1, 6, 10])
        self.assertEqual(self.js('[depth(0, 100), depth(50, 100), depth(200, 100), depth(5, 0)]'), [0, 0.4, 0.8, 0])

    def test_a_band_a_minute_the_older_darker(self):
        got = self.js('(() => { let b = []; for (let t = 0; t < 200; t += 10) b = lay(b, t, t / 1000); return b; })()')
        self.assertEqual([x["from"] for x in got], [0, 60, 120, 180])
        self.assertAlmostEqual(got[0]["h"], 0.05)
        self.assertEqual(self.js('(() => { let b = []; for (let t = 0; t < 2000; t += 60) b = lay(b, t, 0.1); return b.length; })()'), 12)
        self.assertGreater(self.js('compaction(0, 4)'), self.js('compaction(3, 4)'))

    def test_grains_fall_to_the_bed_and_rise_out(self):
        down = self.js('[place({ x: 0.5, born: 0 }, 0, 0.3).y, place({ x: 0.5, born: 0 }, 1.0, 0.3).y, place({ x: 0.5, born: 0 }, 2, 0.3).alive]')
        self.assertEqual(down[0], 0)
        self.assertLess(down[1], 0.7 + 1e-9)
        self.assertFalse(down[2])
        up = self.js('place({ x: 0.5, born: 0, up: true }, 1.1, 0.3).y')
        self.assertLess(up, 0)


if __name__ == "__main__":
    unittest.main()
