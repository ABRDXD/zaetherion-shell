"""view/overdrive/Occultation.js: the clock occultation's rules (atlas #51, docs/OVERDRIVE.md §50)."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/overdrive/Occultation.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class OccultationTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_weightier_events_hold_the_clock(self):
        # A device crossing doesn't interrupt a countdown's split; a split takes the clock from a track's band.
        self.assertEqual(self.js('admit(admit(null, "timer", 6, 0), "device", 4, 500).kind'), "timer")
        self.assertEqual(self.js('admit(admit(null, "media", 1, 0), "timer", 6, 500)'), {"kind": "timer", "room": 6, "at": 500})
        # Once the weightier one has crossed, anything may.
        self.assertEqual(self.js('admit(admit(null, "timer", 6, 0), "media", 1, 2700).kind'), "media")
        # Equal weight restarts the crossing.
        self.assertEqual(self.js('admit(admit(null, "device", 4, 0), "device", 4, 900).at'), 900)
        # Unknown kinds change nothing.
        self.assertIsNone(self.js('admit(null, "clipboard", 7, 0)'))
        self.assertEqual(self.js('admit(null, "timer", 6.7, 0).room'), 6)

    def test_progress_and_the_four_contacts(self):
        self.assertEqual(self.js('[progress(null, 5), progress({kind: "timer", at: 100}, 50), progress({kind: "timer", at: 0}, 2601)]'), [-1, -1, -1])
        self.assertEqual(self.js('progress({kind: "timer", at: 0}, 1300)'), 0.5)
        o = self.js('[-1, 0, 0.0625, 0.125, 0.5, 0.85, 0.925, 1].map(opening)')
        self.assertEqual(o[0], 0)
        self.assertEqual(o[1], 0)
        self.assertAlmostEqual(o[2], 0.5)
        self.assertEqual(o[3:6], [1, 1, 1])
        self.assertAlmostEqual(o[6], 0.5)
        self.assertEqual(o[7], 0)

    def test_transits_cross_the_whole_clock(self):
        # Wholly outside at first and last contact, at a constant rate between.
        self.assertEqual(self.js('[0, 0.5, 1].map(u => transit(u, 100, 20, false))'), [-20, 40, 100])
        self.assertEqual(self.js('[0, 0.5, 1].map(u => transit(u, 100, 20, true))'), [100, 40, -20])

    def test_room_numbers_as_the_ribbon_sets_them(self):
        self.assertEqual(self.js('[0, 6, 9, 10, -3].map(roomNumber)'), ["00", "06", "09", "10", "00"])

    def test_planes(self):
        self.assertEqual(self.js('["timer", "device", "media", "x"].map(plane)'), ["split", "front", "behind", ""])


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class OccultationOnTheClock(unittest.TestCase):
    """The real ClockOccultation in a header row (tools/cuetest/OccultationTest.qml), offscreen."""

    def test_silent_split_priority_front_behind_release(self):
        import sys
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("OccultationTest.qml", timeout=120)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("clock.silent", "clock.split", "clock.priority", "clock.closed", "clock.front", "clock.behind", "clock.release"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
