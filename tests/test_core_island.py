"""The island's settings (Z155): validated, persisted, published once per real change; and the island verb."""
from pathlib import Path
import json
import tempfile
import unittest

import core_fakes
from core.app import Core
from core.errors import OpError
from core.guards import SessionGuard
from core.island import DEFAULTS, Island


class IslandSettingsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)

    def test_defaults_set_persist_and_publish_once(self):
        island = Island(self.dir)
        self.assertEqual(island.snapshot(), DEFAULTS)
        published = []
        island.on_change = lambda: published.append(1)
        island.set(form="fluid")
        island.set(form="fluid")
        self.assertEqual(len(published), 1)
        self.assertEqual(Island(self.dir).snapshot()["form"], "fluid")

    def test_rejects_unknown_values_and_ignores_bad_saved_ones(self):
        island = Island(self.dir)
        with self.assertRaises(OpError):
            island.set(form="round")
        with self.assertRaises(OpError):
            island.set(colour="red")
        (self.dir / "island.json").write_text(json.dumps({"form": "round", "edge": "bottom", "extra": 1}))
        self.assertEqual(Island(self.dir).snapshot(), dict(DEFAULTS, edge="bottom"))
        (self.dir / "island.json").write_text("{not json")
        self.assertEqual(Island(self.dir).snapshot(), DEFAULTS)


class IslandVerbTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        clock, scheduler, _, host = core_fakes.fakes()

        async def no_spawn():
            raise OSError("no view in this test")
        self.core = Core(clock, scheduler, host, Path(self.temp.name), spawn=no_spawn, guard_types=[SessionGuard])

    async def test_verb_sets_and_shows(self):
        run = lambda line: self.core.commands.run(line, "cli")
        self.assertIn("ANGULAR", (await run("island"))["line"])
        self.assertIn("FLUID", (await run("island fluid"))["line"])
        await run("island bottom")
        await run("island floating")
        await run("island screen DP-1")
        self.assertEqual(self.core.island.snapshot(),
                         {"form": "fluid", "edge": "bottom", "placement": "floating", "screen": "DP-1",
                          "rest": DEFAULTS["rest"]})
        await run("island screen auto")
        self.assertEqual(self.core.island.snapshot()["screen"], "")
        self.assertFalse((await run("island sideways"))["ok"])

    async def test_rest_presets_and_items(self):
        """Z201: the owner's rest (B) by default; a preset or one item's mode; bad modes refused."""
        run = lambda line: self.core.commands.run(line, "cli")
        self.assertEqual(self.core.island.snapshot()["rest"],
                         {"power": "hover", "network": "always", "battery": "always", "inbox": "dot"})
        await run("island rest a")
        self.assertEqual(self.core.island.snapshot()["rest"]["inbox"], "matters")
        await run("island rest battery always")
        self.assertEqual(self.core.island.snapshot()["rest"]["battery"], "always")
        self.assertFalse((await run("island rest power dot"))["ok"])
        self.assertFalse((await run("island rest clock always"))["ok"])
        self.assertIn("REST", (await run("island"))["line"])
