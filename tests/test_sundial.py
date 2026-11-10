"""view/ui/Sundial.js: sundial rooms (B's idea, docs/OVERDRIVE.md §43): the light and the shadow it throws."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/ui/Sundial.js"


def sky(sun_alt, sun_az=180, moon_alt=-10, moon_az=90, lit=0.5):
    return {"bodies": {"sun": {"altitude": sun_alt, "azimuth": sun_az}, "moon": {"altitude": moon_alt, "azimuth": moon_az}},
            "moon": {"illumination": lit}}


@unittest.skipUnless(shutil.which("node"), "needs Node")
class SundialTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_the_sun_or_the_moon_or_nothing(self):
        self.assertEqual(self.js(f'light({json.dumps(sky(30))}).body'), "sun")
        self.assertEqual(self.js(f'light({json.dumps(sky(-12, moon_alt=40))}).body'), "moon")
        self.assertIsNone(self.js(f'light({json.dumps(sky(-3, moon_alt=40))})'))   # twilight: neither
        self.assertIsNone(self.js(f'light({json.dumps(sky(-20, moon_alt=-5))})'))
        self.assertIsNone(self.js('light(null)'))
        low, high = self.js(f'[light({json.dumps(sky(2))}).strength, light({json.dumps(sky(40))}).strength]')
        self.assertLess(low, high)
        full, thin = self.js(f'[light({json.dumps(sky(-20, moon_alt=30, lit=1))}).strength, light({json.dumps(sky(-20, moon_alt=30, lit=0.1))}).strength]')
        self.assertGreater(full, thin)

    def test_shadows_fall_away_from_the_light(self):
        east = self.js('shadow({ azimuth: 90, altitude: 20 })')
        self.assertLess(east["x"], 0)
        self.assertAlmostEqual(east["y"], 0, places=6)
        south = self.js('shadow({ azimuth: 180, altitude: 20 })')
        self.assertLess(south["y"], 0)
        low, high = self.js('[shadow({ azimuth: 180, altitude: 3 }).length, shadow({ azimuth: 180, altitude: 60 }).length]')
        self.assertEqual(low, 64)
        self.assertLess(high, 4)
        self.assertEqual(self.js('shadow(null)'), {"x": 0, "y": 0, "length": 0})

    def test_caption(self):
        self.assertEqual(self.js('caption({ body: "sun", azimuth: 214.4, altitude: 31.2 })'), "SUN 214° · 31°")
        self.assertEqual(self.js('caption(null)'), "")


    def test_the_lights_colour_follows_the_sun(self):
        self.assertEqual(self.js('[tint({ body: "sun", altitude: 3 }), tint({ body: "sun", altitude: 12 }), tint({ body: "sun", altitude: 50 }), tint({ body: "moon", altitude: 30 })]'),
                         ["#ffc58a", "#ffe2b8", "#fff4e2", "#cfdcff"])


if __name__ == "__main__":
    unittest.main()
