"""look: saved looks from the command line (Z180). `look` alone opens FART's presets section."""
from core.verbs.base import Result, Usage, Verb

USAGE = "look [<name> | list | save <name> | delete <name>]"
PARTS = {"palette": "palette", "islandForm": "island", "wallpaper": "wallpaper", "hostTheme": "desktop theme"}


async def look(ctx, words):
    core = ctx.core
    if not words:
        return await ctx.settings("presets")
    if words == ["list"]:
        looks = core.presets_snapshot()["looks"]
        if not looks:
            return Result("> NO PRESETS · look save <name> keeps the current look", "info")
        return Result("\n".join(entry["name"] + (" · missing " + ", ".join(PARTS[m] for m in entry["missing"])
                                                 if entry["missing"] else "") for entry in looks), "info")
    if words[0] in ("save", "delete"):
        if len(words) < 2:
            raise Usage(f"look {words[0]} <name>")
        name = " ".join(words[1:])
        if words[0] == "save":
            core.presets.save(name, core.current_look())
            return Result(f"> SAVED LOOK · {name}", "ok")
        core.presets.delete(name)
        return Result(f"> DELETED LOOK · {name}", "ok")
    result = await core.presets_apply(" ".join(words))
    skipped = ", ".join(PARTS[s] for s in result["skipped"])
    return Result(f"> LOOK · {result['name']}" + (f" · skipped {skipped}" if skipped else ""), "ok")


VERBS = [Verb("look", "modes", USAGE, "applies a saved look (wallpaper, palette, island, desktop theme); alone opens presets",
              ("look", "look list", "look save evening", "look evening"), look)]
