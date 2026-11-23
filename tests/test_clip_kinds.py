"""view/rooms/ClipKinds.js: MIME taxonomy in Clips (atlas #31): a clip's kind from what the room already shows."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/ClipKinds.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class ClipKindTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_kinds(self):
        cases = {
            "https://example.org/a?b=1": "LINK", "www.example.org": "LINK", "see https://x.org later": "TEXT",
            "~/Documents/notes.md": "PATH", "/etc/hosts": "PATH", "./run.sh": "PATH",
            "#7e9cd8": "COLOUR", "#fff": "COLOUR", "rgb(10, 20, 30)": "COLOUR",
            "+91 98765 43210": "NUMBER", "482913": "NUMBER", "3.14": "NUMBER", "7": "TEXT",
            "const x = 1;": "CODE", "def main():": "CODE", "import os": "CODE", "items.map(i => i * 2)": "CODE",
            "$ git status": "CODE", "Remember to buy milk.": "TEXT", "Hello there": "TEXT", "": "TEXT",
        }
        got = self.js(f"{json.dumps(list(cases))}.map(t => kind({{text: t, isImage: false}}))")
        self.assertEqual(dict(zip(cases, got)), cases)
        self.assertEqual(self.js('[kind({text: "x", isImage: true}), kind(null)]'), ["IMAGE", "TEXT"])
        self.assertEqual(self.js('[colour({text: " #7e9cd8 "}), colour({text: "hi"})]'), ["#7e9cd8", ""])


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class ClipsMarks(unittest.TestCase):
    """The marks in the real Clips room (tools/cuetest/ClipsTest.qml)."""

    def test_each_kind_has_its_mark(self):
        import sys
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("ClipsTest.qml", timeout=60)
        for name in ("clips.kinds", "clips.copies", "clips.copies.release"):
            self.assertIn(f"CUE_PASS {name}", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Cannot assign") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
