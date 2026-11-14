"""The launcher's apps half in the core (S6): matching, frecency, the one-time import, settings and the blocklist."""
from datetime import datetime, timedelta
from pathlib import Path
import json
import tempfile
import unittest

import core_fakes
from core import matching
from core.app import Core
from core.errors import OpError
from core.guards import SessionGuard
from core.launcher import DEFAULTS, Launcher

APPS = [
    {"id": "firefox", "name": "Firefox", "genericName": "Web Browser", "comment": "Browse the Web", "icon": "firefox",
     "keywords": ["internet", "www"]},
    {"id": "code", "name": "Visual Studio Code", "genericName": "Text Editor", "comment": "Code editing", "icon": "vscode"},
    {"id": "kitty", "name": "kitty", "genericName": "Terminal emulator", "comment": "Fast GPU terminal", "icon": "kitty"},
    {"id": "org.gnome.Nautilus", "name": "Files", "genericName": "", "comment": "Access and organize files", "icon": "folder"},
    {"id": "steam", "name": "Steam", "comment": "Game store", "icon": "steam"},
    {"id": "htop", "name": "Htop", "comment": "Process viewer", "icon": "htop", "terminal": True},
]


class MatchingTests(unittest.TestCase):
    def kind(self, name, query, **fields):
        result = matching.score(matching.Indexed(name, **fields), query)
        return result and result[0]

    def test_kinds_in_dms_order(self):
        self.assertEqual(self.kind("Firefox", "firefox"), "exact")
        self.assertEqual(self.kind("Firefox", "fire"), "prefix")
        self.assertEqual(self.kind("Visual Studio Code", "stu co"), "word")
        self.assertEqual(self.kind("Visual Studio Code", "dio"), "substring")
        self.assertEqual(self.kind("Firefox", "web", generic="web browser"), "generic-prefix")
        self.assertEqual(self.kind("Firefox", "browser", generic="web browser"), "generic")
        self.assertEqual(self.kind("Files", "nautilus", id="org.gnome.nautilus"), "id")
        self.assertEqual(self.kind("Firefox", "inter", keywords=["internet"]), "keyword-prefix")
        self.assertEqual(self.kind("Firefox", "ernet", keywords=["internet"]), "keyword")
        self.assertEqual(self.kind("Files", "organize", comment="access and organize files"), "comment")
        self.assertEqual(self.kind("Firefox", "firefxo"), "fuzzy")
        self.assertIsNone(self.kind("Firefox", "zz"))

    def test_typo_budget_grows_with_the_query(self):
        self.assertIsNone(self.kind("Steam", "sx"))  # two letters: no typos allowed
        self.assertEqual(self.kind("Steam", "staem"), "fuzzy")
        self.assertEqual(matching.levenshtein("kitten", "sitting"), 3)


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)
        self.clock = core_fakes.FakeClock()
        self.session = False

    def make(self, imported=None):
        launcher = Launcher(self.clock, self.dir, imported=lambda: imported, session_active=lambda: self.session)
        launcher.index(APPS)
        return launcher

    def ids(self, launcher, text="", limit=None):
        return [row["id"] for row in launcher.query(text, limit)["rows"]]

    def date(self, days_ago=0):
        return (datetime.fromtimestamp(self.clock.real).date() - timedelta(days=days_ago)).isoformat()

    def test_text_score_orders_results(self):
        launcher = self.make()
        self.assertEqual(self.ids(launcher, "fi"), ["org.gnome.Nautilus", "firefox"])  # both prefixes: by name
        rows = launcher.query("te")["rows"]  # both generic names start with it: tied, so by name
        self.assertEqual([(r["id"], r["match"]) for r in rows][:3],
                         [("kitty", "generic-prefix"), ("code", "generic-prefix"), ("steam", "substring")])
        self.assertEqual(self.ids(launcher, "emul"), ["kitty"])
        self.assertEqual(self.ids(launcher, "  KITTY "), ["kitty"])

    def test_nothing_typed_shows_most_frecent_first_then_by_name(self):
        launcher = self.make()
        launcher.launch("kitty")
        launcher.launch("kitty")
        launcher.launch("steam")
        self.assertEqual(self.ids(launcher, "", 4), ["kitty", "steam", "org.gnome.Nautilus", "firefox"])
        self.assertEqual(len(launcher.query("")["rows"]), DEFAULTS["rows"])

    def test_frecency_lifts_a_weaker_match_and_fades_with_time(self):
        launcher = self.make()
        for _ in range(10):
            launcher.launch("firefox")
        # "f": Files and Firefox are both prefixes; ten launches today put Firefox first.
        self.assertEqual(self.ids(launcher, "f")[0], "firefox")
        self.assertEqual(launcher.frecency("firefox"), (1000, 1500))
        self.clock.advance(20 * 86400)
        self.assertEqual(launcher.frecency("firefox"), (500, 500))
        self.clock.advance(400 * 86400)
        self.assertEqual(launcher.frecency("firefox"), (0, 0))  # older than a year: no longer counted

    def test_history_survives_a_restart(self):
        self.make().launch("code")
        self.assertEqual(self.ids(self.make(), "", 1), ["code"])

    def test_old_counts_import_once_by_name(self):
        stats = {"Firefox": {self.date(1): 3}, "firefox": {self.date(1): 3, self.date(2): 1},
                 "Gone App": {self.date(1): 9}, "Bad": {"yesterday": 2}}
        launcher = self.make(stats)
        record = launcher.history["firefox"]
        self.assertEqual(record["days"], {self.date(1): 3, self.date(2): 1})  # case twins counted once
        self.assertEqual(launcher.pending, {"gone app": {self.date(1): 9}})
        self.assertEqual(self.ids(launcher, "", 1), ["firefox"])
        # A second start never re-imports, even if the old file has grown.
        again = self.make({"Firefox": {self.date(0): 50}})
        self.assertEqual(again.history["firefox"]["days"], {self.date(1): 3, self.date(2): 1})
        self.assertEqual(again.pending, {"gone app": {self.date(1): 9}})
        # An app installed later picks up its old counts when the list next arrives.
        again.index(APPS + [{"id": "gone", "name": "Gone App"}])
        self.assertEqual(again.history["gone"]["days"], {self.date(1): 9})
        self.assertEqual(again.pending, {})

    def test_import_failure_is_not_fatal(self):
        def broken():
            raise OSError("unreadable")
        with self.assertLogs("fart.launcher", "ERROR"):
            launcher = Launcher(self.clock, self.dir, imported=broken)
        self.assertEqual(launcher.pending, {})

    def test_hidden_apps_and_settings(self):
        launcher = self.make()
        launcher.configure(hidden=["firefox"], rows=8)
        self.assertNotIn("firefox", self.ids(launcher, "fi"))
        self.assertEqual(Launcher(self.clock, self.dir).settings["rows"], 8)
        for bad in ({"rows": 99}, {"rows": True}, {"terminal": ""}, {"hidden": "firefox"}, {"colour": 1}):
            with self.assertRaises(OpError):
                launcher.configure(**bad)
        (self.dir / "launcher.json").write_text(json.dumps({"rows": 99, "terminal": "foot"}))
        with self.assertLogs("fart.launcher", "WARNING"):
            self.assertEqual(Launcher(self.clock, self.dir).settings, dict(DEFAULTS, terminal="foot"))

    def test_forget_clears_history(self):
        launcher = self.make({"Gone App": {self.date(1): 1}})
        launcher.launch("kitty")
        launcher.forget()
        self.assertEqual((launcher.history, launcher.pending), ({}, {}))
        self.assertEqual(Launcher(self.clock, self.dir).history, {})

    def test_session_blocks_listed_apps(self):
        launcher = self.make()
        self.session = True
        row = launcher.query("steam")["rows"][0]
        self.assertTrue(row["blocked"])
        with self.assertRaises(OpError) as caught:
            launcher.launch("steam")
        self.assertEqual(caught.exception.message, "> BLOCKED · SESSION")
        self.assertNotIn("steam", launcher.history)
        self.session = False
        self.assertFalse(launcher.query("steam")["rows"][0]["blocked"])
        launcher.launch("steam")

    def test_launch_says_when_a_terminal_is_needed(self):
        launcher = self.make()
        self.assertEqual(launcher.launch("htop"), {"id": "htop", "terminal": "kitty"})
        self.assertEqual(launcher.launch("kitty"), {"id": "kitty", "terminal": None})
        with self.assertRaises(OpError):
            launcher.launch("nope")

    def test_bad_input_is_refused(self):
        launcher = self.make()
        for text, limit in (("x" * 201, None), (3, None), ("", 0), ("", True)):
            with self.assertRaises(OpError):
                launcher.query(text, limit)
        with self.assertRaises(OpError):
            launcher.index("apps")
        launcher.index([{"id": ""}, {"name": "no id"}, "junk", {"id": "ok"}])
        self.assertEqual(list(launcher.apps), ["ok"])

    def test_corrupt_history_starts_empty(self):
        self.make().launch("kitty")
        (self.dir / "launches.json").write_text(json.dumps(
            {"apps": {"kitty": {"days": {"nope": 1}, "last": 0}, "code": {"days": {self.date(): 2}, "last": 1}},
             "pending": {"x": {"bad": 1}}}))
        launcher = Launcher(self.clock, self.dir)
        self.assertEqual(list(launcher.history), ["code"])
        self.assertEqual(launcher.pending, {})


class LauncherCoreTests(unittest.IsolatedAsyncioTestCase):
    async def test_core_wires_the_host_profiles_counts_and_the_session(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        clock, scheduler, profile, host = core_fakes.fakes()
        today = datetime.fromtimestamp(clock.real).date().isoformat()
        profile.launch_stats = {"Steam": {today: 4}}

        async def no_spawn():
            raise OSError("no view in this test")
        core = Core(clock, scheduler, host, Path(temp.name), spawn=no_spawn, guard_types=[SessionGuard])
        core.launcher.index(APPS)
        self.assertEqual(core.launcher.query("", 1)["rows"][0]["id"], "steam")
        self.assertIn("launcher", core.server.snapshots)
        self.assertIn("launcher.query", core.server.ops)
        core.sessions.start("deep")
        self.assertTrue(core.launcher.query("steam")["rows"][0]["blocked"])


if __name__ == "__main__":
    unittest.main()
