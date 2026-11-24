"""Three Python-core faults the C++ port found (Z226 stage 1, 23 Nov), fixed in both cores (24 Nov):
a non-object island.json stopped the core from starting; `^...$` with re.match let a name end in "\\n";
timer.configure kept a pomodoro change it then refused."""
import json
import tempfile
import unittest
from pathlib import Path

import core_fakes  # noqa: F401  (puts the repository on sys.path)
from core.discovery import Discovery
from core.errors import OpError
from core.hostcalls import HostCalls
from core.island import DEFAULTS, Island
from core.sessions import Sessions
from core.tasks import clean_due
from core.timers import Timers


class StrictInputTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.dir = Path(temp.name)

    def test_island_file_that_is_not_an_object_gives_defaults(self):
        for text in ("[1]", "5", '"angular"', "true"):
            (self.dir / "island.json").write_text(text)
            self.assertEqual(Island(self.dir).snapshot(), DEFAULTS, text)

    def test_no_name_or_date_may_end_in_a_newline(self):
        clock, scheduler, _, host = core_fakes.fakes()
        sessions = Sessions(clock, scheduler, host, self.dir)
        with self.assertRaises(OpError):
            sessions.start("nap\n", 600)
        with self.assertRaises(OpError) as caught:
            clean_due("2026-11-25\n")
        self.assertIn("YYYY-MM-DD", str(caught.exception))
        self.assertEqual(clean_due("2026-11-25"), "2026-11-25")
        discovery = Discovery(self.dir, clock, {})
        with self.assertRaises(OpError):
            discovery.bump("rooms\n")
        discovery.bump("rooms")
        for path in ("state\n", "a.b\n"):
            with self.assertRaises(OpError, msg=repr(path)):
                HostCalls._check("audio", next(iter(_calls("audio"))), [], None, path, None)

    def test_a_refused_configure_changes_nothing(self):
        clock, scheduler, _, host = core_fakes.fakes()
        timers = Timers(clock, scheduler, host, self.dir)
        before = timers.snapshot()
        with self.assertRaises(OpError):
            timers.configure(pomodoro={"focus": 600}, sound="yes")
        self.assertEqual(timers.snapshot(), before)
        timers.configure(sound=False)  # the next commit writes only what was asked
        saved = json.loads((self.dir / "timers.json").read_text())
        self.assertNotEqual(saved["config"]["pomodoro"]["focus"], 600)
        self.assertIs(saved["config"]["sound"], False)


def _calls(domain):
    from core.hostcalls import CALLS
    return CALLS[domain]


if __name__ == "__main__":
    unittest.main()
