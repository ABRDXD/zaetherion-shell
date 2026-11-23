"""One procedural mountain range (numpy + Pillow only), shared by the three wallpapers.

Perlin gradient noise → ridged multifractal heights → a perspective render (column marching, back to front)
with snow, sun shading, distance haze and a cloud ceiling. Everything is luminance 0..1.
"""
import math

import numpy as np

LEAN = math.tan(math.radians(12))


def perlin(n, res, rng):
    """Tileable 2D Perlin noise on an n×n grid with res×res cells (n divisible by res). Range about −0.7..0.7."""
    d = n // res
    angles = rng.random((res + 1, res + 1)) * 2 * np.pi
    grads = np.dstack((np.cos(angles), np.sin(angles)))
    grads[-1, :] = grads[0, :]
    grads[:, -1] = grads[:, 0]
    t = np.mgrid[0:res:1 / d, 0:res:1 / d].transpose(1, 2, 0) % 1
    g00 = grads[:-1, :-1].repeat(d, 0).repeat(d, 1)
    g10 = grads[1:, :-1].repeat(d, 0).repeat(d, 1)
    g01 = grads[:-1, 1:].repeat(d, 0).repeat(d, 1)
    g11 = grads[1:, 1:].repeat(d, 0).repeat(d, 1)
    n00 = (t * g00).sum(2)
    n10 = (np.dstack((t[..., 0] - 1, t[..., 1])) * g10).sum(2)
    n01 = (np.dstack((t[..., 0], t[..., 1] - 1)) * g01).sum(2)
    n11 = (np.dstack((t[..., 0] - 1, t[..., 1] - 1)) * g11).sum(2)
    f = 6 * t ** 5 - 15 * t ** 4 + 10 * t ** 3
    n0 = n00 * (1 - f[..., 0]) + f[..., 0] * n10
    n1 = n01 * (1 - f[..., 0]) + f[..., 0] * n11
    return (np.sqrt(2) * ((1 - f[..., 1]) * n0 + f[..., 1] * n1)).astype(np.float32)


def fractal(n, seed, base=4, octaves=7, ridged=False, gain=0.5):
    rng = np.random.default_rng(seed)
    total = np.zeros((n, n), np.float32)
    amp, norm, weight = 1.0, 0.0, np.ones((n, n), np.float32)
    for o in range(octaves):
        res = base * 2 ** o
        if res > n // 2:
            break
        p = perlin(n, res, rng)
        if ridged:
            p = (1.0 - np.abs(p)) ** 2 * weight
            weight = np.clip(p * 2.0, 0, 1)
        total += amp * p
        norm += amp
        amp *= gain
    return total / norm


def heightmap(n=2048, seed=7):
    """Heights 0..1, tileable: ridged peaks on a broad massif."""
    ridges = fractal(n, seed, base=4, octaves=8, ridged=True, gain=0.47)
    massif = fractal(n, seed + 1, base=2, octaves=3)
    hgt = ridges * (0.55 + 0.9 * np.clip(massif + 0.35, 0, 1))
    hgt -= hgt.min()
    return (hgt / hgt.max()) ** 1.7


def surface(hgt, peak=320.0, sun_az=300, sun_alt=28, snow_line=0.42, seed=5):
    """Per-cell luminance: the sun on the true relief (heights × peak, 1 map unit per cell), snow that sticks
    only to high, gentle ground, dark rock on the steep faces."""
    gy, gx = np.gradient(hgt * peak)
    slope = np.arctan(np.hypot(gx, gy))
    aspect = np.arctan2(-gx, gy)
    az, alt = math.radians(sun_az), math.radians(sun_alt)
    shade = np.clip(np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect), 0, 1)
    rng = np.random.default_rng(seed)
    n = hgt.shape[0]
    streak = perlin(n, 32, rng) * 0.6 + perlin(n, 128, rng) * 0.3 + perlin(n, 512, rng) * 0.2
    steep = np.clip((slope - math.radians(66)) / math.radians(16), 0, 1)
    snow = np.clip((hgt - snow_line + streak * 0.22) * 9, 0, 1) * (1 - steep)
    rock = 0.02 + 0.34 * shade ** 1.5
    snowy = 0.22 + 0.80 * shade ** 1.1
    return (rock * (1 - snow) + snowy * snow).astype(np.float32)


def sample(arr, x, y):
    """Bilinear, wrapping (the map tiles)."""
    n = arr.shape[0]
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx, fy = (x - x0).astype(np.float32), (y - y0).astype(np.float32)
    x0 %= n
    y0 %= n
    x1, y1 = (x0 + 1) % n, (y0 + 1) % n
    top = arr[y0, x0] * (1 - fx) + arr[y0, x1] * fx
    bottom = arr[y1, x0] * (1 - fx) + arr[y1, x1] * fx
    return top * (1 - fy) + bottom * fy


def render(hgt, lum, w, h, cam, cam_h, look=0.0, horizon=0.42, scale=1.0, fov=1.0, peak=520.0,
           z0=60.0, zmax=2600.0, haze_tone=0.74, haze_far=2200.0):
    """Perspective view across the map from cam=(x, y) map units, looking toward −y (turned by `look`
    radians). Heights are hgt*peak map units; cam_h is in map units. Returns (luminance, depth)."""
    cols = (np.arange(w, dtype=np.float32) - w / 2) / w
    rows = np.arange(h, dtype=np.float32)[:, None]
    img = np.full((h, w), np.nan, np.float32)
    depth = np.full((h, w), np.inf, np.float32)
    ybuf = np.full(w, float(h), np.float32)
    focal = w * 0.5 / math.tan(fov / 2) * scale
    ca, sa = math.cos(look), math.sin(look)
    z, dz = z0, 0.5
    while z < zmax:
        side = cols * 2 * math.tan(fov / 2) * z
        mx = cam[0] + side * ca - z * sa
        my = cam[1] - z * ca - side * sa
        hh = sample(hgt, mx, my) * peak
        sy = horizon * h - (hh - cam_h) / z * focal
        colour = sample(lum, mx, my)
        haze = 1 - np.exp(-(z / haze_far) ** 1.3 * 2.0)
        colour = colour * (1 - haze) + haze_tone * haze
        top = np.clip(sy, 0, h)
        mask = (rows >= top[None, :]) & (rows < ybuf[None, :])
        img = np.where(mask, colour[None, :], img)
        depth = np.where(mask, z, depth)
        ybuf = np.minimum(ybuf, top)
        z += dz
        dz *= 1.004
    return img, depth
