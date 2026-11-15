"""The Devices room's Wi-Fi and Bluetooth tiles: the hover settings glyph (owner, 15 November 2026), offscreen."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from smoke import prepare  # noqa: E402


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class LinkPlaneGlyph(unittest.TestCase):
    def test_the_settings_glyph(self):
        harness = (ROOT / "tests/fixtures/rooms/LinkPlaneTest.qml").read_text()
        with tempfile.TemporaryDirectory(prefix="zaetherion-tile-") as tmp:
            base = Path(tmp)
            env, _, _ = prepare(base, harness)
            (base / "runtime").mkdir(mode=0o700)
            env.update(XDG_RUNTIME_DIR=str(base / "runtime"), TILE_SHOT=os.environ.get("TILE_SHOT") or str(base / "tile.png"))
            result = subprocess.run(["qs", "--no-color", "--log-rules", "qml.debug=true", "-p", env["FART_VIEW_ENTRY"]],
                                    env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=20)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output[-2500:])
            self.assertNotIn("TILE_FAIL", output, output[-2500:])
            for name in ("the glyph is hidden at rest", "the focused tile shows its glyph", "capture",
                         "the glyph opens settings; the tile still toggles"):
                self.assertIn("TILE_PASS " + name, output, output[-2500:])
            for error in ("Binding loop", "ReferenceError", "TypeError", "Unable to assign"):
                self.assertNotIn(error, output, output[-2500:])


if __name__ == "__main__":
    unittest.main()
