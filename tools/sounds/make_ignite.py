#!/usr/bin/env python3
"""Overdrive's own two sounds (docs/OVERDRIVE.md §2): synthesized here, no third-party audio.

    python3 tools/sounds/make_ignite.py [OUT_DIR]   (default: assets/sounds)

overdrive-ignite.wav: the ignition (~1.1 s). A turbine spools up (a detuned pair of saw-like partials
gliding up an octave and a half, with a growing vibrato), sparks crackle in as it nears the top, then the
fire point lands: a sub thump, an air burst through a band-pass sweeping down, and a short bright shimmer.
overdrive-off.wav: the spin-down (~1.2 s). The same turbine winding down like a tape stopping: its pitch
falls away exponentially and its brightness with it, over a low rumble that thins to nothing.
48 kHz, 16-bit stereo. The seeds are fixed, so the files are reproducible.
"""
import math
from pathlib import Path
import random
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.sounds.make_whoosh import RATE, mix, sweep, thump, write


def turbine(seconds, f0, f1, curve, bright0, bright1, vibrato, pan, attack=0.03, release=0.12, level0=1.0, level1=1.0):
    """A spooling turbine: two detuned partial stacks whose pitch follows f0 → f1 along t**curve, and whose
    level goes level0 → level1."""
    n = int(seconds * RATE)
    out = []
    phase = [0.0, 0.0]
    for i in range(n):
        t = i / n
        f = f0 * (f1 / f0) ** (t ** curve)
        f *= 1 + vibrato * t * math.sin(2 * math.pi * 7.5 * i / RATE)
        bright = bright0 + (bright1 - bright0) * t
        v = 0.0
        for k, detune in enumerate((1.0, 1.007)):
            phase[k] += 2 * math.pi * f * detune / RATE
            # A band-limited saw from its first partials; `bright` sets how many are loud.
            for h in range(1, 7):
                v += math.sin(h * phase[k]) / h * bright ** (h - 1)
        sec = i / RATE
        env = min(1.0, sec / attack) * min(1.0, (seconds - sec) / release) * (level0 + (level1 - level0) * t ** 1.5)
        s = 0.18 * v * env
        out.append((s * math.cos((pan + 1) * math.pi / 4), s * math.sin((pan + 1) * math.pi / 4)))
    return out


def sparks(seconds, start, end, rate, seed):
    """Crackle: short decaying noise grains, denser towards `end`, scattered across the stereo field."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    left, right = [0.0] * n, [0.0] * n
    t = start
    while t < end:
        density = rate * (0.3 + 0.7 * (t - start) / max(1e-6, end - start))
        t += rng.expovariate(density)
        i0 = int(t * RATE)
        length = int(rng.uniform(0.002, 0.009) * RATE)
        gain, pan = rng.uniform(0.3, 1.0), rng.uniform(-0.9, 0.9)
        for j in range(length):
            if i0 + j >= n:
                break
            v = rng.uniform(-1, 1) * gain * math.exp(-j / (length / 4))
            left[i0 + j] += v * math.cos((pan + 1) * math.pi / 4)
            right[i0 + j] += v * math.sin((pan + 1) * math.pi / 4)
    return list(zip(left, right))


def delay(frames, seconds):
    pad = [(0.0, 0.0)] * int(seconds * RATE)
    return pad + frames


def shimmer(seconds, freq, decay):
    n = int(seconds * RATE)
    out = []
    for i in range(n):
        sec = i / RATE
        v = sum(math.sin(2 * math.pi * freq * m * sec + m) / m for m in (1, 1.5, 2.01, 3.02)) * math.exp(-sec / decay)
        out.append((v * 0.8, v * 0.6))
    return out


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "assets/sounds"
    out.mkdir(parents=True, exist_ok=True)
    fire = 0.46
    ignite = mix(
        turbine(fire + 0.08, 70, 290, 1.6, 0.35, 0.8, 0.012, -0.2, release=0.06, level0=0.12),
        sparks(fire + 0.1, 0.18, fire + 0.05, 160, seed=23),
        thump(1.1, fire, 54),
        delay(sweep(0.55, 3200, 180, 1.4, 0.06, 0.5, -0.5, seed=29), fire - 0.01),
        delay(shimmer(0.6, 880, 0.16), fire + 0.02),
        gains=(1.0, 0.22, 0.9, 0.5, 0.05))
    write(out / "overdrive-ignite.wav", ignite, peak_db=-6.0)
    off = mix(
        turbine(1.2, 290, 38, 0.55, 0.8, 0.15, 0.004, 0.2, attack=0.01, release=0.5, level1=0.35),
        sweep(1.2, 900, 90, 1.2, 0.05, 0.3, -0.3, seed=31),
        gains=(1.0, 0.25))
    write(out / "overdrive-off.wav", off, peak_db=-9.0)
    print(f"wrote {out / 'overdrive-ignite.wav'} and {out / 'overdrive-off.wav'}")


if __name__ == "__main__":
    main()
