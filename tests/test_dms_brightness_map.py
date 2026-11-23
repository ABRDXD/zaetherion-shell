"""adapters/dms/DmsBrightnessMap.js: the brightness OSD sample from DMS's snapshot, under Node."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = json.loads((ROOT / "tests/fixtures/dms/s0-v2.1.0.json").read_text())
EVENT = next(e["result"]["data"] for e in FIXTURE["events"] if e["result"]["service"] == "brightness")


def sample(data):
    body = "\n".join(l for l in (ROOT / "adapters/dms/DmsBrightnessMap.js").read_text().splitlines()
                     if not l.startswith(".pragma"))
    script = body + f"\nprocess.stdout.write(JSON.stringify(sample({json.dumps(data)})));"
    return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)


def device(cls, ident, percent):
    return {"class": cls, "id": ident, "name": "x", "current": 0, "max": 100, "currentPercent": percent, "backend": "sysfs"}


@unittest.skipUnless(shutil.which("node"), "needs Node")
class BrightnessMap(unittest.TestCase):
    def test_the_recorded_snapshot(self):
        d = EVENT["devices"][0]
        self.assertEqual(sample(EVENT), {"kind": "brightness", "node": d["id"], "level": d["currentPercent"] / 100, "muted": False})

    def test_backlight_before_ddc(self):
        got = sample({"devices": [device("ddc", "ddc:1", 70), device("backlight", "backlight:a", 40)]})
        self.assertEqual((got["node"], got["level"]), ("backlight:a", 0.4))

    def test_ddc_when_there_is_no_backlight(self):
        self.assertEqual(sample({"devices": [device("ddc", "ddc:1", 70)]})["node"], "ddc:1")

    def test_an_update_event(self):
        got = sample({"device": device("backlight", "backlight:a", 95)})
        self.assertEqual((got["node"], got["level"]), ("backlight:a", 0.95))

    def test_nothing_usable(self):
        for data in (None, {}, {"devices": []}, {"devices": [device("leds", "kbd", 10)]}, {"devices": [{"class": "backlight"}]}):
            self.assertIsNone(sample(data), data)

    def test_level_is_clamped(self):
        self.assertEqual(sample({"devices": [device("backlight", "b", 140)]})["level"], 1)


if __name__ == "__main__":
    unittest.main()
