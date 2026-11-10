"""What a verb is, what it returns, and the small parsers verbs share (docs/M5-COMMAND.md §2)."""
from __future__ import annotations

from dataclasses import dataclass, field
import re
from typing import Awaitable, Callable


class Usage(Exception):
    """The line does not parse. The command line shows the message; the CLI exits 2."""


@dataclass
class Result:
    line: str
    tone: str = "ok"  # ok | info | error
    data: dict | None = None


@dataclass(frozen=True)
class Verb:
    name: str
    domain: str
    usage: str
    summary: str
    examples: tuple[str, ...]
    run: Callable[..., Awaitable[Result]]  # run(context, words)
    aliases: tuple[str, ...] = field(default=())
    record: bool = True  # kept in history (clip queries are not)


def percent(text: str) -> int:
    """40, 40% → 40, within 0..100."""
    match = re.fullmatch(r"(\d{1,3})%?", text)
    if not match or int(match[1]) > 100:
        raise Usage(f"not a level: {text!r} (0 to 100)")
    return int(match[1])


def delta(text: str) -> int | None:
    """+5, -10, +5% → a signed step, or None when the word is not a step."""
    match = re.fullmatch(r"([+-])(\d{1,3})%?", text)
    if not match:
        return None
    step = int(match[2])
    if step > 100:
        raise Usage(f"not a step: {text!r} (up to 100)")
    return step if match[1] == "+" else -step


def switch(text: str) -> bool:
    lowered = text.lower()
    if lowered in ("on", "1", "yes"):
        return True
    if lowered in ("off", "0", "no"):
        return False
    raise Usage(f"say on or off, not {text!r}")


def duration(text: str, bare_minutes: bool = True) -> float:
    """25 = minutes; 90s, 25m, 1h30, 2h."""
    if re.fullmatch(r"\d+", text):
        return int(text) * (60 if bare_minutes else 1)
    match = re.fullmatch(r"(?:(?P<h>\d+)h)?(?:(?P<m>\d+)m?)?(?:(?P<s>\d+)s)?", text)
    if not match or not any(match.groups()):
        raise Usage(f"not a duration: {text!r} (try 25, 90s, 25m or 1h30)")
    return int(match["h"] or 0) * 3600 + int(match["m"] or 0) * 60 + int(match["s"] or 0)


def clock(seconds: float) -> str:
    seconds = max(0, round(seconds))
    hours, rest = divmod(seconds, 3600)
    return (f"{hours}:" if hours else "") + f"{rest // 60:0{2 if hours else 1}d}:{rest % 60:02d}"
