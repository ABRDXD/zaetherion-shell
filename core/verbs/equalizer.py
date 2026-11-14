"""The equaliser verb (Z173): eq [on | off | mono | stereo | <preset> | <band> <gain>]. Bare shows it."""
from __future__ import annotations

from core import eq_chain
from core.verbs.base import Result, Usage, Verb

USAGE = "eq [on | off | mono | stereo | " + " | ".join(p.lower() for p in eq_chain.PRESETS) + " | <band 1-10> <dB>]"


def line(state: dict) -> str:
    if not state["available"]:
        return f"> EQ · UNAVAILABLE · {state['reason']}"
    status = {"on": "ON", "off": "OFF", "starting": "STARTING", "retrying": "RETRYING", "failed": "FAILED"}[state["status"]]
    gains = " ".join(f"{g:+d}" if g else "0" for g in state["bands"])
    error = f" · {state['error']}" if state["error"] else ""
    return f"> EQ · {status} · {state['preset'].upper()} · {'MONO' if state['mono'] else 'STEREO'} · {gains}{error}"


async def eq(ctx, words):
    settings = ctx.core.equalizer
    if not words:
        return Result(line(settings.snapshot()), "info")
    first = words[0].lower()
    if len(words) == 1:
        if first in ("on", "off"):
            return Result(line(settings.set_on(first == "on")))
        if first in ("mono", "stereo"):
            return Result(line(settings.set_mono(first == "mono")))
        if eq_chain.preset_named(first):
            return Result(line(settings.apply_preset(first)))
    if len(words) == 2 and first.isdigit() and 1 <= int(first) <= len(eq_chain.FREQUENCIES):
        try:
            gain = int(words[1])
        except ValueError:
            raise Usage(f"not a gain in dB: {words[1]!r}") from None
        return Result(line(settings.set_band(int(first) - 1, gain)))
    raise Usage(USAGE)


VERBS = [
    Verb("eq", "modes", USAGE, "switches the equaliser, mono or a preset, or sets one band; bare shows it",
         ("eq", "eq on", "eq mono", "eq bass", "eq 1 +4"), eq),
]
