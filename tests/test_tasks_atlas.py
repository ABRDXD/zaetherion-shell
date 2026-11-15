"""view/fluid/TasksAtlasLayout.js: where a task's star sits on the atlas."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def run(expr):
    body = "\n".join(l for l in (ROOT / "view/fluid/TasksAtlasLayout.js").read_text().splitlines() if not l.startswith(".pragma"))
    return json.loads(subprocess.run(["node", "-e", body + f"\nprocess.stdout.write(JSON.stringify({expr}));"],
                                     capture_output=True, text=True, check=True).stdout)


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Atlas(unittest.TestCase):
    def test_sooner_is_nearer_the_centre(self):
        r = run("[radiusFor(-3), radiusFor(0), radiusFor(2), radiusFor(30), radiusFor(400), radiusFor(null)]")
        self.assertEqual(r, sorted(r))
        self.assertEqual(r[0], 0.13)
        self.assertEqual(r[-1], 1.0)
        self.assertLess(r[4], r[5])

    def test_route_runs_open_tasks_by_due_then_done(self):
        p = run('place([{id:"c",days:null,done:false},{id:"a",days:5,done:false},{id:"d",days:-1,done:true},{id:"b",days:-2,done:false}], "home")')
        self.assertEqual([x["id"] for x in p], ["b", "a", "c", "d"])
        self.assertTrue(p[0]["late"])
        self.assertFalse(p[3]["late"])
        self.assertTrue(p[3]["done"])

    def test_each_list_has_its_own_shape_and_keeps_it(self):
        t = '[{id:"a",days:1,done:false}]'
        self.assertEqual(run(f'place({t}, "home")[0].a'), run(f'place({t}, "home")[0].a'))
        self.assertNotEqual(run(f'place({t}, "home")[0].a'), run(f'place({t}, "work")[0].a'))

    def test_chart_is_seen_at_an_angle(self):
        near, far = run("[project(1, Math.PI/2, 0, 0, 100), project(1, -Math.PI/2, 0, 0, 100)]")
        self.assertEqual((near["y"], far["y"]), (50, -50))
        self.assertGreater(run(f"magnitude(0.5, {near['depth']})"), run(f"magnitude(0.5, {far['depth']})"))

    def test_groups_read_soonest_first_and_skip_empty(self):
        g = run('groups([{id:"a",days:null,done:false},{id:"b",days:3,done:false},{id:"c",days:-1,done:false},{id:"d",days:0,done:true},{id:"e",days:30,done:false}])')
        self.assertEqual([(x["key"], [t["id"] for t in x["tasks"]]) for x in g],
                         [("late", ["c"]), ("week", ["b"]), ("later", ["e"]), ("someday", ["a"]), ("done", ["d"])])

    def test_late_is_the_brightest(self):
        u = run('[urgency({days:-2}), urgency({days:0}), urgency({days:20}), urgency({days:null}), urgency({days:-2,done:true})]')
        self.assertEqual(u[0], 1)
        self.assertGreater(u[1], u[2])
        self.assertGreater(u[2], u[3])
        self.assertEqual(u[3], u[4])

    def test_background_field_is_fixed(self):
        self.assertEqual(run("field(5, 7)"), run("field(5, 7)"))


if __name__ == "__main__":
    unittest.main()
