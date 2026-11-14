"""The apps domain (S6) under Quickshell offscreen, against synthetic desktop entries in a private data folder."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ENTRIES = {
    "zt-editor.desktop": "Name=Alpha Editor\nGenericName=Text Editor\nComment=Edits text\nExec=zt-edit --new %F\n"
                         "Path=/tmp\nKeywords=write;notes;\nIcon=zt-missing-icon\n",
    "zt-monitor.desktop": "Name=Beta Monitor\nExec=zt-top\nTerminal=true\n",
    "zt-viewer.desktop": "Name=Gamma Viewer\nExec=zt-view %u\n",
    "zt-hidden.desktop": "Name=Aardvark Hidden\nExec=zt-hidden\nNoDisplay=true\n",
}
CHECKS = ("listed by name, hidden left out", "fields mapped", "terminal flag", "available",
          "field codes dropped, working folder kept", "terminal app runs in the terminal",
          "no terminal given: the program alone", "an unknown id starts nothing", "words quoted for the shell",
          "working folder first", "nothing expands", "Lua string escaped", "dispatch is a Lua call")


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class AppsAdapterTests(unittest.TestCase):
    def test_entries_and_launch(self):
        with tempfile.TemporaryDirectory(prefix="zaetherion-apps-") as tmp:
            base = Path(tmp)
            bundle = base / "bundle"
            for name in ("adapters", "view", "core"):
                shutil.copytree(ROOT / name, bundle / name, ignore=shutil.ignore_patterns("__pycache__"))
            (bundle / "fixtures").mkdir()
            shutil.copy2(ROOT / "tests/fixtures/apps/AppsTest.qml", bundle / "fixtures/AppsTest.qml")
            shutil.copy2(ROOT / "tests/fixtures/apps/AppsTest.qml", bundle / "shell.qml")
            # The entry sits one folder down, so its JS import reads from the bundle root.
            (bundle / "shell.qml").write_text((bundle / "shell.qml").read_text().replace("../adapters/", "adapters/"))
            apps = base / "data/applications"
            apps.mkdir(parents=True)
            for name, body in ENTRIES.items():
                (apps / name).write_text("[Desktop Entry]\nType=Application\n" + body)
            runtime = base / "run"
            runtime.mkdir(mode=0o700)
            env = {k: v for k, v in os.environ.items() if not k.startswith(("FART_", "DMS_"))}
            env.update(XDG_DATA_HOME=str(base / "data"), XDG_DATA_DIRS=str(base / "none"), XDG_RUNTIME_DIR=str(runtime),
                       XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"),
                       XDG_CACHE_HOME=str(base / "cache"), QT_QPA_PLATFORM="offscreen")
            result = subprocess.run(["qs", "--no-color", "-p", str(bundle / "shell.qml")], env=env,
                                    stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertNotIn("APPS_FAIL", output)
            for name in CHECKS:
                self.assertIn("APPS_PASS " + name, output)
            for error in ("ReferenceError", "TypeError", "Unable to assign"):
                self.assertNotIn(error, output)


if __name__ == "__main__":
    unittest.main()
