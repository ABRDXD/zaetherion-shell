"""view/rooms/Architecture.js: spectral architecture's bands, sections and composition (atlas #67).

Run under Node with the QML `.pragma` line stripped; every time is passed in."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Architecture.js"

# Synthetic spectra, 56 bins: bass-heavy, bright, and silence.
BASS = "Array.from({length: 56}, (_, i) => i < 9 ? 0.9 : i < 28 ? 0.25 : 0.05)"
BRIGHT = "Array.from({length: 56}, (_, i) => i < 9 ? 0.1 : i < 28 ? 0.35 : 0.8)"
QUIET = "Array.from({length: 56}, () => 0)"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class ArchitectureTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def run_song(self, parts):
        """Feed (spectrum expression, seconds) parts at 30 frames a second; the sections declared, with their times."""
        return self.js(f"""(() => {{
            const d = sections(), out = [];
            let t = 0;
            for (const [bins, seconds] of {json.dumps(parts)}.map(([e, s]) => [eval(e), s]))
                for (let k = 0; k < seconds * 30; k++, t += 1 / 30) {{ const s = d.push(bins, t); if (s) out.push({{ index: s.index, t: Math.round(s.t * 10) / 10, low: Math.round(s.shares[0] * 100) / 100 }}); }}
            return out;
        }})()""")

    def test_bands_fold_the_bins(self):
        self.assertEqual(self.js(f"bands({BASS}).map(v => Math.round(v * 100) / 100)"), [0.9, 0.25, 0.05])
        self.assertEqual(self.js("bands([])"), [0, 0, 0])

    def test_a_steady_song_is_one_section_after_the_warmup(self):
        got = self.run_song([[BASS, 20]])
        self.assertEqual(len(got), 1)
        self.assertAlmostEqual(got[0]["t"], 1.5, delta=0.1)
        self.assertGreater(got[0]["low"], 0.6)

    def test_a_change_of_character_begins_a_section_not_sooner_than_the_gap(self):
        got = self.run_song([[BASS, 10], [BRIGHT, 10], [BASS, 3], [BRIGHT, 3]])
        times = [s["t"] for s in got]
        self.assertGreaterEqual(len(got), 3)
        self.assertTrue(any(10 <= t <= 12 for t in times), times)
        self.assertTrue(all(b - a >= 6 - 1e-6 for a, b in zip(times, times[1:])), times)

    def test_silence_keeps_the_section(self):
        got = self.run_song([[BASS, 8], [QUIET, 10], [BASS, 8]])
        self.assertEqual(len(got), 1)

    def test_bass_stands_as_one_massive_column_and_brightness_fractures(self):
        bass = self.js("compose([0.8, 0.15, 0.05], 3)")
        bright = self.js("compose([0.1, 0.3, 0.6], 3)")
        self.assertLessEqual(len(bass), 2)
        self.assertGreater(max(c["w"] for c in bass), 0.7)
        self.assertGreaterEqual(len(bright), 6)
        self.assertLess(max(c["w"] for c in bright), 0.35)
        for cols in (bass, bright):
            self.assertAlmostEqual(cols[-1]["x"] + cols[-1]["w"], 1, places=6)   # they fill the width
            self.assertTrue(all(c["x"] >= 0 and c["w"] > 0 for c in cols))
            self.assertEqual(sum(c["role"] == "ink" for c in cols), 1)
        self.assertEqual(self.js("compose([0.1, 0.3, 0.6], 3)"), bright)            # deterministic per section
        self.assertNotEqual(self.js("compose([0.1, 0.3, 0.6], 4)"), bright)

    def test_between_morphs_and_grows_new_columns_from_the_edge(self):
        a = [{"x": 0, "w": 1, "role": "ink", "slant": 1}]
        b = [{"x": 0, "w": 0.5, "role": "paper", "slant": 2}, {"x": 0.5, "w": 0.5, "role": "ink", "slant": 1}]
        self.assertEqual(self.js(f"between({json.dumps(a)}, {json.dumps(b)}, 0)"), a)
        mid = self.js(f"between({json.dumps(a)}, {json.dumps(b)}, 0.5)")
        self.assertEqual([round(c["w"], 3) for c in mid], [0.75, 0.25])
        self.assertEqual(round(mid[1]["x"], 3), 0.75)
        self.assertEqual(self.js(f"between({json.dumps(a)}, {json.dumps(b)}, 1)"), b)

    def test_held_silence_registers_the_room_and_sound_lets_it_go(self):
        got = self.js(f"""(() => {{
            const h = hush(), out = [];
            let t = 0;
            const run = (bins, seconds) => {{ for (let k = 0; k < seconds * 30; k++, t += 1 / 30) out.push([Math.round(t * 100) / 100, h.push(bins, t)]); }};
            run({BASS}, 2); run({QUIET}, 1); run({BASS}, 0.2); run({QUIET}, 2); run({BASS}, 1);
            const on = out.find(([, v]) => v), off = out.slice(out.indexOf(on)).find(([, v]) => !v);
            return {{ on: on[0], off: off[0], blips: out.filter(([s, v]) => s < 3.5 && v).length }};
        }})()""")
        self.assertEqual(got["blips"], 0)                       # a quiet second, broken by a blip, isn't silence
        self.assertAlmostEqual(got["on"], 3.2 + 1.2, delta=0.05)  # 1.2 s into the long quiet
        self.assertAlmostEqual(got["off"], 5.2 + 0.25, delta=0.05)
        grid = self.js("registered()")
        self.assertEqual(len(grid), 12)
        self.assertTrue(all(c["slant"] == 0 and abs(c["w"] - grid[0]["w"]) < 1e-12 for c in grid))
        self.assertAlmostEqual(grid[-1]["x"] + grid[-1]["w"], 1, places=9)


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class MediaArchitecture(unittest.TestCase):
    """The stratum in the real Media room (tools/cuetest/MediaTest.qml)."""

    def test_the_music_composes_the_room(self):
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("MediaTest.qml", timeout=120)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("arch.first", "arch.cut", "arch.inert", "arch.silence", "arch.release", "voice.media", "groove.cut"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertIn("CUE_ACTIVE 0 []", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Cannot assign") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
