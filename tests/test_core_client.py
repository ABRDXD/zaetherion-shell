"""Real offscreen QML socket client against a scripted private Unix server."""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ENTRY = """import QtQuick
import Quickshell
import qs.core.client
Scope {
    CoreClient {
        id: client
        property int handshakes: 0
        onConnectedChanged: {
            if (!connected) return;
            if (++handshakes === 1)
                request("fixture.pending", {}, (ok, error) => console.log("PENDING", ok, error.code));
            else {
                console.log("RECOVERED", tasksData.generation);
                Qt.quit();
            }
        }
    }
}
"""


class ClientTests(unittest.TestCase):
    def test_refusals_and_disconnect_recover_with_fresh_snapshots(self):
        with tempfile.TemporaryDirectory() as tmp, socket.socket(socket.AF_UNIX) as server:
            base = Path(tmp)
            shutil.copytree(ROOT / "core/client", base / "core/client")
            entry = base / "ClientTest.qml"
            entry.write_text(ENTRY)
            path = str(base / "fixture.sock")
            server.bind(path)
            server.listen()
            server.settimeout(6)
            env = dict(PATH=os.defpath, HOME=tmp, XDG_RUNTIME_DIR=tmp,
                       XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"),
                       XDG_STATE_HOME=str(base / "state"), FART_CORE_SOCKET=path, QT_QPA_PLATFORM="offscreen",
                       QT_QUICK_BACKEND="software", DBUS_SESSION_BUS_ADDRESS=f"unix:path={base}/no-bus")
            with subprocess.Popen(["qs", "-n", "-p", str(entry)], env=env, cwd=base,
                                  stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
                try:
                    for attempt in range(4):
                        with server.accept()[0] as peer, peer.makefile("rb") as stream:
                            peer.settimeout(4)
                            for op in ("hello", "subscribe"):
                                req = json.loads(stream.readline())
                                self.assertEqual(req["op"], op)
                                refuse = (attempt, op) in ((0, "hello"), (1, "subscribe"))
                                reply = {"id": req["id"], "ok": not refuse}
                                if refuse:
                                    reply["error"] = {"code": "refused", "message": "fixture"}
                                else:
                                    reply["result"] = {"snapshots": {t: None for t in req["args"].get("topics", [])}}
                                    reply["result"]["snapshots"]["tasks"] = {"generation": attempt}
                                peer.sendall(json.dumps(reply).encode() + b"\n")
                                if refuse:
                                    # The client must close this healthy transport on refusal.
                                    self.assertEqual(stream.readline(), b"")
                                    break
                            if attempt == 2:
                                self.assertEqual(json.loads(stream.readline())["op"], "fixture.pending")
                            if attempt == 3:
                                self.assertEqual(process.wait(timeout=4), 0)
                    output = process.stdout.read()
                    self.assertIn("PENDING false unavailable", output)
                    self.assertIn("RECOVERED 3", output)
                finally:
                    if process.poll() is None:
                        process.kill()
