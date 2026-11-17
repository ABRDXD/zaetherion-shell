#!/usr/bin/env python3
"""Lift the one accent out of an image, so the core can recolour it to the palette's accent (Z213).

For a picture made of greys plus one saturated colour (the NULL plate's lavender beam): the accent's share of each
pixel is its saturation above a floor (softened), the accent layer carries that share times the pixel's brightness,
and the ink is the picture in grey with the accent's light taken out. Recoloured, ink + accent × signal gives back
the picture in the new colour; with the original accent it gives back the original, near enough.

    extract.py <image> <layers-dir> [--floor 0.18] [--soft 1.5]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageOps

from glyph import stale  # tools/typeset/ is on the path when run as a script

# Saturation (0–1) below this is grey; the share rises to 1 over the next RAMP.
FLOOR = 0.18
RAMP = 0.22


def layers(img: Image.Image, floor=FLOOR, soft=1.5):
    rgb = img.convert("RGB")
    _, s, v = rgb.convert("HSV").split()
    share = s.point(lambda p: max(0, min(255, round((p / 255 - floor) / RAMP * 255))))
    if soft:
        share = share.filter(ImageFilter.GaussianBlur(soft))
    # the strongest accent pixel counts as fully accent: a pale accent (lavender on grey) is lifted out whole
    top = max(1, share.getextrema()[1])
    share = share.point(lambda p: min(255, round(p * 255 / top)))
    # the accent's own colour, for the face's original look: the mean of the strongest accent pixels
    signal = ImageChops.multiply(share, v)
    grey = ImageOps.grayscale(rgb)
    ink = ImageChops.subtract(grey, ImageChops.multiply(share, grey))
    return Image.merge("RGB", (ink, ink, ink)), signal, accent_of(rgb, share)


def accent_of(rgb, share):
    px = [(c, a) for c, a in zip(rgb.get_flattened_data(), share.get_flattened_data()) if a > 200]
    if not px:
        return "#ffffff"
    n = len(px)
    r, g, b = (sum(c[i] for c, _ in px) / n for i in range(3))
    top = max(r, g, b, 1)
    return "#%02x%02x%02x" % tuple(round(x / top * 255) for x in (r, g, b))


def main():
    args = sys.argv[1:]
    floor = float(args[args.index("--floor") + 1]) if "--floor" in args else FLOOR
    soft = float(args[args.index("--soft") + 1]) if "--soft" in args else 1.5
    src, out = Path(args[0]).expanduser(), Path(args[1]).expanduser()
    ink, signal, accent = layers(Image.open(src), floor, soft)
    out.mkdir(parents=True, exist_ok=True)
    stale(out)
    ink.save(out / "ink.png", optimize=True)
    signal.save(out / "signal.png", optimize=True)
    (out / "plate.json").write_text(json.dumps(dict(name=src.stem.upper(), kind="extracted", source=str(src), face=src.name, accent=accent)) + "\n")
    print(accent)


if __name__ == "__main__":
    main()
