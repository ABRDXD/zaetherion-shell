"""Orbit.js, the orbit's geometry (docs/ORBIT.md §0), run under Node with the QML `.pragma` line stripped."""
import json
import math
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/shell/Orbit.js"

# OrbitSystem.qml's layout for a field of width × height (wide: the readout beside the system).
LAYOUT = """
function layout(width, height) {
    const compact = width < 1000, cardWidth = compact ? 0 : 236, left = cardWidth > 0 ? cardWidth + 48 : 0;
    const tileW = Math.round(Math.max(88, Math.min(140, height * 0.145))), tileH = Math.round(tileW * 0.54);
    const weights = [1.12, 1, 1.12, 1, 1.12, 1, 0.88, 0.88, 0.88];
    const sizes = weights.map(k => ({ w: Math.round(tileW * k), h: Math.round(tileH * k) }));
    const homeW = Math.round(tileW * 1.6), homeH = Math.round(tileH * 1.8), pad = 8;
    const lift = Math.round(tileH * 0.75), homeLift = Math.round(tileH * 0.3);
    const field = compact ? height - 64 : height;
    const f = fit((width - left) / 2 - 16, field / 2 - 12, tileW * 0.56, tileH * 0.56, lift, ELEVATION);
    const v = view(ELEVATION, f.r);
    const hp = point(0, homeLift, 0, v);
    const home = { x: hp.x, y: hp.y - homeH * hp.k / 2, hw: homeW * hp.k / 2, hh: homeH * hp.k / 2 };
    const inner = Math.min(f.r, homeW / 2 + tileW * 0.62 + pad);
    return { rs: radii(9, inner, f.r), sizes, home, pad, v, lift, f, field, cy: field / 2 + f.dy };
}
"""


@unittest.skipUnless(shutil.which("node"), "needs Node")
class OrbitTests(unittest.TestCase):
    def run_js(self, expression):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + LAYOUT + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_the_centre_and_the_house_shear(self):
        centre, front, back = self.run_js("[project(0, 0, 10, 20, view(45, 300), 0), project(200, Math.PI / 2, 0, 0, view(45, 300), 0),"
                                          " project(200, -Math.PI / 2, 0, 0, view(45, 300), 0)]")
        self.assertAlmostEqual(centre["x"], 10)
        self.assertAlmostEqual(centre["y"], 20)
        # Sheared as FART's 78° edges: the far side sits right of the near side.
        self.assertGreater(back["x"], front["x"])

    def test_perspective_makes_the_near_half_larger(self):
        front, back = self.run_js("[project(300, Math.PI / 2, 0, 0, view(45, 300), 0), project(300, -Math.PI / 2, 0, 0, view(45, 300), 0)]")
        self.assertGreater(front["scale"], 1.15)
        self.assertLess(back["scale"], 0.9)
        self.assertGreater(front["z"], back["z"])
        self.assertGreater(front["y"], 0)
        self.assertLess(back["y"], 0)
        # The near half reaches further from the centre than the far half: the ring is not a flat ellipse.
        self.assertGreater(math.hypot(front["x"], front["y"]), 1.3 * math.hypot(back["x"], back["y"]))
        self.assertAlmostEqual(back["opacity"], 0.6)

    def test_a_raised_tile_stands_on_a_stalk_above_its_foot(self):
        centred, aside = self.run_js("[project(200, Math.PI / 2, 0, 0, view(45, 300), 40), project(200, 0.3, 0, 0, view(45, 300), 40)]")
        lean = lambda p: math.degrees(math.atan2(p["x"] - p["gx"], p["gy"] - p["y"]))
        self.assertLess(centred["y"], centred["gy"])
        # On the centre line a stalk leans exactly to 78°, as the tiles' edges; off it, perspective leans it outward.
        self.assertAlmostEqual(lean(centred), 12, places=6)
        self.assertGreater(lean(aside), 12)

    def test_a_flatter_plane_is_shorter(self):
        steep, flat = self.run_js("[bounds(62), bounds(31)]")
        self.assertLess(flat["maxY"] - flat["minY"], steep["maxY"] - steep["minY"])

    def test_default_spiral_needs_no_nudge_and_nothing_overlaps_or_leaves_the_field(self):
        for size in ((1360, 690), (1120, 600), (1920, 1000), (900, 560)):
            with self.subTest(size=size):
                result = self.run_js(
                    f"(() => {{ const l = layout({size[0]}, {size[1]}); const s = separate(spread(9), l.rs, l.sizes, l.home, l.pad, l.v, l.lift);"
                    " let top = Infinity, bottom = -Infinity;"
                    " s.forEach((a, k) => { const b = box(l.rs[k], a, l.sizes[k], l.v, l.lift); top = Math.min(top, l.cy + b.y - b.hh); bottom = Math.max(bottom, l.cy + b.y + b.hh); });"
                    " for (let i = 0; i < 96; i++) { const t = 2 * Math.PI * i / 96; const p = point(l.f.r * Math.cos(t), 0, l.f.r * Math.sin(t), l.v); top = Math.min(top, l.cy + p.y); bottom = Math.max(bottom, l.cy + p.y); }"
                    " return { worst: worst(s, l.rs, l.sizes, l.home, l.pad, l.v, l.lift), outer: l.rs[7], inner: l.rs[0], top: top, bottom: bottom, field: l.field }; })()")
                self.assertEqual(result["worst"], 0)
                self.assertGreater(result["outer"], result["inner"])
                self.assertGreaterEqual(result["top"], 0)
                self.assertLessEqual(result["bottom"], result["field"])

    def test_error_budget_is_the_share_of_sources_that_cant_be_read(self):
        got = self.run_js("[errorBudget([]), errorBudget(null), errorBudget([true, true]), errorBudget([true, false]), errorBudget([false, undefined])]")
        self.assertEqual(got, [0, 0, 0, 0.5, 1])

    def test_separate_keeps_clear_angles_and_parts_crowded_ones(self):
        same = self.run_js("(() => { const l = layout(1360, 690); const a = spread(9);"
                           " return separate(a, l.rs, l.sizes, l.home, l.pad, l.v, l.lift).map((x, i) => x - a[i]); })()")
        self.assertTrue(all(abs(d) < 1e-9 for d in same))
        crowded = self.run_js("(() => { const l = layout(1360, 690); const a = [1, 1.05, 1.1, 1.15, 1.2, 1.25, 1.3, 1.35];"
                              " return worst(separate(a, l.rs, l.sizes, l.home, l.pad, l.v, l.lift), l.rs, l.sizes, l.home, l.pad, l.v, l.lift); })()")
        self.assertEqual(crowded, 0)



@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class OrbitTakesThePointer(unittest.TestCase):
    """Every tile and every framed sun on the real orbit takes the pointer (tools/cuetest/OrbitHitTest.qml), offscreen:
    room 09's tile once didn't, and the compass once sat on Media's sun in the galaxy."""

    def run_at(self, width, height, overdrive):
        import os
        import sys
        from unittest import mock
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        env = {"HIT_W": str(width), "HIT_H": str(height), "HIT_OD": "1" if overdrive else ""}
        with mock.patch.dict(os.environ, env):
            output = cuetest.run("OrbitHitTest.qml", timeout=180)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("orbit.hit", "orbit.suns", "orbit.click09"):
            self.assertIn(f"CUE_PASS {name}", output)

    def test_the_default_window_silent(self):
        self.run_at(1120, 760, False)

    def test_a_wide_screen_in_overdrive(self):
        self.run_at(1600, 900, True)


if __name__ == "__main__":
    unittest.main()
