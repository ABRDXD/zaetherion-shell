"""DMS's bar: off while the resident view is up, back on when it is gone for long (core/dms_bar.py, Z159, Z224)."""
import json
from pathlib import Path
import tempfile
import unittest

from core_fakes import fakes  # puts the repo on the path, as the other core tests
from core.dms_bar import SHOW_AFTER, DmsBar


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

    def test_turns_only_the_main_bar_off_and_on(self):
        self.bar.sync(True)
        saved = self.saved()
        self.assertIs(saved["barConfigs"][0]["enabled"], False)  # off, so DMS never makes it (Z224)
        expected = json.loads(json.dumps(SETTINGS))
        expected["barConfigs"][0]["enabled"] = False
        self.assertEqual(saved, expected)  # nothing else changed, not even `visible`
        self.bar.sync(False)
        self.assertEqual(self.saved(), SETTINGS)

    def test_on_also_undoes_the_old_hidden_bar(self):
        old = json.loads(json.dumps(SETTINGS))
        old["barConfigs"][0]["visible"] = False  # Z159's way, left by a core from before Z224
        self.path.write_text(json.dumps(old))
        self.bar.sync(True)
        self.bar.release()
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
        self.bar.sync(False)  # already on
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


class TimedBarTests(unittest.TestCase):
    """With the core's clock: off before DMS starts, back on only after SHOW_AFTER without a ready view."""

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name) / "settings.json"
        self.path.write_text(json.dumps(SETTINGS, indent=2))
        self.clock, self.scheduler, _, _ = fakes()
        self.bar = DmsBar(self.path, self.clock, self.scheduler)

    def tearDown(self):
        self.dir.cleanup()

    def on(self):
        return json.loads(self.path.read_text())["barConfigs"][0]["enabled"]

    def test_off_before_dms_starts_and_stays_off_when_the_view_comes(self):
        self.bar.prepare()
        self.assertIs(self.on(), False)
        self.bar.sync(False)  # starting
        self.clock.advance(1)
        self.bar.sync(True)  # ready
        self.clock.advance(SHOW_AFTER * 3)
        self.assertIs(self.on(), False)
        self.assertIsNone(self.bar.show_at)
        self.assertEqual(self.scheduler.pending, {})

    def test_on_again_when_the_view_never_comes(self):
        self.bar.prepare()
        self.bar.sync(False)
        self.clock.advance(SHOW_AFTER - 0.5)
        self.assertIs(self.on(), False)
        self.bar.sync(False)  # another not-ready change does not push the deadline back
        self.clock.advance(1)
        self.assertIs(self.on(), True)
        self.assertEqual(self.bar.snapshot(), {"wantHidden": False, "applied": False, "showAt": None})

    def test_on_again_when_the_view_never_reports_anything(self):
        self.bar.prepare()  # e.g. the view's first start throws before it changes state
        self.assertIs(self.on(), False)
        self.clock.advance(SHOW_AFTER + 1)
        self.assertIs(self.on(), True)

    def test_a_quick_view_restart_does_not_bring_the_bar_back(self):
        self.bar.prepare()
        self.bar.sync(True)
        for _ in range(3):  # exit, restart a second later, ready
            self.bar.sync(False)
            self.clock.advance(2)
            self.bar.sync(True)
        self.clock.advance(SHOW_AFTER * 2)
        self.assertIs(self.on(), False)

    def test_a_view_gone_for_good_brings_it_back_and_a_new_view_turns_it_off(self):
        self.bar.prepare()
        self.bar.sync(True)
        self.bar.sync(False)
        self.clock.advance(SHOW_AFTER + 1)
        self.assertIs(self.on(), True)
        self.bar.sync(True)
        self.assertIs(self.on(), False)

    def test_release_turns_it_on_at_once_and_cancels_the_timer(self):
        self.bar.prepare()
        self.bar.sync(True)
        self.bar.sync(False)  # the view's stop
        self.bar.release()  # after DMS stopped
        self.assertIs(self.on(), True)
        self.assertEqual(self.scheduler.pending, {})
        self.clock.advance(SHOW_AFTER * 2)
        self.assertIs(self.on(), True)

    def test_a_file_that_cannot_be_read_at_the_deadline_is_tried_on_the_next_change(self):
        self.bar.prepare()
        good = self.path.read_text()
        self.path.write_text("{not json")
        self.clock.advance(SHOW_AFTER + 1)
        self.assertEqual(self.path.read_text(), "{not json")
        self.path.write_text(good)
        self.bar.sync(False)
        self.clock.advance(SHOW_AFTER + 1)
        self.assertIs(self.on(), True)


if __name__ == "__main__":
    unittest.main()
