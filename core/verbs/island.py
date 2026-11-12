"""The island verb (Z155): island [fluid | angular | top | bottom | notch | floating | screen <name> | screen auto]."""
from __future__ import annotations

from core.island import CHOICES
from core.verbs.base import Result, Usage, Verb

USAGE = "island [fluid | angular | top | bottom | notch | floating | screen <name> | screen auto]"
WORDS = {value: key for key, values in CHOICES.items() for value in values}


def line(state: dict) -> str:
    screen = state["screen"] or "focused screen"
    return f"> ISLAND · {state['form'].upper()} · {state['edge'].upper()} · {state['placement'].upper()} · {screen}"


async def island(ctx, words):
    settings = ctx.core.island
    if not words:
        return Result(line(settings.snapshot()), "info")
    first = words[0].lower()
    if first == "screen" and len(words) == 2:
        name = words[1]
        return Result(line(settings.set(screen="" if name.lower() == "auto" else name)))
    if len(words) == 1 and first in WORDS:
        return Result(line(settings.set(**{WORDS[first]: first})))
    raise Usage(USAGE)


VERBS = [
    Verb("island", "modes", USAGE, "sets the island's form, edge, placement or screen for every surface; bare shows them",
         ("island", "island fluid", "island bottom", "island floating", "island screen auto"), island),
]
