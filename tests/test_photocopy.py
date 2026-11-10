"""view/rooms/Photocopy.js: photocopy generations in Clips (B's idea, docs/OVERDRIVE.md §49)."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Photocopy.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class PhotocopyTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_older_is_a_later_generation(self):
        self.assertEqual(self.js('[-1, 0, 3, 40].map(generation)'), [0, 0, 3, 12])
        inks = self.js('[0, 1, 6, 12].map(ink)')
        self.assertEqual(inks[0], 1)
        self.assertEqual(inks[3], 0.62)
        self.assertTrue(inks[0] > inks[1] > inks[2] > inks[3])

    def test_the_slip_and_the_speckle(self):
        self.assertEqual(self.js('slip(0)'), {"x": 0, "y": 0, "alpha": 0})
        self.assertGreater(self.js('slip(12).x'), self.js('slip(2).x'))
        a, b, c = self.js('[speckle(41, 3, 300, 40), speckle(41, 3, 300, 40), speckle(42, 3, 300, 40)]')
        self.assertEqual(a, b)
        self.assertNotEqual(a, c)
        self.assertEqual(len(a), 18)
        self.assertTrue(all(0 <= p["x"] <= 300 and 0 <= p["y"] <= 40 for p in a))
        self.assertEqual(self.js('speckle(41, 0, 300, 40)'), [])


if __name__ == "__main__":
    unittest.main()
