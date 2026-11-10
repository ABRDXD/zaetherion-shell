"""fart-next launcher checks; they never start a view or touch live state."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import contextlib
import io

from fart_next import parser, placement, seed_state, split_verb


class SeedStateTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.archive = Path(temp.name) / "fart"
        self.dest = Path(temp.name) / "fart-next"
        self.archive.mkdir()

    def test_copies_once_and_existing_destination_wins(self):
        (self.archive / "todo.json").write_text('[{"content":"old","done":true}]')
        seed_state(self.dest, self.archive)
        copied = self.dest / "todo.json"
        self.assertEqual(json.loads(copied.read_text()), [{"content": "old", "done": True}])
        self.assertEqual(copied.stat().st_mode & 0o777, 0o600)
        copied.write_text("[]")
        seed_state(self.dest, self.archive)
        self.assertEqual(copied.read_text(), "[]")
        self.assertTrue(json.loads((self.archive / "todo.json").read_text())[0]["done"])

    def test_missing_archive_files_are_left_to_view_defaults(self):
        seed_state(self.dest, self.archive)
        self.assertEqual(list(self.dest.iterdir()), [])

    def test_portrait_is_copied_and_repointed(self):
        portrait = self.archive / "portrait.jpg"
        portrait.write_bytes(b"jpeg")
        (self.archive / "settings.json").write_text(json.dumps({"profile": {"avatarPicture": str(portrait)}}))
        seed_state(self.dest, self.archive)
        settings = json.loads((self.dest / "settings.json").read_text())
        self.assertEqual(settings["profile"]["avatarPicture"], str(self.dest / "portrait.jpg"))
        self.assertEqual((self.dest / "portrait.jpg").read_bytes(), b"jpeg")

    def test_invalid_archive_json_stops_without_writing(self):
        (self.archive / "timers.json").write_text("{broken")
        with self.assertRaisesRegex(ValueError, "timers.json"):
            seed_state(self.dest, self.archive)
        self.assertFalse((self.dest / "timers.json").exists())
        self.assertEqual((self.archive / "timers.json").read_text(), "{broken")


class ParserTests(unittest.TestCase):
    def parse(self, *argv):
        return parser().parse_args(argv)

    def refused(self, *argv):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as caught:
            self.parse(*argv)
        self.assertEqual(caught.exception.code, 2)

    def test_open_and_toggle_take_the_clock_rect_and_screen(self):
        for action in ("open", "toggle"):
            args = self.parse(action, "--from", "880,4,160,40", "--screen", "eDP-1")
            self.assertEqual(placement(args), {"from": {"x": 880.0, "y": 4.0, "width": 160.0, "height": 40.0},
                                               "screen": "eDP-1"})
            self.assertEqual(placement(self.parse(action, "--screen", "")), {})  # the hook's empty fallback
            self.assertEqual(placement(self.parse(action)), {})

    def test_bad_placement_is_a_usage_error(self):
        for argv in (("open", "--from", "1,2,3"), ("toggle", "--from", "a,b,c,d"), ("open", "--from", "1,2,0,40"),
                     ("toggle", "--screen", "x" * 65), ("open", "--screen", "eDP\n1")):
            with self.subTest(argv=argv):
                self.refused(*argv)

    def test_key_edges(self):
        self.assertEqual(self.parse("key", "down").edge, "down")
        self.assertEqual(self.parse("key", "up").edge, "up")
        self.refused("key", "sideways")
        self.assertEqual(split_verb(["key", "down"]), (False, None))  # a builtin, not a verb

