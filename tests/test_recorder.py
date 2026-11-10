"""view/rooms/Recorder.js: the graphics card's chart recorder (B's idea, docs/OVERDRIVE.md §45)."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Recorder.js"
READING = {"running": True, "gpus": [{"card": "card0", "vendor": "NVIDIA", "awake": False},
                                     {"card": "card1", "vendor": "AMD", "awake": True, "busy": 0.37, "levels": [800, 1100, 2700],
                                      "level": 1, "vram": 100 * 1048576, "total": 400 * 1048576}]}


@unittest.skipUnless(shutil.which("node"), "needs Node")
class RecorderTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nconst R = {json.dumps(READING)};\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_the_awake_amd_card_is_traced(self):
        c = self.js('cards(R)')
        self.assertEqual(c["main"]["card"], "card1")
        self.assertEqual([g["card"] for g in c["others"]], ["card0"])
        self.assertIsNone(self.js('cards(null).main'))

    def test_one_revolution_is_kept(self):
        got = self.js('(() => { let tr = []; for (let t = 0; t < 100; t++) tr = record(tr, t, cards(R).main); return [tr.length, tr[0].t, tr[tr.length - 1].level]; })()')
        self.assertEqual(got, [60, 40, 0.5])
        self.assertEqual(self.js('record([{ t: 0, busy: 1, level: 0 }], 90, null)'), [])

    def test_the_chart_turns_under_the_stylus(self):
        self.assertEqual(self.js('angle(10, 10)'), 0)
        self.assertAlmostEqual(self.js('angle(10, 25)'), -3.14159265 / 2, places=6)
        self.assertLess(self.js('busyR(0)'), self.js('busyR(1)'))
        self.assertLess(self.js('levelR(1)'), self.js('busyR(0)'))

    def test_caption(self):
        self.assertEqual(self.js('caption(R)'), "AMD 1100 MHZ · 37% · VRAM 100/400 MB · NVIDIA ASLEEP")


if __name__ == "__main__":
    unittest.main()
