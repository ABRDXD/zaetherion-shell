"""The launcher's inline rows (S6, Z27, Z28, Z195): sums, unit conversions, `>cmd`, `?term` and FART verbs."""
from pathlib import Path
import tempfile
import types
import unittest

import core_fakes
from core import inline
from core.app import Core
from core.errors import OpError
from core.launcher import Launcher
from test_core_launcher import APPS


class CalcTests(unittest.TestCase):
    def test_sums(self):
        for text, shown in [("2+2*3", "8"), ("2^10", "1024"), ("10/4", "2.5"), ("2 × 3 ÷ 4", "1.5"), ("(1+2)*3", "9"),
                            ("sqrt(2)", "1.41421356237"), ("pow(2, 3)", "8"), ("-3 + 1", "-2"), ("7 % 3", "1"),
                            ("2*pi", "6.28318530718"), ("0.1+0.2", "0.3")]:
            self.assertEqual(inline.calc(text), shown, text)

    def test_long_sums_and_deep_brackets(self):
        e = "((17^3-29*41+7^4)/(13^2+5*11))*((2^10+3^8+5^6)/(17^2-19))+((97^2-89^2)*(61^2+43^2))/(2^9+7^3)-((123^3-456^2)/(29^2+31^2))"
        self.assertEqual(inline.calc(e), "11127.0283498")
        self.assertEqual(inline.calc(e + "+" + e), "22254.0566996")  # past the old 200-character limit
        self.assertIsNone(inline.calc("(" * 499 + "1+1" + ")" * 499))  # too deep to parse: not a sum, never a crash
        self.assertIsNone(inline.calc("1+" * 600 + "1"))  # past the limit

    def test_what_is_not_a_sum_is_left_to_the_apps(self):
        for text in ["", "2", "-3", "e", "pi", "hello", "firefox", "1,5", "20%", "x+1", "__import__('os')",
                     "(1).real", "1/0", "9^9^9", "sqrt(-1)", "10**400*10**400", "2+" * 120]:
            self.assertIsNone(inline.calc(text), text)


class ConvertTests(unittest.TestCase):
    def shown(self, text):
        c = inline.convert(text)
        return c and f"{c['amount']} {c['source']} = {c['value']} {c['target']}"

    def test_conversions(self):
        self.assertEqual(self.shown("10 km to mi"), "10 km = 6.21371 mi")
        self.assertEqual(self.shown("10km in miles"), "10 km = 6.21371 mi")
        self.assertEqual(self.shown("100 f to c"), "100 °F = 37.7778 °C")
        self.assertEqual(self.shown("0 K -> f"), "0 K = -459.67 °F")
        self.assertEqual(self.shown("5 fl oz to ml"), "5 fl oz = 147.868 mL")
        self.assertEqual(self.shown("1 GiB to MB"), "1 GiB = 1073.74 MB")
        self.assertEqual(self.shown("90 min as h"), "90 min = 1.5 h")

    def test_mixed_or_unknown_units_are_not_conversions(self):
        for text in ["3 kg to m", "10 km", "10 parsecs to km", "km to mi", "firefox"]:
            self.assertIsNone(inline.convert(text), text)


class RowsTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.dir = Path(temp.name)
        verbs = {"vol": "vol [0-100|+n|-n|mute]", "task": "task <text>"}
        self.launcher = Launcher(core_fakes.FakeClock(), self.dir,
                                 verb=lambda text: ({"verb": text.split()[0], "usage": verbs[text.split()[0]], "summary": ""}
                                                    if text.split() and text.split()[0] in verbs else None))
        self.launcher.index(APPS)

    def kinds(self, text, limit=None):
        return [row["kind"] for row in self.launcher.query(text, limit)["rows"]]

    def test_a_prefix_line_is_only_its_own_row(self):
        rows = self.launcher.query(">ls -la")["rows"]
        self.assertEqual([(r["kind"], r["name"], r["description"], r["ready"]) for r in rows],
                         [("command", "> ls -la", "RUN IN KITTY", True)])
        self.assertEqual(self.launcher.query("? hello")["rows"][0]["description"], "BRAVE SEARCH")
        self.assertFalse(self.launcher.query(">")["rows"][0]["ready"])
        self.assertFalse(self.launcher.query("?  ")["rows"][0]["ready"])

    def test_inline_rows_sit_above_the_apps_within_the_limit(self):
        self.assertEqual(self.kinds("2+2", 6)[0], "calc")
        self.assertEqual(self.launcher.query("2+2")["rows"][0]["name"], "2+2 = 4")
        self.assertEqual(self.kinds("10 km to mi")[0], "convert")
        self.assertEqual(self.kinds("vol 40", 3)[0], "verb")
        self.assertEqual(self.launcher.query("vol 40")["rows"][0]["description"], "FART · vol [0-100|+n|-n|mute]")
        self.assertEqual(self.kinds("fi"), ["app", "app"])  # no inline row: the apps as before
        self.assertEqual(len(self.kinds("", 3)), 3)
        self.assertTrue(all(row["ready"] for row in self.launcher.query("fi")["rows"]))

    def test_enter_on_each_kind(self):
        command = self.launcher.act("command", "> echo hi")["argv"]
        self.assertEqual(command[:4], ["kitty", "-e", "sh", "-c"])
        self.assertEqual(command[-1], "echo hi")  # passed as an argument, never spliced into the script
        self.assertEqual(self.launcher.act("search", "?cats & dogs")["argv"],
                         ["xdg-open", "https://search.brave.com/search?q=cats+%26+dogs"])
        self.assertEqual(self.launcher.act("calc", "2+2")["copy"], "4")
        self.assertEqual(self.launcher.act("convert", "10 km to mi")["copy"], "6.21371")
        for kind, text in [("command", ">"), ("search", "?"), ("calc", "firefox"), ("convert", "2+2"), ("app", "x"),
                           ("command", "ls")]:
            with self.assertRaises(OpError, msg=(kind, text)):
                self.launcher.act(kind, text)

    def test_engine_and_browser_settings(self):
        self.launcher.configure(search="duckduckgo", browser="zen-browser", terminal="foot")
        self.assertEqual(self.launcher.act("search", "?x")["argv"], ["zen-browser", "https://duckduckgo.com/?q=x"])
        self.assertEqual(self.launcher.query(">top")["rows"][0]["description"], "RUN IN FOOT")
        for change in [{"search": "altavista"}, {"browser": "--evil"}, {"browser": 3}]:
            with self.assertRaises(OpError, msg=change):
                self.launcher.configure(**change)
        reloaded = Launcher(core_fakes.FakeClock(), self.dir)
        self.assertEqual((reloaded.settings["search"], reloaded.settings["browser"]), ("duckduckgo", "zen-browser"))


class CoreTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        clock, scheduler, profile, host = core_fakes.fakes()

        async def no_spawn():
            raise OSError("no view in this test")
        self.core = Core(clock, scheduler, host, Path(temp.name), spawn=no_spawn)
        self.peer = types.SimpleNamespace(kind="view")

    def test_verb_rows_come_from_the_command_grammar(self):
        commands = self.core.commands
        self.assertEqual(commands.inline("task buy milk")["verb"], "task")  # exact name with arguments
        self.assertEqual(commands.inline("task")["verb"], "task")  # exact name alone
        self.assertIsNone(commands.inline("ta"))  # a bare prefix stays with the apps
        self.assertIsNone(commands.inline("firefox"))
        self.assertIsNone(commands.inline("? vol"))  # ? and > are the launcher's own prefixes
        self.assertEqual(self.core.launcher.query("task buy milk")["rows"][0]["kind"], "verb")

    async def test_enter_on_a_verb_runs_it_in_the_core(self):
        act = self.core.server.ops["launcher.act"]
        reply = await act(self.peer, kind="verb", text="task buy milk")
        self.assertTrue(reply["result"]["ok"], reply)
        self.assertEqual([t["text"] for t in self.core.tasks.snapshot()["tasks"]][-1:], ["buy milk"])
        with self.assertRaises(OpError):
            await act(self.peer, kind="verb", text="firefox")
        self.assertEqual(await act(self.peer, kind="calc", text="6*7"), {"copy": "42"})



class PageTests(unittest.IsolatedAsyncioTestCase):
    """Launcher pages (after cmdk): a verb's genuine choices, never free-text samples."""
    async def asyncSetUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        clock, scheduler, profile, host = core_fakes.fakes()

        async def no_spawn():
            raise OSError("no view in this test")
        self.core = Core(clock, scheduler, host, Path(temp.name), spawn=no_spawn)

    def labels(self, verb):
        return [o["label"] for o in self.core.commands.page(verb)["options"]]

    def test_listed_choices_and_lines(self):
        page = self.core.commands.page("eq")
        self.assertEqual(page["verb"], "eq")
        self.assertIn("bass", self.labels("eq"))
        self.assertEqual(page["options"][0]["line"], "eq " + page["options"][0]["label"])

    def test_free_text_verbs_have_no_page(self):
        self.assertEqual(self.labels("task"), [])
        self.assertEqual(self.labels("clip"), [])

    def test_sessions_page_reads_the_presets(self):
        names = [p["name"] for p in self.core.sessions.snapshot()["presets"]]
        self.assertEqual(self.labels("session"), names + ["end"])

    def test_examples_stand_in_and_prefixes_resolve(self):
        self.assertEqual(self.labels("vo"), self.labels("vol"))   # a unique prefix
        with self.assertRaises(OpError):
            self.core.commands.page("nosuchverb")

    async def test_op(self):
        reply = self.core.server.ops["launcher.page"](types.SimpleNamespace(kind="view"), verb="power")
        self.assertEqual([o["label"] for o in reply["options"]], ["perf", "bal", "save"])

if __name__ == "__main__":
    unittest.main()
