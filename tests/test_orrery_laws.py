"""view/rooms/Orrery.js: the laws under the telemetry orrery (M12).

Run under Node with the QML `.pragma` line stripped; every time is an argument, so nothing here waits."""
import json
import math
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Orrery.js"


def body(id="1:1", name="p", cpu=0.0, rss=100.0, growth=0.0, born=False, pid=1):
    return {"id": id, "pid": pid, "name": name, "cpu": cpu, "rss": rss, "growth": growth, "age": 100, "born": born}


def sample(*bodies, exits=(), forks=0, at=1.0):
    return {"running": True, "warm": True, "at": at, "bodies": list(bodies), "exits": list(exits), "forks": forks,
            "total": {"cpu": 0, "rss": 0, "count": len(bodies)}}


@unittest.skipUnless(shutil.which("node"), "needs Node")
class OrreryLaws(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def run_merges(self, *steps):
        """[(sample, t), …] merged in order; the state after each, plus the probes asked for."""
        script = "let s = {slots: [], rings: [], meteors: []}; const out = [];\n"
        for sample_, t in steps:
            script += f"s = merge(s, {json.dumps(sample_)}, {t}); out.push(JSON.parse(JSON.stringify(s)));\n"
        return self.js("(() => { " + script + " return out; })()")

    # Mass, speed, depth

    def test_mass_is_memory_by_volume(self):
        small, big, huge = self.js("[size(12), size(512), size(4096)]")
        self.assertLess(small, big)
        self.assertLess(big, huge)
        # The cube root: 4 GiB against 12 MiB is ~7×, not the 340× of the memory itself.
        self.assertAlmostEqual(huge / max(small, 1e-9), (4096 / 12) ** (1 / 3), delta=0.6)
        self.assertEqual(self.js("[size(0), size(100000)]"), [2, 18])

    def test_speed_is_cpu_and_an_idle_process_stands_still(self):
        idle, one, four = self.js("[omega(0), omega(100), omega(400)]")
        self.assertEqual(idle, 0)
        self.assertAlmostEqual(one, 2 * math.pi / 8)  # a turn every 8 s at one whole core
        self.assertAlmostEqual(four, 4 * one)

    def test_heavier_sits_deeper_and_growth_sinks(self):
        light, mid, heavy = self.js("[altitude(32, 0), altitude(512, 0), altitude(4096, 0)]")
        self.assertEqual(light, 1)
        self.assertGreater(light, mid)
        self.assertGreater(mid, heavy)
        self.assertEqual(heavy, 0)
        steady, leaking, freeing = self.js("[altitude(512, 0), altitude(512, 2), altitude(512, -2)]")
        self.assertLess(leaking, steady)
        self.assertGreater(freeing, steady)
        # A heavy process that keeps growing goes under the Roche limit and is torn; a steady one is not.
        self.assertEqual(self.js("[roche(altitude(3000, 0)), roche(altitude(3000, 1.5))]"), [False, True])

    # Places

    def test_the_rings_lean_at_78_degrees_and_nest(self):
        g = self.js("geometry(600, 560)")
        top = self.js(f"place({json.dumps(g)}, 1, Math.PI / 2)")
        bottom = self.js(f"place({json.dumps(g)}, 1, -Math.PI / 2)")
        # The major axis runs from the bottom-left to the top-right at 78° from the horizontal.
        self.assertAlmostEqual(math.degrees(math.atan2(bottom["y"] - top["y"], top["x"] - bottom["x"])), 78, delta=0.01)
        radii = self.js(f"[-0.5, 0, 0.5, 1].map(a => radiusAt({json.dumps(g)}, a))")
        self.assertEqual(radii, sorted(radii))
        self.assertAlmostEqual(radii[1], g["inner"])
        self.assertAlmostEqual(radii[3], g["outer"])
        # θ = 0 is nearest the viewer, θ = π furthest.
        self.assertEqual(self.js(f"[place({json.dumps(g)}, 1, 0).depth, place({json.dumps(g)}, 1, Math.PI).depth]"), [1, 0])

    # One sample after another

    def test_a_body_keeps_its_slot_and_its_angle_runs_with_its_cpu(self):
        a, b = body("1:1", "busy", cpu=100), body("2:1", "idle", cpu=0)
        states = self.run_merges((sample(a, b), 0), (sample(b, a), 2))
        first, second = states
        slot_of = lambda state, id: next(i for i, s in enumerate(state["slots"]) if s and s["id"] == id)
        self.assertEqual(slot_of(first, "1:1"), slot_of(second, "1:1"))
        self.assertEqual(slot_of(first, "2:1"), slot_of(second, "2:1"))
        busy0, busy1 = first["slots"][slot_of(first, "1:1")], second["slots"][slot_of(second, "1:1")]
        idle0, idle1 = first["slots"][slot_of(first, "2:1")], second["slots"][slot_of(second, "2:1")]
        # Re-based at the sample's time: the angle carries on from where it was, nothing jumps.
        self.assertAlmostEqual(busy1["theta"], busy0["theta"] + 2 * math.pi / 8 * 2)
        self.assertEqual(idle1["theta"], idle0["theta"])

    def test_a_born_process_falls_in_and_is_captured(self):
        state = self.run_merges((sample(body("1:1", "base")), 0), (sample(body("1:1", "base"), body("9:9", "new", born=True)), 1))[1]
        new = next(s for s in state["slots"] if s and s["id"] == "9:9")
        heights = self.js(f"[0, 0.4, 0.9, 1.5, 4].map(dt => altAt({json.dumps(new)}, 1 + dt))")
        self.assertGreater(heights[0], 1.5)  # from outside the outer ring
        self.assertLess(min(heights[1:4]), new["alt"])  # it swings past its ring once…
        self.assertAlmostEqual(heights[4], new["alt"], delta=0.01)  # …and settles there
        self.assertEqual(self.js(f"presence({json.dumps(new)}, 1)"), 1)  # visible as it falls

    def test_one_that_only_grew_into_the_set_fades_in_where_it_belongs(self):
        state = self.run_merges((sample(body("3:3", "veteran", rss=900)), 5))[0]
        b = state["slots"][0]
        self.assertEqual(b["altFrom"], b["alt"])
        self.assertEqual(self.js(f"[presence({json.dumps(b)}, 5), presence({json.dumps(b)}, 5.5), presence({json.dumps(b)}, 6)]"), [0, 0.5, 1])

    def test_growth_steers_a_body_down_in_a_spiral_not_a_jump(self):
        states = self.run_merges((sample(body("1:1", rss=512)), 0), (sample(body("1:1", rss=530, growth=2, cpu=50)), 1))
        b = states[1]["slots"][0]
        self.assertLess(b["alt"], b["altFrom"])
        self.assertAlmostEqual(self.js(f"altAt({json.dumps(b)}, 1)"), b["altFrom"])  # continuous at the sample
        self.assertAlmostEqual(self.js(f"altAt({json.dumps(b)}, 4)"), b["alt"], delta=0.01)

    def test_small_changes_of_place_wait(self):
        states = self.run_merges((sample(body("1:1", rss=512)), 0), (sample(body("1:1", rss=514)), 1))
        self.assertEqual(states[0]["slots"][0]["altSince"], states[1]["slots"][0]["altSince"])

    def test_an_ended_process_leaves_its_ring_and_a_dropped_one_fades(self):
        a, b = body("1:1", "editor", rss=300), body("2:2", "shell", rss=50)
        states = self.run_merges((sample(a, b), 0), (sample(b, exits=[{"id": "1:1", "name": "editor"}]), 1),
                                 (sample(), 2), (sample(), 3.5))
        self.assertEqual([r["name"] for r in states[1]["rings"]], ["editor"])
        self.assertFalse(any(s and s["id"] == "1:1" for s in states[1]["slots"]))
        # "shell" left the shown set without ending: it fades out where it stood, then its slot is free.
        shell = next(s for s in states[2]["slots"] if s and s["id"] == "2:2")
        self.assertEqual(shell["gone"], 2)
        self.assertEqual(shell["omega"], 0)
        self.assertFalse(any(states[3]["slots"]))
        # The ring outlives both, until it has faded.
        self.assertEqual(len(states[3]["rings"]), 1)
        self.assertEqual(self.run_merges((sample(), 9.5))[0]["rings"], [])

    def test_forks_rain_in_as_meteors_capped_each_standing_for_more(self):
        few = self.run_merges((sample(forks=3, at=7), 0))[0]["meteors"]
        many = self.run_merges((sample(forks=40, at=7), 0))[0]["meteors"]
        self.assertEqual(len(few), 3)
        self.assertEqual(len(many), 8)
        self.assertEqual({m["stands"] for m in many}, {5})
        # Spread over the coming second, and each falls from outside the outer ring to the Roche ring.
        self.assertTrue(all(0 <= m["at"] < 1 for m in many))
        g = self.js("geometry(600, 560)")
        m = many[0]
        start, end, gone = self.js(f"[0.001, 0.899, 0.95].map(d => meteorAt({json.dumps(g)}, {json.dumps(m)}, {m['at']} + d))")
        r = lambda p: math.hypot(p["x"] - g["cx"], (p["y"] - g["cy"]) / 0.8)
        self.assertGreater(r(start), g["outer"])
        self.assertLess(r(end), g["inner"])
        self.assertIsNone(gone)

    def test_only_the_busiest_trails_a_comet_away_from_the_sun(self):
        state = self.run_merges((sample(body("1:1", cpu=40), body("2:2", cpu=90), body("3:3", cpu=2)), 0))[0]
        comets = [s["id"] for s in state["slots"] if s and s["comet"]]
        self.assertEqual(comets, ["2:2"])
        quiet = self.run_merges((sample(body("1:1", cpu=3)), 0))[0]
        self.assertFalse(any(s and s["comet"] for s in quiet["slots"]))
        g = self.js("geometry(600, 560)")
        t = self.js(f"tail({json.dumps(g)}, {{x: {g['cx'] + 50}, y: {g['cy']}}}, 50)")
        self.assertAlmostEqual(t["angle"], 0)  # pointing straight out, away from the centre
        self.assertGreater(self.js(f"tail({json.dumps(g)}, {{x: 0, y: 0}}, 100).length"), t["length"])

    def test_a_release_or_silence_empties_the_orrery(self):
        states = self.run_merges((sample(body("1:1")), 0), ({"running": False}, 1))
        self.assertEqual(states[1], {"slots": [None] * 24, "rings": [], "meteors": []})


if __name__ == "__main__":
    unittest.main()
