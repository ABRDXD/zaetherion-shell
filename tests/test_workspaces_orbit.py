"""Workspaces as an orbit (Z209): the layout maths under Node, and the room offscreen on the fixture's desks."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import cuetest  # noqa: E402

CHECKS = ("front.is.current", "summary.reads", "silent.still", "look.keeps.ring", "pick.selects", "move.survives.look",
          "move.carries", "go.switches", "empty.says.so", "remembered.shell", "turns.short.way", "overdrive.drifts",
          "release.still")


def run(expr):
    body = "\n".join(l for l in (ROOT / "view/rooms/WorkspacesOrbit.js").read_text().splitlines() if not l.startswith(".pragma"))
    return json.loads(subprocess.run(["node", "-e", body + f"\nprocess.stdout.write(JSON.stringify({expr}));"],
                                     capture_output=True, text=True, check=True).stdout)


@unittest.skipUnless(shutil.which("node"), "needs Node")
class OrbitLayout(unittest.TestCase):
    def test_turns_the_short_way(self):
        self.assertEqual(run("[shortest(0, 1, 8), shortest(0, 7, 8), shortest(6, 1, 8), shortest(3, 3, 8), shortest(-1, 2, 8)]"),
                         [1, -1, 3, 0, 3])

    def test_inspected_desk_is_at_the_front_and_nearest(self):
        front, back = run("[place(2, 2, 8), place(6, 2, 8)]")
        self.assertAlmostEqual(front["depth"], 1)
        self.assertAlmostEqual(back["depth"], 0)
        self.assertGreater(front["sin"], back["sin"])

    def test_front_is_biggest_and_occupied_desks_bigger(self):
        front, near_full, near_empty, far_full = run("[size(1, true, true, 600), size(1, true, false, 600), size(1, false, false, 600), size(0, true, false, 600)]")
        self.assertGreater(front, near_full)
        self.assertGreater(near_full, near_empty)
        self.assertGreater(near_full, far_full)

    def test_more_windows_burn_hotter(self):
        self.assertEqual(run("[warmth(0, 7), warmth(1, 7), warmth(2, 7), warmth(9, 7)]"), [-1, 5, 4, 0])

    def test_summary_and_selection(self):
        self.assertEqual(run('summary([])'), "nothing open")
        self.assertEqual(run('summary([{appId:"kitty"},{appId:"firefox"},{appId:"kitty"}])'), "3 windows · kitty, firefox")
        self.assertEqual(run('summary([{appId:""}])'), "1 window · window")
        self.assertEqual(run('[selected([{focused:false},{focused:true}]), selected([{focused:false}]), selected([])]'), [1, 0, 0])


class OrbitRoom(unittest.TestCase):
    def test_room(self):
        output = cuetest.run("WorkspacesTest.qml", timeout=120)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([l for l in output.splitlines() if "CUE_FAIL" in l], [])
        for name in CHECKS:
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
