"""The real core process and CLI on private directories, with the fixture host: no view, no bus, no host actions."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "tools/fart_next.py"


class DaemonTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        base = Path(cls.temp.name)
        cls.runtime = base / "run"
        cls.fixture_log = base / "fixture.jsonl"
        home = base / "home"
        cls.env = dict(os.environ, FART_RUNTIME_DIR=str(cls.runtime), FART_HOST="fixture", FART_MIRROR="0",
                       FART_FIXTURE_LOG=str(cls.fixture_log), XDG_STATE_HOME=str(home / "state"),
                       XDG_CACHE_HOME=str(home / "cache"), XDG_CONFIG_HOME=str(home / "config"),
                       FART_VIEW_ENTRY=str(base / "no-view.qml"))  # a press may try to spawn; nothing is there
        cls.state = home / "state/fart-next"
        (home / "state/fart").mkdir(parents=True)
        (home / "state/fart/todo.json").write_text(json.dumps([{"content": f"t{n}", "done": False} for n in range(12)]))

    @classmethod
    def tearDownClass(cls):
        cls.cli("stop")
        cls.temp.cleanup()

    @classmethod
    def cli(cls, *args):
        return subprocess.run([sys.executable, "-I", str(CLI), *args], env=cls.env, capture_output=True, text=True, timeout=20)

    def raw(self):
        sock = socket.socket(socket.AF_UNIX)
        sock.settimeout(5)
        sock.connect(str(self.runtime / "core.sock"))
        self.addCleanup(sock.close)
        return sock, sock.makefile("rb")

    def test_0_a_release_without_a_core_starts_nothing(self):
        out = self.cli("key", "up")
        self.assertEqual((out.returncode, out.stdout, out.stderr), (0, "", ""))
        self.assertFalse((self.runtime / "core.sock").exists())

    def test_1_starts_on_demand_and_migrates(self):
        out = self.cli("--json", "status")
        self.assertEqual(json.loads(out.stdout)["core"], "stopped")
        self.assertEqual(self.cli("start").returncode, 0)
        status = json.loads(self.cli("--json", "status").stdout)
        self.assertEqual(status["tasks"], {"lists": 1, "open": 12, "done": 0})
        self.assertEqual(status["view"]["state"], "absent")
        self.assertEqual(status["overdrive"]["requested"]["mode"], "off")
        self.assertEqual((self.runtime / "core.sock").stat().st_mode & 0o777, 0o600)
        self.assertLess(status["core"]["rssKiB"], 25 * 1024)

    def test_2_alarm_fires_without_a_view(self):
        self.cli("start")
        out = self.cli("tim", "1s")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("countdown", out.stdout)
        deadline = time.time() + 5
        while time.time() < deadline:
            calls = [json.loads(l) for l in self.fixture_log.read_text().splitlines()] if self.fixture_log.exists() else []
            if any(c[0] == "notify" for c in calls):
                break
            time.sleep(0.05)
        self.assertIn(["notify", "Timers", "⏰ Countdown finished"], calls)
        self.assertIn("countdown DONE", self.cli("status").stdout)
        self.cli("tim", "stop")
        self.assertIn("Timers: idle", self.cli("status").stdout)

    def test_3_protocol_errors(self):
        self.cli("start")
        sock, reader = self.raw()
        sock.sendall(b'{"id":1,"op":"status"}\n')
        self.assertEqual(json.loads(reader.readline())["error"]["code"], "protocol")
        sock.sendall(b'{"id":2,"op":"hello","args":{"client":"cli","protocol":1}}\n')
        self.assertTrue(json.loads(reader.readline())["ok"])
        sock.sendall(b'not json\n{"id":3,"op":"egg"}\n{"id":4,"op":"timer.start","args":{"kind":"countdown","bogus":1}}\n')
        codes = [json.loads(reader.readline())["error"]["code"] for _ in range(3)]
        self.assertEqual(codes, ["bad-request", "unknown-op", "bad-args"])
        sock.sendall(b'{"id":5,"op":"hello","args":{"client":"view","protocol":1}}\n')
        self.assertEqual(json.loads(reader.readline())["error"]["code"], "refused")

    def test_3_unicode_rejection_and_legacy_snapshot(self):
        self.assertEqual(self.cli("start").returncode, 0)
        self.cli("stop")
        path = self.state / "tasks.json"
        saved = json.loads(path.read_text())
        self.addCleanup(path.write_text, json.dumps(saved))
        legacy = json.loads(json.dumps(saved))
        legacy["tasks"][0]["text"] = "\ud800"
        path.write_text(json.dumps(legacy))
        self.assertEqual(self.cli("start").returncode, 0)
        self.addCleanup(self.cli, "stop")
        sock, reader = self.raw()
        self.addCleanup(reader.close)
        sock.sendall(b'{"op":"hello","id":1,"args":{"client":"cli","protocol":1}}\n'
                     b'{"op":"task.add","id":2,"args":{"text":"\\ud800"}}\n'
                     b'{"op":"subscribe","id":3,"args":{"topics":["tasks"]}}\n')
        self.assertTrue(json.loads(reader.readline())["ok"])
        self.assertEqual(json.loads(reader.readline())["error"]["code"], "bad-request")
        rows = json.loads(reader.readline())["result"]["snapshots"]["tasks"]["tasks"]
        self.assertEqual(rows, legacy["tasks"])

    def test_4_reply_follows_its_event(self):
        self.cli("start")
        sock, reader = self.raw()
        sock.sendall(b'{"id":1,"op":"hello","args":{"client":"cli","protocol":1}}\n'
                     b'{"id":2,"op":"subscribe","args":{"topics":["tasks"]}}\n'
                     b'{"id":3,"op":"task.add","args":{"text":"from the socket"}}\n')
        messages = [json.loads(reader.readline()) for _ in range(4)]
        self.assertEqual([m.get("id", m.get("event")) for m in messages], [1, 2, "tasks", 3])
        self.assertEqual(messages[2]["data"]["tasks"][-1]["text"], "from the socket")
        sock.sendall(json.dumps({"id": 4, "op": "task.remove", "args": {"id": messages[3]["result"]["task"]["id"]}}).encode() + b"\n")

    def test_5_exact_limit_and_incomplete_eof(self):
        self.cli("start")
        sock, reader = self.raw()
        self.addCleanup(reader.close)
        sock.sendall(b'{"id":1,"op":"hello","args":{"client":"cli","protocol":1}}\n')
        self.assertTrue(json.loads(reader.readline())["ok"])
        sock.sendall(b'{"id":2,"op":"status"}'.ljust(1 << 20) + b"\n")
        before = json.loads(reader.readline())["result"]["tasks"]
        sock.sendall(b'{"id":3,"op":"task.add","args":{"text":"fixture"}}')
        sock.shutdown(socket.SHUT_WR)
        self.assertEqual(reader.readline(), b"")
        self.assertEqual(json.loads(self.cli("--json", "status").stdout)["tasks"], before)

    def test_5_oversized_line_closes_only_that_client(self):
        self.cli("start")
        sock, reader = self.raw()
        sock.sendall(b'{"id":1,"op":"hello","args":{"client":"cli","protocol":1}}\n')
        reader.readline()
        try:
            sock.sendall(b"x" * (2 << 20) + b"\n")
        except (BrokenPipeError, ConnectionResetError):
            pass
        try:
            self.assertEqual(reader.readline(), b"")
        except ConnectionResetError:
            pass
        self.assertEqual(self.cli("status").returncode, 0)

    def test_6_overdrive_and_session_verbs(self):
        self.cli("start")
        out = self.cli("overdrive", "20m")
        self.assertRegex(out.stdout, r"^timed, \d+:\d\d left · (active|suspended)")
        self.assertEqual(self.cli("overdrive", "off").stdout.strip(), "off")
        self.assertIn("pyq,", self.cli("session", "pyq", "2h").stdout)
        self.assertEqual(self.cli("session", "pyq", "2h").returncode, 1)
        self.assertEqual(self.cli("session", "end").stdout.strip(), "none")
        log = (self.state / "sessions.jsonl").read_text().splitlines()
        self.assertEqual(json.loads(log[-1])["preset"], "pyq")
        self.assertEqual(self.cli("tim", "soon").returncode, 2)

    def test_6_key_edges_reach_the_ignite_machine(self):
        self.cli("start")
        down = self.cli("--json", "key", "down")
        self.assertEqual(json.loads(down.stdout)["action"], "open")
        up = json.loads(self.cli("--json", "key", "up").stdout)
        # Two Python start-ups apart: either released or fired, and either way the meter is down.
        self.assertIn(up["action"], ("released", "fired"))
        self.assertFalse(up["holding"])
        self.assertEqual(json.loads(self.cli("--json", "key", "up").stdout)["action"], "ignored")
        self.assertEqual(self.cli("key", "sideways").returncode, 2)

    def test_6_the_bare_edges_take_the_fast_path(self):
        # `key down|up` without --json is the bind's form, sent before the CLI's imports (COLDSTART.md).
        self.cli("stop")
        down = self.cli("key", "down")  # no core: falls through to the full CLI, which starts one
        self.assertEqual((down.returncode, down.stdout, down.stderr), (0, "", ""))
        self.assertIn(json.loads(self.cli("--json", "key", "up").stdout)["action"], ("released", "fired"))
        self.assertEqual(self.cli("key", "down").returncode, 0)  # the core is up: the fast path
        up = self.cli("key", "up")
        self.assertEqual((up.returncode, up.stdout, up.stderr), (0, "", ""))
        self.assertEqual(json.loads(self.cli("--json", "key", "up").stdout)["action"], "ignored")  # that up landed

    def test_7_stop_removes_the_socket(self):
        self.cli("start")
        self.cli("stop")
        self.assertFalse((self.runtime / "core.sock").exists())
        self.assertEqual(json.loads(self.cli("--json", "status").stdout)["core"], "stopped")


if __name__ == "__main__":
    unittest.main()
