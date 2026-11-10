"""Media verbs: play, next, prev, lyr, out <device>. Playback is acted on only through the view's adapter."""
from __future__ import annotations

from core.errors import OpError
from core.verbs.base import Result, Usage, Verb

PLAYER = {"ready": "active", "hold": 0}


def track(player) -> str:
    if not isinstance(player, dict):
        return ""
    return " — ".join(p for p in (player.get("title"), player.get("artist")) if p)


def simple(method: str, label: str):
    async def run(ctx, words):
        if words:
            raise Usage(f"{label} takes no arguments")
        player = await ctx.host("media", method, read="active", **PLAYER)
        return Result(f"{label}" + (f" · {track(player)}" if track(player) and method == "togglePlaying" else ""))
    return run


async def lyr(ctx, words):
    if words:
        raise Usage("lyr takes no arguments")
    return await ctx.room("media")  # M6 adds the lyrics subpanel


def pick(devices: list, query: str) -> dict:
    """Exact name, else unique prefix, else unique substring; case-insensitive."""
    query = query.lower()
    for test in (lambda n: n == query, lambda n: n.startswith(query), lambda n: query in n):
        found = [d for d in devices if test(str(d.get("name", "")).lower())]
        if len(found) == 1:
            return found[0]
        if len(found) > 1:
            raise OpError("conflict", f"{query!r} matches {', '.join(d['name'] for d in found)}")
    raise OpError("not-found", f"no output like {query!r}; outputs: {', '.join(d.get('name', '?') for d in devices) or 'none'}")


async def out(ctx, words):
    outputs = await ctx.host("audio", read="outputs", hold=0) or []
    if not words:
        names = [("*" if d.get("isDefault") else "") + d.get("name", "?") for d in outputs]
        return Result("outputs: " + (", ".join(names) or "none"), "info", {"outputs": outputs})
    device = pick(outputs, " ".join(words))
    await ctx.host("audio", "setDefault", ["output", device["id"]], hold=0)
    return Result(f"output → {device['name']}", data={"id": device["id"]})


VERBS = [
    Verb("play", "media", "play", "plays or pauses the active player", ("play",), simple("togglePlaying", "play/pause"), aliases=("pause",)),
    Verb("next", "media", "next", "next track", ("next",), simple("next", "next track")),
    Verb("prev", "media", "prev", "previous track", ("prev",), simple("previous", "previous track")),
    Verb("lyr", "media", "lyr", "opens Media for the lyrics", ("lyr",), lyr, aliases=("lyrics",)),
    Verb("out", "media", "out [device]", "default output; bare lists them", ("out", "out headset"), out),
]
