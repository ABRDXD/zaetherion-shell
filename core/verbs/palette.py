"""The palette verb shares the settings picker's persisted selection."""
from core.verbs.base import Result, Verb

USAGE = "palette [<name> | list]"


async def palette(ctx, words):
    settings = ctx.core.palette
    if words == ["list"]:
        return Result("\n".join(f"{entry['id']} · {entry['name']}" for entry in settings.listing()), "info")
    if words:
        settings.choose(" ".join(words))
    return Result("> PALETTE · " + settings.entries[settings.name]["name"], "info" if not words else "ok")


VERBS = [Verb("palette", "modes", USAGE, "chooses the palette for every surface; list shows installed palettes",
              ("palette", "palette list", "palette Amoled Black"), palette)]
