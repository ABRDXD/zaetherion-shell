"""adapters/hyprland/ShortcutEdges.js: one open per keystroke, whether Hyprland sends press+release or release only."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def opens(edges):
    body = "\n".join(l for l in (ROOT / "adapters/hyprland/ShortcutEdges.js").read_text().splitlines()
                     if not l.startswith(".pragma"))
    script = body + f"""
let down = false; const out = [];
for (const kind of {json.dumps(edges)}) {{ const r = edge(down, kind); down = r.down; out.push(r.open); }}
process.stdout.write(JSON.stringify(out));"""
    return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)


@unittest.skipUnless(shutil.which("node"), "needs Node")
class ShortcutEdges(unittest.TestCase):
    def test_a_plain_bind_opens_on_the_press_only(self):
        self.assertEqual(opens(["pressed", "released"]), [True, False])

    def test_a_release_bind_opens_on_its_lone_release(self):  # the Super tap
        self.assertEqual(opens(["released"]), [True])
        self.assertEqual(opens(["released", "released"]), [True, True])  # two taps, two toggles

    def test_mixed_keys_never_double(self):
        self.assertEqual(opens(["pressed", "released", "released", "pressed", "released"]), [True, False, True, True, False])


if __name__ == "__main__":
    unittest.main()
