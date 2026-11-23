"""Room verbs: a bare room name opens it (tim, task and clip open theirs when bare, in their own modules).

`go <name>` flies anywhere in the orbit: a room by name, short name or number (00–08) flies there, as a
switch does; any other words name a moon in a room's system (`go wifi`, `go timers stopwatch`), and the
view opens the orbit and keys that moon. A bare `go` opens the orbit.
"""
from __future__ import annotations

from core.verbs.base import Usage, Verb

ROOMS = (("home", "home", ()), ("med", "media", ("media",)), ("perf", "performance", ("performance",)),
         ("ws", "workspaces", ("workspaces",)), ("dev", "devices", ("devices",)),
         ("inbox", "notifications", ("notifications",)),
         ("codex", "codex", ("keys", "elements", "keybinds", "periodic")))


def opener(page: str):
    async def run(ctx, words):
        if words:
            raise Usage(f"{page} takes no arguments")
        return await ctx.room(page)
    return run


VERBS = [Verb(name, "rooms", name, f"opens {page.capitalize()}", (name,), opener(page), aliases=aliases)
         for name, page, aliases in ROOMS]


# Every word that names a room for `go`: the page id, its labels and short names, and its number.
PAGES = ("home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex")
GO_WORDS = {"med": "media", "perf": "performance", "ws": "workspaces", "dev": "devices", "task": "tasks", "tim": "timers",
            "clip": "clipboard", "clips": "clipboard", "inbox": "notifications", "keys": "codex", "elements": "codex"}


def go_room(word: str) -> str | None:
    """The page a single word names: an id, a short name, a number, or a unique prefix of an id."""
    word = word.lower()
    if word.isdigit() and int(word) < len(PAGES):
        return PAGES[int(word)]
    if word in PAGES:
        return word
    if word in GO_WORDS:
        return GO_WORDS[word]
    matches = [p for p in PAGES if p.startswith(word)] if len(word) >= 3 else []
    return matches[0] if len(matches) == 1 else None


async def go(ctx, words):
    if not words:
        return await ctx.orbit("")
    page = go_room(words[0]) if len(words) == 1 else None
    if page:
        return await ctx.room(page)
    return await ctx.orbit(" ".join(words)[:64])


VERBS.append(Verb("go", "rooms", "go [room | moon]", "flies through the orbit to a room or a moon",
                  ("go", "go 5", "go timers", "go wifi", "go timers stopwatch"), go))
