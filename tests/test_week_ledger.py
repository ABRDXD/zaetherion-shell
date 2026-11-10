"""view/rooms/WeekLedger.js: the week as a ledger (B's idea, docs/OVERDRIVE.md §42)."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/WeekLedger.js"
DAYS = {"2026-11-07": {"tasks": 10, "media": 30}, "2026-11-08": {"notifications": 5}, "2026-11-09": {"codex": 2, "tasks": 3}}


@unittest.skipUnless(shutil.which("node"), "needs Node")
class WeekLedgerTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nconst D = {json.dumps(DAYS)};\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_a_day_against_the_busiest(self):
        self.assertEqual(self.js('["2026-11-07", "2026-11-08", "2026-11-10"].map(k => share(D, k))'), [1, 0.125, 0])
        self.assertEqual(self.js('share(null, "2026-11-07")'), 0)

    def test_the_room_a_day_was_spent_in(self):
        self.assertEqual(self.js('["2026-11-07", "2026-11-08", "2026-11-09", "2026-11-10"].map(k => dominant(D, k))'), ["01", "08", "05", ""])


if __name__ == "__main__":
    unittest.main()
