"""The parity harness (Z226 stage 0): every scenario in tests/parity/scenarios.py against one core.

FART_PARITY_CORE picks the core (unset: the Python core; a path: fartd-cpp). tools/parity.py runs two cores and
compares what they saw.
"""
import os
import unittest

from parity.harness import core_name
from parity.scenarios import SCENARIOS, run_scenario


class ParityTests(unittest.TestCase):
    pass


def _make(sc):
    def test(self):
        run_scenario(sc)
    test.__doc__ = f"stage {sc.stage}: {sc.name} on {core_name()}"
    return test


for _sc in SCENARIOS.values():
    setattr(ParityTests, f"test_{_sc.name}", _make(_sc))


class FixtureClockGate(unittest.TestCase):
    """The fake wall clock only ever moves a fixture core (fartd.fixture_epoch; fartd-cpp must gate it the same)."""

    def test_gate(self):
        import sys
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
        from core.fartd import fixture_epoch
        self.assertEqual(fixture_epoch({"FART_HOST": "fixture", "FART_FIXTURE_EPOCH": "1000"}), 1000.0)
        self.assertIsNone(fixture_epoch({"FART_HOST": "serpantinum", "FART_FIXTURE_EPOCH": "1000"}))
        self.assertIsNone(fixture_epoch({"FART_FIXTURE_EPOCH": "1000"}))
        self.assertIsNone(fixture_epoch({"FART_HOST": "fixture", "FART_FIXTURE_EPOCH": "soon"}))
        self.assertIsNone(fixture_epoch({"FART_HOST": "fixture"}))


if __name__ == "__main__":
    unittest.main()
