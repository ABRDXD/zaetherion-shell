"""FART's Island tab (Z176, Z201): view/shell/IslandRestChoices.js, under Node, matches the core's presets and modes."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from core.island import REST_MODES, REST_PRESETS  # noqa: E402


def run(expression):
    body = "\n".join(l for l in (ROOT / "view/shell/IslandRestChoices.js").read_text().splitlines() if not l.startswith(".pragma"))
    out = subprocess.run(["node", "-e", body + f"\nprocess.stdout.write(JSON.stringify({expression}));"],
                         capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


@unittest.skipUnless(shutil.which("node"), "needs Node")
class IslandRestChoices(unittest.TestCase):
    def test_the_presets_and_modes_are_the_cores(self):
        self.assertEqual(run("PRESETS"), REST_PRESETS)
        self.assertEqual(run("MODES"), {item: list(modes) for item, modes in REST_MODES.items()})
        self.assertEqual(sorted(run("Object.keys(PRESET_NOTES)")), sorted(REST_PRESETS))

    def test_a_rest_names_its_preset_or_none(self):
        for name, rest in REST_PRESETS.items():
            self.assertEqual(run(f"presetOf({json.dumps(rest)})"), name)
        self.assertEqual(run("presetOf({power: 'always', network: 'hover', battery: 'always', inbox: 'dot'})"), "")
        self.assertEqual(run("[presetOf(null), presetOf({})]"), ["", ""])

    def test_every_mode_has_a_label(self):
        for item, modes in REST_MODES.items():
            got = run(f"options('{item}')")
            self.assertEqual([m for m, _ in got], list(modes))
            self.assertTrue(all(label for _, label in got))


if __name__ == "__main__":
    unittest.main()
