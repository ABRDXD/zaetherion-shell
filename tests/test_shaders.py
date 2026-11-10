"""The committed .qsb shaders match their GLSL sources (tools/make_shaders.py)."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
QSB = shutil.which("qsb") or "/usr/lib/qt6/bin/qsb"


@unittest.skipUnless(os.access(QSB, os.X_OK), "needs Qt's qsb")
class ShaderTests(unittest.TestCase):
    def test_every_shader_is_compiled_and_current(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/make_shaders.py"), "--check"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(list((ROOT / "view").rglob("shaders/*.qsb")))


if __name__ == "__main__":
    unittest.main()
