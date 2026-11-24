"""Turning the desktop widgets off and on (owner, 24 Nov: from the right-click menu and inside Edit widgets): the
menu's fifth row and the editor's button; hidden widgets keep their poses and the bare desktop still opens the menu."""
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
    function say(name, value) { console.log("TOGGLE " + JSON.stringify([name, value])); }
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        for (const k of Array.from(item.children ?? [])) { const hit = find(k, test); if (hit) return hit; }
        if (item.item) return find(item.item, test);
        return null;
    }
    function toggleText() {
        const toggle = find(sheet.editor, i => i.objectName === "editorShowToggle");
        return find(toggle, i => typeof i.text === "string" && i.text.length > 0)?.text ?? null;
    }
    readonly property string mon: Quickshell.screens[0]?.name ?? ""
    QtObject { id: spaces; property var workspaces: [{ id: "1", monitor: harness.mon, active: true, windowCount: 0 }] }
    QtObject {
        id: core
        property var calls: []
        property var widgetsData: ({ shown: true, layout: "Default", monitors: ({}),
            defaults: { clock: { column: 2, span: 8, y: 0.42, angle: 0 } }, face: {} })
        function request(op, args, callback) {
            calls = calls.concat([[op, args]]);
            if (op === "widgets.show") widgetsData = Object.assign({}, widgetsData, { shown: args.on });
            if (callback) callback(true, widgetsData);
        }
    }
    DesktopWidgets { id: desktop; fixture: true; workspaces: spaces; core: core }
    readonly property var stage: desktop.stages[0] ?? null
    readonly property var sheet: desktop.sheets[0] ?? null
    property int step: 0
    Timer {
        interval: 300; running: true; repeat: true
        onTriggered: {
            switch (harness.step++) {
            case 0: break;
            case 1: harness.stage.menuRequested(Qt.point(50, 50)); break;
            case 2:
                harness.say("rows", harness.sheet.menu.labels);
                harness.sheet.choose("Hide widgets");
                break;
            case 3:
                harness.say("hidden", [core.calls.map(c => c[0] + ":" + c[1].on), harness.stage.clock.visible, desktop.stages.length]);
                harness.stage.menuRequested(Qt.point(50, 50));  // the bare desktop still answers
                break;
            case 4:
                harness.say("rowsWhenHidden", harness.sheet.menu.labels.slice(-1));
                harness.sheet.choose("Edit widgets");
                break;
            case 5:
                harness.say("editorButton", harness.toggleText());
                harness.sheet.editor.showWidgets(!harness.sheet.editor.shown);
                break;
            case 6:
                harness.say("shownAgain", [core.widgetsData.shown, harness.toggleText()]);
                harness.sheet.editor.closed();
                break;
            case 7:
                harness.say("clockBack", harness.stage.clock.visible);
                harness.say("done", true);
                Qt.quit();
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
    return output, {k: v for k, v in (json.loads(line.split("TOGGLE ", 1)[1]) for line in output.splitlines() if "TOGGLE [" in line)}


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class WidgetsToggle(unittest.TestCase):
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

    def test_the_menu_hides_them_and_the_desktop_still_answers(self):
        self.assertEqual(self.heard("rows"), ["Edit widgets", "Wallpaper", "Theme", "Settings", "Hide widgets"])
        calls, visible, stages = self.heard("hidden")
        self.assertEqual(calls, ["widgets.show:false"])
        self.assertFalse(visible)
        self.assertEqual(stages, 1)
        self.assertEqual(self.heard("rowsWhenHidden"), ["Show widgets"])

    def test_the_editor_shows_them_again(self):
        self.assertEqual(self.heard("editorButton"), "Show widgets")
        self.assertEqual(self.heard("shownAgain"), [True, "Hide widgets"])
        self.assertTrue(self.heard("clockBack"))


if __name__ == "__main__":
    unittest.main()
