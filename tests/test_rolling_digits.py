"""view/ui/RollingDigits.qml (after NumberFlow): changed digits roll, offscreen."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import cuetest  # noqa: E402

CHECKS = ("digits.share.width", "changed.digits.roll", "separator.stays", "rising.rolls.up", "settles",
          "falling.rolls.down", "reduced.swaps", "teardown.quiet")


class RollingDigits(unittest.TestCase):
    def test_roll(self):
        output = cuetest.run("RollingDigitsTest.qml", timeout=60)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([l for l in output.splitlines() if "CUE_FAIL" in l], [])
        for name in CHECKS:
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
