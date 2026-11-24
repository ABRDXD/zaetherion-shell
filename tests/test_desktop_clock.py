"""The desktop clock (Z46, Z85; Astra's Day index for Angular and Offcut for Fluid, owner's picks 23 Nov), offscreen:
built on an empty workspace at the pose the core keeps for that monitor, destroyed when a window arrives, rebuilt
when it leaves; the words follow the date; both forms render. Also the pure word and grid helpers under Node."""
import json
import os
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
    function say(name, value) { console.log("CLOCK " + JSON.stringify([name, value])); }
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const k of Array.from(item.children ?? [])) { const hit = find(k, name); if (hit) return hit; }
        return null;
    }
    QtObject {
        id: spaces
        property var workspaces: [{ id: "1", monitor: Quickshell.screens[0]?.name ?? "", active: true, windowCount: 0 }]
    }
    QtObject {
        id: core
        property var widgetsData: ({ layout: "Default", layouts: ["Default"], columns: 12,
            monitors: ({ [Quickshell.screens[0]?.name ?? ""]: { clock: { column: 1, span: 6, y: 0.3, angle: 0 } } }),
            defaults: { clock: { column: 2, span: 8, y: 0.42, angle: 0 } }, face: { spacing: "original", date: "full", hours: 24, ink: "original" } })
    }
    DesktopWidgets { id: desktop; fixture: true; workspaces: spaces; core: core }
    property int step: 0
    property string out: Quickshell.env("CLOCK_SHOTS") ?? ""
    Timer {
        id: tick; interval: 300; running: true; repeat: true
        onTriggered: {
            const stage = desktop.stages[0] ?? null;
            const words = stage ? [harness.find(stage.clock, "weekdayHead")?.text ?? harness.find(stage.clock, "weekday")?.text,
                                   harness.find(stage.clock, "todayDate")?.text, harness.find(stage.clock, "timeLabel")?.text] : null;
            if (stage) stage.clock.now = new Date(2030, 8, 18, 7, 24);
            switch (harness.step++) {
            case 0: break;
            case 1:
                harness.say("built", !!stage);
                harness.say("rect", stage ? [Math.round(stage.clock.x), Math.round(stage.clock.y), Math.round(stage.clock.width), Math.round(stage.clock.height), stage.width, stage.height] : null);
                harness.say("angularWords", words);
                if (harness.out) stage.clock.grabToImage(r => r.saveToFile(harness.out + "/angular.png"));
                spaces.workspaces = [{ id: "1", monitor: Quickshell.screens[0].name, active: true, windowCount: 1 }];
                break;
            case 2:
                harness.say("occupied", desktop.stages.length);
                core.widgetsData = Object.assign({}, core.widgetsData, { monitors: ({ [Quickshell.screens[0].name]: { clock: { column: 0, span: 12, y: 0.5, angle: 15 } } }),
                                                                       face: { spacing: "wide", date: "short", hours: 12, ink: "tide" } });
                spaces.workspaces = [{ id: "1", monitor: Quickshell.screens[0].name, active: true, windowCount: 0 }];
                break;
            case 3: break;
            case 4:
                harness.say("rebuilt", stage ? [Math.round(stage.clock.x), Math.round(stage.clock.width), stage.clock.rotation] : null);
                harness.say("shortWords", words);
                Design.form = "fluid";
                break;
            case 5: break;
            case 6:
                harness.say("fluidWords", words);
                if (harness.out) stage.clock.grabToImage(r => r.saveToFile(harness.out + "/fluid.png"));
                break;
            case 7:
                harness.say("done", true);
                Qt.quit();
            }
        }
    }
}
'''


def run_harness(shots: str | None = None):
    from smoke import prepare
    with tempfile.TemporaryDirectory() as tmp:
        env, _, _ = prepare(Path(tmp), HARNESS)
        if shots:
            env["CLOCK_SHOTS"] = shots
        run = subprocess.run(["qs", "-n", "--no-color", "-p", str(Path(tmp) / "bundle/Harness.qml")], env=env,
                             capture_output=True, text=True, timeout=60)
    output = run.stdout + run.stderr
    return output, {k: v for k, v in (json.loads(line.split("CLOCK ", 1)[1]) for line in output.splitlines() if "CLOCK [" in line)}


def node(script: str):
    run = subprocess.run(["node", "-e", script], capture_output=True, text=True, timeout=30, cwd=ROOT)
    if run.returncode:
        raise AssertionError(run.stderr)
    return json.loads(run.stdout)


def library(name: str) -> str:
    """A `.pragma library` JS file as plain Node code."""
    return (ROOT / "view/widgets" / name).read_text().replace(".pragma library", "")


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Helpers(unittest.TestCase):
    def test_words(self):
        said = node(library("ClockWords.js") + '''
            const wed = new Date(2030, 8, 18, 7, 24), sun = new Date(2026, 10, 29, 23, 5), mon = new Date(2026, 10, 23, 0, 0);
            console.log(JSON.stringify([weekdayHead(wed), weekday(sun), week(wed), week(sun), week(mon).today,
                dateLabel(wed, false, false), dateLabel(wed, false, true), dateLabel(wed, true, false), dateLabel(wed, true, true),
                timeLabel(wed, 24), timeLabel(wed, 12), timeLabel(sun, 12), timeLabel(mon, 12), tracking("close"), ink("tide", true)]));''')
        self.assertEqual(said, ["WEDNES", "SUNDAY", {"days": [16, 17, 18, 19, 20, 21, 22], "today": 2},
                                {"days": [23, 24, 25, 26, 27, 28, 29], "today": 6}, 0,
                                "18 SEP 2030", "18 SEP", "18 September 2030", "18 Sep",
                                "– 07:24 –", "– 7:24 AM –", "– 11:05 PM –", "– 12:00 AM –", -8, "#174652"])

    def test_week_across_a_month_and_a_dst_change(self):
        said = node("process.env.TZ='Europe/London';" + library("ClockWords.js") + '''
            console.log(JSON.stringify([week(new Date(2026, 9, 25, 12)).days, week(new Date(2026, 2, 1, 12)).days]));''')
        self.assertEqual(said, [[19, 20, 21, 22, 23, 24, 25], [23, 24, 25, 26, 27, 28, 1]])

    def test_grid(self):
        said = node(library("DesktopGrid.js") + '''
            const p = { column: 2, span: 8, y: 0.42, angle: 0 };
            const r = rect(p, 1920, 1080), full = rect({ column: 0, span: 12, y: 0.99, angle: 0 }, 1920, 1080);
            console.log(JSON.stringify([[r.x, r.width].map(Math.round), Math.round(full.x + full.width), full.y + full.height <= 1080,
                moved(p, 300, -50, 1920, 1080), moved(p, 5000, 5000, 1920, 1080).column, resized(p, -2000, 1920, 3).span,
                resized(p, 2000, 1920, 3).span, turned(p, 200).angle, turned(p, -45.4).angle]));''')
        self.assertEqual(said[0], [347, 1227])
        self.assertEqual(said[1], 1920 - 36)  # twelve columns end at the right margin
        self.assertTrue(said[2])  # a pose near the bottom is kept on screen
        self.assertEqual(said[3]["column"], 4)
        self.assertAlmostEqual(said[3]["y"], 0.42 - 50 / 1080, places=3)
        self.assertEqual(said[4:], [4, 3, 10, -160, -45])


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class DesktopClockRun(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output, cls.said = run_harness(os.environ.get("CLOCK_SHOTS"))

    def heard(self, name):
        if name not in self.said:
            self.fail(f"the harness never said {name!r}:\n{self.output[-3000:]}")
        return self.said[name]

    def test_ran_clean(self):
        self.assertTrue(self.heard("done"))
        for problem in ("ReferenceError", "TypeError", "Cannot assign", "is not a type", "Unable to assign"):
            self.assertNotIn(problem, self.output)

    def test_built_at_the_monitors_saved_pose(self):
        self.assertTrue(self.heard("built"))
        x, y, w, h, sw, sh = self.heard("rect")
        gutter = 12 if sw < 920 else 16
        column = (sw - 72 - gutter * 11) / 12
        self.assertAlmostEqual(x, 36 + 1 * (column + gutter), delta=1)
        self.assertAlmostEqual(w, 6 * column + 5 * gutter, delta=1)
        self.assertAlmostEqual(y + h / 2, 0.3 * sh, delta=1)

    def test_words_follow_the_date_and_the_face(self):
        self.assertEqual(self.heard("angularWords"), ["WEDNES", "18 SEP 2030", "– 07:24 –"])
        self.assertEqual(self.heard("shortWords"), ["WEDNES", "18 SEP", "– 7:24 AM –"])
        self.assertEqual(self.heard("fluidWords"), ["WEDNESDAY", "18 Sep", "– 7:24 AM –"])

    def test_a_window_unloads_it_and_emptying_rebuilds_it_at_the_new_pose(self):
        self.assertEqual(self.heard("occupied"), 0)
        x, _, rotation = self.heard("rebuilt")
        self.assertEqual(x, 36)
        self.assertEqual(rotation, 15)


if __name__ == "__main__":
    unittest.main()
