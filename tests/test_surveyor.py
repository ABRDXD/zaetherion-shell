"""The surveyor and its archive, run under Quickshell offscreen by tools/cuetest.py. The surveyor in the real rooms
(view/overdrive/Wanderer.qml, docs/OVERDRIVE.md §16): ground in every room, never over a control or text, a measurement
and the field book, a survey error, the footer, release and reduced motion. The archive's tape bookkeeping (§17)."""
import shutil
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import cuetest  # noqa: E402

CHECKS = ('survey.rooms', 'survey.walk', 'survey.hop', 'survey.measure', 'survey.book', 'survey.error', 'survey.footer', 'survey.release')
ARCHIVE_CHECKS = ('archive.spans', 'archive.tape.played', 'archive.tape.wear', 'archive.fieldbook', 'archive.tape.off', 'archive.revision', 'archive.nightlog')
RUNTIME_ERRORS = ('ReferenceError:', 'TypeError:', 'Cannot assign', 'Unable to assign', 'is not a type', 'depends on non-bindable')


@unittest.skipUnless(shutil.which('qs'), 'Quickshell is not installed')
class SurveyorTests(unittest.TestCase):
    def check(self, output, names):
        self.assertIn('CUE_DONE', output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if 'CUE_FAIL' in line], [])
        for name in names:
            self.assertIn(f'CUE_PASS {name}\n', output + '\n')
        self.assertIn('CUE_ACTIVE 0 []', output)
        self.assertFalse([e for e in RUNTIME_ERRORS if e in output], output[-2000:])

    def test_the_surveyor_in_every_room(self):
        self.check(cuetest.run('SurveyorTest.qml', timeout=300), CHECKS)

    def test_the_archive_tape_wears_where_it_is_played(self):
        self.check(cuetest.run('ArchiveTest.qml', timeout=120), ARCHIVE_CHECKS)


if __name__ == '__main__':
    unittest.main()
