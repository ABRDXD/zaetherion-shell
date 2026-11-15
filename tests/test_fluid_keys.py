"""Fluid's keyboard behaviour (after Radix / Base UI): keyboard-only focus, rings, roving arrows, Enter presses."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import cuetest  # noqa: E402

CHECKS = ("keyboard.only.focus", "ring.when.focused", "arrows.skip.hidden.and.disabled", "arrows.stop.at.the.end",
          "down.moves.along.a.list", "enter.presses")


class FluidKeys(unittest.TestCase):
    def test_keys(self):
        output = cuetest.run("FluidKeysTest.qml", timeout=60)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([l for l in output.splitlines() if "CUE_FAIL" in l], [])
        for name in CHECKS:
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
