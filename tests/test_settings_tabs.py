"""FART's Island and Clips tabs in the real settings pane, offscreen (Z176, Z184, Z201, Z202)."""
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

CHECKS = ("the owner's rest reads as preset B", "edge and screen read from the core",
          "the clipboard settings are not read on another tab", "island capture",
          "island choices go through the island verb", "the clips tab reads DMS's clipboard settings",
          "values read from the core and DMS", "clips capture", "quick paste choices go to the core",
          "history choices go to DMS's config", "clear asks twice", "leaving the tab lets go of the settings",
          "notifications read from the core", "notifications capture", "notification choices go to the core",
          "do-not-disturb goes to the inbox")


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class SettingsTabs(unittest.TestCase):
    def test_island_and_clips_tabs(self):
        harness = (ROOT / "tests/fixtures/settings/TabsTest.qml").read_text()
        with tempfile.TemporaryDirectory(prefix="zaetherion-tabs-") as tmp:
            base = Path(tmp)
            env, _, _ = prepare(base, harness)
            runtime = base / "runtime"
            runtime.mkdir(mode=0o700)
            out = Path(os.environ.get("TABS_SHOTS") or base)
            env.update(XDG_RUNTIME_DIR=str(runtime), TABS_SHOT_ISLAND=str(out / "island.png"), TABS_SHOT_CLIPS=str(out / "clips.png"),
                       TABS_SHOT_NOTIFICATIONS=str(out / "notifications.png"))
            result = subprocess.run(["qs", "--no-color", "--log-rules", "qml.debug=true", "-p", env["FART_VIEW_ENTRY"]],
                                    env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output[-3000:])
            self.assertNotIn("TABS_FAIL", output, output[-3000:])
            for name in CHECKS:
                self.assertIn("TABS_PASS " + name, output, output[-3000:])
            for error in ("Binding loop", "ReferenceError", "TypeError", "Unable to assign"):
                self.assertNotIn(error, output, output[-3000:])


if __name__ == "__main__":
    unittest.main()
