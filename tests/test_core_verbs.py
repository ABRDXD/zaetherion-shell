"""Every grammar v1 verb against a real in-process core (fake clock, fixture profile) and a fake view.

Host calls are recorded by a fake, so nothing reaches a real host; the view half is covered by
test_verbs_view.py against the fixture adapter.
"""
from datetime import date, datetime, timedelta
from pathlib import Path
import tempfile
import unittest

import core_fakes
from core.app import Core
from core.errors import OpError
from core.guards import SessionGuard


class FakeView:
    def __init__(self):
        self.commands = []
        self.state, self.open, self.page = "ready", True, "home"
        self.client = None

    async def command(self, action, page=None, from_=None, query=None, fly=None):
        self.commands.append((action, page, "fly", fly) if fly is not None else (action, page) if query is None else (action, page, query))
        self.open = action != "close"


class FakeHostCalls:
    def __init__(self):
        self.calls = []
        self.values = {
            ("audio", "output"): {"id": "1", "name": "Fixture Speakers", "volume": 0.4, "muted": False},
            ("audio", "outputs"): [{"id": "1", "name": "Fixture Speakers", "isDefault": True},
                                   {"id": "5", "name": "Headset (USB)", "isDefault": False},
                                   {"id": "6", "name": "HDMI Headphones out", "isDefault": False}],
            ("power", "brightness"): {"available": True, "level": 0.5},
            ("power", "profiles"): ["power-saver", "balanced", "performance"],
            ("media", "active"): {"title": "Fixture Signal", "artist": "Test Pattern"},
        }

    async def call(self, domain, method=None, args=(), **options):
        self.calls.append((domain, method, list(args), options))
        return self.values.get((domain, options.get("read")))


class VerbTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        clock, scheduler, self.profile, host = core_fakes.fakes()
        self.clock = clock

        async def no_spawn():
            raise OSError("no view in this test")
        self.core = Core(clock, scheduler, host, Path(self.temp.name), spawn=no_spawn, guard_types=[SessionGuard])  # no device or bus guards
        self.core.view = self.view = FakeView()
        self.core.hostcalls = self.host = FakeHostCalls()

    async def run_line(self, line, source="cli"):
        return await self.core.commands.run(line, source)

    async def ok(self, line, source="cli"):
        result = await self.run_line(line, source)
        self.assertTrue(result["ok"], (line, result))
        return result

    async def code(self, line):
        result = await self.run_line(line)
        self.assertFalse(result["ok"], (line, result))
        return result["code"]

    def today(self) -> date:
        return datetime.fromtimestamp(self.clock.real).date()

    async def test_every_example_parses(self):
        for verb in self.core.commands.verbs:
            for example in verb.examples:
                with self.subTest(example=example):
                    result = await self.run_line(example)
                    self.assertNotEqual(result.get("code"), "usage", result)
                    self.assertNotEqual(result.get("code"), "ambiguous", result)

    async def test_rooms_open_by_name_alias_and_prefix(self):
        for line, page in (("home", "home"), ("med", "media"), ("performance", "performance"), ("ws", "workspaces"),
                           ("dev", "devices"), ("inbox", "notifications"), ("tim", "timers"), ("task", "tasks"),
                           ("clip", "clipboard"), ("lyr", "media"), ("wo", "workspaces")):
            with self.subTest(line=line):
                result = await self.ok(line)
                self.assertEqual((result["tone"], self.view.commands[-1]), ("info", ("open", page)))
        self.assertEqual(await self.code("home now"), "usage")

    async def test_go_flies_to_a_room_or_hands_a_moon_to_the_view(self):
        for line, page in (("go 5", "tasks"), ("go 00", "home"), ("go clips", "clipboard"), ("go inbox", "notifications"),
                           ("go perf", "performance"), ("go Timers", "timers"), ("go work", "workspaces")):
            with self.subTest(line=line):
                await self.ok(line)
                self.assertEqual(self.view.commands[-1], ("open", page))
        for line, target in (("go", ""), ("go wifi", "wifi"), ("go timers stopwatch", "timers stopwatch"), ("go 12", "12")):
            with self.subTest(line=line):
                result = await self.ok(line)
                self.assertEqual(self.view.commands[-1], ("open", None, "fly", target))
                self.assertEqual(result["tone"], "info")

    async def test_timers(self):
        self.assertEqual((await self.ok("tim 25"))["line"], "countdown 25:00 left")
        self.clock.advance(60)
        self.assertEqual((await self.ok("tim pause"))["line"], "countdown 24:00 left (paused)")
        self.assertEqual((await self.ok("focus 50"))["line"], "countdown 24:00 left (paused); pomodoro focus 50:00 left, cycle 1")
        self.assertIn("stopwatch 0:00", (await self.ok("sw"))["line"])
        self.clock.advance(5)
        await self.ok("tim lap")
        self.assertEqual(self.core.timers.snapshot()["stopwatch"]["laps"], [5.0])
        self.assertEqual((await self.ok("tim stop"))["line"], "countdown 24:00 left (paused)")
        self.assertEqual(await self.code("tim soon"), "usage")
        self.assertEqual(await self.code("tim lap now"), "usage")
        self.assertEqual(await self.code("tim 0"), "bad-args")

    async def test_tasks_with_lists_and_due_dates(self):
        result = await self.ok("task buy milk")
        self.assertEqual(result["line"], "added to Tasks")
        self.assertEqual(self.core.tasks.snapshot()["tasks"][-1]["text"], "buy milk")
        self.core.tasks.list_add("Study")
        today = self.today()
        friday = today + timedelta(days=(4 - today.weekday() - 1) % 7 + 1)
        result = await self.ok("task revise ch 4 @study !fri")
        self.assertEqual(result["data"]["due"], friday.isoformat())
        self.assertTrue(result["line"].startswith("added to Study, due Fri "))
        self.assertGreater(friday, today)
        self.assertLessEqual((friday - today).days, 7)
        for word, due in (("!today", today.isoformat()), ("!tomorrow", (today + timedelta(days=1)).isoformat()),
                          ("!+3d", (today + timedelta(days=3)).isoformat()), ("!+2w", (today + timedelta(days=14)).isoformat()),
                          ("!2026-12-24", "2026-12-24"), ("!2026-12-24T18:30", "2026-12-24T18:30")):
            with self.subTest(word=word):
                self.assertEqual((await self.ok(f"task x {word}"))["data"]["due"], due)
        self.assertEqual(await self.code("task x @nowhere"), "not-found")
        for line in ("task @study", "task x !someday", "task x @a @b", "task x !fri !mon"):
            with self.subTest(line=line):
                self.assertEqual(await self.code(line), "usage")
        self.assertEqual(await self.code("task x !2026-02-30"), "bad-args")

    async def test_overdrive_silent_and_session(self):
        self.assertEqual((await self.ok("overdrive"))["line"], "off")
        self.assertEqual((await self.ok("overdrive 20m"))["line"], "timed, 20:00 left · active")
        self.assertEqual((await self.ok("silent"))["line"], "off")
        self.assertEqual((await self.ok("overdrive sticky"))["line"], "sticky · active")
        self.assertEqual((await self.ok("overdrive off"))["line"], "off")
        self.assertEqual(await self.code("overdrive soon"), "usage")
        self.assertEqual((await self.ok("session pyq 2h"))["line"], "pyq, 2:00:00 left")
        self.assertEqual(await self.code("session pyq 2h"), "conflict")
        self.assertEqual((await self.ok("session end"))["line"], "none")
        self.assertEqual(await self.code("session pyq"), "usage")
        self.assertEqual((await self.ok("session focus"))["line"], "focus, 50:00 left")
        self.assertEqual((await self.ok("session end"))["line"], "none")

    async def test_media(self):
        result = await self.ok("play")
        self.assertEqual(result["line"], "play/pause · Fixture Signal — Test Pattern")
        self.assertEqual(self.host.calls[-1], ("media", "togglePlaying", [], {"read": "active", "ready": "active", "hold": 0}))
        self.assertEqual((await self.ok("next"))["line"], "next track")
        self.assertEqual((await self.ok("prev"))["line"], "previous track")
        self.assertEqual((await self.ok("out"))["line"], "outputs: *Fixture Speakers, Headset (USB), HDMI Headphones out")
        self.host.calls.clear()
        self.assertEqual((await self.ok("out headset"))["line"], "output → Headset (USB)")
        self.assertEqual(self.host.calls[-1], ("audio", "setDefault", ["output", "5"], {"hold": 0}))
        self.assertEqual(await self.code("out h"), "conflict")  # a prefix of two names
        self.assertEqual((await self.ok("out phones"))["data"], {"id": "6"})
        self.assertEqual(await self.code("out bluetooth"), "not-found")

    async def test_system(self):
        await self.ok("bri 70")
        self.assertEqual(self.host.calls[-1], ("power", "setBrightness", [0.7], {"lease": "brightness", "ready": "brightness.available"}))
        self.assertEqual((await self.ok("bri -20"))["line"], "brightness 30%")
        self.assertEqual(self.host.calls[-2][3]["linger"], 0.5)
        self.assertEqual((await self.ok("wifi off"))["line"], "Wi-Fi off")
        self.assertEqual(self.host.calls[-1], ("network", "setWifiEnabled", [False], {"hold": 0}))
        self.assertEqual((await self.ok("bluetooth on"))["line"], "Bluetooth on")
        self.assertEqual(await self.code("wifi maybe"), "usage")
        self.assertEqual((await self.ok("power perf"))["line"], "power performance")
        self.assertEqual(self.host.calls[-1], ("power", "setProfile", ["performance"], {"hold": 0}))
        self.host.values[("power", "profiles")] = ["power-saver", "balanced"]
        self.assertEqual(await self.code("power perf"), "unavailable")
        self.assertEqual(await self.code("power turbo"), "usage")
        self.assertEqual(await self.code("bri 120"), "usage")

    async def test_host_actions_fold_the_panel_first(self):
        self.view.open = True
        self.assertEqual((await self.ok("wall"))["line"], "opened wallpapers")
        self.assertEqual(self.view.commands, [("close", None)])
        self.assertEqual(self.host.calls[-1], ("hostActions", "open", ["wallpapers"], {"hold": 0}))
        await self.ok("settings")
        self.assertEqual(self.view.commands, [("close", None)] * 2)  # sent again: the report may lag
        self.view.state = "absent"
        await self.ok("theme")
        self.assertEqual(len(self.view.commands), 2)  # no view, nothing to fold, and no spawn for it
        await self.ok("lock")
        self.assertEqual(self.host.calls[-1], ("power", "lock", [], {"hold": 0}))
        await self.ok("update")
        self.assertEqual(self.host.calls[-1][2], ["updates"])

    async def test_clip_passes_the_query_and_is_never_remembered(self):
        await self.ok("clip invoice march", "view")
        self.assertEqual(self.view.commands[-1], ("open", "clipboard", "invoice march"))
        await self.ok("tim 5", "view")
        self.assertEqual(self.core.commands.history, ["tim 5"])

    async def test_help_lists_every_domain(self):
        domains = (await self.ok("?"))["data"]["domains"]
        self.assertEqual(list(domains), ["rooms", "timers", "tasks", "modes", "media", "system", "clips", "host", "help"])
        self.assertIn("vol", domains["system"])

    async def test_host_errors_become_results(self):
        async def refuse(*args, **kwargs):
            raise OpError("unavailable", "the view did not start")
        self.host.call = refuse
        result = await self.run_line("vol 40")
        self.assertEqual((result["ok"], result["code"], result["verb"]), (False, "unavailable", "vol"))


if __name__ == "__main__":
    unittest.main()
