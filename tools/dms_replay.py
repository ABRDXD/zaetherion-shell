#!/usr/bin/env python3
"""A stand-in DMS server that replays a recorded fixture (tests/fixtures/dms/*.json) over a Unix socket.

Same protocol as the real `dms` (docs/DMS_BACKEND.md, docs/DMS_OBSERVED.md): on connect it sends the recorded
greeting line; a request gets the recorded reply for its method with the request's own id, or
{"id", "error": "unknown method: …"}; `subscribe` gets the recorded events. Nothing real is touched, so tests
and offscreen runs can use it in place of DMS.

    python3 tools/dms_replay.py FIXTURE SOCKET
"""
import json
import os
import socket
import sys
import threading


class Replay:
    def __init__(self, fixture: dict, path: str):
        self.fixture = fixture
        self.path = path
        self.server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        if os.path.exists(path):
            os.unlink(path)
        self.server.bind(path)
        os.chmod(path, 0o600)
        self.server.listen()
        self.thread = threading.Thread(target=self._accept, daemon=True)

    def start(self):
        self.thread.start()
        return self

    def close(self):
        self.server.close()
        if os.path.exists(self.path):
            os.unlink(self.path)

    def _accept(self):
        while True:
            try:
                conn, _ = self.server.accept()
            except OSError:
                return
            threading.Thread(target=self._serve, args=(conn,), daemon=True).start()

    def _send(self, conn, obj):
        conn.sendall((json.dumps(obj) + "\n").encode())

    def _serve(self, conn):
        with conn, conn.makefile("rb") as lines:
            self._send(conn, self.fixture["greeting"])
            for line in lines:
                try:
                    req = json.loads(line)
                except ValueError:
                    continue
                method, rid = req.get("method"), req.get("id")
                if method == "subscribe":
                    for event in self.fixture.get("events", []):
                        self._send(conn, event)
                    continue
                recorded = self.fixture["replies"].get(method)
                if recorded is None:
                    self._send(conn, {"id": rid, "error": f"unknown method: {method}"})
                else:
                    self._send(conn, dict(recorded, id=rid))


if __name__ == "__main__":
    fixture_path, sock_path = sys.argv[1], sys.argv[2]
    replay = Replay(json.load(open(fixture_path)), sock_path).start()
    print(f"replaying {fixture_path} on {sock_path}", flush=True)
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        replay.close()
