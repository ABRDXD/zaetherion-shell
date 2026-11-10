"""Lifecycle and static-clock tests for Astra's two rooms; synthetic state only."""
import unittest
from tools.cuetest import run


class AstraCueTests(unittest.TestCase):
    def test_genealogy_lifecycle(self):
        output = run('AstraTest.qml', timeout=45)
        self.assertIn('CUE_DONE', output)
        self.assertNotIn('CUE_FAIL', output)
        for failure in ('TypeError', 'ReferenceError', 'Failed to load configuration'):
            self.assertNotIn(failure, output)

    def test_temporal_lifecycle_and_second_clock(self):
        output = run('TemporalTest.qml', timeout=60)
        self.assertIn('CUE_DONE', output)
        self.assertNotIn('CUE_FAIL', output)
        for failure in ('TypeError', 'ReferenceError', 'Failed to load configuration'):
            self.assertNotIn(failure, output)

    def test_exhibit_score_playback_lifecycle(self):
        output = run('AstraExhibitTest.qml', timeout=20)
        for marker in ('CUE_DONE', 'CUE_PASS stratum.loaded', 'CUE_PASS stratum.destroyed', 'CUE_PASS stratum.reduced'):
            self.assertIn(marker, output)
        for failure in ('CUE_FAIL', 'TypeError', 'ReferenceError', 'Failed to load configuration'):
            self.assertNotIn(failure, output)

    def test_eigenmode_real_shell_paths(self):
        output = run('AstraEigenTest.qml', timeout=25)
        for marker in ('laplacian.residual', 'modes.orthogonal', 'geometry.mass.matters',
                       'real.room.path', 'real.timer.path', 'real.device.path', 'nodes.fixed',
                       'antinode.moves', 'controls.focus.during.motion', 'reduced.300ms', 'release.destroyed'):
            self.assertIn('CUE_PASS ' + marker, output)
        for failure in ('CUE_FAIL', 'TypeError', 'ReferenceError', 'Failed to load configuration', 'Binding loop'):
            self.assertNotIn(failure, output)
        self.assertIn('CUE_DONE', output)
