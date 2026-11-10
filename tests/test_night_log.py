"""view/rooms/NightLog.js: the night log (B's idea, docs/OVERDRIVE.md §48): the moon, one entry a night."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/NightLog.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class NightLogTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        env = {"TZ": "Asia/Kolkata", "PATH": "/usr/bin:/bin"}
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True, env=env).stdout)

    def test_known_phases(self):
        # Full moon on 5 November 2025 (13:19 UTC), new moon on 20 November 2025 (06:47 UTC).
        full = self.js('age(Date.UTC(2025, 10, 5, 13, 19))')
        new = self.js('age(Date.UTC(2025, 10, 20, 6, 47))')
        self.assertLess(abs(full - 0.5), 0.03)
        self.assertLess(min(new, 1 - new), 0.03)
        self.assertEqual(self.js('[phase(0), phase(0.25), phase(0.5), phase(0.75), phase(0.97)]'), ["NEW", "FIRST QUARTER", "FULL", "LAST QUARTER", "NEW"])
        self.assertAlmostEqual(self.js('lit(0.5)'), 1)

    def test_one_entry_a_night_named_by_its_evening(self):
        got = self.js('(() => { let l = log([], new Date(2026, 10, 9, 23, 14)); l = log(l, new Date(2026, 10, 10, 2, 5));'
                      ' l = log(l, new Date(2026, 10, 10, 14, 0)); l = log(l, new Date(2026, 10, 10, 22, 30)); return l.map(e => [e.night, e.at]); })()')
        self.assertEqual(got, [["2026-11-09", "23:14"], ["2026-11-10", "22:30"]])

    def test_thirty_kept_and_junk_dropped(self):
        self.assertEqual(self.js('(() => { let l = []; for (let d = 1; d <= 40; d++) l = log(l, new Date(2026, 0, d, 23, 0)); return l.length; })()'), 30)
        self.assertEqual(self.js('clean([{ night: "2026-11-09", at: "23:14", age: 0.3 }, { night: "x", at: "23:14", age: 0.3 }, null, { night: "2026-11-09", at: "2:1", age: 2 }]).length'), 1)

    def test_the_line(self):
        self.assertEqual(self.js('line({ night: "2026-11-09", at: "23:14", age: 0.5 })'), "2026-11-09 23:14 · FULL · 100% LIT")


if __name__ == "__main__":
    unittest.main()
