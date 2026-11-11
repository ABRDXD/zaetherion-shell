"""Render the island frame with the inert adapter and exercise palette changes."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from smoke import prepare


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class IslandFrameTests(unittest.TestCase):
    def test_frame_and_palette_changes_offscreen(self):
        self.run_fixture("FrameTest.qml", ("fixture palette", "darkest blue role",
            "darkest role without blue", "empty palette fallback"))

    def test_island_faces_hover_and_queue(self):
        self.run_fixture("SurfaceTest.qml", ("preemption saves dwell", "resume and hover pause",
            "hover resumes remaining time", "rest frame", "idle has no leases",
            "hover delay and playing lease", "hover shows wings", "leases released",
            "track face", "workspace flash", "memory face", "osd face", "notification face"))

    def test_status_faces(self):
        self.run_fixture("EventTest.qml", ("recording status", "charging notice", "DND suppresses ordinary battery warning",
            "critical battery passes DND", "backend comeback", "resident restart", "timer status", "timer done", "session debrief"))

    def run_fixture(self, filename, checks):
        harness = (ROOT / "tests/fixtures/island" / filename).read_text()
        with tempfile.TemporaryDirectory(prefix="zaetherion-island-") as tmp:
            base = Path(tmp)
            env, _, _ = prepare(base, harness)
            runtime = base / "runtime"
            runtime.mkdir(mode=0o700)
            shot = base / "frame.png"
            env.update(XDG_RUNTIME_DIR=str(runtime), ISLAND_FRAME_SHOT=str(shot))
            result = subprocess.run(
                ["qs", "--no-color", "--log-rules", "qml.debug=true", "-p", env["FART_VIEW_ENTRY"]],
                env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=15,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertNotIn("ISLAND_FAIL", output)
            for name in (*checks, "offscreen capture"):
                self.assertIn("ISLAND_PASS " + name, output)
            self.assertTrue(shot.is_file(), output)
            for error in ("Binding loop", "ReferenceError", "TypeError", "Unable to assign"):
                self.assertNotIn(error, output)
