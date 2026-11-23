"""view/rooms/TaskEntry.js: the Tasks room reads its entry line exactly as the `task` verb does.

Run under Node with the QML `.pragma` line stripped, and compared against core/verbs/tasks.py."""
from datetime import datetime, date, timedelta
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from core.verbs.base import Usage  # noqa: E402
from core.verbs.tasks import resolve_due  # noqa: E402

SOURCE = ROOT / "view/rooms/TaskEntry.js"
WORDS = ["today", "tod", "tomorrow", "tom", "tmr", "mon", "tue", "wed", "thursday", "fri", "sat", "sun", "su",
         "+0d", "+3d", "+2w", "+999d", "2026-11-12", "2026-11-12t09:30", "Fri", "TODAY", "never", "+3m", "12-11"]


@unittest.skipUnless(shutil.which("node"), "needs Node")
class TaskEntryTests(unittest.TestCase):
    def run_js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    @staticmethod
    def js_day(day: date) -> str:
        return f"new Date({day.year}, {day.month - 1}, {day.day})"

    def test_due_words_match_the_task_verb(self):
        # Every weekday as "today", across a month and a year boundary.
        for today in [date(2026, 11, 2) + timedelta(days=n) for n in range(7)] + [date(2026, 12, 29), date(2026, 1, 31)]:
            got = self.run_js(f"{json.dumps(WORDS)}.map(w => resolveDue(w, {self.js_day(today)}))")
            for word, js in zip(WORDS, got):
                try:
                    expected = resolve_due(word, today)
                except Usage:
                    expected = None
                self.assertEqual(js, expected, f"!{word} on {today}")

    def test_parse_splits_text_list_and_due(self):
        today = self.js_day(date(2026, 11, 7))  # a Saturday
        self.assertEqual(self.run_js(f'parse("revise ch 4 @study !fri", {today})'),
                         {"text": "revise ch 4", "list": "study", "due": "2026-11-13", "error": ""})
        self.assertEqual(self.run_js(f'parse("  buy   milk ", {today})'),
                         {"text": "buy milk", "list": None, "due": None, "error": ""})
        # A lone "@" or "!" is text, as in the verb.
        self.assertEqual(self.run_js(f'parse("a ! b @", {today})')["text"], "a ! b @")
        self.assertEqual(self.run_js(f'parse("x !soon", {today})')["error"], "not a due date: !soon")
        self.assertEqual(self.run_js(f'parse("x !fri !sat", {today})')["error"], "one !due per task")
        self.assertEqual(self.run_js(f'parse("x @a @b", {today})')["error"], "one @list per task")

    def test_patina_grows_with_neglect_not_with_colour(self):
        today = self.js_day(date(2026, 11, 9))
        ms = lambda d: int(datetime(d.year, d.month, d.day).timestamp() * 1000)
        cases = [({"done": False, "due": "2026-11-08"}, 1), ({"done": False, "due": "2026-10-30"}, 10),
                 ({"done": True, "due": "2026-10-30"}, 0), ({"done": False, "due": "2026-11-12"}, 0),
                 ({"done": False, "due": None, "created": ms(date(2026, 11, 1))}, 0),
                 ({"done": False, "due": None, "created": ms(date(2026, 10, 1))}, 12), ({"done": False, "due": None}, 0)]
        got = self.run_js(f"{json.dumps([c for c, _ in cases])}.map(t => patina(t, {today}))")
        self.assertEqual(got, [n for _, n in cases])
        self.assertEqual(self.run_js("[patinaShift(0), patinaShift(1), patinaShift(400)]"), [0, 0.85, 2.2])
        sides = self.run_js('["t1", "t2", "t3", "t4", "t1"].map(patinaSide)')
        self.assertTrue(set(sides) <= {1, -1} and sides[0] == sides[4] and len(set(sides)) == 2)

    def test_a_task_finished_today_leaves_its_place_until_midnight(self):
        today = self.js_day(date(2026, 11, 9))
        ms = lambda *a: int(datetime(*a).timestamp() * 1000)
        cases = [{"done": True, "doneAt": ms(2026, 11, 9, 10, 42)}, {"done": True, "doneAt": ms(2026, 11, 8, 23, 59)},
                 {"done": False, "doneAt": None}, {"done": True, "doneAt": None}]
        self.assertEqual(self.run_js(f"{json.dumps(cases)}.map(t => vanishedToday(t, {today}))"), [True, False, False, False])

    def test_labels_and_states(self):
        today = self.js_day(date(2026, 11, 7))  # a Saturday
        cases = {"2026-11-07": ("TODAY", "today"), "2026-11-07T09:30": ("TODAY 09:30", "today"),
                 "2026-11-08": ("TOMORROW", "soon"), "2026-11-11": ("WED", "soon"),
                 "2026-11-14": ("14 NOV", "later"), "2026-11-05": ("05 NOV · 2 D LATE", "overdue"),
                 "2027-01-02": ("02 JAN", "later")}
        got = self.run_js(f"{json.dumps(list(cases))}.map(d => [label(d, {today}), state(d, {today})])")
        self.assertEqual([tuple(pair) for pair in got], list(cases.values()))
        self.assertEqual(self.run_js(f'[label(null, {today}), state("", {today})]'), ["", ""])


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class TaskRowLook(unittest.TestCase):
    """Patina and cut-outs on real rows (tools/cuetest/TasksTest.qml)."""

    def test_patina_and_cutouts(self):
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("TasksTest.qml", timeout=60)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("tasks.patina", "tasks.cutout"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Cannot assign") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
