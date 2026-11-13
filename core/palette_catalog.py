"""Read installed palettes without importing or modifying either host's settings."""
from __future__ import annotations

import re
from pathlib import Path

HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
TEXT_CONTRAST = 4.5
DEFAULT = "dms:amoledBlack"
DEFAULT_COLORS = dict(background="#000000", surface="#000000", surfaceRaised="#000000", text="#e6f0ff",
                      textMuted="#999999", textFaint="#999999", line="#555555", accent="#ffffff",
                      warm="#ffcc00", danger="#dd0000", success="#ffffff", highlight="#ffffff")
# Original studies, not a new default. The owner selects which to keep (OPEN 20).
STUDIES = {"Crimson": "#ff657a", "Ice": "#8edfff", "Acid": "#c4f56a", "Amber": "#ffc66d",
           "Violet": "#c6a0ff", "Mono": "#e8e8e8", "Mint": "#83ecc3", "Rose": "#ff9ed0",
           "Cobalt": "#93b7ff", "Copper": "#eeb08c"}


def luminance(color: str) -> float:
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in channels]
    return sum(v * weight for v, weight in zip(linear, (.2126, .7152, .0722)))


def contrast(a: str, b: str) -> float:
    x, y = sorted((luminance(a), luminance(b)))
    return (y + .05) / (x + .05)


def readable(color: str, backgrounds: tuple[str, ...]) -> str:
    """Keep a role when readable; otherwise move minimally toward readable black/white."""
    score = lambda c: min(contrast(c, bg) for bg in backgrounds)
    if score(color) >= TEXT_CONTRAST:
        return color
    target = max(("#000000", "#ffffff"), key=score)
    start = [int(color[i:i + 2], 16) for i in (1, 3, 5)]
    end = [int(target[i:i + 2], 16) for i in (1, 3, 5)]
    for step in range(1, 101):
        mixed = "#" + "".join(f"{round(a + (b - a) * step / 100):02x}" for a, b in zip(start, end))
        if score(mixed) >= TEXT_CONTRAST:
            return mixed
    return target


def normalize(colors: dict) -> dict:
    result = {**DEFAULT_COLORS, **{k: v.lower() for k, v in colors.items()
                                  if k in DEFAULT_COLORS and isinstance(v, str) and HEX.fullmatch(v)}}
    backgrounds = (result["background"], result["surface"])
    for role in ("text", "textMuted", "textFaint", "accent", "warm", "danger", "success", "highlight"):
        result[role] = readable(result[role], backgrounds)
    # A chosen palette keeps the island on its base: blue accents must not become its background.
    result["islandBackground"] = result["background"]
    return result


def catalogue(presets: Path | None = None, themes: Path | None = None, generated: Path | None = None) -> dict:
    """The folders are the hosts' own (adapters/common/palette_sources.py knows which); tests pass private ones."""
    from adapters.common.palette_sources import installed_palettes
    entries = {}

    def add(key, name, source, colors, study=False):
        entries[key] = dict(id=key, name=name, source=source, study=study, colors=normalize(colors))

    add(DEFAULT, "Amoled Black", "DMS", DEFAULT_COLORS)
    for entry in installed_palettes(presets, themes, generated):
        add(entry["id"], entry["name"], entry["source"], entry["colors"])
    for name, accent in STUDIES.items():
        add("amoled:" + name.lower(), name, "AMOLED studies", dict(DEFAULT_COLORS, accent=accent,
            highlight=accent, warm=accent, success=accent, text="#eeeeee", textMuted="#aaaaaa", textFaint="#aaaaaa"), True)
    return entries
