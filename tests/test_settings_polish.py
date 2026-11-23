"""Z219, Cutline polish, in the real settings pane offscreen."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from smoke import prepare  # noqa: E402

CHECKS = ("opening focuses the current choice", "the current choice is the white cut",
          "an unknown value reads READING and can't open", "an offline inbox reads OFFLINE",
          "an offline inbox turns every inbox action off", "an offline inbox says so", "clear arms first",
          "cancel disarms", "clear asks twice, then clears")


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class SettingsPolish(unittest.TestCase):
    def test_polish(self):
        harness = (ROOT / "tests/fixtures/settings/PolishTest.qml").read_text()
        with tempfile.TemporaryDirectory(prefix="zaetherion-polish-") as tmp:
            base = Path(tmp)
            env, _, _ = prepare(base, harness)
            runtime = base / "runtime"
            runtime.mkdir(mode=0o700)
            env.update(XDG_RUNTIME_DIR=str(runtime))
            result = subprocess.run(["qs", "--no-color", "--log-rules", "qml.debug=true", "-p", env["FART_VIEW_ENTRY"]],
                                    env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output[-3000:])
            self.assertNotIn("POLISH_FAIL", output, output[-3000:])
            for name in CHECKS:
                self.assertIn("POLISH_PASS " + name, output, output[-3000:])
            for error in ("Binding loop", "ReferenceError", "TypeError", "Unable to assign"):
                self.assertNotIn(error, output, output[-3000:])


if __name__ == "__main__":
    unittest.main()
