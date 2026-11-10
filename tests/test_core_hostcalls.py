"""Host calls from the core to the view's adapter: payload, replies, refusals, timeouts and disconnects."""
import asyncio
import unittest

import core_fakes  # noqa: F401  (puts the repository on sys.path)
from core.errors import OpError
from core.hostcalls import HostCalls


class FakeClient:
    def __init__(self):
        self.sent = []
        self.closed = False

    def send(self, message):
        self.sent.append(message)


class FakeView:
    def __init__(self):
        self.client = FakeClient()
        self.ensured = 0

    async def ensure(self):
        self.ensured += 1


class HostCallTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.view = FakeView()
        self.calls = HostCalls(self.view, timeout=0.5)

    async def answer(self, **reply):
        while not self.view.client.sent:
            await asyncio.sleep(0)
        self.sent = self.view.client.sent.pop()
        token = self.sent["data"]["token"]
        self.calls.done(self.view.client, token, **reply)

    async def test_call_sends_one_event_and_returns_the_read(self):
        task = asyncio.create_task(self.calls.call("audio", "setVolume", [{"$": "output.id"}, 0.4], lease="mixer",
                                                   ready="output", read="output"))
        await self.answer(ok=True, result={"read": {"id": "1", "volume": 0.4}})
        self.assertEqual(await task, {"id": "1", "volume": 0.4})
        self.assertEqual(self.view.ensured, 1)
        self.assertEqual(self.sent["event"], "view.host")
        self.assertEqual(self.sent["data"], {"token": 1, "domain": "audio", "method": "setVolume",
                                         "args": [{"$": "output.id"}, 0.4], "lease": "mixer", "ready": "output",
                                         "read": "output", "hold": 300, "linger": 0})
        self.assertEqual(self.calls.pending, {})

    async def test_errors_from_the_view_keep_known_codes_only(self):
        task = asyncio.create_task(self.calls.call("audio", read="output", lease="mixer"))
        await self.answer(ok=False, error={"code": "not-found", "message": "no sink"})
        with self.assertRaises(OpError) as caught:
            await task
        self.assertEqual((caught.exception.code, caught.exception.message), ("not-found", "no sink"))
        task = asyncio.create_task(self.calls.call("audio", read="output"))
        await self.answer(ok=False, error={"code": "internal", "message": "x" * 500})
        with self.assertRaises(OpError) as caught:
            await task
        self.assertEqual(caught.exception.code, "unavailable")
        self.assertEqual(len(caught.exception.message), 200)

    async def test_only_listed_calls_and_leases_are_sent(self):
        for args in (("audio", "acquire"), ("audio", "record"), ("palette", None), ("audio", "setVolume", [], "brightness"),
                     ("audio", None, [], None, "output; x"), ("audio", "setVolume", [{"$": "a", "b": 1}])):
            with self.subTest(args=args), self.assertRaises(OpError):
                await self.calls.call(*args)
        self.assertEqual(self.view.client.sent, [])

    async def test_a_lost_reply_times_out(self):
        with self.assertRaises(OpError) as caught:
            await self.calls.call("media", "next")
        self.assertEqual(caught.exception.code, "unavailable")
        self.assertEqual(self.calls.pending, {})
        self.calls.done(self.view.client, 1, ok=True)  # late: ignored

    async def test_disconnect_fails_only_that_clients_calls(self):
        task = asyncio.create_task(self.calls.call("media", "next"))
        await asyncio.sleep(0)
        self.calls.disconnected(FakeClient())
        self.assertFalse(task.done())
        self.calls.disconnected(self.view.client)
        with self.assertRaises(OpError):
            await task

    async def test_only_the_view_answers(self):
        task = asyncio.create_task(self.calls.call("media", "next"))
        await asyncio.sleep(0)
        with self.assertRaises(OpError) as caught:
            self.calls.done(FakeClient(), 1, ok=True)
        self.assertEqual(caught.exception.code, "refused")
        self.calls.done(self.view.client, 1, ok=True)
        self.assertIsNone(await task)


if __name__ == "__main__":
    unittest.main()
