"""The verb registry and matcher, history, help, and vol against a fake view: no host is touched."""
import json
from pathlib import Path
import tempfile
import unittest

import core_fakes  # noqa: F401
from core.command import Commands
from core.errors import OpError
from core.verbs.base import Result, Verb
from core.verbs.system import VERBS as SYSTEM


class FakeView:
    def __init__(self):
        self.commands = []
        self.state, self.open = "ready", True

    async def command(self, action, page=None, from_=None):
        self.commands.append((action, page))
        if action == "close":
            self.open = False


class FakeHostCalls:
    """Answers reads from `values` and records every call as (domain, method, args, options)."""

    def __init__(self, values=None):
        self.values = values or {}
        self.calls = []
        self.fail = None

    async def call(self, domain, method=None, args=(), **options):
        self.calls.append((domain, method, list(args), options))
        if self.fail:
            raise self.fail
        return self.values.get((domain, options.get("read")))


class FakeCore:
    def __init__(self, values=None):
        self.view = FakeView()
        self.hostcalls = FakeHostCalls(values)
        self.clock, *_ = core_fakes.fakes()


def noop(name, domain="test", **extra):
    async def run(context, words):
        return Result(f"{name} {' '.join(words)}".strip())
    return Verb(name, domain, name, name, (name,), run, **extra)


class Harness(unittest.IsolatedAsyncioTestCase):
    verbs = None

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name)
        self.core = FakeCore({("audio", "output"): {"id": "1", "name": "Fixture Speakers", "volume": 0.42, "muted": False}})
        self.commands = Commands(self.core, self.state, self.verbs)

    async def run_line(self, line, source="cli", **flags):
        return await self.commands.run(line, source, **flags)


class MatchingTests(Harness):
    verbs = [noop("task"), noop("tim", aliases=("timers",)), noop("theme"), noop("vol")]

    async def test_exact_alias_and_unique_prefix(self):
        for line, verb in (("tim 25", "tim"), ("TIMERS", "tim"), ("v 40", "vol"), ("th", "theme"), ("help", "?")):
            with self.subTest(line=line):
                self.assertEqual((await self.run_line(line))["verb"], verb)
        self.assertEqual((await self.run_line("v 40"))["line"], "vol 40")

    async def test_ambiguous_prefix_lists_candidates_until_history_decides(self):
        result = await self.run_line("t", "view")
        self.assertEqual((result["ok"], result["code"], result["candidates"], result["complete"]),
                         (False, "ambiguous", ["task", "theme", "tim"], "t"))
        await self.run_line("tim 5", "view")
        self.assertEqual((await self.run_line("t", "view"))["verb"], "tim")  # 1 against 0
        await self.run_line("task a", "view")
        self.assertEqual((await self.run_line("t", "view"))["code"], "ambiguous")  # 1 against 1
        await self.run_line("tim 6", "view")
        await self.run_line("timers", "view")
        self.assertEqual((await self.run_line("t", "view"))["verb"], "tim")  # 2 (distinct lines) against 1

    async def test_unknown_words_fall_through_only_for_the_view(self):
        result = await self.run_line("firefox --new", "cli")
        self.assertEqual((result["ok"], result["code"]), (False, "usage"))
        self.assertEqual(self.core.hostcalls.calls, [])
        result = await self.run_line("firefox --new", "view")
        self.assertEqual((result["ok"], result["fallthrough"]), (True, "launcher"))
        self.assertEqual(self.core.view.commands, [("close", None)])
        self.assertEqual(self.core.hostcalls.calls, [("hostActions", "openLauncher", ["firefox --new"], {"hold": 0})])
        self.assertEqual(self.commands.history, [])

    async def test_fallthrough_folds_a_panel_that_has_not_reported_open(self):
        # The race: open, then type and Enter before the view's open report arrives.
        self.core.view.open = False
        result = await self.run_line("firefox", "view")
        self.assertEqual(result["fallthrough"], "launcher")
        self.assertEqual(self.core.view.commands, [("close", None)])
        self.assertEqual(self.core.hostcalls.calls[-1][1], "openLauncher")  # after the fold

    async def test_empty_and_oversized_lines(self):
        self.assertEqual((await self.run_line("   "))["code"], "usage")
        with self.assertRaises(OpError):
            await self.run_line("x" * 1001)
        with self.assertRaises(OpError):
            await self.run_line("tim", fallthrough="yes")

    def test_duplicate_names_are_refused(self):
        with self.assertRaises(ValueError):
            Commands(self.core, self.state, [noop("tim"), noop("timer", aliases=("tim",))])

    def test_complete_gives_the_hint_or_the_candidates(self):
        self.assertEqual(self.commands.complete("vo")["usage"], "vol")
        hint = self.commands.complete("t")
        self.assertEqual(([c["name"] for c in hint["candidates"]], hint["complete"], hint["verb"]), (["task", "theme", "tim"], "t", None))
        self.assertEqual(self.commands.complete("zz")["candidates"], [])

    async def test_help_lists_domains_and_one_verb(self):
        listing = await self.run_line("?")
        self.assertEqual(listing["data"]["domains"], {"test": ["task", "tim", "theme", "vol"], "help": ["?"]})
        one = await self.run_line("? timers")
        self.assertIn("tim (also timers): tim", one["line"])
        self.assertEqual((await self.run_line("? nope"))["code"], "usage")


class HistoryTests(Harness):
    verbs = [noop("tim"), noop("clip", record=False)]

    async def test_view_lines_are_kept_newest_last_deduplicated_and_private(self):
        for line in ("tim 25", "tim  5", "clip secret words", "tim 25", "?"):
            await self.run_line(line, "view")
        await self.run_line("tim 99", "cli")
        self.assertEqual(self.commands.history, ["tim 5", "tim 25"])
        path = self.state / "history.json"
        self.assertEqual(json.loads(path.read_text())["lines"], ["tim 5", "tim 25"])
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.commands.recent("tim 2")["lines"], ["tim 25"])
        self.assertEqual(Commands(self.core, self.state, self.verbs).history, ["tim 5", "tim 25"])

    async def test_capped_at_100_and_failures_are_not_kept(self):
        for n in range(105):
            await self.run_line(f"tim {n}", "view")
        self.assertEqual(len(self.commands.history), 100)
        self.assertEqual(self.commands.history[0], "tim 5")
        await self.run_line("nope", "view", fallthrough=False)
        self.assertEqual(self.commands.history[-1], "tim 104")

    def test_a_broken_file_starts_empty(self):
        (self.state / "history.json").write_text("{")
        self.assertEqual(Commands(self.core, self.state, self.verbs).history, [])


class VolTests(Harness):
    verbs = SYSTEM

    async def test_absolute_level_holds_the_mixer_for_one_call(self):
        result = await self.run_line("vol 40%")
        self.assertEqual((result["ok"], result["line"], result["data"]), (True, "Fixture Speakers 40%", {"level": 40}))
        self.assertEqual(self.core.hostcalls.calls, [
            ("audio", "setVolume", [{"$": "output.id"}, 0.4], {"read": "output", "lease": "mixer", "ready": "output"})])

    async def test_relative_step_reads_then_sets_within_the_linger(self):
        result = await self.run_line("vol +5")
        self.assertEqual(result["line"], "Fixture Speakers 47%")
        read, write = self.core.hostcalls.calls
        self.assertEqual(read, ("audio", None, [], {"read": "output", "hold": 0, "linger": 0.5, "lease": "mixer", "ready": "output"}))
        self.assertEqual(write[2], [{"$": "output.id"}, 0.47])
        self.core.hostcalls.calls.clear()
        await self.run_line("vol -90")
        self.assertEqual(self.core.hostcalls.calls[1][2][1], 0)
        self.core.hostcalls.values[("audio", "output")]["volume"] = 0.98
        self.assertEqual((await self.run_line("vol +5"))["data"], {"level": 100})

    async def test_bad_levels_are_usage_errors_and_touch_nothing(self):
        for line in ("vol 101", "vol loud", "vol 4 0", "vol +200", "vol -"):
            with self.subTest(line=line):
                self.assertEqual((await self.run_line(line))["code"], "usage")
        self.assertEqual(self.core.hostcalls.calls, [])

    async def test_bare_vol_opens_devices(self):
        result = await self.run_line("vol")
        self.assertEqual((result["line"], result["tone"]), ("→ Devices", "info"))
        self.assertEqual(self.core.view.commands, [("open", "devices")])

    async def test_muted_and_unavailable(self):
        self.core.hostcalls.values[("audio", "output")]["muted"] = True
        self.assertEqual((await self.run_line("vol 10"))["line"], "Fixture Speakers 10% (muted)")
        self.core.hostcalls.fail = OpError("unavailable", "audio is not ready")
        result = await self.run_line("vol 10")
        self.assertEqual((result["ok"], result["code"], result["line"]), (False, "unavailable", "audio is not ready"))


if __name__ == "__main__":
    unittest.main()
