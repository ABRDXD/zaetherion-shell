"""Approved Settings hierarchy, lifecycle and authoritative writes, fixture-only."""
import os
from pathlib import Path
import shutil
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import cuetest


@unittest.skipUnless(shutil.which('qs'), 'Quickshell is not installed')
class SettingsCutlineTests(unittest.TestCase):
    def test_readings_navigation_and_lifecycle(self):
        # Do not inherit live launch/shortcut flags into this isolated surface.
        env = {key: value for key, value in os.environ.items() if not key.startswith('FART_')}
        env.pop('SETTINGS_CONTEXT', None)
        env['QT_LOGGING_RULES'] = 'qml.debug=true'
        with patch.dict(os.environ, env, clear=True):
            output = cuetest.run('SettingsTest.qml', timeout=25)
        self.assertIn('CUE_DONE', output, output[-5000:])
        self.assertNotIn('CUE_FAIL', output, output[-5000:])
        for name in ('current.value', 'alternatives.recede', 'opening.never.writes',
                     'alternatives.reveal', 'same.value.no.write', 'closed.choices.destroyed', 'choice.returns.focus',
                     'one.authoritative.write', 'no.optimistic.value', 'leaving.dismisses',
                     'custom.rest.has.a.reading', 'unknown.is.not.off', 'compact.contains.value', 'close.cancels.palette',
                     'silent.settles', 'no.hidden.config.lease'):
            self.assertIn('CUE_PASS ' + name, output, output[-5000:])
        for section in ('palette', 'wallpaper', 'presets', 'island', 'notifications', 'clips', 'wifi', 'bluetooth'):
            self.assertIn('CUE_PASS section.' + section, output, output[-5000:])
            self.assertIn('CUE_PASS lease.' + section, output, output[-5000:])
        for failure in ('Binding loop', 'ReferenceError', 'TypeError', 'Unable to assign'):
            self.assertNotIn(failure, output, output[-5000:])


if __name__ == '__main__':
    unittest.main()
