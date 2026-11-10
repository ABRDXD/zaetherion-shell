"""view/strata/MediumLaws.js: how each room pushes the Medium (docs/OVERDRIVE.md §34)."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/strata/MediumLaws.js"
ROOMS = ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"]


@unittest.skipUnless(shutil.which("node"), "needs Node")
class MediumLawTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_every_room_has_a_law_and_stays_in_the_shader_limits(self):
        data = {"playing": True, "spectrum": [0.9] * 56, "cpu": 1, "gpu": 1, "desks": 40, "tasks": 40, "running": True, "unread": 400}
        for room in ROOMS:
            for t in (0, 1.7, 1000.3):
                out = self.js(f"emitters({json.dumps(room)}, {t}, {json.dumps(data)})")
                self.assertTrue(out, room)
                self.assertLessEqual(len(out), 8, room)
                for e in out:
                    self.assertTrue(-0.1 <= e["x"] <= 1.1 and -0.1 <= e["y"] <= 1.1, (room, e))
                    self.assertGreater(e["r"], 0, room)
                    self.assertTrue(0 <= e["force"] < 1, (room, e))

    def test_silence_and_empty_rooms_push_nothing(self):
        self.assertEqual(self.js('emitters("media", 3, {playing: false, spectrum: [1, 1]})'), [])
        self.assertEqual(self.js('emitters("media", 3, {playing: true, spectrum: []})'), [])
        self.assertEqual(self.js('emitters("tasks", 3, {tasks: 0})'), [])
        self.assertEqual(self.js('emitters("notifications", 3, {unread: 0})'), [])
        self.assertEqual(self.js('emitters("nowhere", 3, {})'), [])

    def test_a_busier_machine_burns_hotter(self):
        heat = self.js('[0, 1].map(c => emitters("performance", 2, {cpu: c}).reduce((s, e) => s + e.heat, 0))')
        self.assertGreater(heat[1], heat[0] * 3)

    def test_missing_data_does_not_throw(self):
        for room in ROOMS:
            self.assertIsInstance(self.js(f"emitters({json.dumps(room)}, 1)"), list)

    def test_the_bearing_comes_from_the_room_side(self):
        b = self.js('roomBearing("a", ["a", "b", "c", "d"])')
        self.assertAlmostEqual(b["x"], 0.5, places=6)
        self.assertLess(b["y"], 0.2)
        self.assertGreater(b["dy"], 0.9)
        self.assertIsNone(self.js('roomBearing("z", ["a"])'))


if __name__ == "__main__":
    unittest.main()
