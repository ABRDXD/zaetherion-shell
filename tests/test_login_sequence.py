"""The Angular login (Z55, Z108; Astra's Register → Day index at 59c34af with Impression copy, owner's picks 23 Nov),
offscreen through DesktopWidgets' fixture windows: the desktop clock waits while the login plays and appears when it
lands; the travelling tab docks on today's slot of the real clock whatever the weekday; a key lands it at once; an
occupied workspace gets no clock; reduced motion and Fluid don't play. The words are lines.json's Impression."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

HARNESS = '''import QtQuick
import Quickshell
import qs.view.cues
import qs.view.ui
import qs.view.widgets
Scope {
    id: harness
    function say(name, value) { console.log("LOGIN " + JSON.stringify([name, value])); }
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const k of Array.from(item.children ?? [])) { const hit = find(k, name); if (hit) return hit; }
        return null;
    }
    readonly property string mon: Quickshell.screens[0]?.name ?? ""
    QtObject {
        id: spaces
        property string focusedScreen: harness.mon
        property var workspaces: [{ id: "1", monitor: harness.mon, active: true, windowCount: 0 }]
    }
    QtObject {
        id: core
        property var widgetsData: ({ monitors: ({ [harness.mon]: { clock: { column: 1, span: 7, y: 0.4, angle: 0 } } }),
            defaults: { clock: { column: 2, span: 8, y: 0.42, angle: 0 } }, face: {} })
    }
    DesktopWidgets { id: desktop; fixture: true; workspaces: spaces; core: core }
    readonly property var stage: desktop.stages[0] ?? null
    function seq() {
        // The fixture login window's sequence, found through the slot's loader.
        return desktop.loginSequences()[0] ?? null;
    }
    property int step: 0
    property var mondayDock: null
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: {
            switch (harness.step++) {
            case 0:
                harness.say("decisions", [desktop.arrivalFor(false), desktop.arrivalFor(true) === Quickshell.screens[0]]);
                Motion.reduced = true; harness.say("reduced", desktop.arrivalFor(true)); Motion.reduced = false;
                Design.form = "fluid"; harness.say("fluid", desktop.arrivalFor(true)); Design.form = "angular";
                break;
            case 1:
                desktop.arrival = Quickshell.screens[0];
                break;
            case 2: {
                const s = harness.seq();
                s.stop(); s.now = new Date(2030, 8, 18, 7, 24);  // a Wednesday, as the study
                s.elapsed = 900;
                harness.say("playing", [!!s, harness.stage.clock.visible]);
                break;
            }
            case 3: {
                const s = harness.seq();
                s.elapsed = 1449;  // the tab has docked; it goes at 1500
                harness.stage.clock.now = s.now;
                break;
            }
            case 4: {
                const s = harness.seq();
                const tab = harness.find(s, "loginTab");
                const today = harness.find(harness.stage.clock, "todayDate").parent;
                const a = tab.mapToItem(harness.stage, 0, 0), b = today.mapToItem(harness.stage, 0, 0);
                harness.say("docked", [Math.round(a.x - b.x), Math.round(a.y - b.y + 0), Math.round(tab.width * s.boardScale - today.width * s.boardScale)]);
                s.now = new Date(2030, 8, 16, 7, 24);  // a Monday
                harness.stage.clock.now = s.now;
                break;
            }
            case 5: {
                const s = harness.seq();
                const tab = harness.find(s, "loginTab");
                const today = harness.find(harness.stage.clock, "todayDate").parent;
                const a = tab.mapToItem(harness.stage, 0, 0), b = today.mapToItem(harness.stage, 0, 0);
                harness.say("dockedMonday", [Math.round(a.x - b.x), Math.round(a.y - b.y)]);
                s.elapsed = 1500;
                break;
            }
            case 6: break;
            case 7:
                harness.say("landed", [desktop.arrival, harness.stage.clock.visible, desktop.loginSequences().length]);
                desktop.arrival = Quickshell.screens[0];  // again, to skip with a key
                break;
            case 8:
                harness.seq().skip();
                break;
            case 9: break;
            case 10:
                harness.say("skipped", [desktop.arrival, harness.stage.clock.visible]);
                spaces.workspaces = [{ id: "1", monitor: harness.mon, active: true, windowCount: 1 }];
                desktop.arrival = Quickshell.screens[0];
                break;
            case 11:
                harness.say("occupiedPlays", [!!harness.seq(), desktop.stages.length]);
                harness.seq().skip();
                break;
            case 12: break;
            case 13:
                harness.say("occupiedLanded", [desktop.arrival, desktop.stages.length]);
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
    return output, {k: v for k, v in (json.loads(line.split("LOGIN ", 1)[1]) for line in output.splitlines() if "LOGIN [" in line)}


class Words(unittest.TestCase):
    def test_the_login_says_impression_from_lines_json(self):
        study = json.loads((ROOT / "tools/boot-voice-study/lines.json").read_text())
        native = json.loads(re.search(r"var lines = (\[.*\]);", (ROOT / "view/widgets/LoginWords.js").read_text()).group(1))
        self.assertEqual(native, [study[k] for k in ("face", "register", "impression", "day")])

    def test_the_timing_is_the_approved_motion(self):
        self.assertEqual(
            (ROOT / "view/widgets/FoldMotion.qml").read_text().split("\n", 2)[2],
            (ROOT / "tools/login-clock-study/FoldMotion.qml").read_text().split("\n", 1)[1])

    def test_session_start_leaves_the_one_time_marker(self):
        text = (ROOT / "tools/session-start").read_text()
        self.assertLess(text.index('"$LOG_DIR/arrival"'), text.index('"$ROOT/zaetherion" start'))


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class LoginRun(unittest.TestCase):
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

    def test_only_an_angular_login_with_motion_plays(self):
        self.assertEqual(self.heard("decisions"), [None, True])
        self.assertIsNone(self.heard("reduced"))
        self.assertIsNone(self.heard("fluid"))

    def test_the_clock_waits_and_the_tab_docks_on_today(self):
        self.assertEqual(self.heard("playing"), [True, False])
        dx, dy, dw = self.heard("docked")
        self.assertLessEqual(abs(dx), 2)
        self.assertLessEqual(abs(dy), 6)  # the tab's last 3 px of contact bounce, at most
        self.assertLessEqual(abs(dw), 2)
        mx, my = self.heard("dockedMonday")
        self.assertLessEqual(abs(mx), 2)
        self.assertLessEqual(abs(my), 6)

    def test_landing_shows_the_clock_and_a_key_lands_it_at_once(self):
        self.assertEqual(self.heard("landed"), [None, True, 0])
        self.assertEqual(self.heard("skipped"), [None, True])

    def test_an_occupied_workspace_plays_without_a_clock(self):
        self.assertEqual(self.heard("occupiedPlays"), [True, 0])
        self.assertEqual(self.heard("occupiedLanded"), [None, 0])


if __name__ == "__main__":
    unittest.main()


MARKER_HARNESS = '''import QtQuick
import Quickshell
import qs.view.widgets
Scope {
    QtObject { id: spaces; property string focusedScreen: ""; property var workspaces: [] }
    DesktopWidgets { id: desktop; workspaces: spaces; wanted: true }
    Timer { interval: 600; running: true; onTriggered: {
        console.log("MARKER " + JSON.stringify([desktop.arrival !== null, desktop.arrivalChecked]));
        Qt.quit();
    } }
}
'''


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class Marker(unittest.TestCase):
    def run_with(self, content):
        from smoke import prepare
        with tempfile.TemporaryDirectory() as tmp:
            env, _, _ = prepare(Path(tmp), MARKER_HARNESS)
            runtime = Path(tmp) / "runtime"
            (runtime / "zaetherion").mkdir(parents=True)
            marker = runtime / "zaetherion/arrival"
            if content is not None:
                marker.write_text(content)
            env["XDG_RUNTIME_DIR"] = str(runtime)
            run = subprocess.run(["qs", "-n", "--no-color", "-p", str(Path(tmp) / "bundle/Harness.qml")], env=env,
                                 capture_output=True, text=True, timeout=60)
            out = run.stdout + run.stderr
            line = next((l for l in out.splitlines() if "MARKER [" in l), None)
            self.assertIsNotNone(line, out[-2000:])
            return json.loads(line.split("MARKER ", 1)[1]), (marker.read_text() if marker.exists() else None)

    def test_the_first_view_after_login_plays_and_marks_it_played(self):
        said, left = self.run_with("login\n")
        self.assertEqual(said, [True, True])
        self.assertEqual(left, "played\n")

    def test_a_restarted_view_finds_it_played_and_does_not(self):
        self.assertEqual(self.run_with("played\n"), ([False, True], "played\n"))

    def test_no_marker_no_login_and_the_clock_is_not_held(self):
        self.assertEqual(self.run_with(None), ([False, True], None))
