"""tools/zaetherion.py: `page ROOM` opens a room; `page ROOM --toggle` is a room key (closes its own room)."""
import contextlib
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import zaetherion  # noqa: E402


class PageTests(unittest.TestCase):
    def parse(self, *argv):
        return zaetherion.parser().parse_args(argv)

    def test_toggle_is_off_unless_asked(self):
        self.assertFalse(self.parse("page", "devices").toggle)
        self.assertTrue(self.parse("page", "devices", "--toggle").toggle)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            self.parse("page", "nowhere", "--toggle")

    def test_page_opens_and_page_toggle_toggles_that_room(self):
        for argv, op in ((("page", "devices"), "view.open"), (("page", "devices", "--toggle"), "view.toggle")):
            with self.subTest(argv=argv), patch.object(zaetherion, "connect") as connect:
                zaetherion.run(self.parse(*argv))
                connect.return_value.request.assert_called_once_with(op, page="devices")

    def test_aliases_name_the_room(self):
        alias, room = next(iter(zaetherion.ALIASES.items()))
        with patch.object(zaetherion, "connect") as connect:
            zaetherion.run(self.parse("page", alias, "--toggle"))
            connect.return_value.request.assert_called_once_with("view.toggle", page=room)


if __name__ == "__main__":
    unittest.main()
