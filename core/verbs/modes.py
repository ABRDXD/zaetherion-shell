"""Mode and session verbs: overdrive [20m | sticky | off], silent, session."""
from __future__ import annotations

from core.verbs.base import Result, Usage, Verb, duration
from core.verbs.lines import overdrive_line, session_line
from core.sessions import PRESETS


async def overdrive(ctx, words):
    od = ctx.core.overdrive
    if len(words) > 1:
        raise Usage("overdrive [20m | sticky | off]")
    if not words:
        return Result(overdrive_line(od.snapshot(), ctx.now().real), "info")
    word = words[0].lower()
    if word == "off":
        snap = od.release()
    elif word == "sticky":
        snap = od.request("sticky")
    else:
        snap = od.request("timed", duration(word))
    return Result(overdrive_line(snap, ctx.now().real))


async def silent(ctx, words):
    if words:
        raise Usage("silent takes no arguments")
    return Result(overdrive_line(ctx.core.overdrive.release(), ctx.now().real))


async def session(ctx, words):
    sessions = ctx.core.sessions
    if not words:
        return Result(session_line(sessions.snapshot(), ctx.now().real), "info")
    if [w.lower() for w in words] == ["end"]:
        return Result(session_line(sessions.end(), ctx.now().real))
    if len(words) == 1 and words[0].lower() in PRESETS:
        return Result(session_line(sessions.start(words[0].lower()), ctx.now().real))
    if len(words) != 2:
        raise Usage("session <preset> [duration] | session end (presets: " + ", ".join(PRESETS) + ")")
    return Result(session_line(sessions.start(words[0].lower(), duration(words[1])), ctx.now().real))


VERBS = [
    Verb("overdrive", "modes", "overdrive [20m | sticky | off]", "requests or releases Overdrive; bare shows it",
         ("overdrive", "overdrive 20m", "overdrive sticky", "overdrive off"), overdrive),
    Verb("silent", "modes", "silent", "releases Overdrive", ("silent",), silent),
    Verb("session", "modes", "session <preset> [duration] | session end",
         "starts or ends a study session (a preset's own length if none is given); bare shows it",
         ("session focus", "session pyq 2h", "session end"), session),
]
