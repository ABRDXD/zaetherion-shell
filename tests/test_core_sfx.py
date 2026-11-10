"""Sound cues: the D19 gate, UI cue switches, the sfx.cue events and where the core emits them.

The fixture host profile records play commands instead of running pw-play, so nothing sounds.
"""
from itertools import product
import json
from pathlib import Path
import tempfile
import types
import unittest
import unittest.mock

import core_fakes
from core.app import Core
from core.errors import OpError
from core.guards import SessionGuard
from core.sfx import CUES, Sfx


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
        self.assertEqual(snap, {"timer.done": False, "pomodoro.phase": False, "session.end": False, "ui.click": True,
                                "ui.key": True, "ui.switch": True, "ui.error": True, "cmd.run": True,
                                "orbit.out": True, "orbit.land": True, "orbit.hover": True, "ignite": True,
                                "overdrive.off": True, **{f"foley.{n}": True for n in ("pin", "relay", "paper", "ruler", "splice")},
                                **{f"quiet.{n}": True for n in ("thrash", "burst", "device")},
                                **{f"chord.{n}.{pan}": True for n in range(10) for pan in "lcr"}})
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


class SerpantinumProfileTests(unittest.TestCase):
    """The host mapping (Q9), against a temporary copy of the host's sound tree. Nothing is played."""

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
        self.module = types.SimpleNamespace(UI=tables["UI"], ALERTS=tables["ALERTS"], OWN=tables["OWN"], FART_SOUNDS=tables["FART_SOUNDS"])
        for relative in set(self.module.UI.values()) - {"reusables/inputfield/error.wav"}:
            path = root / "src/assets/sounds" / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"RIFF")

    def test_ui_cues_play_the_host_files_at_the_given_gain(self):
        for cue in ("ui.click", "ui.key", "ui.switch", "cmd.run", "orbit.hover"):
            command = self.profile.play_command(cue, 0.4)
            self.assertEqual(command[0], "pw-play")
            self.assertEqual(command[-2], "--volume=0.400")
            self.assertTrue(command[-1].endswith(self.module.UI[cue]), cue)
            self.assertEqual(json.loads(command[2])["application.id"], "fart-sfx")

    def test_the_orbit_whooshes_and_overdrive_s_sounds_are_fart_s_own_files(self):
        for cue in self.module.OWN:
            command = self.profile.play_command(cue, 1.0)
            self.assertEqual(Path(command[-1]), self.module.FART_SOUNDS / self.module.OWN[cue])
            self.assertTrue(Path(command[-1]).is_file(), cue)

    def test_the_error_sound_the_host_names_but_does_not_ship_is_silent(self):
        self.assertIsNone(self.profile.play_command("ui.error", 1.0))

    def test_every_ui_cue_is_mapped_and_alerts_keep_the_freedesktop_sound(self):
        ui = {name for name, cue in CUES.items() if cue.kind == "ui"}
        self.assertEqual(set(self.module.UI) | set(self.module.OWN), ui)
        self.assertFalse(set(self.module.UI) & set(self.module.OWN))
        self.assertEqual(set(self.module.ALERTS), {n for n, c in CUES.items() if c.kind == "alert"})


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
