"""adapters/quickshell/OsdChange.js: which level changes become OSD events (Z24, Z161), under Node."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def steps(samples, quiet=None):
    body = "\n".join(l for l in (ROOT / "adapters/quickshell/OsdChange.js").read_text().splitlines()
                     if not l.startswith(".pragma"))
    quiet = quiet or [False] * len(samples)
    script = body + f"""
let s = null; const out = [];
const samples = {json.dumps(samples)}, quiet = {json.dumps(quiet)};
samples.forEach((x, i) => {{ const r = next(s, x, quiet[i]); s = r.state; out.push(r.event); }});
process.stdout.write(JSON.stringify(out));"""
    return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)


def v(level, muted=False, node=1, kind="volume"):
    return {"kind": kind, "node": node, "level": level, "muted": muted}


@unittest.skipUnless(shutil.which("node"), "needs Node")
class OsdChange(unittest.TestCase):
    def test_first_sample_is_a_baseline(self):
        self.assertEqual(steps([v(0.5)]), [None])

    def test_level_and_mute_changes_are_events(self):
        self.assertEqual(steps([v(0.5), v(0.55), v(0.55, True)]),
                         [None, {"kind": "volume", "level": 0.55, "muted": False},
                          {"kind": "volume", "level": 0.55, "muted": True}])

    def test_rounding_noise_is_not_a_change(self):
        self.assertEqual(steps([v(0.5), v(0.503)]), [None, None])

    def test_a_new_default_device_is_a_new_baseline(self):
        self.assertEqual(steps([v(0.5), v(0.9, node=2), v(0.8, node=2)])[1:],
                         [None, {"kind": "volume", "level": 0.8, "muted": False}])

    def test_kinds_are_separate(self):
        got = steps([v(0.5), v(0.2, kind="mic"), v(0.2, True, kind="mic")])
        self.assertEqual(got, [None, None, {"kind": "mic", "level": 0.2, "muted": True}])

    def test_quiet_drops_the_event_but_keeps_the_level(self):
        self.assertEqual(steps([v(0.5), v(0.6), v(0.6)], quiet=[False, True, False]), [None, None, None])

    def test_level_above_one_is_kept(self):
        # Pipewire allows boost past 100 %; the meter decides how to draw it.
        self.assertEqual(steps([v(1.0), v(1.2)])[1]["level"], 1.2)


if __name__ == "__main__":
    unittest.main()
