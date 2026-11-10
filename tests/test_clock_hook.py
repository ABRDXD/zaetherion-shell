"""The clock hook variant and its installer (adapters/serpantinum/hook/), only ever on temporary copies.

The live host file is read, never written: one test checks that a copy of it, with the archive's hook taken
back out, is exactly the upstream state this installer expects.
"""
import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / "adapters/serpantinum/hook"
sys.path.insert(0, str(HOOK))
import clock_hook  # noqa: E402

LIVE = Path(os.environ.get("SERPANTINUM_DIR") or Path.home() / ".local/share/serpantinum/src") / \
    "quickshell/bar/faces/timedate/TimeDateFace.qml"
QML = Path("/usr/lib/qt6/bin/qml")

HEAD = "import QtQuick\n\nItem {\n    id: root\n    property var barWindow: null\n\n    MouseArea {\n        id: bgMouse\n" \
       "        anchors.fill: parent\n        hoverEnabled: true\n"
TAIL = "    }\n\n    Loader { id: faceLoader }\n}\n"


class Installer(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.face = Path(temp.name) / "TimeDateFace.qml"
        self.write(HEAD + clock_hook.UPSTREAM + TAIL)
        self.face.chmod(0o640)

    def write(self, text):
        self.face.write_text(text)

    def run_cli(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            try:
                code = clock_hook.main([*argv])
            except SystemExit as exit:
                code = exit.code
        return code, out.getvalue(), err.getvalue()

    def test_apply_reapply_remove(self):
        original = self.face.read_text()
        self.assertEqual(self.run_cli(str(self.face))[0], 0)
        installed = self.face.read_text()
        self.assertEqual(installed, HEAD + clock_hook.VARIANT + TAIL)
        self.assertEqual(self.face.stat().st_mode & 0o777, 0o640)
        self.assertEqual(clock_hook.apply(self.face), "unchanged")
        self.assertEqual(self.face.read_text(), installed)
        self.assertEqual(self.run_cli("--check", str(self.face))[1].strip(), "variant")
        self.assertEqual(clock_hook.apply(self.face, remove=True), "removed")
        self.assertEqual(self.face.read_text(), original)
        self.assertEqual(clock_hook.apply(self.face, remove=True), "unchanged")
        self.assertEqual([p.name for p in self.face.parent.iterdir()], ["TimeDateFace.qml"])  # no staging left

    def test_surrounding_changes_are_kept(self):
        edited = HEAD.replace("hoverEnabled: true", "hoverEnabled: false  // a local edit") + clock_hook.UPSTREAM + TAIL + "// end\n"
        self.write(edited)
        clock_hook.apply(self.face)
        clock_hook.apply(self.face, remove=True)
        self.assertEqual(self.face.read_text(), edited)

    def test_a_changed_upstream_handler_is_refused(self):
        changed = HEAD + clock_hook.UPSTREAM.replace('"toggle", "calendar"', '"open", "calendar"') + TAIL
        for text in (changed, HEAD + TAIL, HEAD + clock_hook.UPSTREAM * 2 + TAIL,
                     HEAD + clock_hook.UPSTREAM + clock_hook.VARIANT + TAIL):
            with self.subTest(text=text[-120:]):
                self.write(text)
                code, _, err = self.run_cli(str(self.face))
                self.assertEqual(code, 1)
                self.assertIn("not the one this hook knows", err)
                self.assertEqual(self.face.read_text(), text)
                self.assertEqual(self.run_cli("--remove", str(self.face))[0], 1)

    def test_the_archive_hook_is_left_to_the_archive(self):
        text = HEAD + clock_hook.ARCHIVE + TAIL
        self.write(text)
        code, _, err = self.run_cli(str(self.face))
        self.assertEqual(code, 1)
        self.assertIn("archive", err)
        self.assertEqual(self.face.read_text(), text)
        self.assertEqual(self.run_cli("--check", str(self.face))[1].strip(), "archive")

    def test_there_is_no_default_file(self):
        code, _, _ = self.run_cli()
        self.assertEqual(code, 2)
        self.assertEqual(self.run_cli(str(self.face.parent / "missing.qml"))[0], 1)

    @unittest.skipUnless(LIVE.is_file(), "Serpantinum is not installed here")
    def test_the_live_file_is_a_known_state(self):
        live = LIVE.read_text()  # read only
        state = clock_hook.state(live)
        self.assertIn(state, ("upstream", "archive", "variant"))
        copy = self.face
        # Back to upstream, whichever hunk is live (the archive's before the cutover, the variant after it).
        upstream = live.replace(clock_hook.ARCHIVE, clock_hook.UPSTREAM, 1).replace(clock_hook.VARIANT, clock_hook.UPSTREAM, 1)
        copy.write_text(upstream)
        self.assertEqual(clock_hook.apply(copy), "installed")
        self.assertEqual(clock_hook.apply(copy, remove=True), "removed")
        self.assertEqual(copy.read_text(), upstream)


def placement_function() -> str:
    lines = clock_hook.VARIANT.splitlines()
    start = next(i for i, line in enumerate(lines) if line.startswith("        function fartPlacement()"))
    end = next(i for i in range(start + 1, len(lines)) if lines[i] == "        }")
    return "\n".join(lines[start:end + 1])


@unittest.skipUnless(QML.is_file(), "needs Qt 6's qml runner")
class Placement(unittest.TestCase):
    """The variant's own fartPlacement() text, run offscreen in a stand-in for the bar window."""

    def placement(self, bar_window: str, x=880, y=0) -> list:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "Placement.qml"
            path.write_text(f"""import QtQuick
import QtQuick.Window
Window {{
    width: 1912; height: 44
    Item {{
        id: root
        x: {x}; y: {y}; width: 160; height: 40
        property var barWindow: {bar_window}
        MouseArea {{
            anchors.fill: parent
{placement_function()}
            Component.onCompleted: {{ console.log("PLACEMENT " + JSON.stringify(fartPlacement())); Qt.quit(); }}
        }}
    }}
}}
""")
            env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_FORCE_STDERR_LOGGING="1")  # not journald
            out = subprocess.run([str(QML), str(path)], capture_output=True, text=True, timeout=20, env=env)
        line = next((l for l in (out.stdout + out.stderr).splitlines() if "PLACEMENT " in l), None)
        self.assertIsNotNone(line, out.stderr[-800:])
        return json.loads(line.split("PLACEMENT ", 1)[1])

    def test_a_top_bar_adds_its_margins(self):
        bar = ('({ width: 1912, height: 44, margins: { left: 4, right: 4, top: 4, bottom: 0 },'
               ' anchors: { top: true, left: true, right: true, bottom: false },'
               ' screen: { name: "eDP-1", width: 1920, height: 1080 } })')
        self.assertEqual(self.placement(bar), ["--from", "884,4,160,40", "--screen", "eDP-1"])

    def test_missing_margins_and_screen_fall_back(self):
        self.assertEqual(self.placement("({ width: 1912, height: 44 })"), ["--from", "880,0,160,40", "--screen", ""])
        self.assertEqual(self.placement("null"), ["--from", "880,0,160,40", "--screen", ""])

    def test_a_bottom_bar_counts_from_the_bottom_edge(self):
        bar = ('({ width: 1912, height: 44, margins: { left: 4, right: 4, top: 0, bottom: 4 },'
               ' anchors: { top: false, left: true, right: true, bottom: true },'
               ' screen: { name: "HDMI-A-1", width: 1920, height: 1080 } })')
        self.assertEqual(self.placement(bar, y=4), ["--from", "884,1036,160,40", "--screen", "HDMI-A-1"])


if __name__ == "__main__":
    unittest.main()
