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


class CoreChoiceTests(unittest.TestCase):
    """Z226: FART_CORE picks the core `zaetherion start` runs; Python unless asked."""

    def test_python_unless_asked(self):
        for env in ({}, {"FART_CORE": ""}, {"FART_CORE": "python"}):
            self.assertEqual(zaetherion.core_command(env)[-1], str(zaetherion.ROOT / "core/fartd.py"), env)

    def test_cpp_when_asked_and_built(self):
        binary = zaetherion.ROOT / "core-cpp/build/fartd-cpp"
        with patch.object(zaetherion.os, "access", return_value=True):
            self.assertEqual(zaetherion.core_command({"FART_CORE": "cpp"}), [str(binary)])
        with patch.object(zaetherion.os, "access", return_value=False):
            with self.assertRaisesRegex(zaetherion.Unreachable, "not built"):
                zaetherion.core_command({"FART_CORE": "cpp"})

    def test_anything_else_is_refused(self):
        for value in ("CPP", "rust", "c++"):
            with self.assertRaises(zaetherion.Unreachable, msg=value):
                zaetherion.core_command({"FART_CORE": value})

    def test_live_restart_finds_either_core(self):
        text = (zaetherion.ROOT / "tools/live-restart").read_text()
        self.assertIn("core/fartd.py|$ROOT/core-cpp/build/fartd-cpp", text)
