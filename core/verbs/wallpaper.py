"""wall and theme: FART's own wallpaper and palette sections, and the wallpaper choice from the command line (Z177)."""
from pathlib import Path

from core.verbs.base import Result, Usage, Verb

USAGE = "wall [<name> | list | next | prev | typeset [<name>]]"


async def wall(ctx, words):
    w = ctx.core.wallpaper
    if not words:
        return await ctx.settings("wallpaper")
    if words == ["list"]:
        entries = w.scan()
        if not entries:
            return Result(f"> NO WALLPAPERS · {w.folder}", "info")
        current = w.host["current"]
        return Result("\n".join(("● " if e["path"] == current else "  ") + e["file"] for e in entries), "info")
    if words[0] == "typeset":
        # Z215: a picture redrawn in type, beside it, then shown; about half a minute
        await ctx.core.wallpaper_typeset(name=" ".join(words[1:]) or None)
        return Result("> TYPESET · " + Path(w.host["current"]).name, "ok")
    if words in (["next"], ["prev"]):
        path = w.step(1 if words == ["next"] else -1)
    else:
        path = w.resolve(" ".join(words))
    await ctx.core.wallpaper_choose(path)
    return Result("> WALLPAPER · " + Path(path).name, "ok")


async def theme(ctx, words):
    if words:
        raise Usage("theme takes no arguments; palette <name> chooses one")
    return await ctx.settings("palette")


VERBS = [Verb("wall", "modes", USAGE, "opens FART's wallpaper picker, or sets one by name",
              ("wall", "wall list", "wall next", "wall rain", "wall typeset"), wall),
         Verb("theme", "modes", "theme", "opens FART's palette picker", ("theme",), theme)]
