import subprocess
import sys
import tempfile
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class FacesTest(unittest.TestCase):
    """The planet faces (view/faces) load in every slot without errors, and the Timers face steps once
    per shown second while a timer runs (tools/faces.py, offscreen, a private core)."""

    def test_faces_render_and_timers_steps_per_second(self):
        with tempfile.TemporaryDirectory(prefix='fart-faces-test-') as out:
            run = subprocess.run([sys.executable, str(ROOT / 'tools/faces.py'), out], capture_output=True, text=True, timeout=120)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
            self.assertIn('stepping ok', run.stdout)
            self.assertEqual(len(list(Path(out).glob('faces-*.png'))), 3)


if __name__ == '__main__':
    unittest.main()
