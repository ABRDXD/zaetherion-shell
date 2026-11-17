"""Typeset plates follow the saved palette's accent (Z213): paths, the accent guard, recolouring and the core's hooks."""
import asyncio
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import core_fakes
from core.app import Core
from core.guards import SessionGuard
from core.typeset import contrast_on_black, copy_path, face_of, layers_for, lift


def make_plate(folder: Path, stem="zg-01-torii", face_ext=".png"):
    """A face in the folder and its layers in .typeset/<stem>/ (tiny real PNGs when ImageMagick is there)."""
    layers = folder / ".typeset" / stem
    layers.mkdir(parents=True)
    face = folder / (stem + face_ext)
    if shutil.which("magick"):
        subprocess.run(["magick", "-size", "4x1", "xc:#404040", str(layers / "ink.png")], check=True)
        # the mask: none, full, half, none
        subprocess.run(["magick", "-size", "4x1", "xc:black", "-fill", "white", "-draw", "point 1,0",
                        "-fill", "gray50", "-draw", "point 2,0", "-colorspace", "Gray", str(layers / "signal.png")], check=True)
        shutil.copy(layers / "ink.png", face)
    else:
        for name in ("ink.png", "signal.png"):
            (layers / name).write_bytes(b"x")
        face.write_bytes(b"x")
    (layers / "plate.json").write_text(json.dumps({"name": "TORII", "kind": "glyph", "face": face.name}))
    return face, layers


class PathsAndAccent(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.folder = Path(temp.name)

    def test_a_face_and_its_copies_find_the_layers_others_dont(self):
        face, layers = make_plate(self.folder)
        other = self.folder / "rain.jpg"
        other.write_bytes(b"x")
        self.assertEqual(layers_for(str(face)), layers)
        copy = copy_path(layers, "#ff5a00")
        self.assertEqual(copy, layers / "ff5a00.png")
        self.assertEqual(layers_for(str(copy)), layers)
        self.assertIsNone(layers_for(str(other)))
        (layers / "signal.png").unlink()
        self.assertIsNone(layers_for(str(face)))

    def test_a_copy_maps_back_to_its_face(self):
        face, layers = make_plate(self.folder, face_ext=".jpg")
        self.assertEqual(face_of(str(layers / "8fd6f5.png")), str(face))
        self.assertEqual(face_of(str(face)), str(face))
        (layers / "plate.json").unlink()  # no record: found by stem
        self.assertEqual(face_of(str(layers / "8fd6f5.png")), str(face))

    def test_the_accent_guard_lifts_only_what_cannot_be_read_on_black(self):
        for kept in ("#ff5a00", "#8fd6f5", "#b4befe", "#ffffff"):
            self.assertEqual(lift(kept), kept)
        for dark in ("#0000ff", "#7a0000", "#000000", "#14202b"):
            lifted = lift(dark)
            rgb = [int(lifted[i:i + 2], 16) / 255 for i in (1, 3, 5)]
            self.assertGreaterEqual(contrast_on_black(*rgb), 4.5, (dark, lifted))
        self.assertEqual(lift("8FD6F5"), "#8fd6f5")
        with self.assertRaises(ValueError):
            lift("not a colour")


@unittest.skipUnless(shutil.which("magick"), "needs ImageMagick")
class Recolour(unittest.IsolatedAsyncioTestCase):
    async def test_copy_is_ink_plus_accent_times_mask_and_is_reused(self):
        from adapters.common.typeset_tint import recolour
        with tempfile.TemporaryDirectory() as tmp:
            _, layers = make_plate(Path(tmp))
            out = await recolour(layers, "#ff5a00")
            self.assertEqual(out, str(layers / "ff5a00.png"))
            pixels = subprocess.run(["magick", out, "-depth", "8", "txt:-"], capture_output=True, text=True, check=True).stdout
            rows = [line.split()[2] for line in pixels.splitlines()[1:]]
            self.assertEqual(rows[0].lower(), "#404040")                 # no mask: ink
            self.assertEqual(rows[1].lower(), "#ff9a40")                 # full mask: ink + accent (clamped)
            self.assertEqual(rows[3].lower(), "#404040")
            r, g, b = (int(rows[2][i:i + 2], 16) for i in (1, 3, 5))     # half mask: ink + accent / 2
            self.assertTrue(abs(r - (0x40 + 0x80)) <= 2 and abs(g - (0x40 + 0x2d)) <= 2 and b == 0x40, rows[2])
            mtime = Path(out).stat().st_mtime_ns
            self.assertEqual(await recolour(layers, "#ff5a00"), out)
            self.assertEqual(Path(out).stat().st_mtime_ns, mtime)
            self.assertFalse(list(layers.glob(".*.tmp.png")))


class CoreFollowsThePalette(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        self.folder = self.base / "home/Pictures/Wallpapers"
        self.folder.mkdir(parents=True)
        self.face, self.layers = make_plate(self.folder)
        self.photo = self.folder / "rain.jpg"
        self.photo.write_bytes(b"x")
        clock, scheduler, _, host = core_fakes.fakes()

        async def no_spawn():
            raise OSError("no view in this test")
        from core.palette_catalog import catalogue
        with patch("core.palette.catalogue", return_value=catalogue(self.base / "x", self.base / "y")):
            self.core = Core(clock, scheduler, host, self.base / "state", spawn=no_spawn, guard_types=[SessionGuard])
        self.core.wallpaper.home = self.base / "home"
        self.core.wallpaper.report(True, "")
        self.sets = []

        async def fake_call(domain, method, args=(), **options):
            if (domain, method) == ("wallpaper", "set"):
                self.sets.append(args[0])
        self.core.hostcalls.call = fake_call
        self.recolours = []

        async def recolour(layers, accent):
            self.recolours.append(accent)
            if accent == "#badbad":
                raise RuntimeError("no ImageMagick")
            return str(copy_path(layers, accent))
        patcher = patch("adapters.common.typeset_tint.recolour", recolour)
        patcher.start()
        self.addCleanup(patcher.stop)
        entries = self.core.palette.entries
        accents = {}
        for key, entry in entries.items():
            accents.setdefault(entry["colors"]["accent"], key)
        self.palettes = list(accents.values())[:2]
        self.accent = lambda key: entries[key]["colors"]["accent"]
        self.ops = self.core.server.ops

    async def settle(self):
        while self.core.wallpaper_follows:
            await asyncio.gather(*list(self.core.wallpaper_follows))

    async def test_choosing_a_plate_applies_its_copy_in_the_saved_accent_and_lists_the_face(self):
        accent = self.accent(self.core.palette.name)
        snap = await self.ops["wallpaper.choose"](object(), name="torii")
        self.assertEqual(self.sets, [str(copy_path(self.layers, accent))])
        self.assertEqual((snap["current"], snap["applied"]), (str(self.face), self.sets[0]))
        self.assertEqual(snap["recent"], [str(self.face)])

    async def test_a_palette_change_recolours_a_plate_but_not_a_photo_and_not_on_preview(self):
        await self.ops["wallpaper.choose"](object(), name="torii")
        a, b = self.palettes
        target = b if self.core.palette.name == a else a
        self.ops["palette.preview"](object(), name=target)
        await self.settle()
        self.assertEqual(len(self.sets), 1)  # a hover recolours nothing
        self.ops["palette.choose"](object(), name=target)
        await self.settle()
        self.assertEqual(self.sets[-1], str(copy_path(self.layers, self.accent(target))))
        self.assertEqual(self.core.wallpaper.host["current"], str(self.face))
        await self.ops["wallpaper.choose"](object(), name="rain")
        count = len(self.sets)
        self.ops["palette.choose"](object(), name=a if target == b else b)
        await self.settle()
        self.assertEqual(len(self.sets), count)

    async def test_the_hosts_report_of_a_copy_still_follows(self):
        view = object()
        self.core.view.client = view
        copy = str(copy_path(self.layers, "#123456"))
        self.ops["wallpaper.report"](view, available=True, current=copy)
        self.assertEqual(self.core.wallpaper.host["current"], str(self.face))
        target = [p for p in self.palettes if p != self.core.palette.name][0]
        self.ops["palette.choose"](object(), name=target)
        await self.settle()
        self.assertEqual(self.sets, [str(copy_path(self.layers, self.accent(target)))])

    async def test_a_failed_recolour_shows_the_plate_in_its_own_colour(self):
        self.core.palette.entries[self.core.palette.name]["colors"]["accent"] = "#badbad"
        snap = await self.ops["wallpaper.choose"](object(), name="torii")
        self.assertEqual(self.sets, [str(self.face)])
        self.assertEqual(snap["current"], str(self.face))

    async def test_colours_from_the_wallpaper_never_read_a_plate(self):
        runs = []

        async def colors_for(path):
            runs.append(path)
            return {"accent": "#a0c8ff"}
        with patch("adapters.common.wallpaper_colors.colors_for", colors_for):
            self.ops["wallpaper.colours"](object(), on=True)
            await self.ops["wallpaper.choose"](object(), name="torii")
            self.assertEqual(runs, [])

    async def test_a_preset_with_a_plate_applies_the_copy_in_its_own_palette(self):
        target = [p for p in self.palettes if p != self.core.palette.name][0]
        self.core.presets.save("night", dict(wallpaper=str(self.face), palette=target, islandForm="", hostTheme=""))
        await self.ops["presets.apply"](object(), name="night")
        await self.settle()
        self.assertEqual(self.sets[-1], str(copy_path(self.layers, self.accent(target))))
        self.assertTrue(all(s == self.sets[-1] for s in self.sets))


if __name__ == "__main__":
    unittest.main()
