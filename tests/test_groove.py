"""view/rooms/Groove.js: groove geometry on Media's seek bar (atlas #12): cut as you listen, dead where paused."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Groove.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class GrooveTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_only_what_played_is_cut_and_the_loudest_stays(self):
        got = self.js("""(() => {
            let g = empty();
            g = record(g, 10, 160, 0.4, true);
            g = record(g, 10.5, 160, 0.9, true);
            g = record(g, 10.7, 160, 0.2, true);   // quieter later: the cut keeps its depth
            g = record(g, 50, 160, 1.0, false);    // paused: nothing
            g = record(g, 500, 160, 1.0, true);    // past the end: nothing
            return [g[10], g[50], g.filter(v => v > 0).length, g.length];
        })()""")
        self.assertEqual(got, [0.9, 0, 1, 160])

    def test_the_line_wiggles_by_energy_and_is_straight_where_dead(self):
        got = self.js("""(() => {
            let g = empty();
            for (let i = 0; i < 80; i++) g[i] = i < 40 ? 1 : 0;
            const p = path(g, 320, 30, 0.5);
            const loud = p.filter(q => q.x < 80), dead = p.filter(q => q.x > 82 && q.x < 160);
            return { end: p[p.length - 1].x, loudSpread: Math.max(...loud.map(q => q.y)) - Math.min(...loud.map(q => q.y)),
                     deadSpread: Math.max(...dead.map(q => q.y)) - Math.min(...dead.map(q => q.y)) };
        })()""")
        self.assertEqual(got["end"], 160)
        self.assertGreater(got["loudSpread"], 15)
        self.assertEqual(got["deadSpread"], 0)
        self.assertEqual(self.js("path(null, 100, 20, 0)"), [{"x": 0, "y": 10}])

    def test_the_key_names_the_track_only(self):
        self.assertEqual(self.js('key({artist: "A", title: "T", length: 200.4, artUrl: "file:///x"})'), "A · T · 200")
        self.assertEqual(self.js("key(null)"), "")


if __name__ == "__main__":
    unittest.main()
