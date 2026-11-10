"""Host verbs: wall, theme, settings, update, lock. The panel folds first: host popups open under FART's layer."""
from __future__ import annotations

from core.verbs.base import Result, Usage, Verb

TARGETS = (("wall", "wallpapers", "the host's wallpaper picker"), ("theme", "themes", "the host's themes"),
           ("settings", "settings", "the host's settings"), ("update", "updates", "the host's update page"))


def opener(target: str):
    async def run(ctx, words):
        if words:
            raise Usage("takes no arguments")
        await ctx.fold()
        await ctx.host("hostActions", "open", [target], hold=0)
        return Result(f"opened {target}", "info")
    return run


async def lock(ctx, words):
    if words:
        raise Usage("lock takes no arguments")
    await ctx.fold()
    await ctx.host("power", "lock", hold=0)
    return Result("locked", "info")


VERBS = [*(Verb(name, "host", name, f"opens {label}", (name,), opener(target)) for name, target, label in TARGETS),
         Verb("lock", "host", "lock", "locks the session through the host", ("lock",), lock)]
