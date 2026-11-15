"""view/fluid/PerformanceStarLayout.js: temperature to heat and colour words, tilted orbits."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def run(expr):
    body = "\n".join(l for l in (ROOT / "view/fluid/PerformanceStarLayout.js").read_text().splitlines() if not l.startswith(".pragma"))
    return json.loads(subprocess.run(["node", "-e", body + f"\nprocess.stdout.write(JSON.stringify({expr}));"],
                                     capture_output=True, text=True, check=True).stdout)


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Star(unittest.TestCase):
    def test_heat_runs_cool_to_hot_and_clamps(self):
        self.assertEqual(run("[heat(40), heat(92), heat(10), heat(200)]"), [0, 1, 0, 1])
        self.assertIsNone(run("heat(null)"))
        self.assertLess(run("heat(55)"), run("heat(75)"))

    def test_colour_words_follow_the_spectral_classes(self):
        self.assertEqual(run("[colourName(0.1), colourName(0.5), colourName(0.95), colourName(null)]"), ["orange", "white", "blue", ""])

    def test_orbits_lean_the_language_way(self):
        p = run("onOrbit(100, 50, 0)")
        self.assertAlmostEqual(p["x"], 97.81, places=1)
        self.assertLess(p["y"], 0)   # tilted −12°: the right side rises


if __name__ == "__main__":
    unittest.main()
