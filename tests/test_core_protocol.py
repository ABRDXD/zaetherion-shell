"""Protocol backpressure on private Unix sockets."""
import asyncio
import json
from pathlib import Path
import socket
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from core.protocol import Server


class EnvelopeTests(unittest.IsolatedAsyncioTestCase):
    async def test_only_an_omitted_args_field_defaults_to_an_object(self):
        app = Server()
        rows = ["fixture"]
        app.op("clear", lambda peer: rows.clear())
        replies = []
        peer = SimpleNamespace(kind="cli", send=replies.append)
        request = {"id": 1, "op": "clear"}
        for args in ([], "", False, 0, None):
            with self.subTest(args=args):
                await app.dispatch(peer, json.dumps(dict(request, args=args)).encode())
                self.assertEqual(replies[-1]["error"]["code"], "bad-request")
                self.assertEqual(rows, ["fixture"])
        await app.dispatch(peer, json.dumps(request).encode())
        self.assertTrue(replies[-1]["ok"])
        self.assertEqual(rows, [])


class SlowPeerTests(unittest.IsolatedAsyncioTestCase):
    async def test_stalled_subscriber_drops_backlog_and_other_peer_stays_connected(self):
        app = Server()
        def hello(peer):
            peer.kind = "cli"
        app.op("hello", hello)
        subscribed = asyncio.Event()
        dropped = asyncio.Event()
        app.on_disconnect.append(lambda peer: dropped.set() if "load" in peer.topics else None)
        def snapshot():
            subscribed.set()
            return "x" * 8192
        app.topic("load", snapshot)
        with tempfile.TemporaryDirectory() as directory, patch("core.protocol.MAX_BUFFER", 16384):
            path = str(Path(directory) / "socket")
            async with await asyncio.start_unix_server(app.handle, path):
                reader, writer = await asyncio.open_unix_connection(path)
                try:
                    with socket.socket(socket.AF_UNIX) as stalled:
                        stalled.connect(path)
                        stalled.sendall(b'{"op":"hello","id":1}\n{"op":"subscribe","id":2,"args":{"topics":["load"]}}\n')
                        await asyncio.wait_for(subscribed.wait(), 2)
                        for _ in range(256):
                            app.publish("load")
                        await asyncio.wait_for(dropped.wait(), 2)
                        writer.write(b'{"op":"hello","id":3}\n')
                        self.assertEqual(json.loads(await asyncio.wait_for(reader.readline(), 2))["id"], 3)
                finally:
                    writer.close()
                    await writer.wait_closed()
