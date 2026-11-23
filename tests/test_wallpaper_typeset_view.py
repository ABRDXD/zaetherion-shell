"""The wallpaper picker's Typeset button (Z215), offscreen on a fake core."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import cuetest  # noqa: E402

CHECKS = ("shown.for.a.photo", "asks.for.the.shown.picture", "busy.while.typesetting", "failure.said", "hidden.for.a.plate",
          "plate.note")


class TypesetButton(unittest.TestCase):
    def test_button(self):
        output = cuetest.run("WallpaperTypesetTest.qml", timeout=60)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([l for l in output.splitlines() if "CUE_FAIL" in l], [])
        for name in CHECKS:
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
