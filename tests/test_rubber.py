"""view/shell/Rubber.js: the pull follows with growing resistance, never passes its reach, commits past the threshold."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def run(expr):
    body = "\n".join(l for l in (ROOT / "view/shell/Rubber.js").read_text().splitlines() if not l.startswith(".pragma"))
    return json.loads(subprocess.run(["node", "-e", body + f"\nprocess.stdout.write(JSON.stringify({expr}));"],
                                     capture_output=True, text=True, check=True).stdout)


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Rubber(unittest.TestCase):
    def test_resists_more_the_further_it_goes(self):
        a, b, c = run("[stretch(30), stretch(60), stretch(90)]")
        self.assertLess(a, 30)
        self.assertLess(b - a, a)          # each 30 px of pointer gives less stretch than the last
        self.assertLess(c - b, b - a)

    def test_never_passes_its_reach_and_ignores_the_wrong_way(self):
        self.assertLess(run("stretch(100000)"), 120)
        self.assertEqual(run("stretch(-50)"), 0)

    def test_commits_past_the_threshold(self):
        self.assertEqual(run("[committed(89), committed(90)]"), [False, True])


if __name__ == "__main__":
    unittest.main()
