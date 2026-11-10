"""System verbs: vol, bri, wifi, bt, power (docs/M5-COMMAND.md §2). Each acts through the view's adapter."""
from __future__ import annotations

from core.errors import OpError
from core.verbs.base import Result, Usage, Verb, delta, percent, switch

MIXER = {"lease": "mixer", "ready": "output"}
BRIGHTNESS = {"lease": "brightness", "ready": "brightness.available"}
PROFILES = {"perf": "performance", "performance": "performance", "bal": "balanced", "balanced": "balanced",
            "save": "power-saver", "saver": "power-saver", "power-saver": "power-saver"}


async def vol(ctx, words):
    """Levels exist only while the mixer lease binds the default sink, so each call holds it briefly."""
    if not words:
        return await ctx.room("devices")
    if len(words) != 1:
        raise Usage("vol <0-100 | +n | -n>")
    step = delta(words[0])
    if step is None:
        level = percent(words[0])
    else:
        # Lingers so the set below finds the sink still bound.
        current = await ctx.host("audio", read="output", hold=0, linger=0.5, **MIXER)
        level = max(0, min(100, round(float(current["volume"]) * 100) + step))
    out = await ctx.host("audio", "setVolume", [{"$": "output.id"}, level / 100], read="output", **MIXER) or {}
    muted = " (muted)" if out.get("muted") is True else ""
    return Result(f"{out.get('name') or 'output'} {level}%{muted}", data={"level": level})


async def bri(ctx, words):
    """The host reports brightness only under the brightness lease, and its setter needs that report."""
    if not words:
        return await ctx.room("devices")
    if len(words) != 1:
        raise Usage("bri <0-100 | +n | -n>")
    step = delta(words[0])
    if step is None:
        level = percent(words[0])
    else:
        current = await ctx.host("power", read="brightness", hold=0, linger=0.5, **BRIGHTNESS)
        level = max(0, min(100, round(float(current["level"]) * 100) + step))
    await ctx.host("power", "setBrightness", [level / 100], **BRIGHTNESS)
    return Result(f"brightness {level}%", data={"level": level})


def toggle_verb(domain: str, method: str, label: str):
    async def run(ctx, words):
        if not words:
            return await ctx.room("devices")
        if len(words) != 1:
            raise Usage(f"{label.lower()} on | off")
        on = switch(words[0])
        await ctx.host(domain, method, [on], hold=0)
        return Result(f"{label} {'on' if on else 'off'}", data={"on": on})
    return run


async def power(ctx, words):
    if not words:
        return await ctx.room("devices")
    if len(words) != 1 or words[0].lower() not in PROFILES:
        raise Usage("power perf | bal | save")
    profile = PROFILES[words[0].lower()]
    offered = await ctx.host("power", read="profiles", hold=0) or []
    if profile not in offered:
        raise OpError("unavailable", f"the host offers {', '.join(offered) or 'no power profiles'}")
    await ctx.host("power", "setProfile", [profile], hold=0)
    return Result(f"power {profile}", data={"profile": profile})


VERBS = [
    Verb("vol", "system", "vol <0-100 | +n | -n>", "output volume; bare opens Devices", ("vol 40", "vol +5", "vol -10"), vol),
    Verb("bri", "system", "bri <0-100 | +n | -n>", "screen brightness; bare opens Devices", ("bri 70", "bri -10"), bri),
    Verb("wifi", "system", "wifi [on | off]", "Wi-Fi radio; bare opens Devices", ("wifi off", "wifi on"),
         toggle_verb("network", "setWifiEnabled", "Wi-Fi")),
    Verb("bt", "system", "bt [on | off]", "Bluetooth; bare opens Devices", ("bt on", "bt off"),
         toggle_verb("bluetooth", "setEnabled", "Bluetooth"), aliases=("bluetooth",)),
    Verb("power", "system", "power [perf | bal | save]", "power profile; bare opens Devices", ("power perf", "power save"), power),
]
