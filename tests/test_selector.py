"""The frozen-screen selector (Z48, Z221): its geometry under Node, and the Eclipse stage driven offscreen."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
GEOMETRY = ROOT / "view/selector/SelectionGeometry.js"
sys.path.insert(0, str(ROOT / "tools"))


def geometry(expression: str):
    body = "\n".join(line for line in GEOMETRY.read_text().splitlines() if not line.startswith(".pragma"))
    script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
    return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)


def rect(x, y, w, h):
    return {"x": x, "y": y, "width": w, "height": h}


SCREEN = rect(0, 0, 1080, 608)


@unittest.skipUnless(shutil.which("node"), "needs Node")
class GeometryTests(unittest.TestCase):
    def test_a_drag_spans_either_way_and_stays_on_the_screen(self):
        self.assertEqual(geometry(f"span(544, 400, 100, 100, {json.dumps(SCREEN)})"), rect(100, 100, 444, 300))
        self.assertEqual(geometry(f"span(-20, 500, 50, 700, {json.dumps(SCREEN)})"), rect(0, 500, 50, 108))

    def test_a_small_wobble_is_a_click(self):
        self.assertFalse(geometry("isDrag(10, 10, 13, 12)"))
        self.assertTrue(geometry("isDrag(10, 10, 14, 10)"))

    def test_the_size_reads_in_source_pixels(self):
        self.assertEqual(geometry(f"sizeText({json.dumps(rect(0, 0, 444, 300))}, 1.5)"), "666 × 450 px")

    def test_the_label_moves_below_at_the_top_edge_and_goes_when_neither_side_has_room(self):
        self.assertEqual(geometry(f"labelSide({json.dumps(rect(100, 178, 50, 50))}, {json.dumps(SCREEN)}, 26, 8)"), "above")
        self.assertEqual(geometry(f"labelSide({json.dumps(rect(100, 10, 50, 50))}, {json.dumps(SCREEN)}, 26, 8)"), "below")
        self.assertEqual(geometry(f"labelSide({json.dumps(rect(100, 0, 50, 608))}, {json.dumps(SCREEN)}, 26, 8)"), "none")

    def test_the_label_stays_on_the_screen(self):
        self.assertEqual(geometry(f"labelX({json.dumps(rect(1070, 100, 10, 10))}, {json.dumps(SCREEN)}, 154, 4)"), 926)
        self.assertEqual(geometry(f"labelX({json.dumps(rect(2, 100, 10, 10))}, {json.dumps(SCREEN)}, 154, 4)"), 0)

    def test_the_smallest_window_under_the_pointer_wins(self):
        boxes = [rect(0, 0, 800, 600), rect(100, 100, 200, 100)]
        self.assertEqual(geometry(f"boxAt({json.dumps(boxes)}, 150, 150)"), 1)
        self.assertEqual(geometry(f"boxAt({json.dumps(boxes)}, 500, 500)"), 0)
        self.assertEqual(geometry(f"boxAt({json.dumps(boxes)}, 900, 500)"), -1)

    def test_windows_move_onto_their_screen_and_are_clipped_to_it(self):
        screen = rect(1920, 0, 1080, 608)
        boxes = [rect(1800, 50, 300, 100), rect(100, 100, 50, 50), rect(2000, 500, 50, 50)]
        self.assertEqual(geometry(f"boxesOn({json.dumps(boxes)}, {json.dumps(screen)})"),
                         [rect(0, 50, 180, 100), rect(80, 500, 50, 50)])

    def test_the_answer_is_slurps_format_in_layout_coordinates(self):
        self.assertEqual(geometry(f"answer({json.dumps(rect(100, 100, 444, 300))}, {json.dumps(rect(1920, 0, 1080, 608))})"),
                         "2020,100 444x300")

    def test_each_screen_shows_its_part_of_the_grab(self):
        # The grab starts at the layout's top-left (-1080, 0) and renders at the largest scale (2).
        self.assertEqual(geometry(f"sourceRect({json.dumps(rect(0, 0, 1080, 608))}, {{x: -1080, y: 0}}, 2)"),
                         rect(2160, 0, 2160, 1216))


HARNESS = '''import QtQuick
import Quickshell
import qs.view.selector
Scope {
    id: harness
    property var log: []
    function say(name, value) { console.log("SEL " + JSON.stringify([name, value])); }
    FloatingWindow {
        implicitWidth: 1080; implicitHeight: 608; visible: true
        SelectorStage {
            id: stage
            anchors.fill: parent
            frozen: "FROZEN"
            origin: ({ x: 840, y: 0 }) // the grab starts at the left screen, so this one shows its right half
            screenRect: ({ x: 1920, y: 0, width: 1080, height: 608 })
            onPicked: answer => harness.say("picked", answer)
            onCancelled: harness.say("cancelled", true)
        }
    }
    Timer {
        interval: 300; running: true
        onTriggered: {
            const frame = stage.frame;
            const footer = stage.footer;
            harness.say("idle", [stage.prompt, frame.hasCrop]);
            stage.press(544, 400, Qt.LeftButton);
            harness.say("pressed", stage.prompt);
            stage.move(100, 100);
            harness.say("dragged", [stage.crop, frame.side, frame.marked, footer.visible]);
            stage.grabToImage(result => {
                result.saveToFile("SHOT");
                stage.release(100, 100, Qt.LeftButton);
                stage.press(10, 10, Qt.LeftButton);
                stage.move(12, 11);
                stage.release(12, 11, Qt.LeftButton);
                harness.say("click", stage.crop);
                stage.press(100, 10, Qt.LeftButton);
                stage.move(300, 60);
                harness.say("top edge", frame.side);
                stage.move(400, 590);
                harness.say("reaches footer", footer.visible);
                stage.move(0, 0);
                stage.press(0, 0, Qt.LeftButton);
                stage.move(1080, 608);
                harness.say("fills", [frame.hasCrop, frame.marked, frame.side]);
                stage.press(5, 5, Qt.RightButton);
                stage.mode = "window";
                stage.crop = null;
                stage.windows = [{ x: 1920, y: 0, width: 800, height: 600 }, { x: 2020, y: 100, width: 200, height: 100 }];
                harness.say("window idle", stage.prompt);
                stage.move(150, 150);
                harness.say("window hover", [stage.crop, stage.prompt]);
                stage.release(150, 150, Qt.LeftButton);
                stage.release(700, 500, Qt.LeftButton);
                harness.say("done", true);
                Qt.quit();
            });
        }
    }
}
'''


@unittest.skipUnless(shutil.which("qs") and shutil.which("magick"), "needs Quickshell and ImageMagick")
class StageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from smoke import prepare
        cls.temp = tempfile.TemporaryDirectory()
        base = Path(cls.temp.name)
        frozen, cls.shot = base / "frozen.png", base / "shot.png"
        # A frozen grab of two screens side by side; this stage is the right one, which is pure white.
        subprocess.run(["magick", "-size", "1080x608", "xc:#202020", "-size", "1080x608", "xc:#ffffff", "+append", str(frozen)],
                       check=True)
        env, _, _ = prepare(base, HARNESS.replace("FROZEN", str(frozen)).replace("SHOT", str(cls.shot)))
        harness = base / "bundle/Harness.qml"
        run = subprocess.run(["qs", "-n", "--no-color", "-p", str(harness)], env=env, capture_output=True, text=True, timeout=60)
        cls.output = run.stdout + run.stderr
        cls.said = [json.loads(line.split("SEL ", 1)[1]) for line in cls.output.splitlines() if "SEL [" in line]

    @classmethod
    def tearDownClass(cls):
        if os.environ.get("ZAE_SELECTOR_SHOT"):
            shutil.copy(cls.shot, os.environ["ZAE_SELECTOR_SHOT"])
        cls.temp.cleanup()

    def heard(self, name):
        for said, value in self.said:
            if said == name:
                return value
        self.fail(f"the harness never said {name!r}:\n{self.output[-3000:]}")

    def test_the_run_finished_without_qml_errors(self):
        self.assertTrue(self.heard("done"))
        self.assertNotIn("ReferenceError", self.output)
        self.assertNotIn("TypeError", self.output)

    def test_the_prompt_follows_the_drag(self):
        self.assertEqual(self.heard("idle"), ["Drag to select", False])
        self.assertEqual(self.heard("pressed"), "Release to select")

    def test_a_drag_marks_the_crop_and_release_answers_in_layout_coordinates(self):
        self.assertEqual(self.heard("dragged"), [rect(100, 100, 444, 300), "above", True, True])
        picks = [value for said, value in self.said if said == "picked"]
        self.assertEqual(picks[0], "2020,100 444x300")

    def test_a_click_is_not_a_crop(self):
        self.assertIsNone(self.heard("click"))

    def test_the_label_moves_below_at_the_top_edge(self):
        self.assertEqual(self.heard("top edge"), "below")

    def test_the_footer_steps_aside_for_the_crop(self):
        self.assertFalse(self.heard("reaches footer"))

    def test_a_full_screen_crop_shows_no_frame(self):
        self.assertEqual(self.heard("fills"), [True, False, "none"])

    def test_right_button_cancels(self):
        self.assertTrue(self.heard("cancelled"))

    def test_window_mode_lights_the_smallest_window_and_a_click_takes_it(self):
        self.assertEqual(self.heard("window idle"), "Point at a window")
        self.assertEqual(self.heard("window hover"), [rect(100, 100, 200, 100), "Click to select"])
        picks = [value for said, value in self.said if said == "picked"]
        self.assertEqual(picks[1:], ["2020,100 200x100", "1920,0 800x600"])

    def test_the_crop_keeps_its_pixels_and_the_rest_is_shaded(self):
        def pixel(x, y):
            out = subprocess.run(["magick", str(self.shot), "-format", f"%[hex:p{{{x},{y}}}]", "info:"],
                                 capture_output=True, text=True, check=True).stdout.strip()
            return tuple(int(out[i:i + 2], 16) for i in (0, 2, 4))
        self.assertEqual(pixel(300, 250), (255, 255, 255))  # inside: the frozen white, untouched
        shaded = pixel(700, 250)  # outside: white under 79 % of #090c10
        self.assertTrue(all(abs(c - e) <= 3 for c, e in zip(shaded, (61, 63, 66))), shaded)
        self.assertEqual(pixel(99, 300), (0xf7, 0xf7, 0xed))  # the pale 1 px edge, beside the corner marks
        self.assertEqual(pixel(98, 98), (0xd6, 0xff, 0x74))  # a lime corner


if __name__ == "__main__":
    unittest.main()
