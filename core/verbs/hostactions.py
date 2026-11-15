"""settings, update, lock. `settings` is FART's own (Z176, Z208): `settings <tab>` opens that tab; `settings dms` is
the one way left to DMS's window, for what FART has no tab for yet. Host popups fold the panel first: they open
under FART's layer.

`wall` and `theme` used to open the host's pickers; they open FART's own settings now (core/verbs/wallpaper.py, Z177).
"""
from __future__ import annotations

from core.verbs.base import Result, Usage, Verb

TARGETS = (("update", "updates", "the host's update page"),)
# FART's settings tabs, in PreferencesPane's order (tests/test_core_verbs.py keeps them equal).
SECTIONS = ("palette", "wallpaper", "presets", "island", "notifications", "clips", "wifi", "bluetooth")
ALIASES = {"wi-fi": "wifi", "bt": "bluetooth", "notif": "notifications", "clipboard": "clips", "theme": "palette",
           "wall": "wallpaper"}
SETTINGS_USAGE = "settings [" + " | ".join(SECTIONS) + " | dms]"


def opener(target: str):
    async def run(ctx, words):
        if words:
            raise Usage("takes no arguments")
        await ctx.fold()
        await ctx.host("hostActions", "open", [target], hold=0)
        return Result(f"opened {target}", "info")
    return run


async def settings(ctx, words):
    if not words:
        return await ctx.settings(SECTIONS[0])
    if len(words) == 1 and words[0].lower() == "dms":
        await ctx.fold()
        await ctx.host("hostActions", "open", ["settings"], hold=0)
        return Result("opened DMS's settings", "info")
    section = ALIASES.get(words[0].lower(), words[0].lower()) if len(words) == 1 else ""
    if section not in SECTIONS:
        raise Usage(SETTINGS_USAGE)
    return await ctx.settings(section)


async def lock(ctx, words):
    if words:
        raise Usage("lock takes no arguments")
    await ctx.fold()
    await ctx.host("power", "lock", hold=0)
    return Result("locked", "info")


VERBS = [Verb("settings", "modes", SETTINGS_USAGE, "opens FART's settings, at a tab if named; `settings dms` opens DMS's own",
              ("settings", "settings island", "settings wifi", "settings dms"), settings),
         *(Verb(name, "host", name, f"opens {label}", (name,), opener(target)) for name, target, label in TARGETS),
         Verb("lock", "host", "lock", "locks the session through the host", ("lock",), lock)]
