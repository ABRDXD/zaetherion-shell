"""S0: the recorded DMS fixtures are scrubbed (Z113) and replay over a socket like the real server.

The fixture comes from the first real `dms run` (docs/DMS_OBSERVED.md); nothing here talks to a real DMS."""
import json
from pathlib import Path
import re
import socket
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from dms_replay import Replay  # noqa: E402

FIXTURE = ROOT / "tests/fixtures/dms/s0-v2.1.0.json"


def strings(value, key=""):
    if isinstance(value, dict):
        for k, v in value.items():
            yield from strings(v, k)
    elif isinstance(value, list):
        for v in value:
            yield from strings(v, key)
    elif isinstance(value, str):
        yield key, value


class Scrubbed(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(FIXTURE.read_text())
        self.text = FIXTURE.read_text()

    def test_no_real_hardware_addresses(self):
        for mac in re.findall(r"(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}", self.text):
            self.assertEqual(mac, "00:00:00:00:00:00")

    def test_no_real_ip_addresses(self):
        for ip in re.findall(r"\b\d{1,3}(?:\.\d{1,3}){3}\b", self.text):
            self.assertEqual(ip, "192.0.2.1")

    def test_no_home_paths_but_the_placeholder(self):
        for home in re.findall(r"/home/[^/\"]+", self.text):
            self.assertEqual(home, "/home/user")

    def test_no_local_time_zone(self):
        for offset in re.findall(r"T[\d:.]+([+-]\d\d:\d\d)\"", self.text):
            self.assertEqual(offset, "+00:00")

    def test_identifying_fields_are_placeholders(self):
        identifying = re.compile(r"^(ssid|bssid|mac|hwaddr|serial|serialNumber|uuid|hostname|userName|realName|userPath)$", re.I)
        for key, value in strings(self.data):
            if identifying.match(key) and value:
                self.assertTrue(value.startswith("<"), f"{key} not scrubbed")


class Replays(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = self.dir.name + "/dms-test.sock"
        self.fixture = json.loads(FIXTURE.read_text())
        self.replay = Replay(self.fixture, self.path).start()

    def tearDown(self):
        self.replay.close()
        self.dir.cleanup()

    def connect(self):
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect(self.path)
        return sock, sock.makefile("rb")

    def call(self, sock, lines, rid, method):
        sock.sendall((json.dumps({"id": rid, "method": method, "params": {}}) + "\n").encode())
        return json.loads(lines.readline())

    def test_greeting_first_with_the_pinned_api(self):
        sock, lines = self.connect()
        with sock:
            greeting = json.loads(lines.readline())
        self.assertEqual(greeting["apiVersion"], 38)
        self.assertIn("network", greeting["capabilities"])
        self.assertNotIn("location", greeting["capabilities"])

    def test_recorded_reply_carries_the_request_id(self):
        sock, lines = self.connect()
        with sock:
            lines.readline()
            reply = self.call(sock, lines, 77, "wlroutput.getState")
        self.assertEqual(reply["id"], 77)
        self.assertEqual(reply["result"]["outputs"][0]["name"], "eDP-1")

    def test_unknown_method_is_an_error(self):
        sock, lines = self.connect()
        with sock:
            lines.readline()
            reply = self.call(sock, lines, 3, "weather.getState")
        self.assertEqual(reply, {"id": 3, "error": "unknown method: weather.getState"})

    def test_subscribe_replays_the_events(self):
        sock, lines = self.connect()
        with sock:
            lines.readline()
            sock.sendall(b'{"id": 1, "method": "subscribe", "params": {"clientId": "t"}}\n')
            services = {json.loads(lines.readline())["result"]["service"] for _ in self.fixture["events"]}
        self.assertIn("network", services)
        self.assertIn("server", services)

    def test_clipboard_history_never_recorded(self):
        self.assertNotIn("clipboard.getHistory", self.fixture["replies"])
        for event in self.fixture["events"]:
            if event.get("result", {}).get("service") == "clipboard":
                self.assertFalse(event["result"]["data"].get("history"))


if __name__ == "__main__":
    unittest.main()
