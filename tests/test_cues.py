"""Cue system fixture tests (docs/CUES.md §10), run under Quickshell offscreen by tools/cuetest.py."""
import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import cuetest  # noqa: E402

COMPONENT_TESTS = ('cue.retrigger', 'cue.reverse.0.25', 'cue.reverse.0.5', 'cue.reverse.0.75', 'cue.cancel', 'cue.scope',
                   'cue.reduced', 'cue.destroy', 'cue.burst', 'cue.replay', 'cue.created', 'pulse.repeat.off', 'pulse.retrigger', 'pulse.cancel', 'pulse.repeat',
                   'flash.gate', 'flash.pulse', 'timeline.reverse', 'tween.retarget')
VIEW_TESTS = ('view.navigate.burst', 'view.entrance.interrupt', 'view.entrance.reduced', 'motion.profile', 'overlay.unfold.stagger', 'overlay.unfold.burst', 'overlay.unfold.reverse',
              'calendar.shift.burst', 'view.click.during.entrance', 'button.fill.retarget', 'creature.press.retrigger',
              'view.idle.rooms', 'view.idle.playing', 'heat.scale', 'quiet.heard', 'clock.occultation', 'archive.matchcut', 'desks.sheet', 'home.sky', 'performance.orrery', 'orbit.alive', 'orbit.laws', 'overdrive.language', 'overdrive.ignite.release', 'overdrive.guards')
SATELLITE_TESTS = ('sat.idle.none', 'sat.timer.minutes', 'sat.timer.last.minute', 'sat.suppressed', 'sat.done.flash', 'sat.done.unload',
                   'sat.done.reduced.static', 'sat.pomodoro.phase.done', 'sat.track.dwell', 'sat.track.session', 'sat.track.core', 'sat.idle.end')
RUNTIME_ERRORS = ('ReferenceError:', 'TypeError:', 'Cannot assign', 'Unable to assign', 'is not a type', 'depends on non-bindable')


@unittest.skipUnless(shutil.which('qs'), 'Quickshell is not installed')
class CueFixtureTests(unittest.TestCase):
    def check(self, output, names):
        self.assertIn('CUE_DONE', output, output[-2000:])
        failures = [line for line in output.splitlines() if 'CUE_FAIL' in line]
        self.assertEqual(failures, [])
        for name in names:
            self.assertIn(f'CUE_PASS {name}\n', output + '\n')
        self.assertIn('CUE_ACTIVE 0 []', output)
        self.assertFalse([e for e in RUNTIME_ERRORS if e in output], output[-2000:])

    def test_components(self):
        self.check(cuetest.run('CueTest.qml'), COMPONENT_TESTS)

    def test_adopted_cues_in_the_view(self):
        output = cuetest.run('ViewTest.qml')
        self.check(output, VIEW_TESTS)
        self.assertIn('CUE_CALLS [0,0,0,0]', output)

    def test_satellites(self):
        """DAILY_DRIVER §5: each kind loads only while due, minute wakeups, the gated DONE flash, zero surfaces idle."""
        self.check(cuetest.run('SatTest.qml'), SATELLITE_TESTS)


if __name__ == '__main__':
    unittest.main()
