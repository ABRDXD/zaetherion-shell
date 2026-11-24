"""The desktop menu and the widget editor (Z86; owner's picks 24 Nov: both menus kept, Chase in Angular, Margin in
Fluid), offscreen through DesktopWidgets' fixture windows with a recording core: the menu opens at a right-click
inside the screen, takes the keyboard, dismisses on Escape or a click outside; its rows reach Settings at the right
section; Edit widgets opens the form's placement; moves, resizes and turns are saved and survive reopening."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

HARNESS = '''import QtQuick
import Quickshell
import qs.view.ui
import qs.view.widgets
Scope {
    id: harness
    function say(name, value) { console.log("EDITOR " + JSON.stringify([name, value])); }
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const k of Array.from(item.children ?? [])) { const hit = find(k, test); if (hit) return hit; }
        if (item.item) return find(item.item, test);
        return null;
    }
    function named(item, name) { return find(item, i => i.objectName === name); }
    readonly property string mon: Quickshell.screens[0]?.name ?? ""
    QtObject {
        id: spaces
        property var workspaces: [{ id: "1", monitor: harness.mon, active: true, windowCount: 0 }]
    }
    QtObject {
        id: core
        property var calls: []
        property var widgetsData: ({ layout: "Default", layouts: ["Default"], columns: 12, minSpan: { clock: 3 }, monitors: ({}),
            defaults: { clock: { column: 2, span: 8, y: 0.42, angle: 0 } }, face: {} })
        property var wallpaperData: ({ applied: "" })
        function request(op, args, callback) {
            calls = calls.concat([[op, args]]);
            if (op === "widgets.place") {
                const monitors = Object.assign({}, widgetsData.monitors);
                monitors[args.monitor] = { clock: { column: args.column, span: args.span, y: args.y, angle: args.angle } };
                widgetsData = Object.assign({}, widgetsData, { monitors: monitors });
            }
            if (callback) callback(true, widgetsData);
        }
    }
    property var opened: []
    DesktopWidgets { id: desktop; fixture: true; workspaces: spaces; core: core; onOpenSettings: s => harness.opened = harness.opened.concat([s]) }
    readonly property var stage: desktop.stages[0] ?? null
    readonly property var sheet: desktop.sheets[0] ?? null
    function places() { return core.calls.filter(c => c[0] === "widgets.place").map(c => c[1]); }
    property int step: 0
    Timer {
        interval: 300; running: true; repeat: true
        onTriggered: {
            switch (harness.step++) {
            case 0: break;
            case 1:
                harness.stage.menuRequested(Qt.point(harness.stage.width - 5, harness.stage.height - 5));
                break;
            case 2: {
                const menu = harness.sheet?.menu;
                harness.say("menuOpen", !!menu);
                const at = menu.mapToItem(harness.sheet, 0, 0);
                // A right-click in the bottom-right corner: the menu sits flush against both edges, on screen.
                harness.say("menuInside", menu ? [Math.round(at.x + menu.width) === Math.round(harness.sheet.width),
                                                  Math.round(at.y + menu.height) === Math.round(harness.sheet.height),
                                                  at.x > 0, at.y > 0] : null);
                harness.say("menuFocus", menu?.activeFocus ?? false);
                menu.step(1); menu.step(1); menu.step(-1);
                harness.say("keyboardRow", menu.current);
                menu.dismissed();  // Escape
                break;
            }
            case 3:
                harness.say("escapeCloses", desktop.sheets.length);
                harness.stage.menuRequested(Qt.point(40, 40));
                break;
            case 4:
                // A click outside the menu: the sheet's catch-all
                harness.sheet.dismissed();
                break;
            case 5:
                harness.say("outsideCloses", desktop.sheets.length);
                harness.stage.menuRequested(Qt.point(100, 100));
                break;
            case 6: harness.sheet.choose("Wallpaper"); break;
            case 7: harness.stage.menuRequested(Qt.point(100, 100)); break;
            case 8: harness.sheet.choose("Theme"); break;
            case 9: harness.stage.menuRequested(Qt.point(100, 100)); break;
            case 10: harness.sheet.choose("Settings"); break;
            case 11:
                harness.say("destinations", harness.opened);
                harness.say("closedAfterRows", desktop.sheets.length);
                harness.stage.menuRequested(Qt.point(100, 100));
                break;
            case 12:
                harness.sheet.menu.chosen("Edit widgets");
                break;
            case 13: {
                const ed = harness.sheet?.editor;
                harness.say("angularEditor", [!!ed, ed?.margin, !!harness.named(ed, "turnHandle"), !!harness.named(ed, "spanHandle"), !!harness.named(ed, "marginPanel")]);
                harness.say("editorFocus", ed?.activeFocus ?? false);
                harness.say("context", harness.named(ed, "editorContext")?.text);
                const w = ed.screenSize.width, h = ed.screenSize.height;
                const c = ed.box;
                ed.begin("Move", Qt.point(c.x + 10, c.y + 10)); ed.track(Qt.point(c.x + 10 - 3 * (w / 12), c.y + 10 + h * 0.1)); ed.end();
                ed.begin("Resize", Qt.point(0, 0)); ed.track(Qt.point(-2 * (w / 12), 0)); ed.end();
                const b = ed.box, centre = Qt.point(b.x + b.width / 2, b.y + b.height / 2);
                ed.begin("Rotate", Qt.point(centre.x + 100, centre.y)); ed.track(Qt.point(centre.x, centre.y + 100)); ed.end();
                break;
            }
            case 14:
                harness.say("placed", harness.places().map(p => [p.column, p.span, Math.round(p.y * 100), p.angle]));
                harness.sheet.editor.closed();  // Escape / Preview
                break;
            case 15:
                harness.say("editorClosed", desktop.sheets.length);
                harness.say("stagePose", [harness.stage.pose.column, harness.stage.pose.span, harness.stage.pose.angle, Math.round(harness.stage.clock.rotation)]);
                Design.form = "fluid";
                harness.stage.menuRequested(Qt.point(100, 100));
                break;
            case 16:
                harness.sheet.choose("Edit widgets");
                break;
            case 17: {
                const ed = harness.sheet?.editor;
                const panel = harness.named(ed, "marginPanel");
                harness.say("fluidEditor", [!!ed, ed?.margin, !!panel, !!harness.named(ed, "turnHandle")]);
                harness.say("reopenedPose", [ed.pose.column, ed.pose.span, ed.pose.angle]);
                panel.toolRequested("Rotate");
                panel.valueRequested(-30);
                break;
            }
            case 18: {
                const last = harness.places().slice(-1)[0];
                harness.say("rulerSaved", [last.angle, harness.sheet.editor.tool]);
                harness.say("done", true);
                Qt.quit();
            }
            }
        }
    }
}
'''


def run_harness():
    from smoke import prepare
    with tempfile.TemporaryDirectory() as tmp:
        env, _, _ = prepare(Path(tmp), HARNESS)
        run = subprocess.run(["qs", "-n", "--no-color", "-p", str(Path(tmp) / "bundle/Harness.qml")], env=env,
                             capture_output=True, text=True, timeout=90)
    output = run.stdout + run.stderr
    return output, {k: v for k, v in (json.loads(line.split("EDITOR ", 1)[1]) for line in output.splitlines() if "EDITOR [" in line)}


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class DesktopEditorRun(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output, cls.said = run_harness()

    def heard(self, name):
        if name not in self.said:
            self.fail(f"the harness never said {name!r}:\n{self.output[-3000:]}")
        return self.said[name]

    def test_ran_clean(self):
        self.assertTrue(self.heard("done"))
        for problem in ("ReferenceError", "TypeError", "Cannot assign", "is not a type", "Unable to assign"):
            self.assertNotIn(problem, self.output)

    def test_the_menu_opens_inside_the_screen_with_the_keyboard(self):
        self.assertTrue(self.heard("menuOpen"))
        self.assertEqual(self.heard("menuInside"), [True, True, True, True])
        self.assertTrue(self.heard("menuFocus"))
        self.assertEqual(self.heard("keyboardRow"), 1)

    def test_escape_and_a_click_outside_dismiss_it(self):
        self.assertEqual(self.heard("escapeCloses"), 0)
        self.assertEqual(self.heard("outsideCloses"), 0)

    def test_rows_reach_their_settings(self):
        self.assertEqual(self.heard("destinations"), ["wallpaper", "palette", "current"])
        self.assertEqual(self.heard("closedAfterRows"), 0)

    def test_angular_edits_with_chase_and_each_gesture_is_saved(self):
        self.assertEqual(self.heard("angularEditor"), [True, False, True, True, False])
        self.assertTrue(self.heard("editorFocus"))
        self.assertTrue(self.heard("context").endswith("/   Default"))
        placed = self.heard("placed")
        self.assertEqual(placed[0][:2], [0, 8])     # three columns left, held at the grid's edge
        self.assertEqual(placed[0][2], 52)          # 0.42 + a tenth of the screen
        self.assertEqual(placed[1][:2], [0, 6])     # two columns narrower
        self.assertEqual(placed[2][3], 90)          # a quarter turn
        self.assertEqual(self.heard("editorClosed"), 0)
        self.assertEqual(self.heard("stagePose"), [0, 6, 90, 90])  # the desktop clock follows the saved pose

    def test_fluid_edits_with_margin_and_the_ruler_saves(self):
        self.assertEqual(self.heard("fluidEditor"), [True, True, True, False])
        self.assertEqual(self.heard("reopenedPose"), [0, 6, 90])  # what was saved, after reopening
        self.assertEqual(self.heard("rulerSaved"), [-30, "Rotate"])


if __name__ == "__main__":
    unittest.main()
