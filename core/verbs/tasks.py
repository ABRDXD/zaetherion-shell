"""task <text> [@list] [!due]: adds a task. The core receives a resolved date (CORE.md §4.1)."""
from __future__ import annotations

from datetime import date, datetime, timedelta
import re

from core.errors import OpError
from core.verbs.base import Result, Usage, Verb

USAGE = "task <text> [@list] [!today | !tomorrow | !fri | !+3d | !2026-11-12]"
WEEKDAYS = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")


def resolve_due(word: str, today: date) -> str:
    word = word.lower()
    if word in ("today", "tod"):
        return today.isoformat()
    if word in ("tomorrow", "tom", "tmr"):
        return (today + timedelta(days=1)).isoformat()
    for index, name in enumerate(WEEKDAYS):
        if len(word) >= 3 and name.startswith(word):
            # The next one: !fri on a Friday is a week away (!today is today).
            return (today + timedelta(days=(index - today.weekday() - 1) % 7 + 1)).isoformat()
    match = re.fullmatch(r"\+(\d{1,3})([dw])", word)
    if match:
        return (today + timedelta(days=int(match[1]) * (7 if match[2] == "w" else 1))).isoformat()
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}(t\d{2}:\d{2})?", word):
        return word.upper()  # validated by the task store
    raise Usage(f"not a due date: !{word} (try !today, !tomorrow, !fri, !+3d or !2026-11-12)")


def due_label(due: str) -> str:
    moment = datetime.fromisoformat(due)
    return moment.strftime("%a %-d %b" + (" %H:%M" if "T" in due else ""))


async def task(ctx, words):
    if not words:
        return await ctx.room("tasks")
    tasks = ctx.core.tasks
    text, list_name, due = [], None, None
    for word in words:
        if word.startswith("@") and len(word) > 1:
            if list_name is not None:
                raise Usage("one @list per task")
            list_name = word[1:]
        elif word.startswith("!") and len(word) > 1:
            if due is not None:
                raise Usage("one !due per task")
            due = resolve_due(word[1:], datetime.fromtimestamp(ctx.now().real).date())
        else:
            text.append(word)
    if not text:
        raise Usage(USAGE)
    lists = tasks.snapshot()["lists"]
    target = lists[0]
    if list_name is not None:
        found = [l for l in lists if l["name"].lower() == list_name.lower() or l["id"] == list_name]
        if not found:
            raise OpError("not-found", f"no list named {list_name!r}; lists: {', '.join(l['name'] for l in lists)}")
        target = found[0]
    added = tasks.add(" ".join(text), target["id"], due)["task"]
    return Result(f"added to {target['name']}" + (f", due {due_label(added['due'])}" if added["due"] else ""),
                  data={"id": added["id"], "list": target["id"], "due": added["due"]})


VERBS = [Verb("task", "tasks", USAGE, "adds a task; bare opens Tasks",
              ("task buy milk", "task revise ch 4 @study !fri", "task call home !+3d"), task, aliases=("tasks",))]
