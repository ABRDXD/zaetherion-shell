"""Timer verbs (CORE.md §8): tim, plus focus and sw at top level."""
from __future__ import annotations

from core.verbs.base import Result, Usage, Verb, duration
from core.verbs.lines import timers_line

USAGE = "tim <25 | 90s | 1h30 | focus [min] | sw | lap | pause | stop>"


def line(ctx) -> Result:
    return Result(timers_line(ctx.core.timers.snapshot()))


async def tim(ctx, words):
    if not words:
        return await ctx.room("timers")
    timers = ctx.core.timers
    verb, rest = words[0].lower(), words[1:]
    if verb == "focus":
        return await focus(ctx, rest)
    if rest:
        raise Usage(USAGE)
    if verb == "sw":
        timers.toggle("stopwatch")
    elif verb == "lap":
        timers.lap()
    elif verb == "pause":
        for kind in timers.running():
            timers.toggle(kind)
    elif verb == "stop":
        running = timers.running()
        timers.ack()
        for kind in running:
            timers.reset(kind)
    else:
        timers.start("countdown", duration(verb))
    return line(ctx)


async def focus(ctx, words):
    if len(words) > 1:
        raise Usage("focus [minutes]")
    ctx.core.timers.start("pomodoro", focus=duration(words[0]) if words else None)
    return line(ctx)


async def sw(ctx, words):
    if words:
        raise Usage("sw takes no arguments")
    ctx.core.timers.toggle("stopwatch")
    return line(ctx)


VERBS = [
    Verb("tim", "timers", USAGE, "countdown, pomodoro and stopwatch; bare opens Timers",
         ("tim 25", "tim 90s", "tim focus 50", "tim sw", "tim lap", "tim pause", "tim stop"), tim, aliases=("timers",)),
    Verb("focus", "timers", "focus [minutes]", "starts a pomodoro, optionally with this focus length", ("focus", "focus 50"), focus),
    Verb("sw", "timers", "sw", "starts or pauses the stopwatch", ("sw",), sw),
]
