"""Wallpaper folder scan, resolve, recent, preview ownership, the host's report and the wall verb (Z177, Z178)."""
import asyncio
import json
import tempfile
import unittest
from pathlib import Path

import core_fakes
from core.app import Core
from core.errors import OpError
from core.guards import SessionGuard
from core.wallpaper import DEFAULT_FOLDER, RECENT, Wallpaper


def make_folder(base: Path, names=("rain_on_water.jpg", "Snow Range.png", "rain_city.webp", "loop.mp4")):
    folder = base / "home/Pictures/Wallpapers"
    folder.mkdir(parents=True)
    for name in names:
        (folder / name).write_bytes(b"x")
    (folder / "notes.txt").write_text("not a wallpaper")
    (folder / ".hidden.jpg").write_bytes(b"x")
    (folder / "sub.jpg").mkdir()  # a directory named like an image
    return folder


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        self.folder = make_folder(self.base)
        self.w = Wallpaper(self.base, home=self.base / "home")
        self.events = []
        self.w.on_change = lambda: self.events.append(self.w.snapshot())

    def test_default_folder_and_scan_keeps_only_wallpaper_files(self):
        self.assertEqual(self.w.folder, DEFAULT_FOLDER)
        files = [e["file"] for e in self.w.scan()]
        self.assertEqual(files, ["loop.mp4", "rain_city.webp", "rain_on_water.jpg", "Snow Range.png"])
        kinds = {e["file"]: e["kind"] for e in self.w.scan()}
        self.assertEqual(kinds["loop.mp4"], "video")
        self.assertEqual(kinds["Snow Range.png"], "image")
        self.assertTrue(self.w.listing()["exists"])

    def test_resolve_by_path_file_name_partial_and_refusals(self):
        water = str(self.folder / "rain_on_water.jpg")
        self.assertEqual(self.w.resolve(water), water)
        self.assertEqual(self.w.resolve("snow range"), str(self.folder / "Snow Range.png"))
        self.assertEqual(self.w.resolve("water"), water)
        with self.assertRaisesRegex(OpError, "2 wallpapers match"):
            self.w.resolve("rain")
        with self.assertRaisesRegex(OpError, "unknown"):
            self.w.resolve("absent")
        with self.assertRaises(OpError):
            self.w.resolve(str(self.base / "elsewhere.jpg"))  # never outside the folder
        with self.assertRaises(OpError):
            self.w.resolve("")

    def test_missing_folder_is_empty_and_refuses(self):
        self.w.set_folder(str(self.base / "gone"))
        self.assertEqual(self.w.scan(), [])
        self.assertFalse(self.w.snapshot()["exists"])
        with self.assertRaisesRegex(OpError, "no wallpapers"):
            self.w.resolve("rain")
        with self.assertRaisesRegex(OpError, "no wallpapers"):
            self.w.step(1)

    def test_folder_and_recent_persist_and_bad_storage_falls_back(self):
        a, b = str(self.folder / "loop.mp4"), str(self.folder / "rain_city.webp")
        self.w.applied(a)
        self.w.applied(b)
        self.w.applied(a)
        again = Wallpaper(self.base, home=self.base / "home")
        self.assertEqual(again.recent, [a, b])
        for i in range(RECENT + 3):
            again.applied(f"/x/{i}.jpg")
        self.assertEqual(len(again.recent), RECENT)
        self.w.path.write_text("{broken")
        self.assertEqual(Wallpaper(self.base, home=self.base / "home").folder, DEFAULT_FOLDER)
        self.w.path.write_text(json.dumps({"folder": 4, "recent": "x"}))
        broken = Wallpaper(self.base, home=self.base / "home")
        self.assertEqual((broken.folder, broken.recent), (DEFAULT_FOLDER, []))

    def test_preview_is_owned_and_never_writes(self):
        a, b = object(), object()
        self.w.preview_name("water", a)
        self.assertEqual(self.w.snapshot()["preview"], str(self.folder / "rain_on_water.jpg"))
        self.w.cancel(b)
        self.assertIsNotNone(self.w.preview)
        self.w.cancel(a)
        self.assertIsNone(self.w.preview)
        self.w.preview_name("snow", a)
        self.w.cancel()  # a fold always restores
        self.assertIsNone(self.w.preview)
        self.assertFalse(self.w.path.exists())

    def test_report_publishes_only_changes_and_gates_apply(self):
        with self.assertRaisesRegex(OpError, "can't set"):
            self.w.can_apply()
        self.w.report(True, "/a.jpg")
        self.w.report(True, "/a.jpg")
        self.assertEqual(len(self.events), 1)
        self.w.can_apply()
        self.w.report(True, "/a.jpg", perScreen=True)
        with self.assertRaisesRegex(OpError, "per screen"):
            self.w.can_apply()
        self.w.report(False, "", error="DMS is not running")
        with self.assertRaisesRegex(OpError, "DMS is not running"):
            self.w.can_apply()

    def test_step_wraps_from_current(self):
        files = [e["path"] for e in self.w.scan()]
        self.assertEqual(self.w.step(1), files[0])  # nothing current yet
        self.w.report(True, files[-1])
        self.assertEqual(self.w.step(1), files[0])
        self.assertEqual(self.w.step(-1), files[-2])


class WallpaperCoreTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        self.folder = make_folder(self.base)
        clock, scheduler, _, host = core_fakes.fakes()

        async def no_spawn():
            raise OSError("no view in this test")
        self.core = Core(clock, scheduler, host, self.base / "state", spawn=no_spawn, guard_types=[SessionGuard])
        self.core.wallpaper.home = self.base / "home"
        self.host_calls = []

        async def fake_call(domain, method, args=(), **options):
            self.host_calls.append((domain, method, list(args), options))
        self.core.hostcalls.call = fake_call

    async def test_topic_ops_and_report_from_the_view_only(self):
        self.assertIn("wallpaper", self.core.server.snapshots)
        listing = self.core.server.ops["wallpaper.list"](object())
        self.assertEqual(len(listing["entries"]), 4)
        with self.assertRaisesRegex(OpError, "only the view"):
            self.core.server.ops["wallpaper.report"](object(), available=True, current="/a.jpg")
        view = object()
        self.core.view.client = view
        self.core.server.ops["wallpaper.report"](view, available=True, current="/a.jpg")
        self.assertEqual(self.core.server.snapshots["wallpaper"]()["current"], "/a.jpg")

    async def test_choose_goes_through_the_host_and_records(self):
        self.core.wallpaper.report(True, "")
        result = await self.core.server.ops["wallpaper.choose"](object(), name="water")
        path = str(self.folder / "rain_on_water.jpg")
        self.assertEqual(self.host_calls, [("wallpaper", "set", [path], {"ready": "available", "hold": 0})])
        self.assertEqual((result["current"], result["recent"]), (path, [path]))

    async def test_choose_refused_without_a_host(self):
        with self.assertRaisesRegex(OpError, "can't set"):
            await self.core.server.ops["wallpaper.choose"](object(), name="water")
        self.assertEqual(self.host_calls, [])

    async def test_preview_cancelled_on_disconnect_and_fold(self):
        peer = object()
        self.core.server.ops["wallpaper.preview"](peer, name="snow")
        callback = next(c for c in self.core.server.on_disconnect if getattr(c, "__self__", None) is self.core.wallpaper)
        callback(peer)
        self.assertIsNone(self.core.wallpaper.preview)
        self.core.server.ops["wallpaper.preview"](peer, name="snow")
        callback = next(c for c in self.core.view.on_closed if getattr(c, "__self__", None) is self.core.wallpaper)
        callback()
        self.assertIsNone(self.core.wallpaper.preview)

    async def test_wall_verb(self):
        sent = []

        async def command(action, page=None, from_=None, **extra):
            sent.append((action, page, extra))
        self.core.view.command = command
        result = await self.core.commands.run("wall", "cli")
        self.assertTrue(result["ok"], result)
        self.assertEqual(sent, [("open", "home", {"settings": "wallpaper"})])
        listed = await self.core.commands.run("wall list", "cli")
        self.assertIn("rain_on_water.jpg", listed["line"])
        refused = await self.core.commands.run("wall water", "cli")
        self.assertFalse(refused["ok"])
        self.core.wallpaper.report(True, "")
        done = await self.core.commands.run("wall water", "cli")
        self.assertTrue(done["ok"], done)
        self.assertIn("rain_on_water.jpg", done["line"])
        nxt = await self.core.commands.run("wall next", "cli")
        self.assertIn("Snow Range.png", nxt["line"])
        theme = await self.core.commands.run("theme", "cli")
        self.assertTrue(theme["ok"])
        self.assertEqual(sent[-1], ("open", "home", {"settings": "palette"}))

    async def test_view_command_rejects_unknown_section(self):
        with self.assertRaisesRegex(OpError, "settings must be"):
            await self.core.view.command("open", "home", settings="elsewhere")


if __name__ == "__main__":
    unittest.main()


class WallpaperColourTests(unittest.IsolatedAsyncioTestCase):
    """Colours from the wallpaper (Z179): previewed with it, saved with it, never run for video, races resolved."""

    async def asyncSetUp(self):
        from unittest.mock import patch
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        self.folder = make_folder(self.base)
        clock, scheduler, _, host = core_fakes.fakes()

        async def no_spawn():
            raise OSError("no view in this test")
        from core.palette_catalog import catalogue
        with patch("core.palette.catalogue", return_value=catalogue(self.base / "x", self.base / "y")):
            self.core = Core(clock, scheduler, host, self.base / "state", spawn=no_spawn, guard_types=[SessionGuard])
        self.core.wallpaper.home = self.base / "home"
        self.core.wallpaper.report(True, "")

        async def fake_call(*args, **options):
            return None
        self.core.hostcalls.call = fake_call
        self.runs = []
        self.gate = {}

        async def colors_for(path):
            self.runs.append(path)
            if path in self.gate:
                await self.gate[path].wait()
            if "Snow" in path:
                raise RuntimeError("matugen could not read this image")
            return {"background": "#101418", "accent": "#a0c8ff"}
        patcher = patch("adapters.common.wallpaper_colors.colors_for", colors_for)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.ops = self.core.server.ops

    async def test_off_by_default_and_persisted(self):
        self.assertFalse(self.core.wallpaper.snapshot()["colours"])
        await self.ops["wallpaper.preview"](object(), name="water")
        self.assertEqual(self.runs, [])
        self.ops["wallpaper.colours"](object(), on=True)
        self.assertTrue(Wallpaper(self.base / "state").colours)

    async def test_preview_previews_the_palette_and_cancel_restores(self):
        peer = object()
        self.ops["wallpaper.colours"](peer, on=True)
        await self.ops["wallpaper.preview"](peer, name="water")
        palette = self.core.palette.snapshot()
        self.assertTrue(palette["preview"])
        self.assertEqual(palette["effective"], "wall:" + str(self.folder / "rain_on_water.jpg"))
        self.assertEqual(palette["colors"]["accent"], "#a0c8ff")
        self.ops["wallpaper.cancel"](peer)
        self.assertFalse(self.core.palette.snapshot()["preview"])
        await self.ops["wallpaper.preview"](peer, name="water")
        self.assertEqual(len(self.runs), 1)  # made once, then reused

    async def test_choose_saves_the_made_palette_and_it_survives_a_restart(self):
        from core.palette import Palette
        self.ops["wallpaper.colours"](object(), on=True)
        await self.ops["wallpaper.choose"](object(), name="water")
        key = "wall:" + str(self.folder / "rain_on_water.jpg")
        self.assertEqual(self.core.palette.name, key)
        again = Palette(self.base / "state", {k: v for k, v in self.core.palette.entries.items() if not k.startswith("wall:")})
        self.assertEqual(again.name, key)
        self.assertEqual(again.entries[key]["colors"]["accent"], "#a0c8ff")
        self.assertIn(key, [e["id"] for e in again.listing()])

    async def test_video_is_skipped_and_failure_is_reported_without_changing_the_palette(self):
        self.ops["wallpaper.colours"](object(), on=True)
        before = self.core.palette.name
        await self.ops["wallpaper.choose"](object(), name="loop")
        self.assertEqual(self.runs, [])
        await self.ops["wallpaper.choose"](object(), name="snow")
        self.assertEqual(self.core.palette.name, before)
        self.assertIn("could not read", self.core.wallpaper.snapshot()["coloursError"])
        self.assertEqual(self.core.wallpaper.snapshot()["current"], str(self.folder / "Snow Range.png"))

    async def test_a_slow_earlier_hover_does_not_override_a_later_one(self):
        peer = object()
        self.ops["wallpaper.colours"](peer, on=True)
        water = str(self.folder / "rain_on_water.jpg")
        self.gate[water] = asyncio.Event()
        slow = asyncio.create_task(self.ops["wallpaper.preview"](peer, name="water"))
        await asyncio.sleep(0)
        await self.ops["wallpaper.preview"](peer, name="city")
        self.gate[water].set()
        await slow
        self.assertEqual(self.core.palette.snapshot()["effective"], "wall:" + str(self.folder / "rain_city.webp"))

    async def test_turning_colours_off_ends_a_made_preview(self):
        peer = object()
        self.ops["wallpaper.colours"](peer, on=True)
        await self.ops["wallpaper.preview"](peer, name="water")
        self.ops["wallpaper.colours"](peer, on=False)
        self.assertFalse(self.core.palette.snapshot()["preview"])

    async def test_made_palettes_are_bounded_and_unlisted(self):
        from core.palette import MADE_KEPT
        for i in range(MADE_KEPT + 5):
            self.core.palette.add_made(f"wall:/x/{i}.jpg", str(i), {"background": "#000000"})
        self.assertLessEqual(sum(k.startswith("wall:") for k in self.core.palette.entries), MADE_KEPT + 1)
        self.assertFalse(any(e["id"].startswith("wall:") for e in self.core.palette.listing()))


class MatugenRolesTests(unittest.TestCase):
    def test_matugen_4_json_maps_to_palette_roles(self):
        from adapters.common.wallpaper_colors import MATERIAL_ROLES, argv, roles
        data = json.loads((Path(__file__).parent / "fixtures/matugen/v4.2.0-dark.json").read_text())
        result = roles(data)
        self.assertEqual(set(result), set(MATERIAL_ROLES))
        self.assertEqual(result["background"], data["colors"]["background"]["dark"]["color"])
        self.assertEqual(result["accent"], data["colors"]["primary"]["dark"]["color"])
        self.assertEqual(roles({}), {})
        self.assertEqual(roles({"colors": {"primary": "nope", "background": {"dark": {"color": "#zzzzzz"}}}}), {})
        command = argv("/a b/c.jpg")
        self.assertIn("--dry-run", command)
        self.assertEqual(command[2], "/a b/c.jpg")
