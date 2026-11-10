"""view/rooms/Survey.js: the surveyor's ground, drafting and field book (Overdrive, docs/OVERDRIVE.md §16).

Run under Node with the QML `.pragma` line stripped; nothing in the module reads a clock or Qt."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Survey.js"
W, H = 44, 30
BOUNDS = {"x": 0, "y": 0, "width": 800, "height": 600}


def overlaps(a, b):
    return a["x"] < b["x"] + b["width"] and a["x"] + a["width"] > b["x"] and a["y"] < b["y"] + b["height"] and a["y"] + a["height"] > b["y"]


@unittest.skipUnless(shutil.which("node"), "needs Node")
class SurveyTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def ledges(self, edges, keep, bounds=BOUNDS, minimum=24):
        return self.js(f"ledges({json.dumps(edges)}, {json.dumps(keep)}, {W}, {H}, {json.dumps(bounds)}, {minimum})")

    # The ground

    def test_a_clear_edge_is_ground_with_both_feet_on_it(self):
        got = self.ledges([{"x1": 100, "y1": 300, "x2": 400, "y2": 300}], [])
        self.assertEqual(len(got), 1)
        self.assertAlmostEqual(got[0]["x1"], 100 + W * 0.3)
        self.assertAlmostEqual(got[0]["x2"], 400 - W * 0.3)
        self.assertEqual(got[0]["y1"], 300)

    def test_a_control_above_the_edge_cuts_the_ground_so_the_body_never_covers_it(self):
        button = {"x": 200, "y": 270, "width": 60, "height": 28}
        got = self.ledges([{"x1": 100, "y1": 300, "x2": 500, "y2": 300}], [button])
        self.assertEqual(len(got), 2)
        for seg in got:
            for c in (seg["x1"], seg["x2"]):
                body = {"x": c - W / 2, "y": 300 - H, "width": W, "height": H}
                self.assertFalse(overlaps(body, button), (seg, c))

    def test_content_under_the_edge_is_not_in_the_way(self):
        text_on_the_plane = {"x": 120, "y": 304, "width": 200, "height": 14}
        got = self.ledges([{"x1": 100, "y1": 300, "x2": 400, "y2": 300}], [text_on_the_plane])
        self.assertEqual(len(got), 1)

    def test_walls_short_edges_and_edges_outside_the_window_are_not_ground(self):
        self.assertEqual(self.ledges([{"x1": 100, "y1": 100, "x2": 120, "y2": 300}], []), [])
        self.assertEqual(self.ledges([{"x1": 100, "y1": 300, "x2": 130, "y2": 300}], []), [])
        self.assertEqual(self.ledges([{"x1": 100, "y1": 10, "x2": 400, "y2": 10}], []), [])   # no head room
        self.assertEqual(self.ledges([{"x1": 100, "y1": 700, "x2": 400, "y2": 700}], []), [])   # below the window

    def test_ground_is_clipped_to_the_window(self):
        got = self.ledges([{"x1": -300, "y1": 300, "x2": 300, "y2": 300}], [])
        self.assertAlmostEqual(got[0]["x1"], W / 2)

    def test_a_slanted_edge_keeps_its_slope(self):
        got = self.ledges([{"x1": 400, "y1": 320, "x2": 100, "y2": 300}], [])
        seg = got[0]
        self.assertLess(seg["x1"], seg["x2"])
        self.assertAlmostEqual(self.js(f"yAt({json.dumps(seg)}, 250)"), 310, places=6)

    def test_nearest_and_hops(self):
        segs = [{"x1": 100, "x2": 300, "y1": 300, "y2": 300}, {"x1": 380, "x2": 600, "y1": 250, "y2": 250},
                {"x1": 0, "x2": 90, "y1": 300, "y2": 300}, {"x1": 100, "x2": 300, "y1": 100, "y2": 100}]
        n = self.js(f"nearest({json.dumps(segs)}, 320, 290)")
        self.assertEqual((n["seg"], n["x"], n["y"]), (0, 300, 300))
        floor = [dict(s, edge=i) for i, s in enumerate(segs)]
        self.assertEqual(self.js(f"nearest({json.dumps(floor)}, 320, 290, 0)")["seg"], 1)
        options = self.js(f"hops({json.dumps(segs)}, 0, 300, 300, 1, {{across: 220, up: 150, down: 240}})")
        self.assertEqual(options[0]["seg"], 1)            # ahead first
        self.assertNotIn(3, [o["seg"] for o in options])  # 200 px up is out of reach
        self.assertIn(2, [o["seg"] for o in options])     # behind, but within reach

    def test_a_hop_clears_the_higher_end(self):
        top = min(self.js(f"arc(0, 300, 200, 220, {t / 10}).y") for t in range(11))
        self.assertLess(top, 220 - 17)
        self.assertEqual(self.js("arc(0, 300, 200, 220, 1)"), {"x": 200, "y": 220})

    # Drafting

    def test_dimension_lines_sit_outside_the_control_on_the_side_facing_the_eye(self):
        rect = {"x": 200, "y": 100, "width": 80, "height": 30}
        d = self.js(f"dimension({json.dumps(rect)}, {{x: 150, y: 300}}, {json.dumps(BOUNDS)})")
        self.assertGreater(d["w"]["y"], 130)               # below, towards the eye
        self.assertLess(d["h"]["x"], 200)                  # left, towards the eye
        self.assertEqual((d["w"]["x1"], d["w"]["x2"]), (200, 280))
        self.assertEqual((d["h"]["y1"], d["h"]["y2"]), (100, 130))
        self.assertTrue(d["label"]["below"])
        up = self.js(f"dimension({json.dumps(rect)}, {{x: 400, y: 20}}, {json.dumps(BOUNDS)})")
        self.assertLess(up["w"]["y"], 100)
        self.assertGreater(up["h"]["x"], 280)

    def test_dimension_flips_rather_than_leave_the_window(self):
        rect = {"x": 2, "y": 590, "width": 80, "height": 9}
        d = self.js(f"dimension({json.dumps(rect)}, {{x: 0, y: 700}}, {json.dumps(BOUNDS)})")
        self.assertLess(d["w"]["y"], 590)
        self.assertGreater(d["h"]["x"], 82)

    def test_closest_skips_what_it_measured_lately(self):
        rects = [{"x": 100, "y": 100, "width": 20, "height": 20}, {"x": 160, "y": 100, "width": 20, "height": 20}]
        self.assertEqual(self.js(f"closest({json.dumps(rects)}, 90, 110, 260, [])"), 0)
        self.assertEqual(self.js(f"closest({json.dumps(rects)}, 90, 110, 260, [0])"), 1)
        self.assertEqual(self.js(f"closest({json.dumps(rects)}, 900, 110, 260, [])"), -1)

    def test_the_doorway_is_measured_only_in_empty_space(self):
        keep = [{"x": 0, "y": 0, "width": 800, "height": 400}]
        door = self.js(f"freeRect({json.dumps(keep)}, {json.dumps(BOUNDS)}, 46, 72, 100, 100)")
        self.assertIsNotNone(door)
        self.assertFalse(overlaps(door, keep[0]))
        full = [{"x": 0, "y": 0, "width": 800, "height": 600}]
        self.assertIsNone(self.js(f"freeRect({json.dumps(full)}, {json.dumps(BOUNDS)}, 46, 72, 100, 100)"))

    def test_kinds_come_from_the_type_and_unknown_things_are_spots(self):
        self.assertEqual(self.js('["FButton_QMLTYPE_12(0x55d1)", "FToggle_QMLTYPE_3(0x1)", "SheetTab_QMLTYPE_246_QML_339(0x2)",'
                                 ' "QQuickSlider(0x3)", "AbstractButton_QMLTYPE_101_QML_257(0x4)", "Gizmo(0x2)", "nonsense"].map(kindOf)'),
                         ["BUTTON", "SWITCH", "TAB", "SLIDER", "BUTTON", "SPOT", "SPOT"])

    def test_the_figure_finds_a_clear_spot_beside_its_lines(self):
        rect = {"x": 200, "y": 100, "width": 80, "height": 30}
        eye = {"x": 150, "y": 300}
        d = self.js(f"dimension({json.dumps(rect)}, {json.dumps(eye)}, {json.dumps(BOUNDS)})")
        spot = self.js(f"labelSpot({json.dumps(d)}, [], 60, 12, {json.dumps(BOUNDS)}, {json.dumps(eye)})")
        self.assertEqual(spot, {"x": 210, "y": d["w"]["y"] + 3})
        text_under = {"x": 190, "y": d["w"]["y"], "width": 100, "height": 20}
        spot = self.js(f"labelSpot({json.dumps(d)}, {json.dumps([rect, text_under])}, 60, 12, {json.dumps(BOUNDS)}, {json.dumps(eye)})")
        label = {"x": spot["x"], "y": spot["y"], "width": 60, "height": 12}
        self.assertFalse(overlaps(label, text_under) or overlaps(label, rect), spot)

    # The field book

    def test_a_station_is_written_in_metres_and_a_new_day_starts_a_new_page(self):
        b = self.js('enter(fresh(7), {room: "tasks", kind: "BUTTON", w: 112, h: 38, wall: 984}, "2026-11-09")')
        self.assertEqual((b["stations"], b["total"], b["day"]), (1, 1, "2026-11-09"))
        self.assertEqual(b["readings"], [{"room": "tasks", "kind": "BUTTON", "w": 1.12, "h": 0.38, "unit": "M"}])
        self.assertEqual(b["walls"]["tasks"], {"first": 9.84, "last": 9.84, "changes": 0})
        b2 = self.js(f'enter({json.dumps(b)}, {{room: "tasks", kind: "", w: 0, h: 0, wall: 1440}}, "2026-11-10")')
        self.assertEqual((b2["stations"], b2["total"], b2["readings"]), (1, 2, []))
        self.assertEqual(b2["walls"]["tasks"], {"first": 9.84, "last": 14.4, "changes": 1})

    def test_the_book_keeps_no_labels_and_survives_junk(self):
        junk = {"seed": "x", "readings": [{"room": "tasks", "kind": "BUTTON", "w": 1, "h": 1, "label": "my secret task"}, 5],
                "walls": [], "errors": [{"station": 1}], "scale": 400, "widths": [1, -2, "3"]}
        b = self.js(f"clean({json.dumps(junk)}, 9)")
        self.assertEqual(b["seed"], 9)
        self.assertEqual(b["scale"], 100)
        self.assertEqual(b["readings"], [{"room": "tasks", "kind": "BUTTON", "w": 1, "h": 1, "unit": "M"}])
        self.assertEqual((b["walls"], b["errors"], b["widths"]), ({}, [], [1]))
        self.assertNotIn("secret", json.dumps(b))
        self.assertEqual(self.js("clean(null, 3)")["total"], 0)

    def test_survey_errors_are_seeded_rare_daily_and_lie_one_doorway_from_the_locus(self):
        result = self.js("""(() => {
            let b = fresh(12345), errors = 0, days = {};
            for (let i = 0; i < 4000; i++) {
                const day = "2026-11-" + String(1 + Math.floor(i / 160)).padStart(2, "0");
                if (isError(b, day)) { b = error(b, day); errors++; days[day] = (days[day] || 0) + 1; }
                b = enter(b, {room: "home", kind: "", w: 0, h: 0, wall: 0}, day);
            }
            const c = locus(12345);
            return { errors: errors, most: Math.max(...Object.values(days)), first: b.errors[0].station,
                     radii: b.errors.map(e => Math.hypot(e.e - c.e, e.n - c.n)), again: isError(fresh(12345), "d") };
        })()""")
        self.assertGreater(result["errors"], 3)
        self.assertLess(result["errors"], 26)
        self.assertEqual(result["most"], 1)
        self.assertGreaterEqual(result["first"], 24)
        for r in result["radii"]:
            self.assertAlmostEqual(r, 1, delta=0.02)
        self.assertEqual(self.js("[locus(5), locus(5)]")[0], self.js("locus(5)"))

    def test_a_scale_correction_changes_its_readings_until_the_next_day(self):
        result = self.js("""(() => {
            let b = fresh(1), at = -1;
            for (let i = 0; i < 3000 && at < 0; i++) {
                b = calibrate(b, "2026-11-09");
                if (b.scale !== 100) at = i;
                b = enter(b, {room: "home", kind: "", w: 0, h: 0, wall: 0}, "2026-11-09");
            }
            const corrected = reading(b, 112, 38);
            const nextDay = calibrate(b, "2026-11-10");
            return { at: at, scale: b.scale, corrected: corrected, after: nextDay.scale, lines: lines(b, null).map(l => l.text) };
        })()""")
        self.assertGreaterEqual(result["at"], 0)
        self.assertIn(result["scale"], (99, 101))
        self.assertNotEqual(result["corrected"], "1.12 × 0.38 M")
        self.assertEqual(result["after"], 100)
        self.assertTrue(any(line.startswith("SCALE CORRECTED") for line in result["lines"]))

    def test_its_own_unit_after_enough_stations(self):
        result = self.js("""(() => {
            let b = fresh(2);
            for (let i = 0; i < 130; i++) b = enter(b, {room: "tasks", kind: "BUTTON", w: 100 + (i % 5) * 10, h: 40, wall: 0}, "2026-11-09");
            return { unit: ownUnit(b), reading: reading(b, 240, 60), early: ownUnit(fresh(2)) };
        })()""")
        self.assertEqual(result["early"], 0)
        self.assertEqual(result["unit"], 1.2)
        self.assertEqual(result["reading"], "2.00 × 0.50 SL")

    def test_the_archive_lines(self):
        b = self.js("""(() => {
            let b = fresh(3);
            b = enter(b, {room: "notifications", kind: "BUTTON", w: 112, h: 38, wall: 900}, "2026-11-09");
            b = enter(b, {room: "notifications", kind: "BUTTON", w: 120, h: 38, wall: 1400}, "2026-11-09");
            b = error(b, "2026-11-09");
            return lines(b, null);
        })()""")
        texts = [line["text"] for line in b]
        self.assertEqual(texts[0], "STATIONS TODAY 2 · SINCE THE SURVEY BEGAN 2")
        self.assertIn("INBOX / BUTTON   1.20 × 0.38 M", texts)       # the latest reading of each kind, by room name
        self.assertIn("NORTH WALL OF INBOX   9.00 M ON ARRIVAL · 14.00 M NOW", texts)
        self.assertEqual(b[-1]["tone"], "error")
        self.assertTrue(b[-1]["text"].endswith("NO ROOM AT THIS COORDINATE"))
        self.assertEqual(self.js("lines(fresh(1), null)"), [])

    # Creature parallax

    def test_found_nearer_the_neglected_room_once_the_journey_is_long_enough(self):
        rooms = ["home", "media", "tasks", "timers"]
        journey = {"visits": {"home": 20, "tasks": 15}, "seconds": {"home": 900, "media": 40, "tasks": 600, "timers": 300}}
        self.assertEqual(self.js(f"neglected({json.dumps(journey)}, {json.dumps(rooms)})"), "media")
        self.assertEqual(self.js(f"stationX({json.dumps(rooms)}, 'media', 800)"), 300)
        self.assertEqual(self.js(f"neglected({{visits: {{home: 3}}, seconds: {{}}}}, {json.dumps(rooms)})"), "")
        self.assertEqual(self.js(f"neglected(null, {json.dumps(rooms)})"), "")


if __name__ == "__main__":
    unittest.main()
