"""tools/dms_quiet.py removes exactly DMS's NotificationServer object and refuses a DMS it doesn't understand."""
import contextlib
import io
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


PROMPT_FILES = {
    "DMSShell.qml": """import QtQuick
import qs.Modals.DLauncherV2

Item {
    Connections {
        target: NetworkService

        function onCredentialsNeeded(token, ssid, setting, fields, hints, reason, connType, connName, vpnService, fieldsInfo) {
            wifiPasswordModalLoader.active = true;
        }
    }
}
""",
    "Modules/ControlCenter/Details/BluetoothDetail.qml": """Item {
    Connections {
        target: DMSService

        function onBluetoothPairingRequest(data) {
            modal.show(data);
        }
    }
}
""",
}


def write_prompts(base, patched=False):
    for name, text in PROMPT_FILES.items():
        path = Path(base) / name
        path.parent.mkdir(parents=True, exist_ok=True)
        opening = next(o for f, o in dms_quiet.PROMPTS if str(f) == name)
        path.write_text(dms_quiet.prompt_left_to_fart(text, Path(name), opening) if patched else text)


class PromptTest(unittest.TestCase):
    """DMS's own password and pairing windows are left out, so FART's answer the prompts (Z191)."""

    def test_each_handler_returns_at_once_and_nothing_else_changes(self):
        for name, text in PROMPT_FILES.items():
            opening = next(o for f, o in dms_quiet.PROMPTS if str(f) == name)
            out = dms_quiet.prompt_left_to_fart(text, Path(name), opening)
            lines = out.split("\n")
            i = next(n for n, l in enumerate(lines) if l.strip() == opening)
            self.assertEqual(lines[i + 1].strip(), dms_quiet.PROMPT_NOTE)
            self.assertEqual(lines[i + 1].index("return"), lines[i].index("function") + 4)
            self.assertEqual(out.replace(lines[i + 1] + "\n", ""), text)

    def test_refuses_a_file_without_exactly_one_handler(self):
        path, opening = dms_quiet.PROMPTS[0]
        with self.assertRaises(ValueError):
            dms_quiet.prompt_left_to_fart("Item {}", path, opening)
        with self.assertRaises(ValueError):
            dms_quiet.prompt_left_to_fart(f"{opening}\n}}\n{opening}\n}}", path, opening)

    def test_the_installed_dms_has_exactly_the_handlers_it_patches(self):
        import os
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/nonexistent")) / "dms-shell"
        sources = [d for d in (runtime.iterdir() if runtime.is_dir() else []) if (d / "DMSShell.qml").is_file()]
        if not sources:
            self.skipTest("no DMS UI extracted on this machine")
        for source in sources:      # read only
            for path, opening in dms_quiet.PROMPTS:
                dms_quiet.prompt_left_to_fart((source / path).read_text(), path, opening)


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
            write_prompts(source)
            self.assertEqual(dms_quiet.check(source)[0], "not made by dms_quiet (no marker)")
            self.assertIn("DMSShell.qml still opens DMS's own window", dms_quiet.prompt_problems(source))
            dms_quiet.build(source, out)
            self.assertEqual(dms_quiet.check(out), [])
            self.assertEqual(dms_quiet.prompt_problems(out), [])
            self.assertEqual((out / dms_quiet.MARKER).read_text().strip(), "abc")
            self.assertNotIn(dms_quiet.PROMPT_NOTE, (source / "DMSShell.qml").read_text())      # the source is untouched
            self.assertIn("NotificationServer {", (source / "Services/NotificationService.qml").read_text())
            dms_quiet.build(source, out)  # rebuilds over its own copy
            other = Path(d) / "other"
            other.mkdir()
            with self.assertRaises(SystemExit):
                dms_quiet.build(source, other)  # never over a folder it didn't make
            with self.assertRaises(SystemExit):
                dms_quiet.build(out, Path(d) / "again")  # never from a quiet copy


class BridgeTest(unittest.TestCase):
    """DMS's launcher engine reaches the star chart through one bridge file and one instance (Z197)."""

    def test_one_instance_before_the_root_closes_and_idempotent(self):
        shell = PROMPT_FILES["DMSShell.qml"]
        once = dms_quiet.with_bridge(shell)
        self.assertEqual(once.count(dms_quiet.BRIDGE_LINE), 1)
        self.assertTrue(once.rstrip().endswith(dms_quiet.BRIDGE_LINE + "\n}"))
        self.assertEqual(dms_quiet.with_bridge(once), once)
        with self.assertRaises(ValueError):
            dms_quiet.with_bridge("Item {\n}\n")  # no launcher import: not the shell this knows

    def test_build_carries_it_and_bridge_adds_it_to_an_older_copy(self):
        with tempfile.TemporaryDirectory() as d:
            source, out = Path(d) / "src", Path(d) / "out"
            (source / "Services").mkdir(parents=True)
            (source / "Services/NotificationService.qml").write_text(SERVICE)
            (source / "Modules/DBar").mkdir(parents=True)
            (source / "Modules/DBar/DBarBody.qml").write_text(BAR_LINE)
            write_prompts(source)
            dms_quiet.build(source, out)
            self.assertEqual(dms_quiet.bridge_problems(out), [])
            self.assertIn(dms_quiet.PROMPT_NOTE, (out / "DMSShell.qml").read_text())  # both patches in the one file
            (out / dms_quiet.BRIDGE).unlink()
            (out / "DMSShell.qml").write_text(PROMPT_FILES["DMSShell.qml"])
            self.assertEqual(len(dms_quiet.bridge_problems(out)), 2)
            dms_quiet.add_bridge(out)
            self.assertEqual(dms_quiet.bridge_problems(out), [])
            with self.assertRaises(SystemExit):
                dms_quiet.add_bridge(source)  # only a copy this tool made


class PromptsInPlaceTest(unittest.TestCase):
    """A copy made before Z191 gets the two early returns in place (`dms_quiet.py prompts`)."""

    def test_patches_an_older_copy_once_and_only_a_quiet_copy(self):
        with tempfile.TemporaryDirectory() as d:
            copy = Path(d) / "copy"
            write_prompts(copy)
            with self.assertRaises(SystemExit):
                dms_quiet.add_prompts(copy)                                   # no marker: not ours
            self.assertEqual(len(dms_quiet.prompt_problems(copy)), 2)
            (copy / dms_quiet.MARKER).write_text("rev\n")
            self.assertEqual(sorted(map(str, dms_quiet.add_prompts(copy))), sorted(PROMPT_FILES))
            self.assertEqual(dms_quiet.prompt_problems(copy), [])
            before = {n: (copy / n).read_text() for n in PROMPT_FILES}
            self.assertEqual(dms_quiet.add_prompts(copy), [])                 # twice: nothing more
            self.assertEqual({n: (copy / n).read_text() for n in PROMPT_FILES}, before)
            for name in PROMPT_FILES:
                self.assertEqual((copy / name).read_text().count(dms_quiet.PROMPT_NOTE), 1)

    def test_an_unknown_handler_leaves_every_file_untouched(self):
        with tempfile.TemporaryDirectory() as d:
            copy = Path(d) / "copy"
            write_prompts(copy)
            (copy / dms_quiet.MARKER).write_text("rev\n")
            (copy / "Modules/ControlCenter/Details/BluetoothDetail.qml").write_text("Item {}\n")
            shell = (copy / "DMSShell.qml").read_text()
            with self.assertRaises(ValueError):
                dms_quiet.add_prompts(copy)
            self.assertEqual((copy / "DMSShell.qml").read_text(), shell)     # checked before anything is written


TRIM_SHELL = """import QtQuick
import qs.Modals.DLauncherV2

Item {
    id: root

    DesktopWidgetLayer {}

    DesktopWidgetEditor {}

    DesktopContextMenu {
        Component.onCompleted: PopoutService.desktopContextMenu = this
    }

    Lock {
        id: lock
    }

    Variants {
        model: root.notificationPopupScreens

        delegate: NotificationPopupManager {}
    }

    LazyLoader {
        id: controlCenterLoader
        property var modalRef: colorPickerModal
    }

    MuxModal {
        id: muxModal
    }

    ClipboardHistoryModal {
        id: clipboardHistoryModalPopup
    }

    NotificationModal {
        id: notificationModal

        Component.onCompleted: {
            PopoutService.notificationModal = notificationModal; // a } in a comment
        }
    }

    ColorPickerModal {
        id: colorPickerModal
        property string hint: "{ not a brace"
    }

    Variants {
        id: notepadSlideoutVariants
        model: SettingsData.getFilteredScreens("notepad")
    }

    Variants {
        model: SettingsData.getFilteredScreens("toast")

        delegate: Toast {}
    }

    Loader {
        id: osdSurfacesLoader
        active: root.osdSurfacesLoaded
    }

    Connections {
        target: NetworkService

        function onCredentialsNeeded(token, ssid, setting, fields, hints, reason, connType, connName, vpnService, fieldsInfo) {
            wifiPasswordModalLoader.active = true;
        }
    }
}
"""


def active(text):
    """The lines QML would still run: not a trim's commented-out ones."""
    return "\n".join(line for line in text.split("\n") if not line.startswith("//ZT "))


class TrimTest(unittest.TestCase):
    """Opt-in trims of DMS's always-on UI: only what is named, undone exactly, refused on an unknown shape."""

    def copy(self, base):
        copy = Path(base) / "copy"
        copy.mkdir()
        (copy / "DMSShell.qml").write_text(TRIM_SHELL)
        (copy / dms_quiet.MARKER).write_text("rev\n")
        return copy

    def test_each_trim_takes_out_its_part_and_undoes_exactly(self):
        gone = {"popups": "model: root.notificationPopupScreens", "notifications": "NotificationModal {",
                "toasts": 'getFilteredScreens("toast")', "osd": "active: root.osdSurfacesLoaded",
                "notepad": 'getFilteredScreens("notepad")', "mux": "MuxModal {", "desktop": "DesktopContextMenu {",
                "colorpicker": "ColorPickerModal {"}
        self.assertEqual(set(gone), set(dms_quiet.TRIMS))
        for name, needle in gone.items():
            out = dms_quiet.apply_trim(TRIM_SHELL, name)
            self.assertNotIn(needle, active(out), name)
            self.assertEqual(dms_quiet.trims_in(out), [name])
            self.assertEqual(dms_quiet.apply_trim(out, name), out)  # idempotent
            self.assertEqual(dms_quiet.remove_trim(out, name), TRIM_SHELL)
            kept = active(out)
            root = kept.index("Item {")  # the root still closes at the very end: no brace left dangling
            self.assertEqual(dms_quiet.block_end(kept, root), len(kept.rstrip()), name)
            for other in ("Lock {", "ClipboardHistoryModal {", "onCredentialsNeeded"):
                self.assertIn(other, kept, name)  # lock, quick paste and the prompts are never trimmed

    def test_a_dropped_block_goes_whole_and_its_strings_and_comments_do_not_confuse_it(self):
        out = active(dms_quiet.apply_trim(TRIM_SHELL, "notifications"))
        self.assertNotIn("notificationModal", out)
        self.assertIn("ColorPickerModal {", out)
        out = active(dms_quiet.apply_trim(TRIM_SHELL, "colorpicker"))
        self.assertNotIn("not a brace", out)
        self.assertIn("property var modalRef: null", out)  # its one outside reference, so nothing is undefined
        self.assertIn("Variants {\n        id: notepadSlideoutVariants", out)

    def test_set_trims_makes_exactly_the_named_set_and_none_restores(self):
        with tempfile.TemporaryDirectory() as d:
            copy = self.copy(d)
            self.assertEqual(dms_quiet.set_trims(copy, ["mux", "osd"]), ["osd", "mux"])
            self.assertEqual((copy / dms_quiet.TRIMMED).read_text().split(), ["osd", "mux"])
            self.assertEqual(dms_quiet.set_trims(copy, ["popups", "mux"]), ["popups", "mux"])
            self.assertIn("active: root.osdSurfacesLoaded", active((copy / "DMSShell.qml").read_text()))
            self.assertEqual(dms_quiet.set_trims(copy, []), [])
            self.assertEqual((copy / "DMSShell.qml").read_text(), TRIM_SHELL)
            self.assertFalse((copy / dms_quiet.TRIMMED).exists())

    def test_refuses_unknown_names_a_foreign_folder_and_an_unknown_shape_without_writing(self):
        with tempfile.TemporaryDirectory() as d:
            copy = self.copy(d)
            with self.assertRaises(SystemExit):
                dms_quiet.set_trims(copy, ["bar"])
            (copy / "DMSShell.qml").write_text(TRIM_SHELL.replace("    MuxModal {", "    MuxModal2 {"))
            before = (copy / "DMSShell.qml").read_text()
            with self.assertRaises(ValueError):
                dms_quiet.set_trims(copy, ["osd", "mux"])  # mux no longer matches: osd isn't written either
            self.assertEqual((copy / "DMSShell.qml").read_text(), before)
            (copy / dms_quiet.MARKER).unlink()
            with self.assertRaises(SystemExit):
                dms_quiet.set_trims(copy, ["osd"])
        doubled = TRIM_SHELL.replace("    Lock {", "    MuxModal {\n    }\n\n    Lock {")
        with self.assertRaises(ValueError):
            dms_quiet.apply_trim(doubled, "mux")

    def test_build_applies_only_the_named_trims(self):
        with tempfile.TemporaryDirectory() as d:
            source, out = Path(d) / "src", Path(d) / "out"
            (source / "Services").mkdir(parents=True)
            (source / "Services/NotificationService.qml").write_text(SERVICE)
            (source / "Modules/DBar").mkdir(parents=True)
            (source / "Modules/DBar/DBarBody.qml").write_text(BAR_LINE)
            write_prompts(source)
            (source / "DMSShell.qml").write_text(TRIM_SHELL)
            dms_quiet.build(source, out)
            self.assertEqual(dms_quiet.trims_in((out / "DMSShell.qml").read_text()), [])  # none unless asked
            self.assertFalse((out / dms_quiet.TRIMMED).exists())
            dms_quiet.build(source, out, ["toasts"])
            shell = (out / "DMSShell.qml").read_text()
            self.assertEqual(dms_quiet.trims_in(shell), ["toasts"])
            self.assertIn(dms_quiet.PROMPT_NOTE, shell)
            self.assertIn(dms_quiet.BRIDGE_LINE, shell)
            self.assertEqual(dms_quiet.check(out), [])
            self.assertEqual(dms_quiet.set_trims(out, []), [])
            self.assertIn(dms_quiet.BRIDGE_LINE, (out / "DMSShell.qml").read_text())  # undoing keeps the other patches
            with self.assertRaises(SystemExit):
                dms_quiet.build(source, Path(d) / "x", ["nope"])

    def test_a_rebuild_keeps_the_copys_trims_unless_told(self):
        with tempfile.TemporaryDirectory() as d:
            source, out = Path(d) / "src", Path(d) / "out"
            (source / "Services").mkdir(parents=True)
            (source / "Services/NotificationService.qml").write_text(SERVICE)
            (source / "Modules/DBar").mkdir(parents=True)
            (source / "Modules/DBar/DBarBody.qml").write_text(BAR_LINE)
            write_prompts(source)
            (source / "DMSShell.qml").write_text(TRIM_SHELL)
            self.assertEqual(dms_quiet.kept_trims(out), [])  # no copy yet
            dms_quiet.build(source, out, ["toasts", "mux"])
            self.assertEqual(dms_quiet.kept_trims(out), ["toasts", "mux"])
            argv = ["build", "--source", str(source), "--out", str(out)]
            with contextlib.redirect_stdout(io.StringIO()) as said:
                dms_quiet.main(argv)  # e.g. after a DMS upgrade: the owner's trims come along
            self.assertIn("kept trims: toasts, mux", said.getvalue())
            self.assertEqual(dms_quiet.trims_in((out / "DMSShell.qml").read_text()), ["toasts", "mux"])
            with contextlib.redirect_stdout(io.StringIO()):
                dms_quiet.main([*argv, "--trim", "osd"])
            self.assertEqual(dms_quiet.trims_in((out / "DMSShell.qml").read_text()), ["osd"])
            with contextlib.redirect_stdout(io.StringIO()):
                dms_quiet.main([*argv, "--trim", "none"])
            self.assertEqual(dms_quiet.trims_in((out / "DMSShell.qml").read_text()), [])

    def test_the_session_copy_has_every_part_the_trims_take(self):
        copy = dms_quiet.default_out()
        if not (copy / "DMSShell.qml").is_file():
            self.skipTest("no quiet copy on this machine")
        live = (copy / "DMSShell.qml").read_text()  # read only
        text = live
        for name in dms_quiet.trims_in(live):  # the owner's trims (22 Nov: all eight) undone, in memory only
            text = dms_quiet.remove_trim(text, name)
        self.assertEqual(dms_quiet.trims_in(text), [])
        for name in dms_quiet.TRIMS:
            self.assertEqual(dms_quiet.remove_trim(dms_quiet.apply_trim(text, name), name), text, name)
        again = text
        for name in dms_quiet.trims_in(live):
            again = dms_quiet.apply_trim(again, name)
        self.assertEqual(again, live)  # undo and redo are exact on the copy as it runs


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
        write_prompts(self.copy, patched=True)
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

    def test_a_copy_made_before_z191_still_fits_with_a_warning(self):
        self.stamp()
        for path, _ in dms_quiet.PROMPTS:
            (self.copy / path).unlink()
        self.assertEqual(dms_quiet.fits(self.copy, str(self.program)), [])
        self.assertEqual(len(dms_quiet.prompt_problems(self.copy)), 2)

    def test_a_copy_that_is_not_quiet_does_not_fit(self):
        self.stamp()
        (self.copy / dms_quiet.SERVICE).write_text(SERVICE)
        self.assertIn("still declares", " ".join(dms_quiet.fits(self.copy, str(self.program))))


if __name__ == "__main__":
    unittest.main()
