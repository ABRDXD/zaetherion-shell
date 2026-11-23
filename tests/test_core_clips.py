"""Quick paste's settings in the core (core/clips.py, Z184). The history is DMS's (Z202): no recorder here."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from core.clips import DEFAULTS, Clips  # noqa: E402
from core.errors import OpError  # noqa: E402
from core.host import load_profile  # noqa: E402


class ClipsSettingsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)

    def test_defaults_enter_copies_and_settings_persist(self):
        clips = Clips(self.dir)
        self.assertEqual(clips.snapshot(), {"enterPastes": False, "rows": 6, "showImages": True})  # owner: Enter copies
        published = []
        clips.on_change = lambda: published.append(1)
        clips.set("rows", 8)
        clips.set("rows", 8)
        self.assertEqual(len(published), 1)
        self.assertEqual(Clips(self.dir).snapshot()["rows"], 8)

    def test_bad_values_refused_and_bad_or_old_saved_ones_ignored(self):
        clips = Clips(self.dir)
        for key, value in (("rows", 3), ("rows", True), ("keep", 750), ("recordImages", True), ("enterPastes", "yes")):
            with self.assertRaises(OpError):
                clips.set(key, value)
        # The history settings of the first S3 build (keep, recordImages) are DMS's now: dropped on read.
        (self.dir / "clips.json").write_text(json.dumps({"rows": 99, "showImages": False, "keep": 250, "recordImages": False}))
        self.assertEqual(Clips(self.dir).snapshot(), dict(DEFAULTS, showImages=False))

    def test_no_profile_names_a_clipboard_recorder(self):
        for name in ("serpantinum", "fixture"):
            self.assertFalse(hasattr(load_profile(name), "clip_recorders"), name)
        self.assertNotIn("FART_CLIP_RECORDER", (ROOT / "core/fartd.py").read_text())


if __name__ == "__main__":
    unittest.main()
