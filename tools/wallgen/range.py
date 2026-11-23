"""Three wallpapers from one procedural range, after the owner's references (fog peaks, ASCII figure, city map,
chrome HUD): 1920x1080. Angular overlay: 0°/−12°/78° only, hairline frames, small type, one lavender mark.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).parent))
import terrain as T  # noqa: E402  (tools/wallgen/terrain.py)

OUT = Path(sys.argv[1])
W, H = 1920, 1080
LEAN = math.tan(math.radians(12))
SIGNAL = (0xb4, 0xbe, 0xfe)
MONO = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
GOTHIC = "/usr/share/fonts/TTF/LeagueGothic-Regular.ttf"
METRES = 4870  # height 1.0 in metres, for the readouts


def font(path, size):
    return ImageFont.truetype(path, size)


def grain(arr, amount, seed):
    rng = np.random.default_rng(seed)
    g = rng.normal(0, 1, arr.shape[:2]).astype(np.float32)
    g = (g * 2 + np.roll(g, 1, 0) + np.roll(g, 1, 1)) / 4  # soften to film-grain size
    g /= g.std() + 1e-6
    return arr + g[..., None] * amount if arr.ndim == 3 else arr + g * amount


def tint(lum, shadow=(0.055, 0.068, 0.082), light=(0.93, 0.95, 0.965)):
    """Monochrome with a cool cast: shadows lean steel, highlights stay near white."""
    s, l = np.array(shadow, np.float32), np.array(light, np.float32)
    return s + (l - s) * lum[..., None]


def to_image(rgb):
    return Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")


def sheared(img, xy, text, size, fill, font_path=GOTHIC):
    f = font(font_path, size)
    l = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(l).text(xy, text, font=f, fill=fill, anchor="ls")
    l = l.transform(l.size, Image.Transform.AFFINE, (1, LEAN, -xy[1] * LEAN, 0, 1, 0), Image.Resampling.BICUBIC)
    img.alpha_composite(l)


def frame(d, box, colour, cut=10):
    """A hairline frame with its top-right corner cut by a 78° edge (0° and 78° only)."""
    x0, y0, x1, y1 = box
    d.line([(x0, y0), (x1 - cut, y0), (x1 - cut + cut * LEAN, y0 + cut), (x1, y0 + cut), (x1, y1), (x0, y1), (x0, y0)],
           fill=colour, width=1)


def micro(d, xy, lines, colour, size=10, leading=1.5):
    f = font(MONO, size)
    for i, line in enumerate(lines):
        d.text((xy[0], xy[1] + i * size * leading), line, font=f, fill=colour)


# ── the scene ────────────────────────────────────────────────────────────────────────────────────────────────
hm = np.load(OUT / "hm.npy") if (OUT / "hm.npy").exists() else T.heightmap(2048)
np.save(OUT / "hm.npy", hm)
iy, ix = np.unravel_index(np.argmax(hm), hm.shape)
PEAK, CAM, CAM_H, LOOK, HORIZON = 330, (ix + 260, iy + 700), 300, 0.3, 0.40
lum_map = T.surface(hm, peak=PEAK, snow_line=0.40)
view, depth = T.render(hm, lum_map, W, H, cam=CAM, cam_h=CAM_H, peak=PEAK, look=LOOK, fov=0.9, horizon=HORIZON,
                       haze_far=7000, haze_tone=0.80)
sky = np.isnan(view)
skyline = np.argmax(~sky, axis=0)  # first terrain row per column
summit_x = int(np.argmin(skyline))
summit_y = int(skyline[summit_x])


def clouds(seed, top_frac):
    n = 2048
    rng = np.random.default_rng(seed)
    c = sum(T.perlin(n, r, rng) * a for r, a in ((2, 1.0), (4, 0.55), (8, 0.3), (16, 0.16), (32, 0.08), (64, 0.04)))
    c = (c[:H, :W] - c.min()) / (np.ptp(c) + 1e-6)
    y = np.mgrid[0:H, 0:W][0].astype(np.float32) / H
    ceiling = np.clip((top_frac - y) / 0.16 + (c - 0.5) * 2.2, 0, 1)
    return ceiling, c


# 1 · AERIAL: fog over the summits, cool monochrome, film grain, the HUD reads the scene itself.
def aerial():
    lum = view.copy()
    ceiling, c = clouds(21, top_frac=0.30)
    sky_tone = 0.50 + 0.30 * c ** 1.4  # a textured, darker sky so the overlay reads
    lum[sky] = sky_tone[sky]
    # Mist: a drifting band across the upper slopes, holed by noise so some summits stand clear.
    y = np.mgrid[0:H, 0:W][0].astype(np.float32)
    band = np.exp(-((y - (summit_y + 230)) / 120) ** 2)
    rng = np.random.default_rng(31)
    m = sum(T.perlin(2048, r, rng) * a for r, a in ((4, 1.0), (8, 0.5), (16, 0.3), (32, 0.15)))[:H, :W]
    m = (m - m.min()) / (np.ptp(m) + 1e-6)
    mist = np.clip(band * (m - 0.32) * 2.6, 0, 0.92) * (~sky)
    lum = lum * (1 - mist) + (0.58 + 0.22 * m) * mist
    lum = lum * (1 - ceiling * 0.85) + sky_tone * ceiling * 0.85
    lum = np.clip((lum - 0.02) * 1.06, 0, 1)
    rgb = grain(tint(lum), 0.018, 3)
    img = to_image(rgb)
    d = ImageDraw.Draw(img)
    ink, faint = (240, 243, 246, 235), (240, 243, 246, 165)
    # Left: an altitude scale.
    for i, m in enumerate(range(5200, 1999, -400)):
        y = 150 + i * 70
        d.line([(56, y), (72 if m % 800 == 0 else 66, y)], fill=ink, width=1)
        if m % 800 == 0:
            d.text((80, y - 6), f"{m:,}".replace(",", " "), font=font(MONO, 10), fill=faint)
    d.line([(56, 150), (56, 150 + 8 * 70)], fill=faint, width=1)
    # The summit: a lavender mark, a 78° leader, its height in sheared numerals.
    summit_m = int(hm.max() * METRES)
    sx, sy = summit_x, summit_y
    d.line([(sx - 7, sy - 14), (sx + 7, sy - 14)], fill=SIGNAL + (255,), width=2)
    lx, ly = sx + 6 + 150 * LEAN, sy - 14 - 150
    d.line([(sx + 1 * LEAN, sy - 16), (lx, ly)], fill=SIGNAL + (255,), width=2)
    d.line([(lx, ly), (lx + 180, ly)], fill=SIGNAL + (255,), width=2)
    sheared(img, (int(lx + 4), int(ly - 8)), f"{summit_m:,}".replace(",", " "), 64, (242, 244, 246, 235))
    micro(d, (int(lx + 6), int(ly + 8)), ["summit, north ridge", "metres above the datum"], (240, 243, 246, 215))
    # Bottom right: the skyline as a profile, the summit marked.
    bx0, by0, bx1, by1 = 1460, 880, 1864, 1010
    frame(d, (bx0, by0, bx1, by1), faint)
    prof = skyline.astype(np.float32)
    prof = (prof.max() - prof) / (np.ptp(prof) + 1e-6)
    xs = np.linspace(bx0 + 10, bx1 - 10, W)
    pts = [(float(xs[i]), by1 - 14 - float(prof[i]) * (by1 - by0 - 40)) for i in range(0, W, 4)]
    d.line(pts, fill=ink, width=1)
    px_ = bx0 + 10 + (bx1 - bx0 - 20) * summit_x / W
    d.line([(px_, by0 + 8), (px_, by1 - 6)], fill=SIGNAL + (200,), width=1)
    micro(d, (bx0, by0 - 18), ["skyline profile, this view"], faint)
    micro(d, (bx0 + 10, by1 + 6), [f"bearing {int(math.degrees(LOOK)) % 360:03d}°   range 7 km   haze 0.80"], faint, size=9)
    # Top left: the scene's own numbers, in small type.
    micro(d, (56, 56), ["ridge survey", f"camera {CAM_H * METRES // PEAK // 100 * 100:,} m".replace(",", " "),
                        "light from the north-west, 28°"], (240, 243, 246, 220), size=11)
    img.convert("RGB").save(OUT / "range-fog.png", optimize=True)


# 2 · ASCII: the same view in characters on black, cut back along a 78° edge so the left stays empty.
def ascii_view():
    cw, ch = 6, 11
    cols, rows = W // cw, H // ch
    shift = 470  # move the summit into the drawn half
    lum = np.full((H, W), np.nan, np.float32)
    lum[:, shift:] = view[:, :W - shift]
    land = ~np.isnan(lum)
    lo, hi = np.percentile(lum[land], 4), np.percentile(lum[land], 99.5)
    lum = np.where(land, np.clip((lum - lo) / (hi - lo), 0, 1) ** 1.1 * 0.80 + 0.16, 0.0)
    # Rim light: every ridge's silhouette (land under sky or under a farther ridge) drawn bright.
    dep = np.full((H, W), np.inf, np.float32)
    dep[:, shift:] = depth[:, :W - shift]
    above = np.roll(dep, 1, 0)
    rim = land & ((~np.isfinite(above)) | (above > dep * 1.25))
    rim_img = Image.fromarray((rim * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))
    rim = np.asarray(rim_img) > 0
    lum = np.where(rim & land, np.maximum(lum, 0.88), lum)
    small = np.asarray(Image.fromarray((lum * 255).astype(np.uint8)).resize((cols, rows), Image.Resampling.BOX),
                       np.float32) / 255
    ramp = ".:-=+*e%0@"
    img = Image.new("RGBA", (W, H), (5, 5, 7, 255))
    d = ImageDraw.Draw(img)
    f = font(MONO, 10)
    edge = 0.36  # the fade's 78° line crosses the bottom at 36 % of the width
    sx_cell, sy_cell = (summit_x + shift) // cw, summit_y // ch
    # The island's light notch (owner, 17 Nov): a light plane behind the island's rest and hover sizes, 78° sides,
    # then bright characters thinning into the black so deeper island cards keep an edge too.
    NOTCH_DEPTH, NOTCH_HALF, TAIL = 88, 470, 170

    def notch_half(y):
        return NOTCH_HALF + (NOTCH_DEPTH - y) * LEAN

    tail_rng = np.random.default_rng(17)
    for r in range(rows):
        y = r * ch
        x_cut = edge * W + (H - y) * LEAN
        for c in range(cols):
            x = c * cw
            v = small[r, c] * float(np.clip((x - x_cut) / 220, 0, 1))
            if NOTCH_DEPTH <= y < NOTCH_DEPTH + TAIL and abs(x + cw / 2 - W / 2) < notch_half(y):
                t = (y - NOTCH_DEPTH) / TAIL
                if tail_rng.random() < 0.85 * (1 - t) ** 2.2:
                    v = max(v, 0.78 - 0.6 * t)
            if v < 0.06:
                continue
            g = ramp[min(len(ramp) - 1, int(v * len(ramp)))]
            tone = int(30 + 225 * v)
            colour = (tone, tone, min(255, tone + 5), 255)
            if abs(c - sx_cell) <= 1 and 0 <= sy_cell + 1 - r < 5:
                colour = SIGNAL + (255,)  # the summit's own characters carry the signal
            d.text((x, y), g, font=f, fill=colour)
    plane = [(W / 2 - notch_half(0), 0), (W / 2 + notch_half(0), 0),
             (W / 2 + NOTCH_HALF, NOTCH_DEPTH), (W / 2 - NOTCH_HALF, NOTCH_DEPTH)]
    d.polygon(plane, fill=(201, 206, 214, 255))
    small_ink = (34, 36, 42, 235)
    micro(d, (int(W / 2 - NOTCH_HALF + 22), NOTCH_DEPTH - 24), ["north ridge"], small_ink, size=11)
    tag = f"{int(hm.max() * METRES):,} m".replace(",", " ")
    micro(d, (int(W / 2 + NOTCH_HALF - 22 - font(MONO, 11).getlength(tag)), NOTCH_DEPTH - 24), [tag], small_ink, size=11)
    sheared(img, (96, 860), f"{int(hm.max() * METRES):,}".replace(",", " "), 120, (230, 232, 236, 230))
    micro(d, (100, 880), ["metres: the lavender characters on the right",
                          f"drawn in {len(ramp)} characters, {cols} × {rows}"], (200, 202, 208, 175), size=11)
    img.convert("RGB").save(OUT / "range-ascii.png", optimize=True)


# 3 · SURVEY: the same ground from above as a light contour map; snow hatched at 78°; the camera's sightline.
def survey():
    S = 2
    x0, y0 = int((CAM[0] + ix) / 2 - W / 2), int((CAM[1] + iy) / 2 - H / 2)
    win = np.take(np.take(hm, np.arange(y0, y0 + H) % hm.shape[0], 0), np.arange(x0, x0 + W) % hm.shape[1], 1)
    big = np.asarray(Image.fromarray(win.astype(np.float32), "F").resize((W * S, H * S), Image.Resampling.BICUBIC))
    levels = 46
    q = np.floor(big * levels)
    edge = (q != np.roll(q, 1, 0)) | (q != np.roll(q, 1, 1))
    index = edge & (q % 5 == 0)
    base = np.full((H * S, W * S), 0.885, np.float32)
    snow = ((hm > 0.50) & (lum_map > 0.30)).astype(np.uint8) * 255  # high ground that holds snow in the renders
    snow_win = np.take(np.take(snow, np.arange(y0, y0 + H) % hm.shape[0], 0), np.arange(x0, x0 + W) % hm.shape[1], 1)
    snow_big = np.asarray(Image.fromarray(snow_win).resize((W * S, H * S), Image.Resampling.NEAREST)) > 0
    yy, xx = np.mgrid[0:H * S, 0:W * S]
    hatch = ((xx - (H * S - yy) * LEAN) % (12 * S)) < 1.4 * S
    base[snow_big & hatch] = 0.55
    lake = big < 0.035
    base[edge] = 0.30
    idx_img = Image.fromarray((index * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))
    base[np.asarray(idx_img) > 0] = 0.08
    base[lake] = 0.04
    img = Image.fromarray((base * 255).astype(np.uint8)).resize((W, H), Image.Resampling.LANCZOS).convert("RGBA")
    d = ImageDraw.Draw(img)
    ink = (20, 20, 22, 230)
    # Elevation labels on a few index contours, set on a paper knockout.
    rng = np.random.default_rng(9)
    f = font(MONO, 10)
    placed = []
    ys, xs = np.nonzero(index[::S, ::S])
    for k in rng.permutation(len(xs))[:4000]:
        x, y = int(xs[k]), int(ys[k])
        if any(abs(x - a) < 140 and abs(y - b) < 60 for a, b in placed) or y < 170 or x > W - 80 or win[y, x] < 0.05:
            continue
        m = int(round(win[y, x] * levels / 5)) * 5 * METRES // levels
        label = f"{m:,}".replace(",", " ")
        tw = f.getlength(label)
        d.rectangle([x - 2, y - 7, x + tw + 2, y + 6], fill=(226, 226, 226, 255))
        d.text((x, y - 6), label, font=f, fill=ink)
        placed.append((x, y))
        if len(placed) >= 26:
            break
    # The camera of the other two views and its sightline, the one lavender mark.
    cx, cy = CAM[0] - x0, CAM[1] - y0
    tx, ty = ix - x0, iy - y0  # the summit the other two views look at
    d.line([(cx, cy), (tx, ty)], fill=SIGNAL + (255,), width=3)
    d.rectangle([tx - 5, ty - 5, tx + 5, ty + 5], outline=SIGNAL + (255,), width=2)
    d.polygon([(cx - 6, cy + 5), (cx + 6, cy + 5), (cx + 6 - 11 * LEAN, cy - 6), (cx - 6 - 11 * LEAN, cy - 6)], fill=SIGNAL + (255,))
    d.rectangle([56, 56, 470, 150], fill=(226, 226, 226, 255))
    frame(d, (56, 56, 470, 150), ink)
    sheared(img, (72, 120), "Ridge survey", 44, (18, 18, 20, 240))
    micro(d, (74, 128), ["contours every 106 m, bold every 530 m, snow hatched"], (40, 40, 44, 220))
    d.rectangle([W - 372, H - 52, W - 40, H - 28], fill=(226, 226, 226, 255))
    micro(d, (W - 364, H - 47), ["lavender: the sightline of the other two views"], (40, 40, 44, 220))
    img.convert("RGB").save(OUT / "range-survey.png", optimize=True)


for job in sys.argv[2:] or ['aerial', 'ascii_view', 'survey']:
    globals()[job]()
print("ok", summit_x, summit_y)
