"""Devices' signal map (Z211): the layout maths under Node, and the map offscreen on the fixture."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import cuetest  # noqa: E402

CHECKS = ("levels.ringed", "star.each.other", "star.joins", "strength.read", "silent.still", "strength.unknown",
          "overdrive.pings", "release.still")


def run(expr):
    body = "\n".join(l for l in (ROOT / "view/rooms/DevicesSkyLayout.js").read_text().splitlines() if not l.startswith(".pragma"))
    return json.loads(subprocess.run(["node", "-e", body + f"\nprocess.stdout.write(JSON.stringify({expr}));"],
                                     capture_output=True, text=True, check=True).stdout)


@unittest.skipUnless(shutil.which("node"), "needs Node")
class SkyLayout(unittest.TestCase):
    def test_strength_either_scale(self):
        self.assertEqual(run("[unit(0.5), unit(50), unit(-3), unit(250), unit(undefined)]"), [0.5, 0.5, 0, 1, 0])

    def test_stronger_is_nearer(self):
        weak, strong = run("[satellite(0.1), satellite(0.9)]")
        self.assertLess(strong, weak)

    def test_arc_follows_level(self):
        self.assertEqual(run("[arc(0), arc(0.5), arc(1), arc(2)]"),
                         [{"start": -90, "sweep": 0}, {"start": -90, "sweep": 180}, {"start": -90, "sweep": 360}, {"start": -90, "sweep": 360}])
        top = run("arcEnd(0)")
        self.assertAlmostEqual(top["x"], 0, places=6)
        self.assertAlmostEqual(top["y"], -1, places=6)

    def test_rings_nest_outermost_first(self):
        r = run("[ring(0), ring(1), ring(2)]")
        self.assertEqual(r, sorted(r, reverse=True))

    def test_stars_skip_the_joined_strongest_first_and_keep_their_place(self):
        nets = '[{id:"a",ssid:"A",strength:0.2},{id:"b",ssid:"B",strength:80},{id:"c",ssid:"C",strength:0.9,connected:true}]'
        s = run(f"stars({nets})")
        self.assertEqual([x["id"] for x in s], ["b", "a"])
        self.assertLess(s[0]["r"], s[1]["r"])
        self.assertEqual(run('angleFor("A")'), run('angleFor("A")'))
        self.assertNotEqual(run('angleFor("A")'), run('angleFor("B")'))
        many = ",".join(f'{{id:"n{i}",ssid:"N{i}",strength:0.5}}' for i in range(9))
        self.assertEqual(len(run(f"stars([{many}])")), 6)

    def test_battery_light_and_percent(self):
        self.assertLess(run("lit(0.1)"), run("lit(0.9)"))
        self.assertEqual(run('[percent(0.56), percent(0.56, false), percent(3)]'), ["56", "—", "100"])


class SkyRoom(unittest.TestCase):
    def test_map(self):
        output = cuetest.run("DevicesSkyTest.qml", timeout=90)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([l for l in output.splitlines() if "CUE_FAIL" in l], [])
        for name in CHECKS:
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
