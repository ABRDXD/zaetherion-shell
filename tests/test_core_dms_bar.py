"""DMS's bar: hidden while the resident view is up, shown whenever it is not (core/dms_bar.py, Z159)."""
import json
from pathlib import Path
import tempfile
import unittest

from core_fakes import fakes  # noqa: F401  (puts the repo on the path, as the other core tests)
from core.dms_bar import DmsBar


SETTINGS = {
    "currentThemeName": "custom",
    "barConfigs": [
        {"id": "default", "name": "Main Bar", "enabled": True, "visible": True, "island": True, "note": "ü"},
        {"id": "bar2", "name": "Bar 2", "enabled": False, "visible": True},
    ],
    "after": [1, 2.5],
}


class DmsBarTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name) / "settings.json"
        self.path.write_text(json.dumps(SETTINGS, indent=2, ensure_ascii=False))
        self.path.chmod(0o600)
        self.bar = DmsBar(self.path)

    def tearDown(self):
        self.dir.cleanup()

    def saved(self):
        return json.loads(self.path.read_text())

    def test_hides_and_shows_only_the_main_bar(self):
        self.bar.sync(True)
        saved = self.saved()
        self.assertIs(saved["barConfigs"][0]["visible"], False)
        expected = json.loads(json.dumps(SETTINGS))
        expected["barConfigs"][0]["visible"] = False
        self.assertEqual(saved, expected)  # nothing else changed
        self.bar.sync(False)
        self.assertEqual(self.saved(), SETTINGS)

    def test_written_as_dms_writes_it(self):
        self.bar.sync(True)
        text = self.path.read_text()
        self.assertIn('\n  "barConfigs": [', text)
        self.assertIn('"note": "ü"', text)
        self.assertEqual(list(self.saved()), list(SETTINGS))  # key order kept
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)
        self.assertEqual([p.name for p in Path(self.dir.name).iterdir()], ["settings.json"])

    def test_no_write_when_nothing_changes(self):
        before = self.path.stat().st_mtime_ns
        self.bar.sync(False)  # already visible
        self.bar.sync(False)
        self.assertEqual(self.path.stat().st_mtime_ns, before)
        self.assertIs(self.bar.applied, False)

    def test_a_missing_or_broken_file_is_left_alone_and_retried(self):
        self.path.write_text("{not json")
        self.bar.sync(True)
        self.assertIsNone(self.bar.applied)
        self.assertEqual(self.path.read_text(), "{not json")
        self.path.unlink()
        self.bar.sync(True)
        self.assertIsNone(self.bar.applied)
        self.path.write_text(json.dumps(SETTINGS))
        self.bar.sync(True)
        self.assertIs(self.bar.applied, True)

    def test_no_main_bar_is_not_an_error(self):
        self.path.write_text(json.dumps({"barConfigs": [{"id": "other"}]}))
        self.bar.sync(True)
        self.assertEqual(self.saved(), {"barConfigs": [{"id": "other"}]})


if __name__ == "__main__":
    unittest.main()
