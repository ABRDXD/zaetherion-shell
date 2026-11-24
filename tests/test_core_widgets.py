"""core/widgets.py: the desktop clock's pose per monitor and layout preset, kept across a restart (Z46, Z85)."""
import json
import tempfile
import unittest
from pathlib import Path

import core_fakes  # noqa: F401  (puts the repository on sys.path)
from core.errors import OpError
from core.widgets import DEFAULT_POSE, FACE, Widgets


class WidgetsTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.dir = Path(temp.name)

    def test_defaults_until_placed(self):
        snap = Widgets(self.dir).snapshot()
        self.assertEqual(snap["layout"], "Default")
        self.assertEqual(snap["monitors"], {})
        self.assertEqual(snap["defaults"]["clock"], DEFAULT_POSE)
        self.assertEqual(snap["face"], FACE)
        self.assertFalse((self.dir / "widgets.json").exists())

    def test_a_pose_is_kept_per_monitor_and_survives_a_restart(self):
        w = Widgets(self.dir)
        published = []
        w.on_change = lambda: published.append(1)
        w.place("DP-1", "clock", 1, 6, 0.3, -12)
        w.place("DP-1", "clock", 1, 6, 0.3, -12)  # unchanged: no write, no event
        w.place("HDMI-A-1", "clock", 0, 12, 0.9, 180)
        self.assertEqual(len(published), 2)
        again = Widgets(self.dir)
        self.assertEqual(again.pose("DP-1"), {"column": 1, "span": 6, "y": 0.3, "angle": -12})
        self.assertEqual(again.pose("HDMI-A-1")["span"], 12)
        self.assertEqual(again.pose("eDP-1"), DEFAULT_POSE)

    def test_poses_outside_the_grid_are_refused(self):
        w = Widgets(self.dir)
        for column, span, y, angle in ((10, 3, 0.5, 0), (0, 2, 0.5, 0), (-1, 4, 0.5, 0), (0, 13, 0.5, 0),
                                       (0, 4, 1.5, 0), (0, 4, 0.5, 181), (0, 4.0, 0.5, 0), (True, 4, 0.5, 0),
                                       (0, 4, "0.5", 0), (0, 4, 0.5, None)):
            with self.assertRaises(OpError, msg=(column, span, y, angle)):
                w.place("DP-1", "clock", column, span, y, angle)
        for monitor in ("", "DP 1", "x" * 65, None, "a\n"):
            with self.assertRaises(OpError, msg=monitor):
                w.place(monitor, "clock", 0, 4, 0.5, 0)
        with self.assertRaises(OpError):
            w.place("DP-1", "notes", 0, 4, 0.5, 0)

    def test_a_new_layout_starts_as_a_copy_and_switching_keeps_each(self):
        w = Widgets(self.dir)
        w.place("DP-1", "clock", 1, 6, 0.3, 0)
        w.use_layout("Morning")
        self.assertEqual(w.pose("DP-1")["column"], 1)
        w.place("DP-1", "clock", 4, 8, 0.6, 10)
        w.use_layout("Default")
        self.assertEqual(w.pose("DP-1")["column"], 1)
        again = Widgets(self.dir)
        self.assertEqual(again.snapshot()["layouts"], ["Default", "Morning"])
        again.use_layout("Morning")
        self.assertEqual(again.pose("DP-1")["column"], 4)

    def test_resetting_the_face_keeps_every_pose(self):
        (self.dir / "widgets.json").write_text(json.dumps({"layout": "Default", "layouts": {"Default": {
            "DP-1": {"clock": {"column": 3, "span": 5, "y": 0.2, "angle": 30}}}}, "face": {"hours": 12, "ink": "tide"}}))
        w = Widgets(self.dir)
        self.assertEqual(w.snapshot()["face"]["hours"], 12)
        w.reset_face()
        again = Widgets(self.dir)
        self.assertEqual(again.snapshot()["face"], FACE)
        self.assertEqual(again.pose("DP-1"), {"column": 3, "span": 5, "y": 0.2, "angle": 30})

    def test_odd_files_load_what_is_sound(self):
        for text in ("[1]", "5", "{broken", json.dumps({"layout": "Gone", "layouts": {"Default": {
                "DP-1": {"clock": {"column": 11, "span": 4, "y": 0.5, "angle": 0}},  # past the grid: dropped
                "DP 2": {"clock": DEFAULT_POSE}, "HDMI-A-1": {"clock": DEFAULT_POSE, "dock": {}}}, "": {}, "B": []}})):
            (self.dir / "widgets.json").write_text(text)
            snap = Widgets(self.dir).snapshot()
            self.assertEqual(snap["layout"], "Default", text)
            self.assertNotIn("DP-1", snap["monitors"], text)
            self.assertNotIn("DP 2", snap["monitors"], text)
        self.assertEqual(snap["monitors"], {"HDMI-A-1": {"clock": DEFAULT_POSE}})


if __name__ == "__main__":
    unittest.main()
