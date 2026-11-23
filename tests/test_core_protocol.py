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


class SameConnectionAnswerTests(unittest.IsolatedAsyncioTestCase):
    """A request from the view that waits on a host call the view answers (wallpaper.choose → wallpaper.set →
    host.done) must not wait behind itself: host.done is read while the request is still running."""

    async def serve(self, app, script):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / "socket")
            async with await asyncio.start_unix_server(app.handle, path):
                reader, writer = await asyncio.open_unix_connection(path)
                try:
                    return await script(reader, writer)
                finally:
                    writer.close()

    def app_with_hello(self):
        app = Server()
        def hello(peer):
            peer.kind = "view"
        app.op("hello", hello)
        return app

    async def test_host_done_from_the_same_connection_answers_its_request(self):
        app = self.app_with_hello()
        answer = None
        async def ask(peer):
            nonlocal answer
            answer = asyncio.get_running_loop().create_future()
            return {"read": await asyncio.wait_for(answer, 3)}
        app.op("ask", ask)
        app.op("host.done", lambda peer, token, ok, result=None, error=None: answer.set_result(result["read"]))

        async def script(reader, writer):
            writer.write(b'{"op":"hello","id":1}\n{"op":"ask","id":2}\n')
            self.assertEqual(json.loads(await asyncio.wait_for(reader.readline(), 2))["id"], 1)
            await asyncio.sleep(0.05)  # the ask is running, waiting for its answer
            writer.write(b'{"op":"host.done","args":{"token":1,"ok":true,"result":{"read":"set"}}}\n')
            reply = json.loads(await asyncio.wait_for(reader.readline(), 1))
            self.assertEqual((reply["id"], reply["ok"], reply["result"]), (2, True, {"read": "set"}))
        await self.serve(app, script)

    async def test_other_requests_still_run_one_at_a_time_in_order(self):
        app = self.app_with_hello()
        seen = []
        async def slow(peer, n):
            seen.append(("start", n))
            await asyncio.sleep(0.05 if n == 1 else 0)
            seen.append(("end", n))
            return {"n": n}
        app.op("slow", slow)

        async def script(reader, writer):
            writer.write(b'{"op":"hello","id":1}\n{"op":"slow","id":2,"args":{"n":1}}\n{"op":"slow","id":3,"args":{"n":2}}\n')
            ids = [json.loads(await asyncio.wait_for(reader.readline(), 2))["id"] for _ in range(3)]
            self.assertEqual(ids, [1, 2, 3])
            self.assertEqual(seen, [("start", 1), ("end", 1), ("start", 2), ("end", 2)])
        await self.serve(app, script)
