"""Three Angular type posters in the Hematite palette (1920x1080, drawn at 2x, downsampled).

Angular rules (docs/fart/DESIGN_SYSTEM.md): only 0°, −12° and 78°; planes, hairlines, 78° hatch; one signal accent
per piece; nothing round. Type: League Gothic (display, sheared −12°) and JetBrains Mono (the system's voice).
The island's band (top centre) stays quiet.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(sys.argv[1])
S = 2
W, H = 1920 * S, 1080 * S
LEAN = math.tan(math.radians(12))

GROUND = (0x14, 0x13, 0x15)
SLAB = (0x1e, 0x1c, 0x21)
SHELF = (0x2a, 0x28, 0x30)
HAIR = (0x72, 0x6d, 0x7c)
MUTED = (0xa4, 0x9f, 0xad)
BONE = (0xe4, 0xe2, 0xe8)
SIGNAL = (0xb4, 0xbe, 0xfe)

GOTHIC = "/usr/share/fonts/TTF/LeagueGothic-Regular.ttf"
MONO = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"


def px(v):
    return int(round(v * S))


def canvas():
    return Image.new("RGBA", (W, H), GROUND + (255,))


def layer():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def shear(img, baseline):
    """−12°: tops lean right, the row at `baseline` stays put."""
    return img.transform(img.size, Image.Transform.AFFINE, (1, LEAN, -baseline * LEAN, 0, 1, 0),
                         Image.Resampling.BICUBIC)


def para(x, y0, y1, w):
    k = (y1 - y0) * LEAN
    return [(x + k, y0), (x + k + w, y0), (x + w, y1), (x, y1)]


def poly(img, pts, colour, alpha=255):
    l = layer()
    ImageDraw.Draw(l).polygon(pts, fill=colour + (alpha,))
    img.alpha_composite(l)


def word(text, size, xy, fill=None, outline=None, stroke=1.5, baseline_shear=True):
    """A sheared word on its own layer; xy is the left end of its baseline (1x units)."""
    font = ImageFont.truetype(GOTHIC, px(size))
    l = layer()
    d = ImageDraw.Draw(l)
    x, y = px(xy[0]), px(xy[1])
    kw = dict(font=font, anchor="ls")
    if outline:
        d.text((x, y), text, fill=fill + (255,) if fill else (0, 0, 0, 0), stroke_width=px(stroke),
               stroke_fill=outline, **kw)
    else:
        d.text((x, y), text, fill=fill, **kw)
    return shear(l, y) if baseline_shear else l


def text_width(text, size):
    return ImageFont.truetype(GOTHIC, px(size)).getlength(text) / S


def mono(img, xy, lines, size=13, colour=MUTED + (215,), leading=1.6):
    d = ImageDraw.Draw(img)
    font = ImageFont.truetype(MONO, px(size))
    for i, line in enumerate(lines):
        d.text((px(xy[0]), px(xy[1] + i * size * leading)), line, font=font, fill=colour)


def grain(img, amount):
    noise = Image.effect_noise((W // 2, H // 2), 60).resize((W, H)).filter(ImageFilter.GaussianBlur(0.5))
    img.alpha_composite(Image.merge("RGBA", (noise, noise, noise, Image.new("L", (W, H), amount))))


def finish(img, name):
    grain(img, 9)
    img.convert("RGB").resize((1920, 1080), Image.Resampling.LANCZOS).save(OUT / name, optimize=True)


# 1 · NULL RESULT ─ Michelson and Morley, 1887: the fringes that should have drifted and didn't.
def null_result():
    img = canvas()
    poly(img, para(px(560), 0, H, px(1500)), SLAB)
    # The interferometer's fringes as 78° hatch: cos² intensity under a broad envelope; the zero-order fringe is the signal.
    fringes = layer()
    d = ImageDraw.Draw(fringes)
    xc, period, sigma = 1290, 44, 330
    k = H * LEAN
    for xi in range(560, 1960, 3):
        phase = math.cos(math.pi * (xi - xc) / period) ** 2
        env = math.exp(-((xi - xc) / sigma) ** 2)
        a = int(235 * phase * env)
        if a < 6:
            continue
        colour = SIGNAL if abs(xi - xc) < period / 2 else HAIR
        d.line([(px(xi), H), (px(xi) + k, 0)], fill=colour + (a if colour == HAIR else min(255, a + 20),), width=S)
    # NULL, enormous, a dark solid the fringes pass over.
    img.alpha_composite(word("NULL", 740, (-24, 1092), fill=SHELF + (255,)))
    img.alpha_composite(word("NULL", 740, (-24, 1092), outline=HAIR + (150,), stroke=1.2))
    img.alpha_composite(fringes)
    # The two numbers that decided it.
    img.alpha_composite(word("0.40", 170, (84, 300), outline=HAIR + (230,), stroke=1.6))
    d = ImageDraw.Draw(img)
    w40 = text_width("0.40", 170)
    d.line([(px(78), px(240)), (px(98 + w40 + 18), px(240))], fill=HAIR + (230,), width=px(2))
    img.alpha_composite(word("0.02", 170, (84 + w40 + 60, 300), fill=BONE + (240,)))
    mono(img, (88, 322), ["fringe shift expected", "if the aether wind blew"], size=12, colour=MUTED + (190,))
    mono(img, (88 + w40 + 64, 322), ["observed"], size=12, colour=MUTED + (190,))
    mono(img, (88, 398), ["Cleveland, July 1887.",
                          "Two beams of light, one half-silvered mirror,",
                          "a sandstone slab floating on mercury.",
                          "If the aether existed, the fringes would drift.",
                          "They did not."], size=14, colour=BONE + (200,), leading=1.75)
    finish(img, "aether-null-result.png")


# 2 · QUINTESSENCE ─ four elements climb 78° steps; the fifth sits above them, cut and slipped.
def quintessence():
    img = canvas()
    steps = [("EARTH", 150, 900, 1080), ("WATER", 470, 800, 1080), ("AIR", 790, 700, 1080), ("FIRE", 1110, 600, 1080)]
    for i, (name, x, top, bottom) in enumerate(steps):
        poly(img, para(px(x), px(top), px(bottom), px(300)), (SLAB, SHELF)[i % 2])
        k = (bottom - top) * LEAN
        img.alpha_composite(word(name, 118, (x + k * 0.86 + 22, top + 108), outline=MUTED + (235,), stroke=1.5))
    # The fifth body: huge, solid, cut along 78° with the right part slipped up; the cut's edge is the one signal.
    size, base, x0 = 560, 560, 760
    full = word("ÆTHER", size, (x0, base), fill=BONE + (236,))
    cut_x = 1350  # where the 78° cut crosses the baseline (1x)
    mask_left = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask_left).polygon(para(-px(400), 0, px(base), px(cut_x + 400)) + [(px(cut_x), H), (0, H)], fill=255)
    left = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    left.paste(full, (0, 0), mask_left)
    right = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    right.paste(full, (0, 0), Image.eval(mask_left, lambda v: 255 - v))
    img.alpha_composite(left)
    img.alpha_composite(right, (px(16), -px(52)))
    d = ImageDraw.Draw(img)
    gap_top, gap_bottom = 120, base + 40
    k = (gap_bottom - gap_top) * LEAN
    cx = cut_x + (base - gap_bottom) * LEAN  # the cut line at gap_bottom
    d.line([(px(cx + 6), px(gap_bottom)), (px(cx + 6 + k), px(gap_top))], fill=SIGNAL + (255,), width=px(3))
    mono(img, (84, 230), ["The fifth body.",
                          "Above the air, unchanging,",
                          "it moves only in circles."], size=15, colour=BONE + (215,), leading=1.75)
    mono(img, (84, 330), ["Aristotle, On the Heavens"], size=12, colour=MUTED + (170,))
    finish(img, "aether-quintessence.png")


# 3 · UPPER AIR ─ the name at poster size, sliced into bands and slid like a misregistered print.
def upper_air():
    img = canvas()
    poly(img, para(px(-200), px(620), H, px(1000)), SLAB)
    name, size = "ZÆTHERION", 600
    width = text_width(name, size)
    x0, base = (1920 - width) / 2 - 40, 1010
    solid = word(name, size, (x0, base), fill=BONE + (230,))
    hollow = word(name, size, (x0, base), outline=HAIR + (240,), stroke=1.6)
    signal = word(name, size, (x0, base), fill=SIGNAL + (255,))
    top = base - size * 0.74  # League Gothic's cap height, about 0.74 em
    cuts = [top + (base - top) * f for f in (0, 0.24, 0.45, 0.53, 0.78, 1.02)]
    shifts = [0, -64, 34, -10, 46]
    sources = [hollow, solid, signal, solid, hollow]
    for (y0, y1), dx, src in zip(zip(cuts, cuts[1:]), shifts, sources):
        band = src.crop((0, px(y0), W, px(y1)))
        img.alpha_composite(band, (px(dx), px(y0)))
    # Hairline registration rules at the cuts, flat (0°), short of the edges.
    d = ImageDraw.Draw(img)
    for y in cuts[1:-1]:
        d.line([(px(40), px(y)), (px(1880), px(y))], fill=HAIR + (90,), width=S)
    mono(img, (84, 196), ["aithḗr: the upper air,",
                          "pure and bright, above the clouds.",
                          "From aíthein, to burn, to shine."], size=15, colour=BONE + (215,), leading=1.75)
    finish(img, "aether-upper-air.png")


OUT.mkdir(parents=True, exist_ok=True)
null_result()
quintessence()
upper_air()
sheet = Image.new("RGB", (1920, 1100), GROUND)
for i, name in enumerate(("null-result", "quintessence", "upper-air")):
    im = Image.open(OUT / f"aether-{name}.png").resize((940, 529))
    sheet.paste(im, ((i % 2) * 980, (i // 2) * 560))
sheet.save(OUT / "sheet2.png")
print("ok")
