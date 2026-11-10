"""Guard monitors without real hardware: debounce, a fake Hyprland socket and a fake runtime_status file."""
import asyncio
import json
import os
from pathlib import Path
import socket
import tempfile
import threading
import unittest

from core_fakes import ROOT  # noqa: F401  (puts the repo on sys.path)
import core.guards as guards
from core.guards import DgpuGuard, Guard, Guards, any_fullscreen


class Toggle(Guard):
    name = "fullscreen"


class GuardsTests(unittest.IsolatedAsyncioTestCase):
    async def test_on_reports_at_once_and_off_after_quiet(self):
        old = guards.OFF_DEBOUNCE
        guards.OFF_DEBOUNCE = 0.05
        self.addCleanup(setattr, guards, "OFF_DEBOUNCE", old)
        reports = []
        group = Guards(lambda name, on: reports.append((name, on)), [Toggle])
        self.assertEqual(group.start(), set())
        toggle = group.by_name["fullscreen"]
        toggle.set(True)
        toggle.set(False)
        toggle.set(True)  # flapping back on cancels the pending off
        await asyncio.sleep(0.1)
        self.assertEqual(reports, [("fullscreen", True), ("fullscreen", True)])
        toggle.set(False)
        await asyncio.sleep(0.1)
        self.assertEqual(reports[-1], ("fullscreen", False))
        group.stop()
        self.assertEqual(group.availability(), {"fullscreen": "available"})

    async def test_dgpu_reads_runtime_status(self):
        with tempfile.TemporaryDirectory() as temp:
            status = Path(temp) / "runtime_status"
            status.write_text("suspended\n")
            reports = []
            guard = DgpuGuard(lambda name, on: reports.append(on), status)
            self.assertFalse(guard.start())
            status.write_text("active\n")
            guard._tick()
            guard.stop()
            self.assertEqual(reports, [True])


class HyprlandTests(unittest.TestCase):
    def test_fullscreen_only_counts_visible_workspaces(self):
        replies = {b"j/monitors": [{"activeWorkspace": {"id": 1, "name": "1"}, "specialWorkspace": {"id": 0, "name": ""}}],
                   b"j/workspaces": [{"id": 1, "hasfullscreen": False}, {"id": 2, "hasfullscreen": True}]}
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            server = socket.socket(socket.AF_UNIX)
            server.bind(str(directory / ".socket.sock"))
            server.listen()

            def serve():
                for _ in range(4):
                    conn, _ = server.accept()
                    with conn:
                        conn.sendall(json.dumps(replies[conn.recv(64)]).encode())
            thread = threading.Thread(target=serve, daemon=True)
            thread.start()
            self.assertFalse(any_fullscreen(directory))
            replies[b"j/workspaces"][0]["hasfullscreen"] = True
            self.assertTrue(any_fullscreen(directory))
            thread.join(2)
            server.close()


if __name__ == "__main__":
    unittest.main()
