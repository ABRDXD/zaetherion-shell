"""The cutover tool (tools/cutover.py, docs/CUTOVER.md), only ever in a sandbox.

A rehearsal switches a sandbox's `fart` launcher and clock file to fart-next and back, and must leave both
byte-identical to where they started. The live launcher and clock file are read, never written.
"""
import contextlib
import hashlib
import io
import os
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import cutover  # noqa: E402

HOOK = ROOT / "adapters/serpantinum/hook"
ARCHIVE_HUNK = (HOOK / "archive.qmlpart").read_text()
CLOCK = "import QtQuick\n\nItem {\n    MouseArea {\n        anchors.fill: parent\n" + ARCHIVE_HUNK + "\n    }\n}\n"
LIVE_FILES = [Path.home() / ".local/bin/fart",
              Path(os.environ.get("SERPANTINUM_DIR") or Path.home() / ".local/share/serpantinum/src")
              / "quickshell/bar/faces/timedate/TimeDateFace.qml"]


def digest(paths):
    return {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in paths if p.is_file()}


@unittest.skipUnless((cutover.ARCHIVE / "tools/fart_clock.py").is_file(), "the archive's clock tool is not on this machine")
class CutoverTest(unittest.TestCase):
    def setUp(self):
        self.live = digest(LIVE_FILES)
        self.dir = tempfile.TemporaryDirectory(prefix="fart-cutover-test-")
        self.root = Path(self.dir.name)
        (self.root / ".local/bin").mkdir(parents=True)
        self.fart = self.root / ".local/bin/fart"
        self.fart.write_text(cutover.ARCHIVE_LAUNCHER)
        self.fart.chmod(0o755)
        self.clock = self.root / "TimeDateFace.qml"
        self.clock.write_text(CLOCK)

    def tearDown(self):
        self.dir.cleanup()
        self.assertEqual(digest(LIVE_FILES), self.live, "the live launcher or clock file changed")

    def run_tool(self, *args):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cutover.main([*args, "--root", str(self.root)])
        return code, out.getvalue() + err.getvalue()

    def test_apply_and_rollback_round_trip(self):
        before = digest([self.fart, self.clock])
        code, out = self.run_tool("apply")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.fart.read_text(), cutover.NEXT_LAUNCHER)
        self.assertEqual((self.root / ".local/bin/fart-archive").read_text(), cutover.ARCHIVE_LAUNCHER)
        self.assertTrue(os.access(self.root / ".local/bin/fart-archive", os.X_OK))
        self.assertEqual(cutover.clock_hook.state(self.clock.read_text()), "variant")
        self.assertEqual(self.run_tool("apply")[0], 0)  # a second apply changes nothing
        code, out = self.run_tool("rollback")
        self.assertEqual(code, 0, out)
        self.assertEqual(digest([self.fart, self.clock]), before)
        self.assertFalse((self.root / ".local/bin/fart-archive").exists())

    def test_refuses_an_unknown_launcher_without_changing_anything(self):
        self.fart.write_text("#!/bin/sh\nexec something-else\n")
        before = digest([self.fart, self.clock])
        code, out = self.run_tool("apply")
        self.assertEqual(code, 1)
        self.assertIn("Nothing was changed", out)
        self.assertEqual(digest([self.fart, self.clock]), before)

    def test_switching_needs_a_sandbox_or_live(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            cutover.main(["apply"])


if __name__ == "__main__":
    unittest.main()
