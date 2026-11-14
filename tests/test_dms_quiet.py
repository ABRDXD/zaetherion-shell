"""tools/dms_quiet.py removes exactly DMS's NotificationServer object and refuses a DMS it doesn't understand."""
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import dms_quiet  # noqa: E402

SERVICE = """import Quickshell.Services.Notifications

Singleton {
    id: root
    property string a: "{ not a brace"

    NotificationServer {
        id: server
        keepOnReload: false
        onNotification: notif => {
            const s = `}${notif.summary}`; // a } in a comment
            /* and { here */
            if (notif.urgency === NotificationUrgency.Critical) { root.a = '}' }
        }
    }

    function after() { return NotificationUrgency.Low }
}
"""


BAR_LINE = ("    readonly property real surfaceExclusiveZone: isIsland ? ((islandFree || (islandHost?.floating ?? "
            "SettingsData.islandSetting(barConfig, \"islandFloating\"))) ? 0 : SettingsData.islandReserveThickness(barConfig)) : "
            "(!(barConfig?.visible ?? true) || ((barConfig?.autoHide ?? false) && !barWindow.reserveExclusiveWhenAutoHidden)) ? -1 : "
            "(barWindow.effectiveBarThickness + effectiveSpacing)\n")


class QuietTest(unittest.TestCase):
    def test_a_hidden_island_bar_reserves_nothing(self):
        out = dms_quiet.hidden_bar_reserves_nothing(BAR_LINE)
        self.assertIn("isIsland ? (!(barConfig?.visible ?? true) ? -1 : (islandFree || ", out)
        self.assertEqual(out.count("(") - out.count(")"), BAR_LINE.count("(") - BAR_LINE.count(")"))
        with self.assertRaises(ValueError):
            dms_quiet.hidden_bar_reserves_nothing("readonly property real surfaceExclusiveZone: 0\n")

    def test_removes_only_the_server(self):
        out = dms_quiet.quiet(SERVICE)
        self.assertNotIn("NotificationServer {", out)
        self.assertNotIn("keepOnReload", out)
        self.assertIn('property string a: "{ not a brace"', out)
        self.assertIn("function after() { return NotificationUrgency.Low }", out)
        start = SERVICE.index("    NotificationServer {")
        end = SERVICE.index("\n\n    function after()")
        self.assertEqual(out, SERVICE[:start] + "    // NotificationServer removed by ZÆTHERION tools/dms_quiet.py:"
                         " our server holds org.freedesktop.Notifications." + SERVICE[end:])

    def test_refuses_none_or_two(self):
        with self.assertRaises(ValueError):
            dms_quiet.quiet("Singleton {}\n")
        twice = SERVICE.replace("    function after()", "    NotificationServer { }\n    function after()")
        with self.assertRaises(ValueError):
            dms_quiet.quiet(twice)

    def test_refuses_when_the_id_is_used(self):
        with self.assertRaises(ValueError):
            dms_quiet.quiet(SERVICE.replace("return NotificationUrgency.Low", "return server.trackedNotifications"))

    def test_build_and_check(self):
        with tempfile.TemporaryDirectory() as d:
            source, out = Path(d) / "src", Path(d) / "out"
            (source / "Services").mkdir(parents=True)
            (source / "Services/NotificationService.qml").write_text(SERVICE)
            (source / "Services/NotificationService.qml").chmod(0o444)
            (source / ".dankrev").write_text("abc\n")
            (source / "Modules/DBar").mkdir(parents=True)
            (source / "Modules/DBar/DBarBody.qml").write_text(BAR_LINE)
            self.assertEqual(dms_quiet.check(source)[0], "not made by dms_quiet (no marker)")
            dms_quiet.build(source, out)
            self.assertEqual(dms_quiet.check(out), [])
            self.assertEqual((out / dms_quiet.MARKER).read_text().strip(), "abc")
            self.assertIn("NotificationServer {", (source / "Services/NotificationService.qml").read_text())
            dms_quiet.build(source, out)  # rebuilds over its own copy
            other = Path(d) / "other"
            other.mkdir()
            with self.assertRaises(SystemExit):
                dms_quiet.build(source, other)  # never over a folder it didn't make
            with self.assertRaises(SystemExit):
                dms_quiet.build(out, Path(d) / "again")  # never from a quiet copy


class FitsTest(unittest.TestCase):
    """The copy runs at login only with the `dms` program it was made from."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        self.program = base / "dms"
        self.program.write_text("#!/bin/sh\n")
        self.copy = base / "copy"
        (self.copy / dms_quiet.SERVICE).parent.mkdir(parents=True)
        (self.copy / dms_quiet.SERVICE).write_text(dms_quiet.quiet(SERVICE))
        (self.copy / dms_quiet.BAR).parent.mkdir(parents=True)
        (self.copy / dms_quiet.BAR).write_text(dms_quiet.hidden_bar_reserves_nothing(BAR_LINE))
        (self.copy / dms_quiet.MARKER).write_text("rev\n")

    def stamp(self):
        (self.copy / dms_quiet.PROGRAM).write_text(dms_quiet.program_stamp(str(self.program)) + "\n")

    def test_the_program_it_was_made_for_fits(self):
        self.stamp()
        self.assertEqual(dms_quiet.fits(self.copy, str(self.program)), [])

    def test_a_changed_program_does_not_fit(self):
        self.stamp()
        self.program.write_text("#!/bin/sh\n# upgraded\n")
        self.assertIn("dms changed", " ".join(dms_quiet.fits(self.copy, str(self.program))))

    def test_a_copy_with_no_record_does_not_fit(self):
        self.assertIn("records no dms program", " ".join(dms_quiet.fits(self.copy, str(self.program))))

    def test_a_copy_that_is_not_quiet_does_not_fit(self):
        self.stamp()
        (self.copy / dms_quiet.SERVICE).write_text(SERVICE)
        self.assertIn("still declares", " ".join(dms_quiet.fits(self.copy, str(self.program))))


if __name__ == "__main__":
    unittest.main()
