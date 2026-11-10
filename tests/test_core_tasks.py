"""Task lists and the todo.json migration (docs/CORE.md §4.2)."""
import json
from pathlib import Path
import tempfile
import unittest

from core_fakes import fakes
from core.errors import OpError
from core.tasks import Tasks

TWELVE = [{"content": f"task {n}", "done": n % 3 == 0} for n in range(12)]


class TaskTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.state = Path(temp.name)
        self.clock = fakes()[0]

    def tasks(self):
        return Tasks(self.clock, self.state)

    def test_twelve_tasks_migrate_in_order(self):
        (self.state / "todo.json").write_text(json.dumps(TWELVE))
        snap = self.tasks().snapshot()
        self.assertEqual(snap["lists"], [{"id": "default", "name": "Tasks"}])
        self.assertEqual([(t["text"], t["done"], t["list"]) for t in snap["tasks"]],
                         [(i["content"], i["done"], "default") for i in TWELVE])
        self.assertEqual(len({t["id"] for t in snap["tasks"]}), 12)
        self.assertEqual(json.loads((self.state / "todo.json").read_text()), TWELVE)
        self.assertEqual((self.state / "tasks.json").stat().st_mode & 0o777, 0o600)

    def test_invalid_todo_is_left_alone(self):
        (self.state / "todo.json").write_text("[broken")
        self.assertEqual(self.tasks().snapshot()["tasks"], [])
        self.assertEqual((self.state / "todo.json").read_text(), "[broken")
        self.assertFalse((self.state / "tasks.json").exists())

    def test_existing_tasks_file_wins(self):
        first = self.tasks()
        first.add("mine")
        (self.state / "todo.json").write_text(json.dumps(TWELVE))
        self.assertEqual([t["text"] for t in self.tasks().snapshot()["tasks"]], ["mine"])

    def test_list_remove_moves_tasks_to_default(self):
        tasks = self.tasks()
        tasks.add("a")
        exams = tasks.list_add("Exams")["list"]["id"]
        tasks.add("b", list=exams, due="2026-11-10")
        tasks.list_remove(exams)
        snap = tasks.snapshot()
        self.assertEqual([(t["text"], t["list"], t["due"]) for t in snap["tasks"]],
                         [("a", "default", None), ("b", "default", "2026-11-10")])
        with self.assertRaises(Exception) as caught:
            tasks.list_remove("default")
        self.assertEqual(caught.exception.code, "conflict")

    def test_remove_then_restore_keeps_id_and_index(self):
        tasks = self.tasks()
        ids = [tasks.add(text)["task"]["id"] for text in "abc"]
        removed = tasks.remove(ids[1])
        self.assertEqual(removed["index"], 1)
        tasks.restore(removed["task"], removed["index"])
        self.assertEqual([t["id"] for t in tasks.snapshot()["tasks"]], ids)

    def test_update_done_due_and_move(self):
        tasks = self.tasks()
        a = tasks.add("a")["task"]["id"]
        tasks.add("b")
        done = tasks.update(a, done=True, due="2026-11-07T09:30")["task"]
        self.assertEqual((done["done"], done["due"]), (True, "2026-11-07T09:30"))
        self.assertIsInstance(done["doneAt"], int)
        self.assertIsNone(tasks.update(a, done=False, due=None)["task"]["doneAt"])
        tasks.move(a, 1)
        self.assertEqual([t["text"] for t in tasks.snapshot()["tasks"]], ["b", "a"])

    def test_rejected_update_preserves_snapshot_and_next_write(self):
        tasks = self.tasks()
        original = tasks.add("original")["task"]
        for bad in ({"due": "invalid"}, {"list": "missing"}):
            with self.assertRaises(OpError):
                tasks.update(original["id"], text="changed", done=True, **bad)
            self.assertEqual(tasks.snapshot()["tasks"], [original])
        tasks.add("another")
        self.assertEqual(self.tasks().snapshot()["tasks"][0], original)

    def test_bad_arguments(self):
        tasks = self.tasks()
        for call in (lambda: tasks.add("   "), lambda: tasks.add("x", due="friday"), lambda: tasks.add("x", due="2026-02-30"),
                     lambda: tasks.add("x" * 1001), lambda: tasks.update("nope", done=True)):
            with self.assertRaises(Exception) as caught:
                call()
            self.assertIn(caught.exception.code, ("bad-args", "not-found"))

    def test_move_with_bad_index_keeps_the_task(self):
        tasks = self.tasks()
        a = tasks.add("a")["task"]["id"]
        tasks.add("b")
        for index in (-1, "1", True, 1.5):
            with self.assertRaises(Exception) as caught:
                tasks.move(a, index)
            self.assertEqual(caught.exception.code, "bad-args")
        tasks.add("c")
        self.assertEqual([t["text"] for t in self.tasks().snapshot()["tasks"]], ["a", "b", "c"])


if __name__ == "__main__":
    unittest.main()
