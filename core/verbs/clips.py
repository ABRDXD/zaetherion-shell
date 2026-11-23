"""clip [words]: opens Clips, filtered by the words. Queries are never kept in history."""
from __future__ import annotations

from core.verbs.base import Result, Verb


async def clip(ctx, words):
    if not words:
        return await ctx.room("clipboard")
    await ctx.core.view.command("open", "clipboard", query=" ".join(words))
    return Result("→ Clips", "info", {"page": "clipboard"})


VERBS = [Verb("clip", "clips", "clip [words]", "opens Clips, filtered by the words", ("clip", "clip invoice"), clip,
              aliases=("clips", "clipboard"), record=False)]
