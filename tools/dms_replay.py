#!/usr/bin/env python3
"""A stand-in DMS server that replays a recorded fixture (tests/fixtures/dms/*.json) over a Unix socket.

Same protocol as the real `dms` (docs/DMS_BACKEND.md, docs/DMS_OBSERVED.md): on connect it sends the recorded
greeting line; a request gets the recorded reply for its method with the request's own id, or
{"id", "error": "unknown method: …"}; `subscribe` gets the recorded events. Nothing real is touched, so tests
and offscreen runs can use it in place of DMS.

    python3 tools/dms_replay.py FIXTURE SOCKET [--log FILE] [--script FILE]

`subscribe` honours `services`: the `server` event always comes first, then one snapshot per listed service
that the fixture has. Without `services` it sends everything, as the real DMS does (the adapter must never
ask for that, docs/DMS_ADAPTER.md §2).

--log FILE appends one JSON line per fact: {"conn", "event": "open" | "request" | "close"}; a request line has
"id", "method", "params". Tests read it to see what the adapter sent and which connection carried it.

--script FILE (or `script=` as a dict) makes the stand-in say what a test needs, all synthetic:
    {"replies": {"<method>": {"result": …} | {"error": "…"}},   replaces the recorded reply of that method
     "silent":  ["<method>", …],                                 never answered (for timeouts)
     "after":   {"<method>": [{"service": "…", "data": …}, …]}}  pushed to every subscriber after that method
"""
import json
import os
import socket
import sys
import threading


class Replay:
    def __init__(self, fixture: dict, path: str, log_path: str | None = None, script: dict | None = None):
        self.fixture = fixture
        self.path = path
        self.log_path = log_path
        self.script = script or {}
        self.lock = threading.Lock()
        self.subscribers = []
        self.connections = 0
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
            with self.lock:
                self.connections += 1
                number = self.connections
            threading.Thread(target=self._serve, args=(conn, number), daemon=True).start()

    def _log(self, number, event, **fields):
        if not self.log_path:
            return
        with self.lock, open(self.log_path, "a") as out:
            out.write(json.dumps(dict(conn=number, event=event, **fields)) + "\n")

    def _send(self, conn, obj):
        data = (json.dumps(obj) + "\n").encode()
        with self.lock:
            try:
                conn.sendall(data)
            except OSError:
                pass

    def _snapshots(self, services):
        events = self.fixture.get("events", [])
        if services is None:
            return events
        wanted = set(services) | {"server"}
        picked = [e for e in events if e.get("result", {}).get("service") in wanted]
        picked.sort(key=lambda e: e["result"]["service"] != "server")    # server first, the rest in recorded order
        return picked

    def _push(self, events):
        with self.lock:
            targets = list(self.subscribers)
        for conn, services in targets:
            for event in events:
                if services is None or event["service"] in services or event["service"] == "server":
                    self._send(conn, {"id": 1, "result": event})

    def _serve(self, conn, number):
        self._log(number, "open")
        try:
            self._requests(conn, number)
        except OSError:
            pass                                    # a peer that vanished (SIGKILL, reset) is an ordinary close
        with self.lock:
            self.subscribers = [s for s in self.subscribers if s[0] is not conn]
        self._log(number, "close")

    def _requests(self, conn, number):
        with conn, conn.makefile("rb") as lines:
            self._send(conn, self.fixture["greeting"])
            for line in lines:
                try:
                    req = json.loads(line)
                except ValueError:
                    continue
                method, rid = req.get("method"), req.get("id")
                self._log(number, "request", id=rid, method=method, params=req.get("params"))
                if method == "subscribe":
                    services = (req.get("params") or {}).get("services")
                    with self.lock:
                        self.subscribers.append((conn, None if services is None else set(services)))
                    for event in self._snapshots(services):
                        self._send(conn, event)
                    continue
                if method in self.script.get("silent", []):
                    continue
                scripted = self.script.get("replies", {}).get(method)
                recorded = scripted or self.fixture["replies"].get(method)
                if recorded is None:
                    self._send(conn, {"id": rid, "error": f"unknown method: {method}"})
                else:
                    self._send(conn, dict(recorded, id=rid))
                self._push(self.script.get("after", {}).get(method, []))


if __name__ == "__main__":
    args = sys.argv[1:]
    options = {}
    for flag in ("--log", "--script"):
        if flag in args:
            i = args.index(flag)
            options[flag] = args[i + 1]
            del args[i:i + 2]
    fixture_path, sock_path = args[0], args[1]
    script = json.load(open(options["--script"])) if "--script" in options else None
    replay = Replay(json.load(open(fixture_path)), sock_path, options.get("--log"), script).start()
    print(f"replaying {fixture_path} on {sock_path}", flush=True)
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        replay.close()
