"""Sound cues: the D19 gate, UI cue switches, the sfx.cue events and where the core emits them.

The fixture host profile records play commands instead of running pw-play, so nothing sounds.
"""
import asyncio
from itertools import product
import json
from pathlib import Path
import signal
import tempfile
import types
import unittest
import unittest.mock

import core_fakes
from core.app import Core
from core.errors import OpError
from core.guards import SessionGuard
from core.sfx import CUES, STOPPABLE, VIEW_CUES, Sfx


class GateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name)
        self.clock, _, self.profile, self.host = core_fakes.fakes()
        self.sound, self.session = True, False
        self.events = []
        self.sfx = self.make()

    def make(self):
        sfx = Sfx(self.host, self.clock, self.state, sound_on=lambda: self.sound, session_active=lambda: self.session)
        sfx.on_cue = self.events.append
        return sfx

    def plays(self):
        return [c for c in self.profile.calls if c[0] == "play"]

    def test_alert_truth_table(self):
        for sound, muted, volume, dnd, session, name in product((True, False), (False, True), (1.0, 0.0), (False, True),
                                                                (False, True), ("timer.done", "pomodoro.phase", "session.end")):
            with self.subTest(sound=sound, muted=muted, volume=volume, dnd=dnd, session=session, cue=name):
                self.sound, self.session = sound, session
                self.profile.muted, self.profile.volume, self.profile.dnd_on = muted, volume, dnd
                self.profile.calls.clear()
                event = self.sfx.emit(name)
                quieted = session and not CUES[name].session
                reason = ("off" if not sound else "session" if quieted else "muted" if muted or volume == 0
                          else "dnd" if dnd else None)
                self.assertEqual((event["audible"], event["reason"]), (reason is None, reason))
                self.assertEqual(self.plays(), [["play", name, "1.000"]] if reason is None else [])

    def test_an_explicit_sound_overrides_the_setting(self):
        self.sound = False
        self.assertTrue(self.sfx.emit("timer.done", sound=True)["audible"])
        self.sound = True
        self.assertEqual(self.sfx.emit("timer.done", sound=False)["reason"], "off")

    def test_ui_cues_are_on_by_default_and_played_by_the_core(self):
        self.sound = False  # the timer sound setting does not gate UI cues
        snap = {c["name"]: c["enabled"] for c in self.sfx.snapshot()["cues"]}
        self.assertEqual(snap, {"timer.done": False, "pomodoro.phase": False, "session.end": False,
                                "notify.normal": True, "notify.critical": True, "ui.click": True,
                                "ui.key": True, "ui.switch": True, "ui.error": True, "cmd.run": True,
                                "orbit.out": True, "orbit.land": True, "orbit.hover": True, "ignite": True,
                                "overdrive.off": True, **{f"foley.{n}": True for n in ("pin", "relay", "paper", "ruler", "splice")},
                                **{f"quiet.{n}": True for n in ("thrash", "burst", "device")},
                                **{f"chord.{n}.{pan}": True for n in range(10) for pan in "lcr"},
                                **{n: True for n in ("hold.confirm", "hold.charge", "osd.tick", "power.plug", "power.unplug", "battery.low",
                                                     "net.up", "net.down", "dnd.on", "dnd.off")}})
        self.profile.volume = 0.5
        for name in ("ui.click", "ui.key", "ui.switch", "ui.error", "cmd.run"):
            event = self.sfx.emit(name)
            self.assertEqual((event["audible"], event["reason"], event["gain"]), (True, None, 0.5))
        self.assertEqual(self.plays(), [["play", n, "0.500"] for n in ("ui.click", "ui.key", "ui.switch", "ui.error", "cmd.run")])
        self.sfx.configure({"ui.key": False})
        self.assertEqual(self.sfx.emit("ui.key")["reason"], "off")
        self.session = True
        self.assertEqual(self.sfx.emit("ui.click")["reason"], "session")
        self.session, self.profile.dnd_on = False, True
        self.assertEqual(self.sfx.emit("ui.click")["reason"], "dnd")
        self.profile.dnd_on, self.profile.muted = False, True
        self.assertEqual(self.sfx.emit("ui.click")["reason"], "muted")
        self.assertEqual(len(self.plays()), 5)

    def test_a_cue_the_host_has_no_file_for_is_not_audible(self):
        self.profile.silent.add("ui.error")
        event = self.sfx.emit("ui.error")
        self.assertEqual((event["audible"], event["reason"], event["gain"]), (False, "no-sound", 0.0))
        self.assertEqual(self.plays(), [])

    def test_host_settings_are_read_only_for_a_cue_that_is_on(self):
        reads = []
        self.profile.sfx = lambda: reads.append(1) or (False, 1.0)
        self.sfx.configure({"cmd.run": False})
        self.sfx.emit("cmd.run")
        self.sound = False
        self.sfx.emit("timer.done")
        self.assertEqual(reads, [])

    def test_switches_persist_and_alerts_cannot_be_switched_here(self):
        self.sfx.configure({"ui.key": False, "cmd.run": False})
        path = self.state / "sfx.json"
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertFalse(json.loads(path.read_text())["cues"]["ui.key"])
        self.assertFalse(self.make().enabled["cmd.run"])
        self.assertTrue(self.make().enabled["ui.click"])
        for bad in ({"timer.done": True}, {"nope": True}, {"cmd.run": "yes"}, ["cmd.run"]):
            with self.subTest(bad=bad), self.assertRaises(OpError):
                self.sfx.configure(bad)
        path.write_text("{")
        self.assertTrue(self.make().enabled["cmd.run"])

    def test_events_carry_sequence_and_time(self):
        self.sfx.emit("timer.done")
        self.clock.advance(2)
        self.sfx.emit("cmd.run")
        self.assertEqual([(e["cue"], e["seq"]) for e in self.events], [("timer.done", 1), ("cmd.run", 2)])
        self.assertEqual(self.events[1]["at"] - self.events[0]["at"], 2000)
        with self.assertRaises(OpError):
            self.sfx.emit("doorbell")

    def test_the_view_reports_its_own_moments_only(self):
        for name in ("ui.click", "ui.key", "ui.switch", "ui.error", "orbit.out", "orbit.land", "orbit.hover"):
            self.assertEqual(self.sfx.emit_from_view(name)["cue"], name)
        for name in ("timer.done", "cmd.run", "ignite", "doorbell"):
            with self.subTest(cue=name), self.assertRaises(OpError) as caught:
                self.sfx.emit_from_view(name)
            self.assertEqual(caught.exception.code, "refused")


class SystemMomentTests(unittest.TestCase):
    """S5's system moments: the island reports them; do-not-disturb's own sound is the core's."""

    def test_the_view_may_report_the_island_s_moments_but_not_dnd(self):
        from core.sfx import VIEW_CUES
        for name in ("hold.confirm", "hold.charge", "osd.tick", "power.plug", "power.unplug", "battery.low", "net.up", "net.down"):
            self.assertIn(name, VIEW_CUES)
        self.assertNotIn("dnd.on", VIEW_CUES)
        self.assertNotIn("dnd.off", VIEW_CUES)

    def test_switching_dnd_plays_its_cue_once_per_change(self):
        from core.notifications import Inbox
        heard = []
        with tempfile.TemporaryDirectory() as d:
            clock, scheduler, _, _ = core_fakes.fakes()
            inbox = Inbox(clock, scheduler, Path(d))
            inbox.on_dnd = heard.append
            inbox.set_dnd(True)
            inbox.set_dnd(True)
            inbox.set_dnd(False)
        self.assertEqual(heard, [True, False])


class HoldChargeTests(unittest.IsolatedAsyncioTestCase):
    """hold.charge rises while the island's hold runs; the view cuts it short with sfx.stop (a SIGTERM to the player)."""

    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, self.profile, host = core_fakes.fakes()
        self.host = host

        async def no_spawn():
            raise OSError("no view in this test")
        self.core = Core(self.clock, scheduler, host, Path(self.temp.name), spawn=no_spawn, guard_types=[SessionGuard])
        self.view, self.other = FakeClient(["sfx"]), FakeClient(["timers"])
        self.core.server.clients.update({self.view, self.other})
        self.core.view.client = self.view
        self.core.view.state = "ready"
        self.ops = self.core.server.ops

    def calls(self, kind):
        return [c for c in self.profile.calls if c[0] == kind]

    def real_player(self):
        """A profile that really spawns: the charge is a long `sleep`, so termination is observable."""
        self.profile.record = None
        self.profile.play_command = lambda cue, gain: ["sleep", "30"]

    async def tidy(self):
        for player in [p for p in self.host.players.values() if p is not True]:
            player.stop()
        await asyncio.gather(*self.host.tasks)

    def test_the_cue_is_mapped_and_the_view_may_report_and_stop_it(self):
        self.assertEqual((CUES["hold.charge"].kind, CUES["hold.charge"].session), ("ui", False))
        self.assertIn("hold.charge", VIEW_CUES)
        self.assertEqual(STOPPABLE, {"hold.charge"})
        self.assertTrue(STOPPABLE <= set(VIEW_CUES))

    async def test_stop_ends_the_last_charge(self):
        self.ops["sfx.play"](self.view, cue="hold.charge")
        self.assertEqual(self.calls("play"), [["play", "hold.charge", "1.000"]])
        self.assertEqual(self.ops["sfx.stop"](self.view, cue="hold.charge"), {"cue": "hold.charge"})
        self.assertEqual(self.calls("stop"), [["stop", "hold.charge"]])

    async def test_stop_with_nothing_playing_is_harmless(self):
        self.ops["sfx.stop"](self.view, cue="hold.charge")
        self.assertEqual(self.calls("stop"), [])
        self.ops["sfx.play"](self.view, cue="hold.charge")
        self.ops["sfx.stop"](self.view, cue="hold.charge")
        self.ops["sfx.stop"](self.view, cue="hold.charge")  # twice: the second finds nothing
        self.assertEqual(len(self.calls("stop")), 1)

    async def test_a_gated_off_charge_leaves_nothing_to_stop(self):
        self.core.sfx.configure({"hold.charge": False})
        self.ops["sfx.play"](self.view, cue="hold.charge")
        self.ops["sfx.stop"](self.view, cue="hold.charge")
        self.assertEqual((self.calls("play"), self.calls("stop")), ([], []))

    async def test_a_new_charge_stops_the_old_one_first(self):
        self.ops["sfx.play"](self.view, cue="hold.charge")
        self.ops["sfx.play"](self.view, cue="hold.charge")
        self.assertEqual([c[0] for c in self.profile.calls], ["play", "stop", "play"])

    async def test_other_cues_are_not_stoppable_and_unknown_ones_are_refused(self):
        for name in ("ui.click", "hold.confirm", "timer.done", "doorbell"):
            with self.subTest(cue=name), self.assertRaises(OpError) as caught:
                self.ops["sfx.stop"](self.view, cue=name)
            self.assertEqual(caught.exception.code, "refused")
        self.ops["sfx.play"](self.view, cue="hold.charge")
        with self.assertRaises(OpError):
            self.ops["sfx.stop"](self.view, cue="ui.click")
        self.assertEqual(self.calls("stop"), [])

    async def test_only_the_view_stops_a_cue(self):
        self.ops["sfx.play"](self.view, cue="hold.charge")
        with self.assertRaises(OpError) as caught:
            self.ops["sfx.stop"](self.other, cue="hold.charge")
        self.assertEqual(caught.exception.code, "refused")
        self.assertEqual(self.calls("stop"), [])

    async def test_stop_terminates_the_running_player_process(self):
        self.real_player()
        self.ops["sfx.play"](self.view, cue="hold.charge")
        for _ in range(100):  # the spawn runs as a task on the loop
            await asyncio.sleep(0.01)
            player = self.host.players.get("hold.charge")
            if player and player.process:
                break
        process = player.process
        self.assertIsNone(process.returncode)
        self.ops["sfx.stop"](self.view, cue="hold.charge")
        await asyncio.wait_for(process.wait(), 5)
        self.assertEqual(process.returncode, -signal.SIGTERM)
        await asyncio.gather(*self.host.tasks)
        self.assertEqual(self.host.players, {})
        self.ops["sfx.stop"](self.view, cue="hold.charge")  # already exited: a no-op

    async def test_stop_before_the_process_exists_still_ends_it(self):
        self.real_player()
        self.ops["sfx.play"](self.view, cue="hold.charge")
        player = self.host.players["hold.charge"]
        self.ops["sfx.stop"](self.view, cue="hold.charge")  # the spawn task has not run yet
        await asyncio.wait_for(asyncio.gather(*self.host.tasks), 5)
        self.assertEqual(player.process.returncode, -signal.SIGTERM)

    async def test_a_new_charge_terminates_the_old_process(self):
        self.real_player()
        self.ops["sfx.play"](self.view, cue="hold.charge")
        first = self.host.players["hold.charge"]
        self.ops["sfx.play"](self.view, cue="hold.charge")
        second = self.host.players["hold.charge"]
        self.assertIsNot(first, second)
        await self.tidy()
        self.assertEqual(first.process.returncode, -signal.SIGTERM)
        self.assertEqual(second.process.returncode, -signal.SIGTERM)


class SerpantinumProfileTests(unittest.TestCase):
    """The sound map: every cue is one of ZÆTHERION's own files (owner, 13 November 2026). Nothing is played."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        patcher = unittest.mock.patch.dict("os.environ", {"SERPANTINUM_DIR": str(root / "src"), "XDG_CONFIG_HOME": str(root)})
        patcher.start()
        self.addCleanup(patcher.stop)
        from core.host import load_profile
        self.profile = load_profile("serpantinum")
        tables = type(self.profile).__init__.__globals__  # the profile module is loaded from a path, not imported
        self.module = types.SimpleNamespace(OWN=tables["OWN"], TAKES=tables["TAKES"], FART_SOUNDS=tables["FART_SOUNDS"])

    def test_every_cue_has_one_of_our_files_and_nothing_else_is_mapped(self):
        self.assertEqual(set(self.module.OWN) | set(self.module.TAKES), set(CUES))
        self.assertFalse(set(self.module.OWN) & set(self.module.TAKES))
        for cue in CUES:
            command = self.profile.play_command(cue, 1.0)
            self.assertIsNotNone(command, cue)
            self.assertEqual(Path(command[-1]).parent, self.module.FART_SOUNDS, cue)
            self.assertTrue(Path(command[-1]).is_file(), cue)

    def test_cues_play_at_the_given_gain_as_events(self):
        command = self.profile.play_command("ui.click", 0.4)
        self.assertEqual((command[0], command[-2]), ("pw-play", "--volume=0.400"))
        self.assertEqual(json.loads(command[2])["application.id"], "fart-sfx")
        self.assertEqual(json.loads(command[2])["media.role"], "event")

    def test_typing_cycles_through_its_takes(self):
        takes = self.module.TAKES["ui.key"]
        played = [Path(self.profile.play_command("ui.key", 1.0)[-1]).name for _ in range(len(takes) + 1)]
        self.assertEqual(played, [*takes, takes[0]])

    def test_an_unknown_cue_has_no_file(self):
        self.assertIsNone(self.profile.play_command("no.such.cue", 1.0))


class FakeClient:
    def __init__(self, topics):
        self.topics, self.sent, self.closed, self.kind = set(topics), [], False, "view"

    def send(self, message):
        self.sent.append(message)


class CoreCueTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, self.profile, host = core_fakes.fakes()

        async def no_spawn():
            raise OSError("no view in this test")
        self.core = Core(self.clock, scheduler, host, Path(self.temp.name), spawn=no_spawn, guard_types=[SessionGuard])
        self.view = FakeClient(["sfx"])
        self.other = FakeClient(["timers"])
        self.core.server.clients.update({self.view, self.other})
        self.core.view.client = self.view
        self.core.view.state = "ready"

    def cues(self, client=None):
        return [m["data"]["cue"] for m in (client or self.view).sent if m.get("event") == "sfx.cue"]

    async def test_opening_and_folding_make_no_sound(self):
        # Serpantinum's popups open and close silently, so FART's panel does too (Q9 follows the host).
        self.core.view_state(self.view, True, "home")
        self.core.view_state(self.view, False, "home")
        self.assertEqual(self.cues(), [])

    async def test_sfx_play_is_the_view_only(self):
        play = self.core.server.ops["sfx.play"]
        self.assertEqual(play(self.view, cue="ui.click")["cue"], "ui.click")
        with self.assertRaises(OpError):
            play(self.other, cue="ui.click")
        self.assertEqual(self.cues(), ["ui.click"])
        self.assertEqual(self.cues(self.other), [])
        self.assertEqual([c for c in self.profile.calls if c[0] == "play"], [["play", "ui.click", "1.000"]])

    async def test_command_cues_only_for_the_view_and_only_for_results(self):
        commands = self.core.commands
        await commands.run("tim 5", "view")
        await commands.run("tim soon", "view")
        await commands.run("tim 5", "cli")
        await commands.run("s", "view")  # ambiguous: a list, not a result
        self.assertEqual(self.cues(), ["cmd.run", "ui.error"])

    async def test_alarm_plays_through_the_gate_and_sessions_quiet_it(self):
        self.core.timers.configure(sound=True)
        self.core.timers.start("countdown", 60)
        self.clock.advance(61)
        self.assertEqual([c for c in self.profile.calls if c[0] == "play"], [["play", "timer.done", "1.000"]])
        self.profile.calls.clear()
        self.core.sessions.start("pyq", 3600)
        self.core.timers.start("countdown", 60)
        self.clock.advance(61)
        self.assertEqual([c for c in self.profile.calls if c[0] == "play"], [])
        self.clock.advance(3600)  # the session completes: its own cue still sounds
        self.assertEqual([c for c in self.profile.calls if c[0] == "play"], [["play", "session.end", "1.000"]])
        self.assertEqual(self.cues(), ["timer.done", "timer.done", "session.end"])
        reasons = [m["data"]["reason"] for m in self.view.sent if m.get("event") == "sfx.cue"]
        self.assertEqual(reasons, [None, "session", None])

    async def test_the_sfx_snapshot_follows_the_timer_sound_setting(self):
        self.view.topics.add("sfx")
        before = self.core.server.revs["sfx"]
        self.core.timers.start("countdown", 60)
        self.assertEqual(self.core.server.revs["sfx"], before)
        self.core.timers.configure(sound=True)
        self.assertEqual(self.core.server.revs["sfx"], before + 1)
        alerts = [c["enabled"] for c in self.core.sfx.snapshot()["cues"] if c["kind"] == "alert"]
        self.assertEqual(alerts, [True, True, True])


if __name__ == "__main__":
    unittest.main()
