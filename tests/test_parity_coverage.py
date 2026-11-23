"""The parity harness's own bookkeeping (Z226): every op and topic is checked or owed, never both."""
import unittest

from parity.coverage import pending_ops, pending_topics, registered_ops
from parity.scenarios import SCENARIOS, TOPICS


class CoverageTests(unittest.TestCase):
    def test_every_op_is_checked_or_owed(self):
        ops = registered_ops()
        self.assertGreater(len(ops), 90)
        covered = {op for sc in SCENARIOS.values() for op in sc.ops}
        owed = pending_ops()
        self.assertEqual(covered - ops, set(), "scenarios name ops the core doesn't have")
        self.assertEqual(set(owed) - ops, set(), "coverage.py owes ops the core doesn't have")
        self.assertEqual(covered & set(owed), set(), "covered ops still listed as owed: move them out of coverage.py")
        self.assertEqual(ops - covered - set(owed), set(), "new ops with no parity check: add a scenario or owe one")

    def test_every_topic_is_checked_or_owed(self):
        covered = {t for sc in SCENARIOS.values() if sc.name != "protocol_subscribe" for t in sc.topics}
        owed = pending_topics()
        self.assertEqual(covered & set(owed), set())
        self.assertEqual(set(TOPICS) - covered - set(owed), set())
        self.assertEqual((covered | set(owed)) - set(TOPICS), set())

    def test_scenarios_send_what_they_declare(self):
        # Cheap static check: each declared op appears in its scenario's source.
        import inspect
        for sc in SCENARIOS.values():
            source = inspect.getsource(sc.run)
            for op in sc.ops:
                if op in ("hello", "subscribe"):
                    continue
                with self.subTest(scenario=sc.name, op=op):
                    self.assertIn(f'"{op}"', source)

    def test_json_corpus_is_current(self):
        import sys
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
        import json_corpus
        import contextlib
        import io
        with contextlib.redirect_stdout(io.StringIO()) as out:
            code = json_corpus.main(["--check"])
        self.assertEqual(code, 0, out.getvalue())


if __name__ == "__main__":
    unittest.main()
