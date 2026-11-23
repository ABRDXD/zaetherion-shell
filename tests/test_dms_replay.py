"""tools/dms_replay.py, the stand-in DMS: subscribe honours `services`, the request log, and the script.

The base replay behaviour is in test_dms_fixtures.py; everything here is the F2 additions (docs/DMS_ADAPTER.md §9.1).
Scripted replies are synthetic."""
import json
from pathlib import Path
import socket
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from dms_replay import Replay  # noqa: E402

FIXTURE = json.loads((ROOT / "tests/fixtures/dms/s0-v2.1.0.json").read_text())


class StandIn(unittest.TestCase):
    def start(self, script=None, log=True):
        self.dir = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.addCleanup(self.dir.cleanup)
        self.path = self.dir.name + "/dms-test.sock"
        self.log = self.dir.name + "/requests.jsonl" if log else None
        self.replay = Replay(FIXTURE, self.path, self.log, script).start()
        self.addCleanup(self.replay.close)

    def connect(self):
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(2)
        sock.connect(self.path)
        self.addCleanup(sock.close)
        lines = sock.makefile("rb")
        return sock, lines, json.loads(lines.readline())

    def send(self, sock, rid, method, params=None):
        sock.sendall((json.dumps({"id": rid, "method": method, "params": params or {}}) + "\n").encode())

    def log_lines(self):
        time.sleep(0.1)
        return [json.loads(l) for l in Path(str(self.log)).read_text().splitlines()]

    def read_services(self, lines, count):
        return [json.loads(lines.readline())["result"]["service"] for _ in range(count)]


class Subscribe(StandIn):
    def test_only_the_listed_services_come_after_server(self):
        self.start()
        sock, lines, _ = self.connect()
        self.send(sock, 1, "subscribe", {"clientId": "t", "services": ["network"]})
        self.assertEqual(self.read_services(lines, 2), ["server", "network"])
        sock.settimeout(0.3)
        with self.assertRaises(TimeoutError):
            lines.readline()

    def test_server_comes_first_whatever_the_order_asked_for(self):
        self.start()
        sock, lines, _ = self.connect()
        self.send(sock, 1, "subscribe", {"services": ["gamma", "network", "brightness"]})
        services = self.read_services(lines, 4)
        self.assertEqual(services[0], "server")
        self.assertEqual(sorted(services[1:]), ["brightness", "gamma", "network"])

    def test_without_services_everything_is_sent(self):
        self.start()
        sock, lines, _ = self.connect()
        self.send(sock, 1, "subscribe", {"clientId": "t"})
        self.assertEqual(len(self.read_services(lines, len(FIXTURE["events"]))), len(FIXTURE["events"]))

    def test_a_service_the_fixture_lacks_is_skipped(self):
        self.start()
        sock, lines, _ = self.connect()
        self.send(sock, 1, "subscribe", {"services": ["no-such-service"]})
        self.assertEqual(self.read_services(lines, 1), ["server"])


class RequestLog(StandIn):
    def test_open_request_and_close_are_logged_per_connection(self):
        self.start()
        sock, lines, _ = self.connect()
        self.send(sock, 5, "network.getState")
        lines.readline()
        lines.close()
        sock.close()
        other, _, _ = self.connect()
        self.send(other, 1, "subscribe", {"services": ["network"]})
        entries = self.log_lines()
        first = [e for e in entries if e["conn"] == 1]
        self.assertEqual([e["event"] for e in first], ["open", "request", "close"])
        self.assertEqual((first[1]["id"], first[1]["method"], first[1]["params"]), (5, "network.getState", {}))
        second = [e for e in entries if e["conn"] == 2]
        self.assertEqual(second[1]["params"], {"services": ["network"]})

    def test_no_log_file_unless_asked(self):
        self.start(log=False)
        sock, lines, _ = self.connect()
        self.send(sock, 1, "network.getState")
        lines.readline()
        self.assertIsNone(self.log)


class Script(StandIn):
    def test_a_scripted_reply_replaces_the_recorded_one(self):
        self.start({"replies": {"network.wifi.toggle": {"result": {"enabled": False}}, "network.getState": {"error": "fake failure"}}})
        sock, lines, _ = self.connect()
        self.send(sock, 3, "network.wifi.toggle")
        self.assertEqual(json.loads(lines.readline()), {"id": 3, "result": {"enabled": False}})
        self.send(sock, 4, "network.getState")
        self.assertEqual(json.loads(lines.readline()), {"id": 4, "error": "fake failure"})

    def test_a_silent_method_is_never_answered_but_is_logged(self):
        self.start({"silent": ["network.wifi.scan"]})
        sock, lines, _ = self.connect()
        self.send(sock, 1, "network.wifi.scan")
        sock.settimeout(0.3)
        with self.assertRaises(TimeoutError):
            lines.readline()
        self.assertIn("network.wifi.scan", [e.get("method") for e in self.log_lines()])

    def test_events_follow_a_method_to_subscribers_who_asked_for_the_service(self):
        pushed = {"service": "network", "data": {"wifiEnabled": False, "synthetic": True}}
        self.start({"after": {"network.wifi.toggle": [pushed]}})
        subscriber, sub_lines, _ = self.connect()
        self.send(subscriber, 1, "subscribe", {"services": ["network"]})
        self.read_services(sub_lines, 2)
        quiet, quiet_lines, _ = self.connect()
        self.send(quiet, 1, "subscribe", {"services": ["gamma"]})
        self.read_services(quiet_lines, 2)
        caller, caller_lines, _ = self.connect()
        self.send(caller, 9, "network.wifi.toggle")
        self.assertEqual(json.loads(caller_lines.readline())["id"], 9)
        self.assertEqual(json.loads(sub_lines.readline()), {"id": 1, "result": pushed})
        quiet.settimeout(0.3)
        with self.assertRaises(TimeoutError):
            quiet_lines.readline()


if __name__ == "__main__":
    unittest.main()
