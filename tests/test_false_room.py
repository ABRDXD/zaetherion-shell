"""view/overdrive/FalseRoom.js: the False Room's rules (atlas W1, docs/OVERDRIVE.md §53)."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/overdrive/FalseRoom.js"
ROOMS = ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"]


@unittest.skipUnless(shutil.which("node"), "needs Node")
class FalseRoomRules(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def state(self, **over):
        # Every condition holds: the room's own sidereal hour, on battery, nothing playing, two rare hops in a long history.
        base = {"seed": 7, "battery": {"available": True, "charging": False}, "playing": False,
                "recent": [["home", 1], ["codex", 2], ["clipboard", 3]],
                "edges": {"home>media": 30, "media>home": 20, "home>codex": 1, "codex>clipboard": 0}}
        base.update(over)
        return base

    def lst(self):
        return self.js("hour(7)") + 0.5

    def test_the_field_book_learns_it_one_error_at_a_time(self):
        def notes(k, spent="[]"):
            return self.js(f'notes({{seed: 7, errors: Array({k}).fill(0)}}, {{e: 3, n: 6}}, {spent})')
        self.assertEqual(notes(1), [])
        self.assertEqual([n["text"] for n in notes(2)], ["THE ERRORS DO NOT SCATTER · THEY CLOSE ON ONE POINT"])
        three = notes(3)
        self.assertEqual(len(three), 2)
        self.assertIn("STATION −1   E 3.00  N 6.00   BEARING 027°", three[1]["text"])
        self.assertEqual(three[1]["tone"], "error")
        hour = str(self.js("hour(7)")).zfill(2)
        self.assertIn(f"{hour}H BY THE STARS", notes(4)[2]["text"])
        self.assertEqual(len(notes(7)), 6)
        self.assertEqual(len(notes(40)), 6)      # four conditions, no more
        self.assertIn("ENTERED 2 TIMES", notes(3, '["a", "b"]')[-1]["text"])
        self.assertEqual(self.js("notes(null, null, null)"), [])

    def test_sighted_after_three_survey_errors(self):
        self.assertEqual(self.js('[sighted(null), sighted({errors: [1, 2]}), sighted({errors: [1, 2, 3]})]'), [False, False, True])

    def test_sidereal_time(self):
        # J2000.0 (2000-01-01 12:00 UT) at Greenwich: GMST 18h 41m 50.5s.
        self.assertAlmostEqual(self.js('sidereal(Date.UTC(2000, 0, 1, 12), 0)'), 18.697374558, places=5)
        # 82.5° east is 5.5 hours on.
        self.assertAlmostEqual(self.js('sidereal(Date.UTC(2000, 0, 1, 12), 82.5)'), (18.697374558 + 5.5) % 24, places=5)

    def test_every_condition_must_hold(self):
        ok = self.state(lst=self.lst())
        self.assertTrue(self.js(f'conditions({json.dumps(ok)}).all'))
        for name, change in (("sky", {"lst": self.lst() + 1}), ("battery", {"battery": {"available": True, "charging": True}}),
                             ("battery", {"battery": {"available": False}}), ("quiet", {"playing": True}),
                             ("rare", {"recent": [["home", 1], ["media", 2], ["home", 3]]}),
                             ("rare", {"edges": {"home>codex": 1}})):
            got = self.js(f'conditions({json.dumps({**ok, **change})})')
            self.assertFalse(got["all"], change)
            self.assertFalse(got[name], change)

    def test_a_set_once_spent_stays_shut(self):
        conds = self.js(f'conditions({json.dumps(self.state(lst=self.lst()))})')
        sig = conds["signature"]
        self.assertTrue(self.js(f'open({json.dumps(conds)}, [])'))
        spent = self.js(f'spend([], {json.dumps(sig)})')
        self.assertFalse(self.js(f'open({json.dumps(conds)}, {json.dumps(spent)})'))
        self.assertEqual(self.js(f'spend({json.dumps(spent)}, {json.dumps(sig)})'), spent)
        self.assertEqual(len(self.js('spend(Array.from({length: 30}, (_, i) => "s" + i), "x")')), 16)

    def test_place_and_pressure(self):
        p = self.js('place({e: 6, n: 0})')
        self.assertAlmostEqual(p["theta"], 1.5707963, places=5)
        self.assertAlmostEqual(p["r"], 1.18)
        self.assertAlmostEqual(self.js('place({e: 0, n: 9}).r'), 1.40)
        self.assertEqual(self.js('[NaN, 5, 20, 60, 99].map(pressure)'), ["—", "I", "II", "III", "IV"])

    def test_the_reconstruction_holds_only_metadata(self):
        journey = {"seconds": {"home": 3600, "media": 60}, "visits": {"home": 50, "media": 3},
                   "hours": {"home": [0] * 9 + [1] + [0] * 14}, "recent": [["home", 0], ["media", 60], ["nowhere", 61]]}
        m = self.js(f'reconstruct({json.dumps(ROOMS)}, {json.dumps(journey)}, 400)')
        self.assertEqual(len(m["spokes"]), 10)
        home, media, codex = m["spokes"][0], m["spokes"][1], m["spokes"][9]
        self.assertAlmostEqual(home["x"], 0, places=6)
        self.assertAlmostEqual(home["y"], -200 * 0.62)             # Home at the top, the longest
        self.assertLess(abs(media["x"]) + abs(media["y"]), abs(home["y"]))
        self.assertAlmostEqual(abs(codex["x"]) + abs(codex["y"]), 200 * 0.12 * (abs(codex["x"]) + abs(codex["y"])) / 24, places=3)
        self.assertEqual((len(home["ticks"]), len(media["ticks"])), (40, 3))
        bars = [b for b in m["ring"] if (b["x0"], b["y0"]) != (b["x1"], b["y1"])]
        self.assertEqual([b["hour"] for b in bars], [9])
        self.assertEqual([p["id"] for p in m["path"]], ["home", "media"])   # unknown rooms dropped
        self.assertTrue(all(set(p) == {"id", "x", "y", "stamp"} for p in m["path"]))
        self.assertEqual(self.js(f'reconstruct({json.dumps(ROOMS)}, null, 400).path'), [])


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class FalseRoomInTheShell(unittest.TestCase):
    """The False Room on the real orbit and its sheet (tools/cuetest/FalseRoomTest.qml), offscreen."""

    def test_unseen_sighted_open_entered_spent_release(self):
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("FalseRoomTest.qml", timeout=180)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("false.unseen", "false.sighted", "false.open", "false.entered", "false.spent", "false.release"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
