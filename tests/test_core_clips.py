"""Clips settings and the clipboard recorders the core runs (core/clips.py, Z184). Stand-in recorders only."""
import asyncio
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "tests"))

from core import clips as clips_module  # noqa: E402
from core.clips import DEFAULTS, Clips  # noqa: E402
from core.errors import OpError  # noqa: E402
from core.fartd import clip_recorder_wanted  # noqa: E402
from core.host import load_profile  # noqa: E402


class ClipsSettingsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)

    def test_defaults_enter_copies_and_settings_persist(self):
        clips = Clips(self.dir)
        self.assertFalse(clips.snapshot()["enterPastes"])  # owner, 14 November: Enter copies
        self.assertEqual(clips.snapshot()["recording"], "session")
        published = []
        clips.on_change = lambda: published.append(1)
        clips.set("rows", 8)
        clips.set("rows", 8)
        self.assertEqual(len(published), 1)
        self.assertEqual(Clips(self.dir).snapshot()["rows"], 8)

    def test_bad_values_refused_and_bad_saved_ones_ignored(self):
        clips = Clips(self.dir)
        for key, value in (("rows", 3), ("rows", True), ("keep", 9999), ("enterPastes", "yes"), ("colour", 1)):
            with self.assertRaises(OpError):
                clips.set(key, value)
        (self.dir / "clips.json").write_text(json.dumps({"rows": 99, "keep": 250, "extra": 1}))
        self.assertEqual({k: Clips(self.dir).snapshot()[k] for k in DEFAULTS}, dict(DEFAULTS, keep=250))

    def test_the_profile_names_the_recorders(self):
        profile = load_profile("serpantinum")
        both = profile.clip_recorders(250, True)
        self.assertEqual([argv[2] for argv in both], ["text", "image"])
        self.assertIn("250", both[0])
        self.assertEqual(len(profile.clip_recorders(750, False)), 1)

    def test_only_a_session_that_hands_them_over_records(self):
        self.assertFalse(clip_recorder_wanted({"FART_HOST": "serpantinum"}))
        self.assertTrue(clip_recorder_wanted({"FART_HOST": "serpantinum", "FART_CLIP_RECORDER": "1"}))
        self.assertFalse(clip_recorder_wanted({"FART_HOST": "fixture", "FART_CLIP_RECORDER": "1"}))


class ClipsRecorderTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clips = Clips(Path(self.temp.name))
        self.calls = []

    async def wait_for(self, predicate, timeout=5.0):
        end = asyncio.get_running_loop().time() + timeout
        while not predicate():
            if asyncio.get_running_loop().time() > end:
                self.fail("timed out")
            await asyncio.sleep(0.02)

    async def test_runs_restarts_for_new_settings_and_stops_with_the_core(self):
        def recorders(keep, images):
            self.calls.append((keep, images))
            return [["sleep", "30"]] * (2 if images else 1)
        self.clips.attach(recorders)
        await self.wait_for(lambda: self.clips.status == "on")
        self.assertEqual(self.calls, [(750, True)])
        self.clips.set("recordImages", False)
        self.clips.set("keep", 250)
        await self.wait_for(lambda: self.calls[-1] == (250, False) and self.clips.status == "on")
        await self.clips.close()
        self.assertIsNone(self.clips._runner)

    async def test_a_recorder_that_keeps_stopping_is_given_up(self):
        original = clips_module.BACKOFF
        clips_module.BACKOFF = (0.01, 0.01, 0.01)
        self.addCleanup(setattr, clips_module, "BACKOFF", original)
        self.clips.attach(lambda keep, images: [["sh", "-c", "exit 3"]])
        await self.wait_for(lambda: self.clips.status == "failed")
        self.assertIn("3", self.clips.snapshot()["error"])
        await self.clips.close()


if __name__ == "__main__":
    unittest.main()
