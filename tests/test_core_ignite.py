"""The ignite hold (core/ignite.py) with the fake clock: DAILY_DRIVER §4.6 and its test list.

The state machine runs alone first, with recorded effects, then inside a Core with a fake view, where
firing requests Overdrive for the panel. Nothing here touches a real key bind.
"""
import asyncio
from pathlib import Path
import tempfile
import unittest

import core_fakes
from core.app import Core
from core.guards import SessionGuard
from core.ignite import FIRE, LOST, METER, Ignite


class Machine(unittest.TestCase):
    def setUp(self):
        self.clock, self.scheduler, _, _ = core_fakes.fakes()
        self.effects, self.published = [], []
        self.fold_ok = False
        self.ignite = Ignite(self.clock, self.scheduler, open_panel=lambda: self.effects.append("open"),
                             fold_panel=lambda: self.effects.append("fold"), may_fold=lambda: self.fold_ok,
                             fire=lambda: self.effects.append("fire") or "granted")
        self.ignite.on_change = lambda: self.published.append(self.ignite.snapshot())

    def hold(self, ms):
        self.ignite.down()
        self.clock.advance(ms / 1000)
        return self.ignite.up()

    def test_press_lengths(self):
        # (held for ms, meter shown, fired)
        for ms, meter, fired in ((100, False, False), (149, False, False), (151, True, False),
                                 (599, True, False), (601, True, True)):
            with self.subTest(ms=ms):
                self.effects.clear(), self.published.clear()
                result = self.hold(ms)
                self.assertEqual(self.effects, ["open", "fire"] if fired else ["open"])
                self.assertEqual(result["action"], "fired" if fired else "released")
                self.assertEqual(any(p["holding"] for p in self.published), meter)
                self.assertEqual(any(p["fired"] for p in self.published), fired)
                self.assertEqual(self.ignite.snapshot(), {"holding": False, "since": None, "fired": False, "outcome": None})
                if meter:
                    self.assertFalse(self.published[-1]["holding"])  # the release always ends the meter
                self.assertEqual([k for k in ("ignite.meter", "ignite.fire", "ignite.lost") if k in self.scheduler.pending], [])

    def test_fire_happens_while_still_held(self):
        self.ignite.down()
        self.clock.advance(FIRE + 0.001)
        self.assertEqual(self.effects, ["open", "fire"])
        snap = self.ignite.snapshot()
        self.assertEqual((snap["holding"], snap["fired"], snap["outcome"]), (True, True, "granted"))
        self.assertEqual(snap["since"], round((self.clock.real - FIRE - 0.001) * 1000))
        self.assertEqual(self.ignite.up()["action"], "fired")
        self.assertEqual(self.effects, ["open", "fire"])  # the release does not fire again

    def test_a_late_fire_deadline_is_honoured_by_the_release(self):
        self.ignite.down()
        self.clock.boot += 0.7  # the deadline has passed but was not serviced yet
        self.clock.real += 0.7
        self.assertEqual(self.ignite.up()["action"], "fired")
        self.assertEqual(self.effects, ["open", "fire"])

    def test_a_lost_release_ends_the_meter(self):
        self.ignite.down()
        self.clock.advance(LOST - 0.01)
        self.assertTrue(self.ignite.snapshot()["holding"])
        self.clock.advance(0.02)
        self.assertEqual(self.ignite.phase, "idle")
        self.assertFalse(self.published[-1]["holding"])
        self.assertEqual(self.ignite.up()["action"], "ignored")  # the late release finds nothing to end

    def test_a_second_press_while_held_is_ignored(self):
        self.ignite.down()
        self.clock.advance(0.3)
        self.assertEqual(self.ignite.down()["action"], "ignored")
        self.clock.advance(0.2)  # 500 ms from the first press, not 200 ms from the second
        self.assertEqual(self.effects, ["open"])
        self.clock.advance(0.101)
        self.assertEqual(self.effects, ["open", "fire"])

    def test_a_release_without_a_press_is_ignored(self):
        self.assertEqual(self.ignite.up()["action"], "ignored")
        self.assertEqual((self.effects, self.published), ([], []))

    def test_an_idle_command_line_folds_instead(self):
        self.fold_ok = True
        self.assertEqual(self.ignite.down()["action"], "fold")
        self.clock.advance(1)
        self.assertEqual(self.ignite.up()["action"], "ignored")
        self.assertEqual((self.effects, self.published), (["fold"], []))

    def test_publishes_only_on_change(self):
        self.hold(METER * 1000 - 10)
        self.assertEqual(self.published, [])
        self.hold(FIRE * 1000 + 50)
        self.assertEqual([(p["holding"], p["fired"]) for p in self.published], [(True, False), (True, True), (False, False)])

    def test_a_failing_effect_still_ends(self):
        def broken():
            raise RuntimeError("boom")
        self.ignite.fire = broken
        with self.assertLogs("fart.ignite", "ERROR"):
            self.ignite.down()
            self.clock.advance(FIRE + 0.01)
        self.assertEqual(self.ignite.snapshot()["outcome"], "refused")
        self.ignite.up()
        self.assertEqual(self.ignite.phase, "idle")


class FakeClient:
    def __init__(self, pid=0):
        self.pid, self.topics, self.sent, self.closed, self.kind = pid, {"ignite"}, [], False, "view"

    def send(self, message):
        self.sent.append(message)


class InCore(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, self.profile, host = core_fakes.fakes()
        self.spawns = 0

        async def no_spawn():
            self.spawns += 1
            raise OSError("no view in this test")
        self.core = Core(self.clock, scheduler, host, Path(self.temp.name), spawn=no_spawn, guard_types=[SessionGuard])

    def connect_view(self):
        self.view = FakeClient()
        self.core.server.clients.add(self.view)
        self.core.view.client, self.core.view.state = self.view, "ready"

    def commands(self):
        return [m["data"] for m in self.view.sent if m.get("event") == "view.command"]

    async def settle(self):
        for _ in range(5):
            await asyncio.sleep(0)

    async def test_a_hold_on_the_open_panel_requests_overdrive_until_it_closes(self):
        self.connect_view()
        self.core.ignite.down()
        await self.settle()
        self.assertEqual(self.commands()[-1], {"action": "open", "page": "home", "from": None, "focus": "cmdline"})
        self.core.view_state(self.view, True, "home")
        self.clock.advance(FIRE + 0.01)
        self.assertEqual(self.core.ignite.snapshot()["outcome"], "granted")
        self.assertEqual(self.core.overdrive.state.mode, "panel")
        self.assertEqual(self.core.ignite.up()["action"], "fired")
        self.assertEqual(self.core.overdrive.state.mode, "panel")  # the release ends the meter, not the lease
        self.core.view_state(self.view, False, "home")
        self.assertEqual(self.core.overdrive.state.mode, "off")
        ignite = [m["data"] for m in self.view.sent if m.get("event") == "ignite"]
        self.assertEqual([(d["holding"], d["fired"]) for d in ignite], [(True, False), (True, True), (False, False)])

    async def test_a_short_tap_opens_the_command_line_and_requests_nothing(self):
        self.connect_view()
        self.core.ignite.down()
        self.clock.advance(0.1)
        self.core.ignite.up()
        await self.settle()
        self.assertEqual(self.commands()[-1]["focus"], "cmdline")
        self.assertEqual(self.core.overdrive.state.mode, "off")

    async def test_a_cold_press_fires_when_the_panel_opens_within_the_window(self):
        self.connect_view()  # connected but not open yet: the unfold has not reported
        self.core.ignite.down()
        self.clock.advance(FIRE + 0.01)
        self.assertEqual(self.core.ignite.snapshot()["outcome"], "pending")
        self.core.ignite.up()
        self.assertEqual(self.core.overdrive.state.mode, "off")
        self.clock.advance(0.5)
        self.core.view_state(self.view, True, "home")
        self.assertEqual(self.core.overdrive.state.mode, "panel")

    async def test_a_pending_fire_expires_with_the_window(self):
        self.connect_view()
        self.core.ignite.down()
        self.clock.advance(FIRE + 0.01)
        self.core.ignite.up()
        self.clock.advance(LOST)
        self.core.view_state(self.view, True, "home")
        self.assertEqual(self.core.overdrive.state.mode, "off")

    async def test_a_crash_after_a_pending_fire_drops_it(self):
        self.connect_view()
        self.core.ignite.down()
        self.clock.advance(FIRE + 0.01)
        self.assertEqual(self.core.ignite.snapshot()["outcome"], "pending")
        for callback in self.core.view.on_closed:  # the view dies before it reports open
            callback()
        self.core.ignite.up()
        self.clock.advance(0.5)
        self.connect_view()  # a respawned view opening within the window is a new panel, not this press's
        self.core.view_state(self.view, True, "home")
        self.assertEqual(self.core.overdrive.state.mode, "off")

    async def test_a_view_crash_while_held_drops_the_fire_and_ends_on_release(self):
        self.connect_view()
        self.core.ignite.down()
        self.clock.advance(0.2)
        for callback in self.core.view.on_closed:  # what ViewManager._watch runs when the process dies
            callback()
        self.core.view.client, self.core.view.state, self.core.view.open = None, "absent", False
        self.clock.advance(0.5)
        self.assertEqual(self.core.ignite.snapshot()["outcome"], "pending")
        self.core.ignite.up()
        self.clock.advance(5)
        self.assertEqual(self.core.ignite.phase, "idle")
        self.assertEqual(self.core.overdrive.state.mode, "off")

    async def test_a_release_with_the_view_absent(self):
        with self.assertLogs("fart.core", "WARNING"):
            self.core.ignite.down()  # spawns, and the fake spawn fails
            await self.settle()
        self.assertEqual(self.spawns, 1)
        self.clock.advance(0.3)
        self.assertEqual(self.core.ignite.up()["action"], "released")
        self.assertEqual(self.core.overdrive.state.mode, "off")

    async def test_an_idle_command_line_folds_on_the_press(self):
        self.connect_view()
        self.core.view_state(self.view, True, "tasks", cmdlineIdle=True)
        self.assertEqual(self.core.ignite.down()["action"], "fold")
        await self.settle()
        self.assertEqual(self.commands()[-1]["action"], "close")
        self.core.view_state(self.view, False, "tasks", cmdlineIdle=True)
        self.assertFalse(self.core.view.cmdline_idle)  # only an open panel's command line counts
        self.core.view_state(self.view, True, "tasks", cmdlineIdle=False)
        self.assertEqual(self.core.ignite.down()["action"], "open")  # text typed: no fold

    async def test_the_panel_s_own_plate_holds_without_folding_or_opening(self):
        # The ignite plate inside the open panel (docs/OVERDRIVE.md §2): an idle command line does not fold it,
        # no open command is sent, and the hold fires as the key's does.
        self.connect_view()
        self.core.view_state(self.view, True, "orbit", cmdlineIdle=True)
        sent = len(self.commands())
        down = self.core.server.ops["key.down"]
        self.assertEqual(down(self.view, panel=True)["action"], "hold")
        self.clock.advance(FIRE + 0.01)
        self.assertEqual(self.core.overdrive.state.mode, "panel")
        self.assertEqual(self.core.server.ops["key.up"](self.view)["action"], "fired")
        await self.settle()
        self.assertEqual(len(self.commands()), sent)
        # Another client cannot claim the panel's route: the CLI's press still folds the idle panel.
        cli = FakeClient()
        cli.kind = "cli"
        self.assertEqual(down(cli, panel=True)["action"], "fold")

    async def test_the_same_hold_cuts_a_running_overdrive(self):
        self.connect_view()
        self.core.view_state(self.view, True, "home")
        self.core.overdrive.request("sticky")
        down, up = self.core.server.ops["key.down"], self.core.server.ops["key.up"]
        down(self.view, panel=True)
        self.clock.advance(FIRE - 0.1)
        self.assertEqual(self.core.overdrive.state.mode, "sticky")  # a short press changes nothing
        self.clock.advance(0.11)
        self.assertEqual((self.core.ignite.snapshot()["outcome"], self.core.overdrive.state.mode), ("released", "off"))
        up(self.view)
        down(self.view, panel=True)
        self.clock.advance(FIRE + 0.01)
        self.assertEqual(self.core.overdrive.state.mode, "panel")  # and the next hold ignites again

    async def test_a_lease_starting_and_ending_plays_ignite_and_the_spin_down(self):
        self.connect_view()
        cues = []
        self.core.sfx.on_cue = lambda event: cues.append(event["cue"])
        self.core.view_state(self.view, True, "home")
        self.core.overdrive.request("timed", 60)
        self.core.overdrive.request("sticky")  # already on: no second ignition
        self.core.overdrive.guard("session", True)  # suspended, still requested: silent
        self.core.overdrive.guard("session", False)
        self.core.overdrive.release()
        self.core.overdrive.release()  # already off: nothing
        self.assertEqual(cues, ["ignite", "overdrive.off"])
        self.core.overdrive.request("panel")
        self.core.view_state(self.view, False, "home")  # the panel closing ends a panel lease
        self.assertEqual(cues, ["ignite", "overdrive.off", "ignite", "overdrive.off"])

    async def test_the_key_ops_are_registered(self):
        self.assertIn("key.down", self.core.server.ops)
        self.assertIn("key.up", self.core.server.ops)
        self.assertIn("ignite", self.core.server.snapshots)


if __name__ == "__main__":
    unittest.main()
