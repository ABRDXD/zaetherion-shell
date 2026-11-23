"""Palette persistence, publication, optional catalogues and preview ownership."""
from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch
from collections import Counter

import core_fakes
from core.app import Core
from core.errors import OpError
from core.guards import SessionGuard
from core.palette import Palette
from core.palette_catalog import DEFAULT, STUDIES, catalogue, contrast, normalize
from adapters.common.palette_sources import dms_dark


def isolated_entries(path):
    return catalogue(path / "missing-presets", path / "missing-themes")


class PaletteTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.path = Path(temp.name)
        self.entries = isolated_entries(self.path)
        self.palette = Palette(self.path, self.entries)
        self.events = []
        self.palette.on_change = lambda: self.events.append(self.palette.snapshot())

    def test_default_persistence_and_only_real_changes_publish(self):
        self.assertEqual(self.palette.name, DEFAULT)
        self.palette.choose("Crimson")
        self.palette.choose("amoled:crimson")
        self.assertEqual(len(self.events), 1)
        self.assertEqual(Palette(self.path, self.entries).name, "amoled:crimson")
        self.assertEqual(json.loads(self.palette.path.read_text()), {"name": "amoled:crimson"})

    def test_preview_then_cancel_does_not_write(self):
        owner = object()
        self.palette.preview_name("Ice", owner)
        self.assertEqual(self.palette.snapshot()["effective"], "amoled:ice")
        self.assertEqual(self.palette.name, DEFAULT)
        self.assertFalse(self.palette.path.exists())
        self.palette.cancel(owner)
        self.assertEqual(self.palette.snapshot()["effective"], DEFAULT)
        self.assertEqual(len(self.events), 2)

    def test_only_preview_owner_can_cancel_but_fold_always_can(self):
        a, b = object(), object()
        self.palette.preview_name("Ice", a)
        self.palette.preview_name("Amber", b)
        self.palette.cancel(a)
        self.assertEqual(self.palette.snapshot()["effective"], "amoled:amber")
        self.palette.cancel()
        self.assertFalse(self.palette.snapshot()["preview"])

    def test_choose_supersedes_preview_and_late_cancel(self):
        owner = object()
        self.palette.preview_name("Ice", owner)
        self.palette.choose("Violet")
        self.palette.cancel(owner)
        self.assertEqual(self.palette.snapshot()["effective"], "amoled:violet")
        self.assertFalse(self.palette.snapshot()["preview"])

    def test_unknown_name_changes_nothing(self):
        before = self.palette.snapshot()
        for name in ("missing", None, "../../missing"):
            with self.assertRaises(OpError):
                self.palette.choose(name)
        self.assertEqual(before, self.palette.snapshot())
        self.assertEqual(self.events, [])

    def test_missing_saved_preset_and_invalid_storage_fall_back(self):
        for value in ('{"name":"serpantinum:missing"}', '{broken', '[]', 'null', '{"name":42}'):
            self.palette.path.write_text(value)
            self.assertEqual(Palette(self.path, self.entries).name, DEFAULT)

    def test_missing_install_is_silent_and_studies_are_true_black(self):
        self.assertEqual(Counter(x["source"] for x in self.entries.values()), {"DMS": 1, "AMOLED studies": 10})
        for entry in self.entries.values():
            self.assertEqual(entry["colors"]["background"], "#000000")
            self.assertEqual(entry["colors"]["surface"], "#000000")
        self.assertEqual(len(STUDIES), 10)

    def test_runtime_files_are_mapped_not_changed(self):
        presets, themes = self.path / "presets", self.path / "themes"
        presets.mkdir(); (themes / "sample").mkdir(parents=True)
        source = presets / "Sample.json"
        original = '{"name":"Sample","colors":{"base":"#101010","text":"#eeeeee","blue":"#88ddff"}}'
        source.write_text(original)
        (presets / "Invalid.json").write_text("broken")
        (themes / "sample/theme.json").write_text(json.dumps({"name": "Sample DMS", "dark": {
            "background": "#000000", "surface": "#101010", "primary": "#88aaff"}}))
        entries = catalogue(presets, themes)
        self.assertEqual(entries["serpantinum:Sample"]["colors"]["accent"], "#88ddff")
        self.assertIn("dms:sample", entries)
        self.assertNotIn("serpantinum:Invalid", entries)
        self.assertEqual(source.read_text(), original)
        source.unlink()
        self.assertNotIn("serpantinum:Sample", catalogue(presets, themes))

    def test_matugen_reads_existing_colours_without_generating_them(self):
        presets = self.path / "presets"
        presets.mkdir()
        (presets / "Matugen.json").write_text('{"name":"Matugen","isMatugen":true}')
        generated = self.path / "generated.json"
        self.assertNotIn("serpantinum:Matugen", catalogue(presets, self.path / "absent", generated))
        generated.write_text('{"base":"#000000","text":"#eeeeee","blue":"#88ddff"}')
        self.assertIn("serpantinum:Matugen", catalogue(presets, self.path / "absent", generated))

    def test_dms_declared_flavour_and_accent(self):
        data = {"dark": {"background": "#111111"}, "variants": {
            "defaults": {"dark": {"flavor": "black", "accent": "white"}},
            "flavors": [{"id": "black", "dark": {"background": "#000000"}}],
            "accents": [{"id": "white", "black": {"primary": "#ffffff"}}]}}
        self.assertEqual(dms_dark(data), {"background": "#000000", "primary": "#ffffff"})

    def test_readability_guard_on_light_and_dark_surfaces(self):
        for background in ("#000000", "#101824", "#f8f8f8", "#ffffff", "#292633"):
            colors = normalize(dict(background=background, surface=background, text="#777777", accent="#777777"))
            for role in ("text", "textMuted", "textFaint", "accent"):
                self.assertGreaterEqual(contrast(colors[role], background), 4.5)
            self.assertEqual(colors["islandBackground"], background)


class PaletteIntegrationTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.path = Path(temp.name)
        clock, scheduler, _, host = core_fakes.fakes()
        async def no_spawn():
            raise OSError("no view in this test")
        with patch("core.palette.catalogue", return_value=isolated_entries(self.path)):
            self.core = Core(clock, scheduler, host, self.path, spawn=no_spawn, guard_types=[SessionGuard])

    async def test_verb_and_topic_share_selection(self):
        before = self.core.server.revs["palette"]
        result = await self.core.commands.run("palette ice", "cli")
        self.assertTrue(result["ok"])
        self.assertIn("Ice", result["line"])
        self.assertEqual(self.core.server.snapshots["palette"]()["name"], "amoled:ice")
        self.assertEqual(self.core.server.revs["palette"], before + 1)
        self.assertIn("Amoled Black", (await self.core.commands.run("palette list", "cli"))["line"])
        self.assertTrue((await self.core.commands.run("palette Amoled Black", "cli"))["ok"])
        self.assertFalse((await self.core.commands.run("palette absent", "cli"))["ok"])

    async def test_preview_ops_disconnect_and_fold_restore_topic(self):
        peer = object()
        self.core.server.ops["palette.preview"](peer, name="Ice")
        self.assertTrue(self.core.server.snapshots["palette"]()["preview"])
        # The registered callback is connection-specific; no other subsystem is involved.
        callback = next(c for c in self.core.server.on_disconnect if getattr(c, '__self__', None) is self.core.palette)
        callback(peer)
        self.assertEqual(self.core.palette.snapshot()["effective"], DEFAULT)
        self.core.server.ops["palette.preview"](peer, name="Amber")
        callback = next(c for c in self.core.view.on_closed if getattr(c, '__self__', None) is self.core.palette)
        callback()
        self.assertFalse(self.core.palette.snapshot()["preview"])
        self.assertFalse(self.core.palette.path.exists())

    async def test_style_command_preserves_preview_owner_palette_file_and_topic(self):
        from core.island import Island
        peer = object()
        self.core.palette.choose("Violet")
        saved = self.core.palette.path.read_bytes()
        self.core.palette.preview_name("Ice", peer)
        before = self.core.palette.snapshot()
        revision = self.core.server.revs["palette"]
        for form in ("fluid", "angular", "fluid"):
            result = await self.core.commands.run("island " + form, "view", record=False)
            self.assertTrue(result["ok"])
            self.assertEqual(Island(self.path).snapshot()["form"], form)
            self.assertEqual(self.core.palette.snapshot(), before)
            self.assertIs(self.core.palette.owner, peer)
            self.assertEqual(self.core.palette.path.read_bytes(), saved)
            self.assertEqual(self.core.server.revs["palette"], revision)
        self.core.palette.cancel(peer)
        self.assertEqual(self.core.palette.snapshot()["effective"], "amoled:violet")


class PaletteCliTests(unittest.TestCase):
    def test_zaetherion_palette_command_in_private_core(self):
        import os
        import subprocess
        import sys
        import time
        root = Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory(prefix="palette-cli-") as directory:
            base = Path(directory)
            for name in ("home", "run", "state", "cache", "config"):
                (base / name).mkdir(mode=0o700)
            env = {k: v for k, v in os.environ.items() if not k.startswith("FART_")}
            env.update(HOME=str(base / "home"), XDG_RUNTIME_DIR=str(base / "run"), XDG_STATE_HOME=str(base / "state"),
                XDG_CACHE_HOME=str(base / "cache"), XDG_CONFIG_HOME=str(base / "config"), FART_HOST="fixture", FART_MIRROR="0",
                FART_RUNTIME_DIR=str(base / "run"), FART_STATE_DIR=str(base / "state"), WAYLAND_DISPLAY="", HYPRLAND_INSTANCE_SIGNATURE="",
                DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent/palette-fixture", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent/palette-fixture")
            process = subprocess.Popen([sys.executable, "-I", str(root / "core/fartd.py")], env=env,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                for _ in range(100):
                    if (base / "run/core.sock").exists(): break
                    time.sleep(.02)
                run = subprocess.run([sys.executable, "-I", str(root / "tools/zaetherion.py"), "--json", "palette", "Ice"],
                    env=env, capture_output=True, text=True, timeout=10)
                self.assertEqual(run.returncode, 0, run.stderr)
                self.assertTrue(json.loads(run.stdout)["ok"])
                self.assertEqual(json.loads((base / "state/palette.json").read_text()), {"name": "amoled:ice"})
            finally:
                process.terminate(); process.wait(5)
