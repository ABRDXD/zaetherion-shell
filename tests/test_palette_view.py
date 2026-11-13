"""Fixture-only palette UI checks. No screenshots or host actions."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PaletteViewTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("qs"), "Quickshell unavailable")
    def test_preview_choose_close_disconnect_update_design(self):
        with tempfile.TemporaryDirectory(prefix="palette-test-") as directory:
            base = Path(directory)
            bundle = base / "bundle"
            bundle.mkdir()
            for name in ("core", "view", "adapters", "assets"):
                (bundle / name).symlink_to(ROOT / name, target_is_directory=True)
            shutil.copy2(ROOT / "tests/fixtures/palette/PickerTest.qml", bundle / "shell.qml")
            for name in ("home", "runtime", "config", "state", "cache"):
                (base / name).mkdir(mode=0o700)
            env = {k: v for k, v in os.environ.items() if not k.startswith("FART_")}
            env.update(HOME=str(base / "home"), XDG_RUNTIME_DIR=str(base / "runtime"),
                XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"), XDG_CACHE_HOME=str(base / "cache"),
                FART_STATE_DIR=str(base / "state"), FART_CACHE_DIR=str(base / "cache"),
                QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", WAYLAND_DISPLAY="", HYPRLAND_INSTANCE_SIGNATURE="",
                DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent/palette-fixture", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent/palette-fixture")
            run = subprocess.run(["qs", "-n", "--no-color", "--log-rules", "qml.debug=true", "-p", str(bundle / "shell.qml")],
                env=env, capture_output=True, text=True, timeout=20)
            output = run.stdout + run.stderr
            self.assertEqual(run.returncode, 0, output)
            self.assertIn("PALETTE_DONE", output)
            self.assertEqual(output.count("PALETTE_PASS"), 6, output)
            for error in ("PALETTE_FAIL", "ReferenceError", "TypeError", "Binding loop", "Unable to assign"):
                self.assertNotIn(error, output)
