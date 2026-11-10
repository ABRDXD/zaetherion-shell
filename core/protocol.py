"""JSON lines over a Unix socket: requests, replies and full-snapshot topic events (docs/CORE.md §2)."""
from __future__ import annotations

import asyncio
import inspect
import json
import logging
import os
import socket
import struct
from typing import Callable

from core.errors import OpError

log = logging.getLogger("fart.protocol")
PROTOCOL = 1
MAX_LINE = 1 << 20
MAX_BUFFER = 4 << 20


def encode(message: dict) -> bytes:
    return json.dumps(message, separators=(",", ":"), ensure_ascii=False).encode("utf-8", errors="backslashreplace") + b"\n"


class Client:
    def __init__(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        self.reader, self.writer = reader, writer
        sock = writer.get_extra_info("socket")
        creds = sock.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i")) if sock else b"\0" * 12
        self.pid, self.uid, _ = struct.unpack("3i", creds)
        self.kind: str | None = None
        self.topics: set[str] = set()
        self.closed = False

    def send(self, message: dict):
        if self.closed:
            return
        frame = encode(message)
        transport = self.writer.transport
        if transport.get_write_buffer_size() + len(frame) > MAX_BUFFER:
            log.warning("dropping a %s client over the output limit", self.kind or "new")
            self.closed = True
            transport.abort()
            return
        self.writer.write(frame)

    def close(self):
        if not self.closed:
            self.closed = True
            self.writer.close()


class Server:
    def __init__(self):
        self.ops: dict[str, Callable] = {}
        self.snapshots: dict[str, Callable[[], dict]] = {}
        self.revs: dict[str, int] = {}
        self.clients: set[Client] = set()
        self.on_disconnect: list[Callable[[Client], None]] = []
        self.op("subscribe", self.subscribe)
        self.op("unsubscribe", self.unsubscribe)

    def op(self, name: str, handler: Callable):
        """handler(client, **args) -> result; may be a coroutine."""
        self.ops[name] = handler

    def topic(self, name: str, snapshot: Callable[[], dict]):
        self.snapshots[name] = snapshot
        self.revs[name] = 0

    def publish(self, name: str):
        self.revs[name] += 1
        listeners = [c for c in self.clients if name in c.topics]
        if not listeners:
            return
        data = self.snapshots[name]()
        for client in listeners:
            client.send({"event": name, "rev": self.revs[name], "data": data})

    def push(self, client: Client, name: str, data: dict):
        client.send({"event": name, "rev": 0, "data": data})

    def subscribe(self, client: Client, topics):
        if not isinstance(topics, list) or not all(t in self.snapshots for t in topics):
            raise OpError("bad-args", f"topics must be a list from {', '.join(self.snapshots)}")
        client.topics.update(topics)
        return {"snapshots": {t: self.snapshots[t]() for t in topics}, "revs": {t: self.revs[t] for t in topics}}

    def unsubscribe(self, client: Client, topics):
        client.topics.difference_update(topics if isinstance(topics, list) else [])
        return {}

    async def handle(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        client = Client(reader, writer)
        if client.uid != os.getuid():
            log.warning("refused a peer with uid %d", client.uid)
            writer.close()
            return
        self.clients.add(client)
        try:
            while not client.closed:
                try:
                    line = await reader.readline()
                except (ValueError, asyncio.LimitOverrunError):
                    log.warning("closing a client that sent a line over %d bytes", MAX_LINE)
                    break
                except ConnectionError:
                    break
                if not line.endswith(b"\n"):
                    break  # EOF, including an incomplete last frame
                await self.dispatch(client, line)
        finally:
            self.clients.discard(client)
            client.close()
            for callback in self.on_disconnect:
                callback(client)

    async def dispatch(self, client: Client, line: bytes):
        try:
            message = json.loads(line.decode("utf-8"))
            # JSON escapes can introduce unpaired surrogates even in valid UTF-8.
            if b"\\u" in line:
                json.dumps(message, ensure_ascii=False).encode("utf-8")
        except (ValueError, RecursionError):
            return client.send({"id": None, "ok": False, "error": {"code": "bad-request", "message": "not JSON"}})
        request_id = message.get("id") if isinstance(message, dict) else None
        try:
            if not isinstance(message, dict) or not isinstance(message.get("op"), str):
                raise OpError("bad-request", "a request needs an op")
            op, args = message["op"], message.get("args", {})
            if not isinstance(args, dict):
                raise OpError("bad-request", "args must be an object")
            if client.kind is None and op != "hello":
                raise OpError("protocol", "send hello first")
            handler = self.ops.get(op)
            if handler is None:
                raise OpError("unknown-op", f"unknown op {op!r}")
            try:
                inspect.signature(handler).bind(client, **args)
            except TypeError as error:
                raise OpError("bad-args", str(error)) from None
            result = handler(client, **args)
            if inspect.isawaitable(result):
                result = await result
            reply = {"id": request_id, "ok": True, "result": result if result is not None else {}}
        except OpError as error:
            reply = {"id": request_id, "ok": False, "error": {"code": error.code, "message": error.message}}
        except Exception:
            log.exception("op failed")
            reply = {"id": request_id, "ok": False, "error": {"code": "internal", "message": "internal error; see the core log"}}
        if request_id is not None:
            client.send(reply)
        elif not reply["ok"]:
            log.info("notification %s failed: %s", message.get("op") if isinstance(message, dict) else "?", reply["error"]["code"])
