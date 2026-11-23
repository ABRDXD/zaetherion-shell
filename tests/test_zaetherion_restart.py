"""`zaetherion restart` and `stop` wait for the old core to exit, not only for its socket to go.
Fake cores in private runtime folders; the real core, DMS and the live runtime are never touched."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import zaetherion

# Behaves like core/fartd.py where it matters: core.lock is taken non-blocking, a second core exits, and on
# `shutdown` the socket goes first while the lock stays held for FAKE_LINGER seconds (the supervisor's teardown).
FAKE_CORE = '''
import fcntl, json, os, socket, sys, time
from pathlib import Path
runtime = Path(os.environ["FART_RUNTIME_DIR"])
lock = (runtime / "core.lock").open("a")
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    raise SystemExit("fartd: another core is already running")
with (runtime / "starts.log").open("a") as starts:
    starts.write(f"{os.getpid()}\\n")
path = runtime / "core.sock"
path.unlink(missing_ok=True)
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(str(path))
server.listen(4)
while True:
    connection, _ = server.accept()
    for line in connection.makefile("rb"):
        message = json.loads(line)
        connection.sendall(json.dumps({"id": message["id"], "ok": True, "result": {}}).encode() + b"\\n")
        if message["op"] == "shutdown":
            path.unlink()
            time.sleep(float(os.environ.get("FAKE_LINGER", "0")))
            os._exit(0)
    connection.close()
'''


class RestartRaceTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        base = Path(temp.name)
        self.runtime = base / "run" / "zaetherion"
        self.runtime.mkdir(parents=True, mode=0o700)
        (base / "root" / "core").mkdir(parents=True)
        (base / "root" / "core" / "fartd.py").write_text(FAKE_CORE)  # what start_core launches
        env = {"PATH": os.environ.get("PATH", os.defpath), "HOME": str(base), "FART_RUNTIME_DIR": str(self.runtime),
               "XDG_STATE_HOME": str(base / "state"), "XDG_CACHE_HOME": str(base / "cache")}
        for patcher in (patch.dict(os.environ, env, clear=True),  # no FART_* from the desktop
                        patch.object(zaetherion, "ROOT", base / "root"),
                        patch.object(zaetherion, "seed_state"),
                        patch.object(zaetherion, "stop_legacy_view")):
            patcher.start()
            self.addCleanup(patcher.stop)
        self.addCleanup(self.kill_fakes)

    def kill_fakes(self):
        log = self.runtime / "starts.log"
        for pid in log.read_text().split() if log.exists() else ():
            try:
                os.kill(int(pid), signal.SIGKILL)
            except ProcessLookupError:
                pass

    def starts(self) -> int:
        log = self.runtime / "starts.log"
        return len(log.read_text().split()) if log.exists() else 0

    def start_old_core(self, linger: float) -> subprocess.Popen:
        script = self.runtime.parent / "old_core.py"
        script.write_text(FAKE_CORE)
        old = subprocess.Popen([sys.executable, "-I", str(script)], env=dict(os.environ, FAKE_LINGER=str(linger)),
                               stdin=subprocess.DEVNULL)
        self.addCleanup(old.wait)
        self.addCleanup(old.kill)
        for _ in range(200):
            connection = zaetherion.try_connect(self.runtime / "core.sock")
            if connection:
                connection.close()
                return old
            time.sleep(0.025)
        self.fail("the fake core did not start")

    def run_cli(self, action: str):
        return zaetherion.run(zaetherion.parser().parse_args([action]))

    def test_restart_waits_for_a_slow_exiting_core_then_starts_a_new_one(self):
        old = self.start_old_core(linger=1.0)
        self.run_cli("restart")
        self.assertIsNotNone(old.poll(), "the old core must be gone before the new one starts")
        self.assertEqual(self.starts(), 2)  # the old core and exactly one new one, which holds the lock
        self.assertFalse(zaetherion.core_lock_free(self.runtime))
        self.assertIsNone(self.run_cli("close"))  # the new core answers

    def test_stop_returns_only_after_the_core_has_exited(self):
        old = self.start_old_core(linger=0.5)
        self.run_cli("stop")
        self.assertIsNotNone(old.poll())
        self.assertTrue(zaetherion.core_lock_free(self.runtime))

    def test_stop_waits_for_a_core_that_is_already_shutting_down(self):
        old = self.start_old_core(linger=0.5)
        connection = zaetherion.connect(start=False)
        connection.request("shutdown")  # socket gone, lock still held
        connection.close()
        self.assertFalse(zaetherion.core_lock_free(self.runtime))
        self.run_cli("stop")
        self.assertIsNotNone(old.poll())

    def test_a_core_that_does_not_exit_in_time_is_reported_and_no_second_core_starts(self):
        old = self.start_old_core(linger=30)
        with patch.object(zaetherion, "STOP_WAIT", 0.4):
            with self.assertRaisesRegex(zaetherion.Unreachable,
                                        r"the old core did not exit within 0\.4 s; not starting another; see .*core\.log"):
                self.run_cli("restart")
        self.assertIsNone(old.poll())
        self.assertEqual(self.starts(), 1)

    def test_stop_with_no_core_returns_at_once(self):
        started = time.monotonic()
        self.run_cli("stop")
        self.assertLess(time.monotonic() - started, 1)


if __name__ == "__main__":
    unittest.main()
