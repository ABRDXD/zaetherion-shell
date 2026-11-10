"""view/rooms/Geology.js: thermal strata (atlas #16) and the battery ledger (#22) from the weather's reports."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Geology.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class GeologyTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_layers_settle_oldest_at_the_bottom_and_heat_compacts(self):
        strata = [{"span": 2400, "temp": 45}, {"span": 2400, "temp": 85}, {"span": 600, "temp": None}]
        got = self.js(f"layers({json.dumps(strata)}, 120)")
        self.assertAlmostEqual(got[0]["y"] + got[0]["h"], 120)        # the oldest lies on the floor
        self.assertAlmostEqual(got[-1]["y"], 0, places=6)             # the newest at the top
        self.assertGreater(got[0]["h"], got[1]["h"])                  # same span, the hot one pressed thinner
        self.assertGreater(got[1]["tone"], got[0]["tone"])
        self.assertEqual(self.js("layers([], 100)"), [])
        self.assertEqual(self.js("layers([{span: 0, temp: 50}], 100)"), [])

    def test_the_ledger_sinks_by_what_was_spent_and_credits_charging(self):
        entries = [{"span": 3600, "battery": 80, "drain": 20}, {"span": 900, "battery": 90, "drain": -40},
                   {"span": 3600, "battery": 70, "drain": 0}, {"span": 3600, "battery": None, "drain": 5}]
        got = self.js(f"ledger({json.dumps(entries)}, 300)")
        self.assertEqual(len(got), 3)                                  # no battery, no entry
        self.assertAlmostEqual(got[-1]["x"] + got[-1]["w"], 300)
        self.assertEqual([round(e["depth"], 3) for e in got], [0.5, 0.25, 0])
        self.assertEqual([e["credit"] for e in got], [False, True, False])
        self.assertGreater(got[0]["w"], got[1]["w"])


if __name__ == "__main__":
    unittest.main()
