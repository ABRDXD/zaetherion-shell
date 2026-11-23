"""view/rooms/DayFold.js: Home's creases (atlas #9) and its editions (#11)."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/DayFold.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class DayFoldTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_each_opening_presses_a_crease_and_a_new_day_is_a_fresh_sheet(self):
        got = self.js('(() => { let s = press(null, "2026-11-09", 9.5, 0.3); s = press(s, "2026-11-09", 14, 0.6);'
                      ' const kept = s.creases.length; s = press(s, "2026-11-10", 8, 0.25); return [kept, s.creases.length, s.day]; })()')
        self.assertEqual(got, [2, 1, "2026-11-10"])

    def test_a_crease_at_the_same_place_is_pressed_again(self):
        got = self.js('(() => { let s = press(null, "d", 9, 0.3); s = press(s, "d", 14, 0.6); s = press(s, "d", 9.1, 0.305);'
                      ' return s.creases.map(c => [c.x, c.n]); })()')
        self.assertEqual(got, [[0.6, 1], [0.305, 2]])

    def test_creases_are_capped(self):
        self.assertEqual(self.js('(() => { let s = null; for (let i = 0; i < 40; i++) s = press(s, "d", i / 2, i / 40); return s.creases.length; })()'), 24)

    def test_older_creases_relax_and_alternate(self):
        f = self.js('folds(press(press(press(null, "d", 8, 0.2), "d", 12, 0.5), "d", 16, 0.8))')
        self.assertEqual([c["newest"] for c in f], [False, False, True])
        self.assertEqual(f[2]["depth"], 1)
        self.assertLess(f[0]["depth"], f[1]["depth"])
        self.assertEqual([c["valley"] for c in f], [True, False, True])
        self.assertEqual(self.js('folds(null)'), [])

    def test_the_next_solar_event(self):
        self.assertEqual(self.js('next(9, 6.5, 12.2, 17.8)'), {"h": 12.2, "name": "NOON"})
        self.assertEqual(self.js('next(18, 6.5, 12.2, 17.8)'), {"h": 24, "name": "SUNRISE", "tomorrow": True})
        self.assertIsNone(self.js('next(18, NaN, NaN, NaN)'))

    def test_editions_follow_the_sun(self):
        got = self.js('[3, 9, 15, 19, 23].map(h => edition(h, 6.5, 12.2, 17.8))')
        self.assertEqual(got, ["EARLY EDITION", "MORNING EDITION", "AFTERNOON EDITION", "EVENING EDITION", "LATE FINAL"])
        self.assertEqual(self.js('edition(10, NaN, NaN, NaN)'), "MORNING EDITION")

    def test_printings_count_every_pressing(self):
        self.assertEqual(self.js('printing(press(press(null, "d", 9, 0.3), "d", 9.1, 0.301))'), "2ND PRINTING")
        self.assertEqual(self.js('[1, 2, 3, 4, 11, 12, 13, 21, 22].map(ordinal)'),
                         ["1ST", "2ND", "3RD", "4TH", "11TH", "12TH", "13TH", "21ST", "22ND"])
        self.assertEqual(self.js('printing(null)'), "")

    def test_the_front_page_follows_the_edition_and_today(self):
        rooms = '["tasks", "timers", "notifications", "workspaces"]'
        self.assertEqual(self.js(f'front({rooms}, "MORNING EDITION", {{}})')[0], "workspaces")
        self.assertEqual(self.js(f'front({rooms}, "EVENING EDITION", null)'), ["tasks", "timers", "notifications", "workspaces"])
        # A room lived in all day reaches the front page.
        self.assertEqual(self.js(f'front({rooms}, "MORNING EDITION", {{notifications: 30, tasks: 2}})')[0], "notifications")


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class HomeFolded(unittest.TestCase):
    """Home folded and set as an edition (tools/cuetest/HomeFoldTest.qml), offscreen."""

    def test_pressed_set_as_an_edition_pressed_again_and_released(self):
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("HomeFoldTest.qml", timeout=120)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("fold.silent", "fold.pressed", "fold.edition", "fold.again", "week.ledger", "fold.release"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertIn("CUE_ACTIVE 0 []", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Cannot assign") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
