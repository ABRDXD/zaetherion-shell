"""Typeset plates: wallpapers that follow the palette's accent (Z213).

A plate is a wallpaper whose face (the file in the folder) has layers in `<folder>/.typeset/<stem>/`: `ink.png`
(everything but the accent) and `signal.png` (where the accent sits), written by tools/typeset. The applied
wallpaper is a recoloured copy in that same directory, `<hex>.png`, made by adapters/common/typeset_tint.py as
ink + accent × signal; the copy maps back to its face, so the picker and presets only ever see the face.
Paths and colours only here: no image tool is known to the core.
"""
from __future__ import annotations

import colorsys
import json
import re
from pathlib import Path

LAYERS = ".typeset"
HEX = re.compile(r"^#?([0-9a-fA-F]{6})$")
# The accent must read on the plates' black ground: at least this contrast against black (WCAG, as the rooms use).
MIN_CONTRAST = 4.5


def layers_for(path: str) -> Path | None:
    """The plate's layer directory for a face or for one of its copies; None for any other wallpaper."""
    p = Path(path)
    if p.parent.parent.name == LAYERS:  # a recoloured copy: <folder>/.typeset/<stem>/<hex>.png
        directory = p.parent
    else:
        directory = p.parent / LAYERS / p.stem
    return directory if (directory / "ink.png").is_file() and (directory / "signal.png").is_file() else None


def face_of(path: str) -> str:
    """A copy's face (the file the picker lists); any other path is its own face."""
    p = Path(path)
    if p.parent.parent.name != LAYERS:
        return path
    try:
        face = json.loads((p.parent / "plate.json").read_text()).get("face")
    except (OSError, ValueError):
        face = None
    if isinstance(face, str) and face and "/" not in face:
        return str(p.parent.parent.parent / face)
    folder = p.parent.parent.parent
    matches = sorted(q for q in folder.glob(p.parent.name + ".*") if q.is_file())
    return str(matches[0]) if matches else path


def contrast_on_black(r: float, g: float, b: float) -> float:
    lin = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) + 0.05) / 0.05


def lift(accent: str) -> str:
    """The accent as `#rrggbb`; one too dark to read on black is lightened (hue and saturation kept) until it does."""
    m = HEX.fullmatch(accent.strip()) if isinstance(accent, str) else None
    if not m:
        raise ValueError(f"not a colour: {accent!r}")
    r, g, b = (int(m.group(1)[i:i + 2], 16) / 255 for i in (0, 2, 4))
    h, lightness, s = colorsys.rgb_to_hls(r, g, b)
    out = tuple(round(c * 255) for c in (r, g, b))
    # judged on the colour as it will be written (whole channel values), so rounding can't land it under the limit
    while contrast_on_black(*(c / 255 for c in out)) < MIN_CONTRAST and lightness < 1:
        lightness = min(1.0, lightness + 0.02)
        out = tuple(round(c * 255) for c in colorsys.hls_to_rgb(h, lightness, s))
    return "#%02x%02x%02x" % out


def copy_path(layers: Path, accent: str) -> Path:
    """Where the copy in this (lifted) accent lives."""
    return layers / (lift(accent)[1:] + ".png")
