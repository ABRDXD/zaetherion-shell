"""view/rooms/Spectro.js: the process spectrograph (atlas #74): axes, thickness, tracks, notches and ghosts."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Spectro.js"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class SpectroTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_axes(self):
        xs = self.js('[0.2, 1, 60, 3600, 604800, 1e9, null].map(ageX)')
        self.assertEqual((xs[0], xs[1], xs[4], xs[5], xs[6]), (0, 0, 1, 1, 0))
        self.assertTrue(xs[1] < xs[2] < xs[3] < xs[4])
        ys = self.js('[0, 0.1, 1, 100, 400, 800].map(cpuY)')
        self.assertEqual((ys[0], ys[1], ys[4], ys[5]), (0, 0, 1, 1))
        self.assertLess(ys[2], ys[3])
        self.assertEqual(self.js('[0, 16, 4096, 1e6].map(thick)'), [1, 1, 7, 7])

    def test_an_interruption_is_a_stop_and_a_restart(self):
        got = self.js('''(() => {
            let t = {};
            const run = (cpu, at) => { t = track(t, [{ id: "1:5", name: "make", cpu: cpu, rss: 50, age: 30 }], at); };
            run(0, 0); run(20, 1); run(0, 2); run(0, 3); run(15, 4); run(0, 5); run(30, 6);
            const two = t["1:5"].notches;
            run(30, 70);
            return [two, t["1:5"].notches];
        })()''')
        self.assertEqual(got, [[4, 6], []])

    def test_a_process_that_was_never_busy_has_no_notches(self):
        got = self.js('(() => { let t = {}; for (let s = 0; s < 5; s++) t = track(t, [{ id: "2:1", cpu: 0, rss: 4, age: 9e5 }], s); return t["2:1"].notches; })()')
        self.assertEqual(got, [])

    def test_an_ended_process_leaves_a_ghost_for_five_seconds(self):
        got = self.js('''(() => {
            let t = track({}, [{ id: "3:1", name: "cc1", cpu: 90, rss: 200, age: 2 }], 0);
            t = track(t, [], 1);
            const ghost = t["3:1"] ? t["3:1"].gone : -1;
            t = track(t, [], 5.5);
            const still = !!t["3:1"];
            t = track(t, [], 6.5);
            return [ghost, still, !!t["3:1"]];
        })()''')
        self.assertEqual(got, [1, True, False])

    def test_the_tallest_are_named(self):
        got = self.js('named(track({}, [{ id: "a", cpu: 1, age: 9 }, { id: "b", cpu: 300, age: 9 }, { id: "c", cpu: 0, age: 9 }, { id: "d", cpu: 40, age: 9 }], 0), 2)')
        self.assertEqual(got, ["b", "d"])
        self.assertAlmostEqual(self.js('notchYs(1, 100)')[0], 60)


if __name__ == "__main__":
    unittest.main()
