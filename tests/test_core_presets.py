"""Presets (Z180): storage, preview of every part and its restore, apply order, missing parts, the look verb."""
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import core_fakes
from core.app import Core
from core.errors import OpError
from core.guards import SessionGuard
from core.palette_catalog import DEFAULT, catalogue
from core.presets import MAX_LOOKS, Presets


class PresetStoreTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.dir = Path(temp.name)

    def test_save_overwrites_by_name_and_persists_cleaned(self):
        p = Presets(self.dir)
        p.save("Evening", {"wallpaper": "/a.jpg", "palette": "amoled:ice", "islandForm": "fluid", "hostTheme": 5})
        p.save("evening", {"palette": "amoled:amber"})
        again = Presets(self.dir)
        self.assertEqual(again.looks, [{"name": "Evening", "wallpaper": "", "palette": "amoled:amber",
                                        "islandForm": "", "hostTheme": ""}])

    def test_names_resolve_rename_delete_and_refusals(self):
        p = Presets(self.dir)
        p.save("Evening", {})
        p.save("Morning", {})
        self.assertEqual(p.resolve("eve")["name"], "Evening")
        with self.assertRaises(OpError):
            p.resolve("ning")  # two match
        with self.assertRaises(OpError):
            p.rename("Evening", "morning")
        p.rename("Evening", "Night")
        p.delete("night")
        self.assertEqual([look["name"] for look in p.looks], ["Morning"])
        for bad in ("", " " * 3, "x" * 49, "a\nb"):
            with self.assertRaises(OpError):
                p.save(bad, {})

    def test_broken_storage_and_the_cap(self):
        (self.dir / "presets.json").write_text("{nope")
        self.assertEqual(Presets(self.dir).looks, [])
        (self.dir / "presets.json").write_text(json.dumps({"looks": [{"name": "A"}, {"name": "a"}, {"name": 3}, "x"]}))
        self.assertEqual([look["name"] for look in Presets(self.dir).looks], ["A"])
        p = Presets(self.dir)
        for i in range(MAX_LOOKS - 1):
            p.save(f"L{i}", {})
        with self.assertRaisesRegex(OpError, "at most"):
            p.save("one more", {})


class PresetCoreTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        clock, scheduler, _, host = core_fakes.fakes()

        async def no_spawn():
            raise OSError("no view in this test")
        with patch("core.palette.catalogue", return_value=catalogue(self.base / "x", self.base / "y")):
            self.core = Core(clock, scheduler, host, self.base / "state", spawn=no_spawn, guard_types=[SessionGuard])
        self.calls = []

        async def fake_call(domain, method, args=(), **options):
            self.calls.append((domain, method, list(args)))
        self.core.hostcalls.call = fake_call
        self.wall = self.base / "rain.jpg"
        self.wall.write_bytes(b"x")
        self.core.wallpaper.report(True, str(self.base / "old.jpg"))
        self.core.host_theme = dict(available=True, current="amoledBlack", error="")
        self.ops = self.core.server.ops
        self.core.presets.save("Rain", {"wallpaper": str(self.wall), "palette": "amoled:ice", "islandForm": "fluid",
                                        "hostTheme": "oxeoDeep"})

    async def test_save_takes_the_current_look(self):
        self.ops["presets.save"](object(), name="Now")
        now = self.core.presets.resolve("Now")
        self.assertEqual(now, {"name": "Now", "wallpaper": str(self.base / "old.jpg"), "palette": DEFAULT,
                               "islandForm": "angular", "hostTheme": "amoledBlack"})

    async def test_preview_moves_palette_and_island_only_and_cancel_restores(self):
        peer = object()
        snap = self.ops["presets.preview"](peer, name="rain")
        self.assertEqual(snap["preview"], "Rain")
        self.assertEqual(self.core.palette.snapshot()["effective"], "amoled:ice")
        self.assertEqual(self.core.island.snapshot()["form"], "fluid")
        self.assertEqual(self.core.island.state["form"], "angular")  # nothing written
        self.assertEqual(self.calls, [])
        self.ops["presets.cancel"](peer)
        self.assertEqual(self.core.palette.snapshot()["effective"], DEFAULT)
        self.assertEqual(self.core.island.snapshot()["form"], "angular")
        self.assertIsNone(self.core.presets.preview)

    async def test_disconnect_and_fold_end_a_preview(self):
        peer = object()
        self.ops["presets.preview"](peer, name="rain")
        self.core.presets_cancel_for(peer)
        self.assertEqual(self.core.island.snapshot()["form"], "angular")
        self.ops["presets.preview"](peer, name="rain")
        self.core.presets_cancel_for()
        self.assertFalse(self.core.palette.snapshot()["preview"])

    async def test_apply_sets_every_part_in_order(self):
        result = await self.ops["presets.apply"](object(), name="rain")
        self.assertEqual(result["applied"], ["palette", "islandForm", "wallpaper", "hostTheme"])
        self.assertEqual(result["skipped"], [])
        self.assertEqual(self.core.palette.name, "amoled:ice")
        self.assertEqual(self.core.island.state["form"], "fluid")
        self.assertEqual(self.calls, [("wallpaper", "set", [str(self.wall)]), ("hostTheme", "set", ["oxeoDeep"])])
        self.assertEqual(self.core.wallpaper.host["current"], str(self.wall))

    async def test_missing_parts_are_marked_and_skipped(self):
        self.wall.unlink()
        self.core.host_theme = dict(available=False, current="", error="DMS is not running")
        self.core.presets.save("Gone", {"palette": "nowhere:x", "wallpaper": str(self.wall), "hostTheme": "t"})
        listed = {look["name"]: look for look in self.core.presets_snapshot()["looks"]}
        self.assertEqual(listed["Gone"]["missing"], ["wallpaper", "palette", "hostTheme"])
        result = await self.ops["presets.apply"](object(), name="gone")
        self.assertEqual((result["applied"], result["skipped"]), ([], ["palette", "wallpaper", "hostTheme"]))
        self.assertEqual(self.calls, [])

    async def test_host_theme_report_only_from_the_view(self):
        with self.assertRaisesRegex(OpError, "only the view"):
            self.ops["hosttheme.report"](object(), available=True, current="x")
        view = object()
        self.core.view.client = view
        self.ops["hosttheme.report"](view, available=True, current="oxeoDeep")
        self.assertEqual(self.core.presets_snapshot()["hostTheme"]["current"], "oxeoDeep")

    async def test_look_verb(self):
        sent = []

        async def command(action, page=None, from_=None, **extra):
            sent.append(extra)
        self.core.view.command = command
        self.assertTrue((await self.core.commands.run("look", "cli"))["ok"])
        self.assertEqual(sent, [{"settings": "presets"}])
        self.assertIn("Rain", (await self.core.commands.run("look list", "cli"))["line"])
        self.assertTrue((await self.core.commands.run("look save Later", "cli"))["ok"])
        done = await self.core.commands.run("look rain", "cli")
        self.assertTrue(done["ok"], done)
        self.assertEqual(self.core.palette.name, "amoled:ice")
        self.assertTrue((await self.core.commands.run("look delete later", "cli"))["ok"])
        self.assertFalse((await self.core.commands.run("look absent", "cli"))["ok"])


if __name__ == "__main__":
    unittest.main()
