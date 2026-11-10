"""view/overdrive/MatchCut.js and MatchCut.qml: the archive match cut (atlas #40, docs/OVERDRIVE.md §51)."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/overdrive/MatchCut.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class MatchCutRules(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_a_room_number_by_its_value(self):
        self.assertEqual(self.js('find("FIELD NOTE / 005", "05")'), {"at": 13, "length": 3})
        self.assertEqual(self.js('find("DAY 5 OF THE SURVEY", "05")'), {"at": 4, "length": 1})
        self.assertEqual(self.js('find("FIELD NOTE / 000", "00")'), {"at": 13, "length": 3})
        # Other numbers holding the digits aren't the room's.
        self.assertIsNone(self.js('find("ROOM 105 · 50 · 2026", "05")'))
        # The first run of the value wins.
        self.assertEqual(self.js('find("2 OF 05 · 5", "05")'), {"at": 5, "length": 2})
        self.assertIsNone(self.js('find(null, "05")'))
        self.assertIsNone(self.js('find("05", "x")'))

    def test_hold_glide_land(self):
        g = self.js('[0, 0.1, 0.2, 0.51, 0.82, 1].map(glide)')
        self.assertEqual(g[:3], [0, 0, 0])
        self.assertAlmostEqual(g[3], 0.5, places=2)
        self.assertEqual(g[4:], [1, 1])
        for got, want in zip(self.js('[0.5, 0.82, 0.91, 1].map(fade)'), [1, 1, 0.5, 0]):
            self.assertAlmostEqual(got, want)

    def test_the_box_and_the_type(self):
        a, b = '{x: 0, y: 0, w: 10, h: 10, size: 10}', '{x: 100, y: 50, w: 30, h: 40, size: 40}'
        start = self.js(f'box({a}, {b}, 0)')
        self.assertEqual({k: v for k, v in start.items() if k != "size"}, {"x": 0, "y": 0, "w": 10, "h": 10})
        self.assertAlmostEqual(start["size"], 10)
        mid = self.js(f'box({a}, {b}, 0.5)')
        self.assertEqual((mid["x"], mid["y"]), (50, 25))
        self.assertAlmostEqual(mid["size"], 20)  # geometric, as a camera's scale
        self.assertEqual(self.js('trail(0.2, 3, 0.05)'), [0, 0, 0])
        t = self.js('trail(0.6, 3, 0.05)')
        self.assertTrue(t[0] > t[1] > t[2] > 0)


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class MatchCutOnTheArchive(unittest.TestCase):
    """The real FArchive over a real RoomSheet (tools/cuetest/MatchCutTest.qml), offscreen."""

    def test_pivot_hold_land_release(self):
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("MatchCutTest.qml", timeout=120)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("match.found", "match.absent", "match.hold", "match.landed", "match.release"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
