"""view/ui/Paper.js: handled paper (B's idea, docs/OVERDRIVE.md §41): wear, foxing, thumbing and the dog-ear."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/ui/Paper.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class PaperTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_wear_grows_with_time_spent(self):
        w = self.js('[0, 600, 10800, 86400].map(wear)')
        self.assertEqual(w[0], 0)
        self.assertTrue(w[0] < w[1] < w[2] < w[3] <= 1)
        self.assertAlmostEqual(w[2], 0.632, places=3)

    def test_foxing_is_the_rooms_own_and_grows(self):
        few, many, again, other = self.js('[spots("tasks", 800, 600, 0.2), spots("tasks", 800, 600, 0.9), spots("tasks", 800, 600, 0.2), spots("media", 800, 600, 0.2)]')
        self.assertEqual(few, again)
        self.assertEqual(many[:len(few)], few)
        self.assertGreater(len(many), len(few))
        self.assertNotEqual(few, other)
        self.assertTrue(all(0 <= s["x"] <= 800 and 0 <= s["y"] <= 600 for s in many))
        self.assertEqual(self.js('spots("tasks", 800, 600, 0)'), [])

    def test_foxing_gathers_at_the_margins(self):
        spots = self.js('spots("notifications", 1000, 1000, 1)')
        edge = sum(1 for s in spots if min(s["x"], 1000 - s["x"], s["y"], 1000 - s["y"]) < 250)
        self.assertGreater(edge, len(spots) * 0.6)

    def test_thumbing_and_the_dog_ear(self):
        self.assertEqual(self.js('thumb(0, 800, 600).alpha'), 0)
        self.assertAlmostEqual(self.js('thumb(1, 800, 600).alpha'), 0.2)
        self.assertEqual(self.js('[0, 19, 20, 40, 80, 100000].map(dogEar)'), [0, 0, 10, 18, 26, 44])


@unittest.skipUnless(shutil.which("node"), "needs Node")
class CockleTests(unittest.TestCase):
    js = PaperTests.js

    def test_the_sheet_warms_and_cools_slowly(self):
        up = self.js('heat(40, 90, 60)')
        self.assertTrue(40 < up < 70)
        self.assertEqual(self.js('heat(40, null, 60)'), 40)
        self.assertGreater(self.js('heat(80, 40, 30)'), 70)

    def test_it_cockles_from_fifty_degrees(self):
        self.assertEqual(self.js('[cockle(45), cockle(70), cockle(95)]'), [0, 0.5, 1])
        self.assertEqual(self.js('[swell(0), swell(1)]'), [0, 4])
        self.assertEqual(self.js('ripples(0, 500, 90)'), [])
        bands = self.js('ripples(1, 500, 90)')
        self.assertEqual(len(bands), 12)
        self.assertEqual([b["light"] for b in bands[:3]], [True, False, True])


if __name__ == "__main__":
    unittest.main()
