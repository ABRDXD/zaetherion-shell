"""view/rooms/SurveyorNotes.js: the archive's revision history (atlas #58), and the one impossible revision."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/SurveyorNotes.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class RevisionTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_filed_and_revised_by_reading(self):
        self.assertEqual(self.js('revision("FIELD NOTE / 001", "2026-11-09", 250, 3, 7, [])'), "FILED 2026-11-09 · REV 3")
        self.assertEqual(self.js('revision("FIELD NOTE / 001", "", 250, 3, 7, [])'), "")

    def test_one_note_is_revised_before_it_was_filed_once_the_survey_is_long(self):
        labels = ["FIELD NOTE / 000", "FIELD NOTE / 001", "FIELD NOTE / 002"]
        got = self.js(f'{json.dumps(labels)}.map(l => revision(l, "2026-11-09", 0, 21, 4, {json.dumps(labels)}))')
        odd = [line for line in got if line.count("REV") == 2]
        self.assertEqual(len(odd), 1)
        self.assertEqual(got.index(odd[0]), 4 % 3)
        earlier = odd[0].rsplit(" ", 1)[1]
        self.assertLess(earlier, "2026-11-09")
        self.assertEqual(self.js(f'{json.dumps(labels)}.map(l => revision(l, "2026-11-09", 0, 20, 4, {json.dumps(labels)}))').count(odd[0]), 0)
        self.assertEqual(self.js('dayOffset("2026-03-02", -3)'), "2026-02-27")


if __name__ == "__main__":
    unittest.main()
