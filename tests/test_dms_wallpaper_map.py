"""adapters/dms/DmsWallpaperMap.js: DMS's session.json to the wallpaper domain, and the set command, under Node (Z177)."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def run(expression):
    body = "\n".join(l for l in (ROOT / "adapters/dms/DmsWallpaperMap.js").read_text().splitlines()
                     if not l.startswith(".pragma"))
    script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
    return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)


def session(text):
    return run(f"fromSession({json.dumps(text)})")


@unittest.skipUnless(shutil.which("node"), "needs Node")
class WallpaperMap(unittest.TestCase):
    def test_this_machines_shape_with_per_mode_paths(self):
        # The keys DMS 2.1.0 writes here (13 Nov 2026), trimmed: per-mode on, dark mode current.
        data = {"wallpaperPath": "/home/u/Pictures/Wallpapers/rain.jpg", "perModeWallpaper": True,
                "wallpaperPathDark": "/home/u/Pictures/Wallpapers/rain.jpg",
                "wallpaperPathLight": "/home/u/Pictures/Wallpapers/light.jpg"}
        self.assertEqual(session(json.dumps(data)), {"current": "/home/u/Pictures/Wallpapers/rain.jpg", "perScreen": False})

    def test_per_screen_and_colour_and_missing(self):
        self.assertEqual(session(json.dumps({"wallpaperPath": "/a.png", "perMonitorWallpaper": True})),
                         {"current": "/a.png", "perScreen": True})
        self.assertEqual(session(json.dumps({"wallpaperPath": "#101010"})), {"current": "", "perScreen": False})
        self.assertEqual(session(json.dumps({})), {"current": "", "perScreen": False})
        self.assertEqual(session(json.dumps({"wallpaperPath": 4, "perMonitorWallpaper": "yes"})),
                         {"current": "", "perScreen": False})

    def test_broken_text_is_empty_not_an_error(self):
        for text in ("", "{broken", "[]", "null", "\"x\""):
            with self.subTest(text=text):
                self.assertEqual(session(text), {"current": "", "perScreen": False})

    def test_set_command_is_one_argv_with_the_path_unquoted(self):
        path = "/home/u/Pictures/Wallpapers/a body; of $water.jpg"
        self.assertEqual(run(f"setCommand({json.dumps(path)})"), ["dms", "ipc", "call", "wallpaper", "set", path])


if __name__ == "__main__":
    unittest.main()
