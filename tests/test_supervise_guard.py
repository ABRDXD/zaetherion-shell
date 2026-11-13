"""A private test core must not take charge of the owner's DMS through inherited settings."""
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tools"))

from core import fartd  # noqa: E402
import smoke  # noqa: E402


class GuardTest(unittest.TestCase):
    def test_fixture_host_needs_opt_in(self):
        self.assertFalse(fartd.supervise_allowed({"FART_HOST": "fixture", "FART_SUPERVISE": "dms"}))
        self.assertTrue(fartd.supervise_allowed({"FART_HOST": "fixture", "FART_SUPERVISE_FIXTURE": "1"}))
        self.assertTrue(fartd.supervise_allowed({"FART_HOST": "serpantinum"}))

    def test_view_env_drops_supervision(self):
        env = fartd.view_env({"FART_SUPERVISE": "dms", "FART_SUPERVISE_FIXTURE": "1", "PATH": "/bin"}, FART_X="1")
        self.assertEqual(env, {"PATH": "/bin", "FART_X": "1"})

    def test_inherited_env_strips_fart(self):
        saved = dict(os.environ)
        try:
            os.environ.update(FART_SUPERVISE="dms", FART_CORE_SOCKET="/x", FART_LOG="1")
            env = smoke.inherited_env(FART_HOST="fixture")
        finally:
            os.environ.clear()
            os.environ.update(saved)
        self.assertEqual({k for k in env if k.startswith("FART_")}, {"FART_HOST"})

    def test_fixture_core_ignores_inherited_supervise(self):
        """End to end: a fixture core with FART_SUPERVISE=dms comes up, says it ignored it, and starts no DMS."""
        with tempfile.TemporaryDirectory() as d:
            base = Path(d)
            run = base / "run"
            run.mkdir(mode=0o700)
            bindir = base / "bin"
            bindir.mkdir()
            marker = base / "dms-started"
            dms = bindir / "dms"
            dms.write_text(f"#!/bin/sh\ntouch {marker}\nsleep 30\n")
            dms.chmod(0o755)
            env = dict(PATH=f"{bindir}:{os.environ['PATH']}", HOME=str(base), XDG_RUNTIME_DIR=str(run),
                       FART_HOST="fixture", FART_STATE_DIR=str(base / "state"), FART_RUNTIME_DIR=str(run / "z"),
                       FART_MIRROR="0", FART_LOG="-", FART_SUPERVISE="dms", FART_VIEW_ENTRY=str(base / "none.qml"),
                       QT_QPA_PLATFORM="offscreen", DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent/x",
                       DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent/x")
            core = subprocess.Popen([sys.executable, "-I", str(ROOT / "core/fartd.py")], env=env, cwd=base,
                                    stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            try:
                deadline = time.time() + 10
                while not (run / "z" / "core.sock").exists():
                    self.assertIsNone(core.poll(), "core exited early")
                    self.assertLess(time.time(), deadline, "core did not start")
                    time.sleep(0.05)
                time.sleep(1.0)
            finally:
                core.terminate()
                _, err = core.communicate(timeout=10)
            self.assertIn(b"FART_SUPERVISE=dms ignored", err)
            self.assertFalse(marker.exists())


if __name__ == "__main__":
    unittest.main()
