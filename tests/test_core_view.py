"""View spawn, handshake and reaping with a fake process and the fake clock (docs/CORE.md §7)."""
import asyncio
import threading
import unittest

from core_fakes import fakes
import core.view as view_module
from core.errors import OpError
from core.view import REAP_AFTER, ViewManager


class FakeProcess:
    def __init__(self, pid, exit_at_once=False):
        self.pid = pid
        self.exit = asyncio.get_running_loop().create_future()
        self.signals = []
        if exit_at_once:
            self.exit.set_result(1)

    async def wait(self):
        return await asyncio.shield(self.exit)

    def terminate(self):
        self.signals.append("TERM")
        if not self.exit.done():
            self.exit.set_result(-15)

    def kill(self):
        self.signals.append("KILL")


class FakeClient:
    def __init__(self, pid):
        self.pid = pid
        self.closed = False
        self.sent = []

    def send(self, message):
        self.sent.append(message)


class ViewTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.clock, self.scheduler, _, _ = fakes()
        self.processes = []
        self.exit_at_once = False
        self.triggers = []
        self.closed_events = 0
        self.view = ViewManager(self.clock, self.scheduler, self.spawn, lambda: None, pressure=self.pressure)
        self.view.on_closed.append(self.count_closed)

    def count_closed(self):
        self.closed_events += 1

    async def spawn(self):
        process = FakeProcess(1000 + len(self.processes), self.exit_at_once)
        self.processes.append(process)
        if not self.exit_at_once:
            asyncio.get_running_loop().call_soon(self.view.hello, FakeClient(process.pid))
        return process

    def pressure(self, callback):
        trigger = type("Trigger", (), {"close": lambda self: None})()
        self.triggers.append(callback)
        return trigger

    async def settle(self):
        for _ in range(5):
            await asyncio.sleep(0)

    async def open_then_close(self):
        await self.view.command("open", "tasks")
        self.view.report(True, "tasks")
        self.view.report(False, "tasks")

    async def test_open_spawns_and_delivers_the_command(self):
        snapshot = await self.view.command("open", "timers", {"x": 1, "y": 2, "width": 3, "height": 4})
        self.assertEqual(snapshot["state"], "ready")
        self.assertEqual(self.view.client.sent[-1]["data"], {"action": "open", "page": "timers",
                                                            "from": {"x": 1, "y": 2, "width": 3, "height": 4}})
        with self.assertRaises(OpError):
            await self.view.command("open", "kitchen")

    async def test_screen_and_focus_travel_with_the_command(self):
        await self.view.command("open", "home", screen="eDP-1", focus="cmdline")
        self.assertEqual(self.view.client.sent[-1]["data"], {"action": "open", "page": "home", "from": None,
                                                            "screen": "eDP-1", "focus": "cmdline"})
        await self.view.command("open", "home", screen="")
        self.assertNotIn("screen", self.view.client.sent[-1]["data"])  # empty: the focused screen
        await self.view.command("open", None, fly="wifi")
        self.assertEqual(self.view.client.sent[-1]["data"]["fly"], "wifi")
        await self.view.command("open", None, fly="")
        self.assertEqual(self.view.client.sent[-1]["data"]["fly"], "")
        for bad in ({"screen": "x" * 65}, {"screen": "eDP\n1"}, {"screen": 3}, {"focus": "tasks"}, {"fly": "x" * 65}, {"fly": "a\nb"}):
            with self.subTest(bad=bad), self.assertRaises(OpError):
                await self.view.command("open", "home", **bad)

    async def test_the_idle_command_line_counts_only_while_open(self):
        await self.view.command("open", "home")
        self.view.report(True, "home", True)
        self.assertTrue(self.view.cmdline_idle)
        self.view.report(False, "home", True)
        self.assertFalse(self.view.cmdline_idle)
        with self.assertRaises(OpError):
            self.view.report(True, "home", "yes")

    async def test_two_cold_opens_share_spawn_and_keep_latest_page(self):
        loop = asyncio.get_running_loop()
        entered = asyncio.Event()
        release = threading.Event()

        def before_spawn():
            loop.call_soon_threadsafe(entered.set)
            if not release.wait(2):
                raise TimeoutError("test barrier timed out")

        self.view.before_spawn = before_spawn
        first = asyncio.create_task(self.view.command("open", "tasks"))
        await asyncio.wait_for(entered.wait(), 1)
        second = asyncio.create_task(self.view.command("open", "timers"))
        await self.settle()
        release.set()
        await asyncio.wait_for(asyncio.gather(first, second), 2)
        self.assertEqual(len(self.processes), 1)
        self.assertEqual([event["data"]["page"] for event in self.view.client.sent], ["timers"])

    async def test_the_foreign_check_runs_before_the_first_open_and_only_once(self):
        calls = []
        self.view.before_spawn = lambda: calls.append("check")
        self.view.start_checks()
        await asyncio.wait_for(asyncio.shield(self.view.foreign_check), 1)
        self.view.start_checks()  # already started: no second check
        await self.view.command("open", "tasks")
        self.view.report(True, "tasks")
        await self.view.reap("test", force=True)
        await self.settle()
        await self.view.command("open", "tasks")
        self.assertEqual(calls, ["check"])
        self.assertEqual(len(self.processes), 2)

    async def test_a_failed_foreign_check_fails_the_open_and_is_retried(self):
        calls = []

        def before_spawn():
            calls.append("check")
            if len(calls) == 1:
                raise OSError("qs missing")

        self.view.before_spawn = before_spawn
        self.view.start_checks()
        with self.assertRaises(OpError):
            await self.view.command("open", "tasks")
        await self.view.command("open", "tasks")
        self.assertEqual(calls, ["check", "check"])
        self.assertEqual(self.view.state, "ready")

    async def test_close_supersedes_open_before_first_hello(self):
        spawned = asyncio.Event()

        async def silent():
            self.processes.append(FakeProcess(2000))
            spawned.set()
            return self.processes[-1]

        self.view.spawn = silent
        opening = asyncio.create_task(self.view.command("open", "tasks"))
        await asyncio.wait_for(spawned.wait(), 1)
        await self.view.command("close")
        client = FakeClient(2000)
        self.assertTrue(self.view.hello(client))
        await opening
        self.assertEqual([event["data"]["action"] for event in client.sent], ["close"])

    async def test_closed_view_is_reaped_after_the_idle_time(self):
        await self.open_then_close()
        self.clock.advance(REAP_AFTER - 1)
        await self.settle()
        self.assertEqual(self.processes[0].signals, [])
        self.clock.advance(1)
        await self.settle()
        self.assertEqual(self.processes[0].signals, ["TERM"])
        self.assertEqual(self.view.state, "absent")

    async def test_reopening_a_minute_before_the_reap_keeps_it(self):
        await self.open_then_close()
        self.clock.advance(REAP_AFTER - 60)
        self.view.report(True, "tasks")
        self.clock.advance(120)
        await self.settle()
        self.assertEqual(self.processes[0].signals, [])

    async def test_pressure_reaps_only_a_settled_closed_view(self):
        await self.view.command("open", "home")
        self.view.report(True, "home")
        self.triggers[0]()
        await self.settle()
        self.assertEqual(self.processes[0].signals, [])
        self.view.report(False, "home")
        self.clock.advance(1)
        self.triggers[0]()
        await self.settle()
        self.assertEqual(self.processes[0].signals, [])  # deferred to 5 s after close
        self.clock.advance(4)
        await self.settle()
        self.assertEqual(self.processes[0].signals, ["TERM"])

    async def test_pressure_after_six_seconds_reaps_at_once(self):
        await self.open_then_close()
        self.clock.advance(6)
        self.triggers[0]()
        await self.settle()
        self.assertEqual(self.processes[0].signals, ["TERM"])

    async def test_reap_ends_a_panel_lease(self):
        await self.open_then_close()
        self.assertEqual(self.closed_events, 1)
        self.clock.advance(REAP_AFTER)
        await self.settle()
        self.assertEqual(self.closed_events, 2)

    async def test_overdrive_blocks_the_idle_reaper(self):
        self.view.may_reap = lambda: False
        await self.open_then_close()
        self.clock.advance(REAP_AFTER * 6)
        await self.settle()
        self.assertEqual(self.processes[0].signals, [])

    async def test_release_rechecks_original_deadline_and_new_lease_wins_race(self):
        await self.open_then_close()
        self.view.may_reap = lambda: False
        self.clock.advance(REAP_AFTER + 1)
        await self.settle()
        self.view.may_reap = lambda: True
        self.view.check_idle_reap()
        self.view.may_reap = lambda: False
        await self.settle()
        self.assertEqual(self.processes[0].signals, [])
        self.view.may_reap = lambda: True
        self.view.check_idle_reap()
        await self.settle()
        self.assertEqual(self.processes[0].signals, ["TERM"])

    async def test_no_hello_times_out(self):
        old = view_module.READY_TIMEOUT
        view_module.READY_TIMEOUT = 0.05
        self.addCleanup(setattr, view_module, "READY_TIMEOUT", old)

        async def silent():
            process = FakeProcess(2000)
            self.processes.append(process)
            return process
        self.view.spawn = silent
        with self.assertRaises(OpError) as caught:
            await self.view.command("open", "home")
        self.assertEqual(caught.exception.code, "unavailable")
        self.assertEqual(self.processes[0].signals, ["TERM"])

    async def test_crash_loop_stops_respawning(self):
        self.exit_at_once = True
        for _ in range(3):
            with self.assertRaises(OpError):
                await self.view.command("open", "home")
            await self.settle()
        with self.assertRaises(OpError) as caught:
            await self.view.command("open", "home")
        self.assertIn("crashed", caught.exception.message)
        self.assertEqual(len(self.processes), 3)

    async def test_close_never_spawns(self):
        await self.view.command("close")
        self.assertEqual(self.processes, [])

    async def test_command_waits_for_reconnected_view(self):
        await self.view.command("open", "home")
        old = self.view.client
        self.view.disconnected(old)
        pending = asyncio.create_task(self.view.command("open", "tasks"))
        await self.settle()
        self.assertFalse(pending.done())
        client = FakeClient(old.pid)
        self.assertTrue(self.view.hello(client))
        await asyncio.wait_for(pending, 1)
        self.assertEqual(client.sent[0]["data"]["page"], "tasks")
        self.assertEqual(len(self.processes), 1)

    async def test_only_the_spawned_pid_may_be_the_view(self):
        await self.view.command("open", "home")
        self.assertFalse(self.view.hello(FakeClient(1)))


if __name__ == "__main__":
    unittest.main()
