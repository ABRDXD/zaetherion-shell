"""The island verb (Z155, Z201): island [fluid | angular | top | bottom | notch | floating | screen <name> | screen auto
| rest <today|a|b|c> | rest <power|network|battery|inbox> <mode>]."""
from __future__ import annotations

from core.island import CHOICES, REST_MODES, REST_PRESETS
from core.verbs.base import Result, Usage, Verb

USAGE = ("island [fluid | angular | top | bottom | notch | floating | screen <name> | screen auto"
         " | rest <today|a|b|c> | rest <power|network|battery|inbox> <mode>]")
WORDS = {value: key for key, values in CHOICES.items() for value in values}


def line(state: dict) -> str:
    screen = state["screen"] or "focused screen"
    rest = " ".join(f"{item}:{mode}" for item, mode in state["rest"].items())
    return f"> ISLAND · {state['form'].upper()} · {state['edge'].upper()} · {state['placement'].upper()} · {screen} · REST {rest.upper()}"


async def island(ctx, words):
    settings = ctx.core.island
    if not words:
        return Result(line(settings.snapshot()), "info")
    first = words[0].lower()
    if first == "screen" and len(words) == 2:
        name = words[1]
        return Result(line(settings.set(screen="" if name.lower() == "auto" else name)))
    if first == "rest" and len(words) == 2 and words[1].lower() in REST_PRESETS:
        return Result(line(settings.set_rest(**REST_PRESETS[words[1].lower()])))
    if first == "rest" and len(words) == 3 and words[1].lower() in REST_MODES:
        return Result(line(settings.set_rest(**{words[1].lower(): words[2].lower()})))
    if len(words) == 1 and first in WORDS:
        return Result(line(settings.set(**{WORDS[first]: first})))
    raise Usage(USAGE)


VERBS = [
    Verb("island", "modes", USAGE, "sets the island's form, edge, placement or screen for every surface; bare shows them",
         ("island", "island fluid", "island bottom", "island floating", "island screen auto", "island rest b",
          "island rest battery matters"), island),
]
