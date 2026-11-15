"""Confluence Tasks (the star atlas), offscreen on a fake core's lists."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import cuetest  # noqa: E402

CHECKS = ("fluid.presented", "open.count", "sooner.is.nearer", "late.burns.warm", "done.is.hollow", "next.is.the.late.one",
          "route.drawn", "lists.as.constellations", "entry.reads", "editing.follows.focus", "switch.list", "angular.keeps.sheet")


class FluidTasks(unittest.TestCase):
    def test_atlas(self):
        output = cuetest.run("FluidTasksTest.qml", timeout=120)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([l for l in output.splitlines() if "CUE_FAIL" in l], [])
        for name in CHECKS:
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Binding loop") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
