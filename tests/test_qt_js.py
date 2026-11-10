"""Qt's JS engine is older than current browsers: these have reached a commit and failed only at runtime."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
MISSING = re.compile(r"\.flatMap\(|Object\.fromEntries\(")


class QtJsTests(unittest.TestCase):
    def test_no_method_the_engine_lacks(self):
        found = []
        for path in [*ROOT.glob("view/**/*.qml"), *ROOT.glob("view/**/*.js"), *ROOT.glob("adapters/**/*.qml")]:
            for number, line in enumerate(path.read_text().splitlines(), 1):
                code = line.split("//", 1)[0]
                if MISSING.search(code):
                    found.append(f"{path.relative_to(ROOT)}:{number}")
        self.assertEqual(found, [])
