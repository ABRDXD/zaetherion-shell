"""FocusMap.js spatial picks (MONTAGE.md §3.3), run under Node with the QML `.pragma` line stripped."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/ui/FocusMap.js"


def r(x, y, w=40, h=24):
    return {"x": x, "y": y, "width": w, "height": h}


@unittest.skipUnless(shutil.which("node"), "needs Node")
class FocusMapTests(unittest.TestCase):
    def pick(self, from_index, rects, direction):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = (body + f"\nconst rects = {json.dumps(rects)};\n"
                  f"process.stdout.write(String(pick(rects[{from_index}], rects, {json.dumps(direction)})));")
        return int(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_grid_moves_to_the_neighbour(self):
        grid = [r(0, 0), r(100, 0), r(0, 100), r(100, 100)]
        self.assertEqual(self.pick(0, grid, "right"), 1)
        self.assertEqual(self.pick(0, grid, "down"), 2)
        self.assertEqual(self.pick(3, grid, "left"), 2)
        self.assertEqual(self.pick(3, grid, "up"), 1)

    def test_no_candidate_at_the_edge(self):
        grid = [r(0, 0), r(100, 0)]
        self.assertEqual(self.pick(0, grid, "left"), -1)
        self.assertEqual(self.pick(0, grid, "up"), -1)

    def test_cone_excludes_items_beyond_45_degrees(self):
        # (100, 150) is further across than along: outside the right cone, inside the down cone.
        rects = [r(0, 0), r(100, 150)]
        self.assertEqual(self.pick(0, rects, "right"), -1)
        self.assertEqual(self.pick(0, rects, "down"), 1)

    def test_across_distance_weighs_double(self):
        # Along 100, across 40 scores 180; along 170, across 0 scores 170, so the straight one wins.
        rects = [r(0, 0), r(100, 40), r(170, 0)]
        self.assertEqual(self.pick(0, rects, "right"), 2)
        rects = [r(0, 0), r(100, 30), r(170, 0)]  # 160 < 170
        self.assertEqual(self.pick(0, rects, "right"), 1)

    def fallback(self, zone, direction, side="left"):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify(fallback({json.dumps(zone)}, {json.dumps(direction)}, {json.dumps(side)})));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_fallbacks_leave_the_room_into_the_index_and_the_command_line(self):
        self.assertEqual(self.fallback("room", "left"), "index")
        self.assertEqual(self.fallback("room", "up"), "command")
        self.assertEqual(self.fallback("room", "right"), "")
        self.assertEqual(self.fallback("room", "down"), "")
        self.assertEqual(self.fallback("index", "right"), "room")
        self.assertEqual(self.fallback("index", "up"), "command")
        self.assertEqual(self.fallback("index", "left"), "")
        self.assertEqual(self.fallback("header", "down"), "room")
        for direction in ("left", "right", "up", "down"):
            self.assertEqual(self.fallback("list", direction), "room")
        self.assertEqual(self.fallback("command", "down"), "")

    def test_a_ribbon_on_the_right_mirrors_the_room_and_index_fallbacks(self):
        self.assertEqual(self.fallback("room", "right", "right"), "index")
        self.assertEqual(self.fallback("room", "left", "right"), "")
        self.assertEqual(self.fallback("room", "up", "right"), "command")
        self.assertEqual(self.fallback("index", "left", "right"), "room")
        self.assertEqual(self.fallback("index", "right", "right"), "")
        self.assertEqual(self.fallback("header", "down", "right"), "room")

    def test_unknown_direction(self):
        self.assertEqual(self.pick(0, [r(0, 0), r(100, 0)], "forward"), -1)


if __name__ == "__main__":
    unittest.main()
