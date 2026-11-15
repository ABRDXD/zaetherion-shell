"""Confluence Performance (the star), offscreen on fixture telemetry."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import cuetest  # noqa: E402

CHECKS = ("fluid.presented", "readings", "companion.with.gpu", "calm.verdict", "hotter.is.bluer", "memory.grows.the.star",
          "hot.verdict", "overdrive.layers.draw", "no.gpu.no.companion", "angular.keeps.readings")


class FluidPerformance(unittest.TestCase):
    def test_star(self):
        output = cuetest.run("FluidPerformanceTest.qml", timeout=120)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([l for l in output.splitlines() if "CUE_FAIL" in l], [])
        for name in CHECKS:
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
