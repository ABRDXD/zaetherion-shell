"""tools/keytest.py: keyboard reach, spatial reach, the reticle rect, Escape, the zone fallbacks, list rows and the title band in all nine rooms, offscreen."""
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class KeytestTests(unittest.TestCase):
    def test_every_room_passes(self):
        run = subprocess.run([sys.executable, str(ROOT / "tools/keytest.py")], capture_output=True, text=True, timeout=240)
        self.assertEqual(run.returncode, 0, run.stdout[-3000:] + run.stderr[-2000:])
        self.assertIn("KEY_DONE", run.stdout)
        for page in ("home", "media", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications"):
            for check in ("tab", "spatial", "reticle", "shown", "hidden", "escape", "index", "index.back", "command", "rows"):
                self.assertIn(f"KEY_PASS {page}.{check}", run.stdout)
        for page in ("home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"):
            self.assertIn(f"KEY_PASS {page}.band", run.stdout)


if __name__ == "__main__":
    unittest.main()
