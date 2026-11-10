"""view/rooms/Harmonic.js: the harmonic typesetter (atlas #13): bands, the envelope, the set, section changes."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Harmonic.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class HarmonicTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_bands_split_the_energy(self):
        bass = self.js('bands(Array.from({length: 56}, (_, i) => i < 9 ? 1 : 0))')
        self.assertEqual((bass["low"], bass["high"]), (1, 0))
        self.assertLess(bass["centroid"], 0.1)
        bright = self.js('bands(Array.from({length: 56}, (_, i) => i > 40 ? 1 : 0))')
        self.assertEqual(bright["high"], 1)
        self.assertGreater(bright["centroid"], 0.8)
        self.assertEqual(self.js('bands([])')["energy"], 0)
        self.assertEqual(self.js('bands(new Array(56).fill(0))')["centroid"], 0)

    def test_the_envelope_is_slow(self):
        got = self.js('[ease(null, {low: 1, mid: 0, high: 0, energy: 1, centroid: 0}, 1).low,'
                      ' ease({low: 0, mid: 0, high: 0, energy: 0, centroid: 0}, {low: 1, mid: 0, high: 0, energy: 1, centroid: 0}, 1).low,'
                      ' ease({low: 0, mid: 0, high: 0, energy: 0, centroid: 0}, {low: 1, mid: 0, high: 0, energy: 1, centroid: 0}, 60).low]')
        self.assertEqual(got[0], 1)
        self.assertLess(got[1], 0.2)
        self.assertGreater(got[2], 0.99)

    def test_bass_broadens_brightness_leans_loudness_thickens(self):
        quiet = self.js('typeset({low: 0.1, mid: 0.2, high: 0.1, energy: 0.02, centroid: 0.1})')
        heavy = self.js('typeset({low: 0.7, mid: 0.2, high: 0.1, energy: 0.6, centroid: 0.15})')
        bright = self.js('typeset({low: 0.1, mid: 0.7, high: 0.6, energy: 0.3, centroid: 0.7})')
        self.assertEqual((quiet["stretch"], quiet["slant"], quiet["weight"]), (0.9, 0, 300))
        self.assertGreater(heavy["stretch"], 1.1)
        self.assertEqual(heavy["weight"], 700)
        self.assertLess(bright["slant"], -0.2)
        self.assertLess(bright["tracking"], quiet["tracking"])

    def test_a_section_change_is_an_energy_shift(self):
        steady = self.js('(() => { let h = []; for (let t = 0; t <= 20; t += 0.5) h = keep(h, t, 0.3); return boundary(h, 20, 0); })()')
        drop = self.js('(() => { let h = []; for (let t = 0; t <= 20; t += 0.5) h = keep(h, t, t < 16.5 ? 0.3 : 0.05); return boundary(h, 20, 0); })()')
        soon = self.js('(() => { let h = []; for (let t = 0; t <= 20; t += 0.5) h = keep(h, t, t < 16.5 ? 0.3 : 0.05); return boundary(h, 20, 15); })()')
        self.assertEqual((steady, drop, soon), (False, True, False))
        self.assertTrue(self.js('boundary([], 50, 5)'))
        self.assertEqual(self.js('(() => { let h = []; for (let t = 0; t <= 30; t++) h = keep(h, t, 1); return h.length; })()'), 9)


if __name__ == "__main__":
    unittest.main()
