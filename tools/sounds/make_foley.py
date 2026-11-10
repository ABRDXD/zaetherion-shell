#!/usr/bin/env python3
"""Overdrive's material sounds and room chords (docs/OVERDRIVE_IDEAS.md #46, #47, #49): synthesized here, no third-party audio.

    python3 tools/sounds/make_foley.py [OUT_DIR]   (default: assets/sounds)

Structural foley, each a dry, short physical event (48 kHz, 16-bit stereo, peak -9 dBFS):
foley-pin (a drafting pin going in), foley-relay (a muted relay locking), foley-paper (paper shearing under tension),
foley-ruler (a ruler sliding on a desk), foley-splice (a film splice snapping).
Quiet telemetry (#48), faint and without pitch to follow: quiet-thrash (brushed noise), quiet-burst (a narrow click train),
quiet-device (a low double pulse).
Room chords: each room has a two- or three-note interval from its number, soft sine partials with a slow decay, panned
left, centre or right: chord-<n>-<l|c|r>.wav. The orbit picks the pan from where the room's tile stands.
The seeds are fixed, so the files are reproducible.
"""
import math
from pathlib import Path
import random
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tools.sounds.make_whoosh import RATE, mix, write

# Two or three semitone offsets per room, from a low D: Home is an open fifth; each room its own interval.
CHORDS = [(0, 7), (0, 3, 7), (0, 5, 10), (0, 4, 9), (0, 2, 7), (0, 3, 10), (0, 5, 7), (0, 4, 11), (0, 6, 11), (0, 2, 5, 9)]
ROOT = 146.83
PANS = {"l": -0.65, "c": 0.0, "r": 0.65}


def noise_burst(seconds, tilt, decay, seed, pan=0.0):
    """Noise with a one-pole tilt (0 is dark, 1 is bright) under an exponential decay."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out, last = [], 0.0
    for i in range(n):
        x = rng.uniform(-1, 1)
        last += (x - last) * (0.04 + 0.9 * tilt)
        v = last * math.exp(-i / RATE / decay)
        out.append((v * math.cos((pan + 1) * math.pi / 4), v * math.sin((pan + 1) * math.pi / 4)))
    return out


def tick(seconds, freq, decay, start=0.0):
    n = int(seconds * RATE)
    out = []
    for i in range(n):
        t = i / RATE - start
        v = 0.0 if t < 0 else math.sin(2 * math.pi * freq * t) * math.exp(-t / decay)
        out.append((v, v))
    return out


def stick_slip(seconds, seed):
    """Friction: a stream of tiny grains at an uneven rate, swelling and dying."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    left = [0.0] * n
    at = 0
    while at < n:
        length = rng.randint(30, 90)
        gain = rng.uniform(0.3, 1.0) * math.sin(math.pi * at / n)
        for j in range(length):
            if at + j < n:
                left[at + j] += rng.uniform(-1, 1) * gain * (1 - j / length)
        at += rng.randint(120, 620)
    return [(v, v * 0.9) for v in left]


def chord(semitones, pan):
    seconds = 0.62
    n = int(seconds * RATE)
    out = []
    g = (pan + 1) * math.pi / 4
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / 0.012) * math.exp(-t / 0.19)
        v = sum(math.sin(2 * math.pi * ROOT * 2 ** (s / 12) * t) + 0.25 * math.sin(4 * math.pi * ROOT * 2 ** (s / 12) * t) for s in semitones) / len(semitones)
        out.append((v * env * math.cos(g), v * env * math.sin(g)))
    return out


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "assets/sounds"
    out.mkdir(parents=True, exist_ok=True)
    write(out / "foley-pin.wav", mix(tick(0.12, 1900, 0.008), noise_burst(0.12, 0.9, 0.006, 41), gains=(0.6, 0.5)), peak_db=-9.0)
    write(out / "foley-relay.wav", mix(tick(0.16, 420, 0.012), tick(0.16, 310, 0.014, start=0.028), noise_burst(0.16, 0.4, 0.01, 43), gains=(0.7, 0.8, 0.4)), peak_db=-9.0)
    write(out / "foley-paper.wav", mix(noise_burst(0.34, 0.75, 0.12, 47, pan=0.2), stick_slip(0.34, 49), gains=(0.45, 0.7)), peak_db=-12.0)
    write(out / "foley-ruler.wav", mix(stick_slip(0.4, 53), noise_burst(0.4, 0.2, 0.2, 57), gains=(0.8, 0.4)), peak_db=-12.0)
    write(out / "foley-splice.wav", mix(tick(0.14, 980, 0.01), tick(0.14, 240, 0.02, start=0.012), noise_burst(0.14, 0.95, 0.012, 59), gains=(0.5, 0.8, 0.6)), peak_db=-9.0)
    clicks = [tick(0.26, 3100, 0.0016, start=0.022 * k) for k in range(9)]
    write(out / "quiet-thrash.wav", mix(noise_burst(0.6, 0.3, 0.26, 61), stick_slip(0.6, 63), gains=(0.8, 0.35)), peak_db=-26.0)
    write(out / "quiet-burst.wav", mix(*clicks, gains=[1.0] * len(clicks)), peak_db=-28.0)
    write(out / "quiet-device.wav", mix(tick(0.36, 68, 0.055), tick(0.36, 68, 0.055, start=0.16), gains=(1.0, 0.8)), peak_db=-22.0)
    count = 8
    for n, semitones in enumerate(CHORDS):
        for tag, pan in PANS.items():
            write(out / f"chord-{n}-{tag}.wav", chord(semitones, pan), peak_db=-14.0)
            count += 1
    print(f"wrote {count} files to {out}")


if __name__ == "__main__":
    main()
