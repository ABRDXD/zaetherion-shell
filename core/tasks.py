"""Task lists with due dates; the version 1 todo.json migrates once into the default list (docs/CORE.md §4)."""
from __future__ import annotations

import copy
from datetime import datetime
import logging
import os
from pathlib import Path
import re

from core.errors import OpError, bad_args
from core.store import publish_new, read_json, write_json

log = logging.getLogger("fart.tasks")
DEFAULT = "default"
MAX_TEXT = 1000
MAX_NAME = 64
DUE = re.compile(r"^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2})?$")


def new_id(prefix: str) -> str:
    return prefix + os.urandom(4).hex()


def clean_text(text, limit=MAX_TEXT, name="text") -> str:
    if not isinstance(text, str) or not text.strip():
        raise bad_args(f"{name} must be non-empty text")
    text = text.strip()
    if len(text) > limit:
        raise bad_args(f"{name} is longer than {limit} characters")
    return text


def clean_due(due):
    if due is None:
        return None
    if not isinstance(due, str) or not DUE.match(due):
        raise bad_args("due must be YYYY-MM-DD or YYYY-MM-DDTHH:MM")
    try:
        datetime.fromisoformat(due)
    except ValueError as error:
        raise bad_args("due is not a real date") from error
    return due


def empty() -> dict:
    return {"version": 1, "lists": [{"id": DEFAULT, "name": "Tasks"}], "tasks": []}


def migrate_todo(items) -> dict:
    state = empty()
    for item in items:
        if isinstance(item, dict) and isinstance(item.get("content"), str) and item["content"].strip():
            state["tasks"].append({"id": new_id("t"), "list": DEFAULT, "text": item["content"].strip()[:MAX_TEXT],
                                   "done": item.get("done") is True, "due": None, "created": None, "doneAt": None})
    return state


class Tasks:
    def __init__(self, clock, state_dir: Path):
        self.clock = clock
        self.path = state_dir / "tasks.json"
        self.todo_path = state_dir / "todo.json"
        self.on_change = lambda: None
        self.state = self._load()

    def _load(self) -> dict:
        try:
            state = read_json(self.path)
        except ValueError:
            log.error("tasks.json is invalid; kept aside as tasks.json.invalid")
            publish_new(self.path.with_name("tasks.json.invalid"), self.path.read_text())
            return self._fresh(empty())
        if isinstance(state, dict) and isinstance(state.get("tasks"), list):
            if not any(entry.get("id") == DEFAULT for entry in state.get("lists") or []):
                state["lists"] = [{"id": DEFAULT, "name": "Tasks"}, *(state.get("lists") or [])]
            return state
        try:
            todo = read_json(self.todo_path)
        except ValueError:
            log.error("todo.json is invalid; not migrated and left untouched")
            return empty()
        if not isinstance(todo, list):
            return self._fresh(empty())
        state = migrate_todo(todo)
        if not publish_new(self.path, state):  # a concurrent writer won; take its file
            return read_json(self.path)
        log.info("migrated %d tasks from todo.json into the default list", len(state["tasks"]))
        return state

    def _fresh(self, state: dict) -> dict:
        write_json(self.path, state)
        return state

    def _commit(self):
        write_json(self.path, self.state)
        self.on_change()

    def snapshot(self) -> dict:
        return {"lists": copy.deepcopy(self.state["lists"]), "tasks": copy.deepcopy(self.state["tasks"])}

    def summary(self) -> dict:
        tasks = self.state["tasks"]
        return {"lists": len(self.state["lists"]), "open": sum(not t["done"] for t in tasks), "done": sum(t["done"] for t in tasks)}

    # Helpers

    def _list(self, list_id) -> dict:
        found = next((entry for entry in self.state["lists"] if entry["id"] == list_id), None)
        if not found:
            raise OpError("not-found", f"no list {list_id!r}")
        return found

    def _task(self, task_id) -> tuple[int, dict]:
        found = next(((i, t) for i, t in enumerate(self.state["tasks"]) if t["id"] == task_id), None)
        if not found:
            raise OpError("not-found", f"no task {task_id!r}")
        return found

    def _members(self, list_id) -> list[int]:
        return [i for i, t in enumerate(self.state["tasks"]) if t["list"] == list_id]

    @staticmethod
    def _check_index(index):
        if index is not None and (isinstance(index, bool) or not isinstance(index, int) or index < 0):
            raise bad_args("index must be a non-negative integer")

    def _insert(self, task: dict, index=None):
        members = self._members(task["list"])
        self._check_index(index)
        if index is not None and index < len(members):
            self.state["tasks"].insert(members[index], task)
        else:
            self.state["tasks"].insert(members[-1] + 1 if members else len(self.state["tasks"]), task)

    def _index_in_list(self, task: dict) -> int:
        return [self.state["tasks"][i]["id"] for i in self._members(task["list"])].index(task["id"])

    def _now_ms(self) -> int:
        return round(self.clock.now().real * 1000)

    # Operations (docs/CORE.md §2.4)

    def add(self, text, list=None, due=None, index=None):
        list_id = self._list(list or DEFAULT)["id"]
        task = {"id": new_id("t"), "list": list_id, "text": clean_text(text), "done": False,
                "due": clean_due(due), "created": self._now_ms(), "doneAt": None}
        self._insert(task, index)
        self._commit()
        return {"task": copy.deepcopy(task)}

    def done_between(self, start_ms: int, end_ms: int) -> int:
        """How many tasks were finished between two moments (the session debrief): a count, nothing they say."""
        return sum(1 for t in self.state["tasks"] if t["done"] and isinstance(t.get("doneAt"), int) and start_ms <= t["doneAt"] <= end_ms)

    def update(self, id, text=None, done=None, due=..., list=None):
        position, original = self._task(id)
        task = original.copy()
        if text is not None:
            task["text"] = clean_text(text)
        if done is not None:
            if not isinstance(done, bool):
                raise bad_args("done must be true or false")
            if done != task["done"]:
                task["done"], task["doneAt"] = done, self._now_ms() if done else None
        if due is not ...:
            task["due"] = clean_due(due)
        if list is not None and list != task["list"]:
            self._list(list)
            del self.state["tasks"][position]
            task["list"] = list
            self._insert(task)
        else:
            self.state["tasks"][position] = task
        self._commit()
        return {"task": copy.deepcopy(task)}

    def move(self, id, index):
        position, task = self._task(id)
        # Validate before removing, so a bad index cannot drop the task.
        self._check_index(index)
        del self.state["tasks"][position]
        self._insert(task, index)
        self._commit()
        return {"task": copy.deepcopy(task)}

    def remove(self, id):
        position, task = self._task(id)
        index = self._index_in_list(task)
        del self.state["tasks"][position]
        self._commit()
        return {"task": copy.deepcopy(task), "index": index}

    def restore(self, task, index=None):
        if not isinstance(task, dict) or not isinstance(task.get("id"), str) or not re.fullmatch(r"t[0-9a-f]{8}", task["id"]):
            raise bad_args("task must be a removed task")
        if any(t["id"] == task["id"] for t in self.state["tasks"]):
            raise OpError("conflict", "that task still exists")
        list_id = task.get("list") if any(e["id"] == task.get("list") for e in self.state["lists"]) else DEFAULT
        restored = {"id": task["id"], "list": list_id, "text": clean_text(task.get("text")), "done": task.get("done") is True,
                    "due": clean_due(task.get("due")), "created": task.get("created") if isinstance(task.get("created"), int) else None,
                    "doneAt": task.get("doneAt") if isinstance(task.get("doneAt"), int) else None}
        self._insert(restored, index)
        self._commit()
        return {"task": copy.deepcopy(restored)}

    def list_add(self, name):
        entry = {"id": new_id("l"), "name": clean_text(name, MAX_NAME, "name")}
        self.state["lists"].append(entry)
        self._commit()
        return {"list": dict(entry)}

    def list_rename(self, id, name):
        entry = self._list(id)
        entry["name"] = clean_text(name, MAX_NAME, "name")
        self._commit()
        return {"list": dict(entry)}

    def list_remove(self, id):
        if id == DEFAULT:
            raise OpError("conflict", "the default list cannot be removed")
        entry = self._list(id)
        moved = [t for t in self.state["tasks"] if t["list"] == id]
        self.state["tasks"] = [t for t in self.state["tasks"] if t["list"] != id]
        self.state["lists"].remove(entry)
        for task in moved:
            task["list"] = DEFAULT
            self._insert(task)
        self._commit()
        return {}
