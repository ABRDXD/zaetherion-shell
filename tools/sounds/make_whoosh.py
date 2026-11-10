#!/usr/bin/env python3
"""FART's own orbit sounds (docs/ORBIT.md §0): two whooshes synthesized from noise, no third-party audio.

    python3 tools/sounds/make_whoosh.py [OUT_DIR]   (default: assets/sounds)

orbit-out.wav: the pull-back, a rising sweep panning left to right (~0.55 s).
orbit-in.wav: the dive, a falling sweep that lands on a soft low thump (~0.5 s).
White noise through a state-variable band-pass whose centre glides exponentially, shaped by a smooth
envelope; 48 kHz, 16-bit stereo, peak at -6 dBFS. The seed is fixed, so the files are reproducible.
"""
import math
from pathlib import Path
import random
import struct
import sys
import wave

RATE = 48000


def sweep(seconds, f0, f1, q, attack, pan0, pan1, seed):
    rng = random.Random(seed)
    n = int(seconds * RATE)
    low = band = 0.0
    out = []
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** t                          # exponential glide
        g = 2 * math.sin(math.pi * min(f, RATE / 6) / RATE)
        x = rng.uniform(-1, 1)
        high = x - low - band / q
        band += g * high
        low += g * band
        # Envelope: a smooth rise to `attack`, then a long cosine fall to silence.
        env = math.sin(0.5 * math.pi * t / attack) ** 2 if t < attack else 0.5 + 0.5 * math.cos(math.pi * (t - attack) / (1 - attack))
        pan = pan0 + (pan1 - pan0) * t
        s = band * env
        out.append((s * math.cos((pan + 1) * math.pi / 4), s * math.sin((pan + 1) * math.pi / 4)))
    return out


def thump(seconds, start, freq):
    n = int(seconds * RATE)
    out = []
    for i in range(n):
        t = i / RATE - start
        v = 0.0 if t < 0 else math.sin(2 * math.pi * freq * t * (1 - 0.3 * t)) * math.exp(-t / 0.07) * min(1, t / 0.004)
        out.append((v, v))
    return out


def mix(*tracks, gains):
    n = max(len(t) for t in tracks)
    return [(sum(g * (t[i][0] if i < len(t) else 0) for t, g in zip(tracks, gains)),
             sum(g * (t[i][1] if i < len(t) else 0) for t, g in zip(tracks, gains))) for i in range(n)]


def write(path, frames, peak_db=-6.0):
    peak = max(max(abs(l), abs(r)) for l, r in frames) or 1
    scale = 10 ** (peak_db / 20) / peak * 32767
    # 4 ms fades at both ends, so neither edge clicks.
    fade = int(0.004 * RATE)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        data = bytearray()
        for i, (l, r) in enumerate(frames):
            k = min(1, i / fade, (len(frames) - 1 - i) / fade)
            data += struct.pack("<hh", int(l * scale * k), int(r * scale * k))
        w.writeframes(bytes(data))


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "assets/sounds"
    out.mkdir(parents=True, exist_ok=True)
    write(out / "orbit-out.wav", sweep(0.55, 280, 2600, 1.6, 0.35, -0.6, 0.6, seed=7))
    write(out / "orbit-in.wav", mix(sweep(0.5, 2800, 240, 1.6, 0.55, 0.5, -0.2, seed=11), thump(0.5, 0.36, 72), gains=(1.0, 0.12)))
    print(f"wrote {out / 'orbit-out.wav'} and {out / 'orbit-in.wav'}")


if __name__ == "__main__":
    main()
