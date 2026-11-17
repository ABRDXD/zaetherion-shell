#!/usr/bin/env python3
"""ZÆTHERION glyph plates: a scene drawn in type, FART // Angular.

Each cell of a monospace grid carries the next character of a running line of text. The scene's light decides the
cell's weight (Thin in shadow, ExtraBold in light) and its ink; true shadow is left empty, so silhouettes read as
voids cut out of a field of words. Where the scene glows warm, the glyph takes the signal colour. Over it, the house
furniture: registration crosses, a hairline with nodes, the mono colophon, one large upright CJK title and a small
sheared Latin one.

    glyph.py <scene.json> <face.png> [--layers DIR]

With --layers, the plate is also written as two layers that let the core recolour it to any accent (Z213):
DIR/ink.png (everything but the accent, the accent's places left as ground) and DIR/signal.png (where the accent
sits, 0–255); the face is ink + signal × the scene's own accent. They come from two renders, the accent drawn in
black and in white: their difference is the mask, edges and all.
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps

W, H = 3840, 2160
M = 112
FONTS = Path("/usr/share/fonts/TTF")
WEIGHTS = ["Thin", "ExtraLight", "Light", "Regular", "Medium", "SemiBold", "Bold", "ExtraBold"]
HERE = Path(__file__).resolve().parent
CJK = "/usr/share/fonts/noto-cjk/NotoSansCJK-Black.ttc"
CJK_JP = 0  # the .ttc's Japanese face


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def mono(weight, size):
    return ImageFont.truetype(str(FONTS / f"JetBrainsMonoNerdFontMono-{weight}.ttf"), size)


def sans(weight, size, italic=False):
    f = ImageFont.truetype(str(HERE / "fonts" / ("RobotoCondensed-Italic.ttf" if italic else "RobotoCondensed.ttf")), size)
    f.set_variation_by_axes([weight])
    return f


def cover(img, box, zoom=1.0):
    """Scale and crop the source to fill W×H; `box` (0–1 focus x, y) picks what stays; `zoom` > 1 closes in on it."""
    fx, fy = box
    if zoom > 1:
        zw, zh = img.width / zoom, img.height / zoom
        cx, cy = img.width * fx, img.height * fy
        left = min(max(0, cx - zw / 2), img.width - zw)
        top = min(max(0, cy - zh / 2), img.height - zh)
        img = img.crop((round(left), round(top), round(left + zw), round(top + zh)))
        fx = fy = 0.5
    s = max(W / img.width, H / img.height)
    img = img.resize((math.ceil(img.width * s), math.ceil(img.height * s)), Image.LANCZOS)
    x = round((img.width - W) * fx)
    y = round((img.height - H) * fy)
    return img.crop((x, y, x + W, y + H))


def field(cfg, scene):
    """The glyph field: returns an RGB image."""
    size = cfg.get("cell", 18)
    probe = mono("Regular", size)
    cw = probe.getlength("M")
    ch = round(size * cfg.get("leading", 1.12))
    cols, rows = int(W / cw), int(H / ch)
    small = scene.resize((cols, rows), Image.BOX)
    lum = ImageOps.grayscale(small)
    if cfg.get("invert"):
        lum = ImageOps.invert(lum)
    lo, hi, gamma = cfg.get("levels", [0, 255, 1.0])
    void = cfg.get("void", 0.08)
    ink = hexrgb(cfg.get("ink", "#dbe7f2"))
    deep = hexrgb(cfg.get("deep", "#1b2530"))
    signal = hexrgb(cfg["signal"])
    warm = cfg.get("warm", None)  # [min saturation, hue range] for signal glyphs
    fonts = [mono(w, size) for w in WEIGHTS]
    text = cfg["text"]
    bands = cfg.get("bands")  # [[from 0–1, weight index 0–7, colour, text?], …] in rising order
    sbox = cfg.get("signal_box")  # [x0, y0, x1, y1 as shares, from v]: glyphs there take the signal
    streams = {}
    # the frame's furniture sits on clear ground: no glyphs under the colophon strip or in given boxes (px)
    clear = [(0, H - M - 40, W, H)] + [tuple(b) for b in cfg.get("clear", [])]
    quiet = lambda x, y: any(a <= x <= c2 and b <= y <= d2 for a, b, c2, d2 in clear)
    out = Image.new("RGB", (W, H), hexrgb(cfg.get("ground", "#000000")))
    d = ImageDraw.Draw(out)
    # smooth and bluish = sky: void cells whose local texture is below `void_smooth` (0–255) and saturation above 40
    vsmooth = cfg.get("void_smooth")
    if vsmooth:
        g = ImageOps.grayscale(scene)
        detail = ImageChops.difference(g, g.filter(ImageFilter.GaussianBlur(6))).filter(ImageFilter.GaussianBlur(10))
        tex = detail.resize((cols, rows), Image.BOX)
        tex = tex.point(lambda p: min(255, p * 8))
    vhue = cfg.get("void_hue")  # [min saturation 0–255, hue from, hue to] (°): that colour (a blue sky) stays unwritten
    hsv = small.convert("HSV") if (warm or vhue or vsmooth) else None
    x0 = (W - cols * cw) / 2
    k = 0
    for r in range(rows):
        for c in range(cols):
            v = lum.getpixel((c, r)) / 255
            v = max(0.0, min(1.0, (v * 255 - lo) / max(1, hi - lo))) ** gamma
            k += 1
            if v < void or quiet(x0 + c * cw, r * ch):
                continue
            if vsmooth and tex.getpixel((c, r)) < vsmooth and hsv.getpixel((c, r))[1] > 40:
                continue
            if vhue:
                hh, ss, vv = hsv.getpixel((c, r))
                hue = hh / 255 * 360
                if ss >= vhue[0] and vhue[1] <= hue <= vhue[2]:
                    continue
            if bands:
                # ink-wash layers: the band picks the voice (its own text, weight and ink); far is thin and faint
                band = next((bd for bd in reversed(bands) if v >= bd[0]), None)
                if band is None:
                    continue
                streams[id(band)] = streams.get(id(band), 0) + 1
                btxt = band[3] if len(band) > 3 else text
                chs = btxt[(r * cols + c) % len(btxt)]
                if chs == " ":
                    continue
                col = hexrgb(band[2])
                # a band's weight may be a range, followed by the light inside the band
                if isinstance(band[1], list):
                    nxt = next((bd[0] for bd in bands if bd[0] > band[0]), 1.0)
                    t = (v - band[0]) / max(1e-6, nxt - band[0])
                    f = fonts[round(band[1][0] + (band[1][1] - band[1][0]) * max(0, min(1, t)))]
                else:
                    f = fonts[band[1]]
                if sbox and sbox[0] <= c / cols <= sbox[2] and sbox[1] <= r / rows <= sbox[3] and v >= sbox[4]:
                    col = signal
                if warm:
                    hh, ss, vv = hsv.getpixel((c, r))
                    hue = hh / 255 * 360
                    if ss >= warm[0] and vv > 60 and (warm[1] <= hue <= warm[2] or (warm[1] > warm[2] and (hue >= warm[1] or hue <= warm[2]))):
                        col = signal
                d.text((x0 + c * cw, r * ch), chs, font=f, fill=col)
                continue
            chs = text[k % len(text)]
            if chs == " ":
                continue
            col = mix(deep, ink, v)
            if warm:
                hh, ss, vv = hsv.getpixel((c, r))
                hue = hh / 255 * 360
                if ss >= warm[0] and vv > 60 and (warm[1] <= hue <= warm[2] or (warm[1] > warm[2] and (hue >= warm[1] or hue <= warm[2]))):
                    col = signal
            f = fonts[min(len(fonts) - 1, int(v * len(fonts)))]
            d.text((x0 + c * cw, r * ch), chs, font=f, fill=col)
    return out


def furniture(img, cfg, no):
    d = ImageDraw.Draw(img, "RGBA")
    muted = hexrgb("#8d96a3")
    ink = hexrgb("#e6f0ff")
    signal = hexrgb(cfg["signal"])
    cap = mono("Medium", 22)

    def reg(x, y):
        d.line([(x, y - 28), (x, y + 28)], fill=muted, width=2)
        d.line([(x - 28, y), (x + 28, y)], fill=muted, width=2)
        d.ellipse([x - 14, y - 14, x + 14, y + 14], outline=muted, width=2)

    for x, y in [(M, M + 88), (W - M, M + 88), (M, H - M), (W - M, H - M)]:
        reg(x, y)
    # the colophon: a hairline with an ink node and a signal node, mono either side
    d.line([(M + 48, H - M), (W - M - 48, H - M)], fill=(42, 48, 56, 255), width=2)
    d.rectangle([M + 42, H - M - 6, M + 54, H - M + 6], fill=ink)
    d.rectangle([W - M - 54, H - M - 6, W - M - 42, H - M + 6], fill=signal)
    spaced = lambda s: s.upper()
    left = f"ZÆTHERION · FART // ANGULAR · GLYPH {no:02d} · {cfg['name']}"
    right = f"{cfg['colophon']} · SIGNAL: THE PALETTE'S ACCENT · −12° / 78°"
    d.text((M + 72, H - M + 18), spaced(left), font=cap, fill=muted, spacing=4)
    tw = d.textlength(spaced(right), font=cap)
    d.text((W - M - 72 - tw, H - M + 18), spaced(right), font=cap, fill=muted)
    # the reading: a mono block top-left and an aside, on a ground plane whose right edge runs at 78°
    rlines = cfg["reading"].upper().split("\n")
    rw = max(d.textlength(l, font=cap) for l in rlines)
    if cfg.get("aside"):
        rw = max(rw, d.textlength(cfg["aside"], font=sans(300, 40, True)))
    rh = 34 * len(rlines) + (110 if cfg.get("aside") else 10)
    rx0, ry0, rx1, ry1 = M + 30, M + 120, M + 72 + rw + 60, M + 150 + rh + 30
    rrun = (ry1 - ry0) * math.tan(math.radians(12))
    d.polygon([(rx0, ry0), (rx1 + rrun, ry0), (rx1, ry1), (rx0, ry1)], fill=hexrgb(cfg.get("ground", "#000000")))
    d.multiline_text((M + 72, M + 150), cfg["reading"].upper(), font=cap, fill=muted, spacing=10)
    if cfg.get("aside"):
        d.text((M + 72, M + 150 + 34 * (cfg["reading"].count("\n") + 1) + 40), cfg["aside"], font=sans(300, 40, True), fill=ink)
    # the title: CJK upright, large; Latin under it sheared −12°
    t = cfg["title"]
    side = t.get("side", "right")
    cjk = ImageFont.truetype(CJK, t.get("size", 420), index=CJK_JP)
    glyphs = t["cjk"]
    gw, gh = t.get("size", 420), t.get("size", 420)
    vertical = t.get("vertical", True)
    tx = W - M - 160 - gw if side == "right" else M + 120
    ty = t.get("top", 220)
    # measure first, so the plane behind and the Latin under it fit the real glyphs
    boxes = [d.textbbox((tx, ty + i * gh * 1.02), g, font=cjk) for i, g in enumerate(glyphs)] if vertical \
        else [d.textbbox((tx, ty), glyphs, font=cjk)]
    bottom = max(bx[3] for bx in boxes)
    lsz = t.get("latin_size", 120)
    # a ground plane behind the title block, its outer edges at 78°, so the field never runs under the title
    px0, py0 = min(bx[0] for bx in boxes) - 90, ty - 40
    px1, py1 = max(bx[2] for bx in boxes) + 60, bottom + lsz * 1.3 + 90
    run = (py1 - py0) * math.tan(math.radians(12))
    d.polygon([(px0 + run, py0), (px1 + run, py0), (px1, py1), (px0, py1)], fill=hexrgb(cfg.get("ground", "#000000")))
    for i, g in enumerate(glyphs if vertical else [glyphs]):
        d.text((tx, ty + i * gh * 1.02), g, font=cjk, fill=ink)
    # a signal rule beside the CJK
    rx = tx - 40 if side == "right" else tx + (gw if vertical else len(glyphs) * gw) + 40
    d.rectangle([rx, ty + 20, rx + 6, bottom - 40], fill=signal)
    d.text((rx - 34 if side == "right" else rx + 22, ty + 20), "", font=cap)
    # Latin, sheared: drawn on its own layer then affine-sheared by tan 12°
    latin = t["latin"]
    lf = sans(900, t.get("latin_size", 120))
    lw = int(d.textlength(latin, font=lf)) + 80
    lh = int(t.get("latin_size", 120) * 1.3)
    layer = Image.new("RGBA", (lw + lh, lh), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((lh * 0.3, 0), latin, font=lf, fill=ink + (255,))
    sh = math.tan(math.radians(12))
    layer = layer.transform(layer.size, Image.AFFINE, (1, sh, -sh * lh, 0, 1, 0), Image.BICUBIC)
    lx = (tx + gw - lw if side == "right" else tx)
    img.paste(layer, (int(lx), int(bottom + 24)), layer)
    d.text((int(lx) + 8 if side != "right" else int(tx + gw - d.textlength(t["sub"].upper(), font=cap)), int(bottom + 24 + lh + 10)), t["sub"].upper(), font=cap, fill=signal)


def render(cfg, scene, signal):
    cfg = dict(cfg, signal=signal)
    img = field(cfg, scene)
    furniture(img, cfg, cfg["no"])
    return img


def compose(ink, mask, accent):
    """The one recolouring rule, shared with the core's (adapters/common/typeset.py): ink + accent × mask."""
    solid = Image.new("RGB", ink.size, hexrgb(accent))
    return ImageChops.add(ink, ImageChops.multiply(solid, Image.merge("RGB", (mask, mask, mask))))


def main():
    args = sys.argv[1:]
    layers = None
    if "--layers" in args:
        i = args.index("--layers")
        layers = Path(args[i + 1]).expanduser()
        del args[i:i + 2]
    cfg = json.loads(Path(args[0]).read_text())
    src = Image.open(Path(cfg["src"]).expanduser()).convert("RGB")
    scene = cover(src, cfg.get("focus", [0.5, 0.5]), cfg.get("zoom", 1.0))
    if cfg.get("mirror"):
        scene = ImageOps.mirror(scene)
    ink = render(cfg, scene, "#000000")
    lit = render(cfg, scene, "#ffffff")
    mask = ImageOps.grayscale(ImageChops.difference(lit, ink))
    compose(ink, mask, cfg["signal"]).save(args[1], optimize=True)
    if layers:
        layers.mkdir(parents=True, exist_ok=True)
        ink.save(layers / "ink.png", optimize=True)
        mask.save(layers / "signal.png", optimize=True)
        (layers / "plate.json").write_text(json.dumps(dict(name=cfg["name"], kind="glyph", source=cfg["src"], face=Path(args[1]).name,
                                                           accent=cfg["signal"]), ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
