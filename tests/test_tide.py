"""view/rooms/Tide.js: the disk as a tide (B's idea, docs/OVERDRIVE.md §44)."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Tide.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class TideTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_the_water_rises_fast_and_falls_slow(self):
        up, down = self.js('[level(0, 1, 1), 1 - level(1, 0, 1)]')
        self.assertGreater(up, down)
        self.assertEqual(self.js('level(0.3, 0.3, 5)'), 0.3)

    def test_reads_run_it_in_writes_draw_it_out(self):
        self.assertLess(self.js('drift(50e6, 0)'), 0)
        self.assertGreater(self.js('drift(0, 50e6)'), 0)
        self.assertEqual(self.js('drift(0, 0)'), 0)

    def test_a_burst_leaves_a_wrack_line_and_the_high_water_stays(self):
        got = self.js('''(() => {
            let s = null, t = 0;
            for (let i = 0; i < 6; i++) s = step(s, 0.8, 1, ++t);
            for (let i = 0; i < 6; i++) s = step(s, 0.02, 1, ++t);
            const one = s.wracks.length, high = s.high;
            for (let i = 0; i < 400; i++) s = step(s, 0.02, 1, ++t);
            return [one, s.wracks.length, high.at, s.high.h > 0.5, s.high.at];
        })()''')
        self.assertEqual(got[0], 1)
        self.assertEqual(got[1], 0)        # gone after five minutes
        self.assertEqual(got[2], got[4])   # the tideline stays
        self.assertTrue(got[3])

    def test_a_low_ripple_leaves_nothing(self):
        got = self.js('(() => { let s = null; for (let i = 1; i < 6; i++) s = step(s, 0.05, 1, i); for (let i = 6; i < 12; i++) s = step(s, 0, 1, i); return s.wracks.length; })()')
        self.assertEqual(got, 0)
        self.assertAlmostEqual(self.js('fade({ h: 0.5, at: 0 }, 150)'), 0.5)


if __name__ == "__main__":
    unittest.main()
