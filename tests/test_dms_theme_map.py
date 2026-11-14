"""adapters/dms/DmsThemeMap.js: DMS's current theme from settings.json and the switch commands, under Node (Z180)."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def run(expression):
    body = "\n".join(l for l in (ROOT / "adapters/dms/DmsThemeMap.js").read_text().splitlines() if not l.startswith(".pragma"))
    script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
    return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)


@unittest.skipUnless(shutil.which("node"), "needs Node")
class ThemeMap(unittest.TestCase):
    def current(self, data):
        return run(f"currentFrom({json.dumps(data if isinstance(data, str) else json.dumps(data))})")

    def test_this_machines_custom_theme_and_builtins(self):
        # The keys DMS 2.1.0 writes here (14 Nov 2026), trimmed.
        self.assertEqual(self.current({"currentThemeName": "custom", "currentThemeCategory": "custom",
                                       "customThemeFile": "/home/u/.config/dms/themes/amoledBlack/theme.json"}), "amoledBlack")
        self.assertEqual(self.current({"currentThemeName": "purple"}), "purple")
        self.assertEqual(self.current({"currentThemeName": "custom", "customThemeFile": "/tmp/mine.json"}), "")
        for text in ("", "{x", "[]", "null"):
            self.assertEqual(self.current(text), "")

    def test_switch_is_two_dms_settings_sets_in_order(self):
        self.assertEqual(run('setCommands("/home/u/.config", "oxeoDeep")'), [
            ["dms", "ipc", "call", "settings", "set", "customThemeFile", "/home/u/.config/dms/themes/oxeoDeep/theme.json"],
            ["dms", "ipc", "call", "settings", "set", "currentThemeName", "custom"]])

    def test_ids_cannot_leave_the_themes_folder(self):
        for bad in ("..", ".", "../x", "a/b", "", "a b", "x" * 65, 3):
            with self.subTest(bad=bad):
                self.assertEqual(run(f"setCommands('/c', {json.dumps(bad)})"), [])


if __name__ == "__main__":
    unittest.main()
