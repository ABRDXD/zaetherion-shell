#!/usr/bin/env python3
"""ZÆTHERION's own UI, notice and alert sounds: synthesized here, no third-party audio.

    python3 tools/sounds/make_ui.py [OUT_DIR]   (default: assets/sounds)

One family, "modern HUD" (owner, 13 November 2026: cybernetic, not jolly, not 8-bit): glassy sine blips with a
breath of high-passed noise, resonant filter sweeps (servos), fast grain clusters ("computing"), inharmonic FM metal,
sub thumps and a short early-reflection space. Intervals are fourths, fifths and tritones, never a major arpeggio. No
square waves, no bit-crush. Rounded edges, nothing above -9 dBFS.
The click, keys, switch, error, confirm and normal notification are CC0 samples (NOTICE, "Sounds"), not made
here. 48 kHz, 16-bit stereo. Fixed seeds: reproducible.
"""
from __future__ import annotations

from pathlib import Path
import sys
import wave

import numpy as np

RATE = 48000
PEAK = 10 ** (-9 / 20)
D4 = 293.66


def note(semitones: float) -> float:
    return D4 * 2 ** (semitones / 12)


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def env(t: np.ndarray, attack: float, decay: float) -> np.ndarray:
    """A rounded attack (raised cosine) into an exponential decay."""
    a = np.clip(t / attack, 0, 1) if attack > 0 else np.ones_like(t)
    return (0.5 - 0.5 * np.cos(np.pi * a)) * np.exp(-np.maximum(t - attack, 0) / decay)


def bell(freq: float, seconds: float, decay: float, bright: float = 1.0, attack: float = 0.004) -> np.ndarray:
    """A soft FM bell: carrier with a 3.5:1 modulator whose depth falls faster than the note."""
    t = t_axis(seconds)
    index = 1.6 * bright * np.exp(-t / (decay * 0.35))
    y = np.sin(2 * np.pi * freq * t + index * np.sin(2 * np.pi * freq * 3.5 * t))
    y += 0.25 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t / (decay * 0.5))
    return y * env(t, attack, decay)


def felt(freq: float, seconds: float, decay: float, attack: float = 0.002) -> np.ndarray:
    """A muted, woody tone: fundamental and a quick second partial, like a felt mallet on a bar."""
    t = t_axis(seconds)
    y = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 3.9 * t) * np.exp(-t / (decay * 0.15))
    return y * env(t, attack, decay)


def tick(freq: float, seconds: float, decay: float, seed: int, noise: float = 0.25) -> np.ndarray:
    """A tiny click: a short sine with a breath of filtered noise on the transient."""
    t = t_axis(seconds)
    rng = np.random.default_rng(seed)
    n = rng.uniform(-1, 1, t.size)
    n = np.convolve(n, np.ones(6) / 6, mode="same")  # take the edge off
    y = np.sin(2 * np.pi * freq * t) * env(t, 0.0008, decay) + noise * n * env(t, 0.0003, decay * 0.25)
    return y


def shutter(seed: int) -> np.ndarray:
    """A camera shutter: two band-limited noise clicks 70 ms apart."""
    t = t_axis(0.16)
    rng = np.random.default_rng(seed)
    n = np.convolve(rng.uniform(-1, 1, t.size), np.ones(4) / 4, mode="same")
    n -= np.convolve(n, np.ones(40) / 40, mode="same")  # high-pass
    out = n * env(t, 0.0005, 0.008)
    out += 0.7 * np.roll(n, 77) * env(t - 0.07, 0.0005, 0.012) * (t >= 0.07)
    return out


def seq(parts: list[tuple[float, np.ndarray]], seconds: float) -> np.ndarray:
    """Place (start, signal) parts on one timeline."""
    out = np.zeros(int(seconds * RATE))
    for start, y in parts:
        i = int(start * RATE)
        n = min(y.size, out.size - i)
        out[i:i + n] += y[:n]
    return out


def stereo(y: np.ndarray, width: float = 0.0) -> np.ndarray:
    """Centre, with an optional few-sample delay on the right for air (never a hard pan)."""
    d = int(width * 0.0004 * RATE)
    right = np.concatenate([np.zeros(d), y])[:y.size] if d else y
    return np.stack([y, right], axis=1)


def write(path: Path, y: np.ndarray, peak: float = PEAK, width: float = 0.0) -> None:
    fade = min(int(0.004 * RATE), y.size)
    y = y.copy()
    y[-fade:] *= np.linspace(1, 0, fade)  # never end on a click
    y = y / (np.max(np.abs(y)) or 1) * peak
    data = (np.clip(stereo(y, width), -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def sweep(f0: float, f1: float, seconds: float, decay: float, shape: str = "sine") -> np.ndarray:
    """A pitch glide (exponential), as a sine or a soft pulse."""
    t = t_axis(seconds)
    freq = f0 * (f1 / f0) ** np.clip(t / seconds, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    y = np.sin(phase) if shape == "sine" else np.tanh(3 * np.sin(phase)) * 0.6
    return y * env(t, 0.001, decay)


def pulse(freq: float, seconds: float, decay: float, width: float = 0.25, attack: float = 0.0008) -> np.ndarray:
    """A band-limited pulse wave (first 12 harmonics): reedy and digital, without aliasing."""
    t = t_axis(seconds)
    y = sum(np.sin(np.pi * k * width) / k * np.cos(2 * np.pi * freq * k * t) for k in range(1, 13))
    return y * env(t, attack, decay)


def ring(freq: float, mod: float, seconds: float, decay: float) -> np.ndarray:
    """Ring modulation: sum and difference tones, metallic and pitch-ambiguous."""
    t = t_axis(seconds)
    return np.sin(2 * np.pi * freq * t) * np.sin(2 * np.pi * mod * t) * env(t, 0.001, decay)


def metal(freq: float, seconds: float, decay: float, ratio: float = 1.414, index: float = 2.5) -> np.ndarray:
    """Inharmonic FM (ratio √2): struck metal plate, not a bell."""
    t = t_axis(seconds)
    depth = index * np.exp(-t / (decay * 0.4))
    return np.sin(2 * np.pi * freq * t + depth * np.sin(2 * np.pi * freq * ratio * t)) * env(t, 0.0008, decay)


def burst(seconds: float, rate: float, seed: int, decay: float) -> np.ndarray:
    """A data burst: a gated train of short noise grains, like a modem chirp heard through a wall."""
    t = t_axis(seconds)
    rng = np.random.default_rng(seed)
    n = np.convolve(rng.uniform(-1, 1, t.size), np.ones(3) / 3, mode="same")
    gate = (np.sin(2 * np.pi * rate * t) > 0.3).astype(float)
    gate = np.convolve(gate, np.ones(24) / 24, mode="same")
    return n * gate * env(t, 0.001, decay)


def thump(freq: float, seconds: float, decay: float) -> np.ndarray:
    """A sub thump: a sine that drops an octave in its first 40 ms."""
    return sweep(freq * 2, freq, seconds, decay)


def crush(y: np.ndarray, bits: int = 6, hold: int = 3) -> np.ndarray:
    """A light bit-crush: fewer levels and a sample-and-hold, mixed under the clean signal."""
    held = np.repeat(y[::hold], hold)[:y.size]
    q = np.round(held * 2 ** (bits - 1)) / 2 ** (bits - 1)
    return 0.7 * y + 0.3 * q


def biquad(x: np.ndarray, kind: str, freq, q: float = 0.707) -> np.ndarray:
    """An RBJ biquad (lowpass, highpass, bandpass); `freq` may be an array for a sweep."""
    f = np.broadcast_to(np.asarray(freq, dtype=float), x.shape)
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(x.size):
        w = 2 * np.pi * min(f[i], RATE * 0.45) / RATE
        c, s = np.cos(w), np.sin(w)
        alpha = s / (2 * q)
        if kind == "lowpass":
            b0, b1, b2 = (1 - c) / 2, 1 - c, (1 - c) / 2
        elif kind == "highpass":
            b0, b1, b2 = (1 + c) / 2, -(1 + c), (1 + c) / 2
        else:
            b0, b1, b2 = alpha, 0.0, -alpha
        a0, a1, a2 = 1 + alpha, -2 * c, 1 - alpha
        v = (b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1, y2, y1 = x1, x[i], y1, v
        y[i] = v
    return y


def air(seconds: float, decay: float, seed: int, cutoff: float = 6000) -> np.ndarray:
    """A breath of high-passed noise: the "glass" on a blip's transient."""
    t = t_axis(seconds)
    n = np.random.default_rng(seed).uniform(-1, 1, t.size)
    return biquad(n, "highpass", cutoff) * env(t, 0.0005, decay)


def blip(freq: float, seconds: float, decay: float, seed: int, glass: float = 0.08) -> np.ndarray:
    """A HUD blip: a clean sine with a whisper of its octave and a glass transient."""
    t = t_axis(seconds)
    y = (np.sin(2 * np.pi * freq * t) + 0.2 * np.sin(2 * np.pi * freq * 2 * t)) * env(t, 0.0015, decay)
    return y + glass * air(seconds, decay * 0.3, seed)


def servo(f0: float, f1: float, seconds: float, decay: float, seed: int, q: float = 6.0) -> np.ndarray:
    """A servo: noise through a resonant band-pass that glides from f0 to f1."""
    t = t_axis(seconds)
    n = np.random.default_rng(seed).uniform(-1, 1, t.size)
    freq = f0 * (f1 / f0) ** np.clip(t / seconds, 0, 1)
    return biquad(n, "bandpass", freq, q) * env(t, 0.01, decay) * 3


def grains(seconds: float, count: int, seed: int, notes=(12, 17, 19, 24, 29, 31), decay: float = 0.012) -> np.ndarray:
    """Computing: a quick cluster of tiny sine grains on the scale's fourths and fifths, thinning out."""
    rng = np.random.default_rng(seed)
    out = np.zeros(int(seconds * RATE))
    for k in range(count):
        at = (k / count) ** 1.4 * seconds * 0.8
        g = blip(note(rng.choice(notes)), 0.03, decay, seed + k, glass=0.1) * (1 - 0.6 * k / count)
        i = int(at * RATE)
        out[i:i + g.size] += g[:out.size - i]
    return out


def space(y: np.ndarray, amount: float = 0.18) -> np.ndarray:
    """A short early-reflection space (three taps, 11–37 ms, darkened), so dry blips don't sound like a toy."""
    out = y.copy()
    for ms, g in ((11, 0.5), (23, 0.35), (37, 0.22)):
        d = int(ms / 1000 * RATE)
        out[d:] += amount * g * y[:-d]
    return out


def sounds() -> dict[str, tuple[np.ndarray, float, float]]:
    """file stem → (signal, peak, stereo width)."""
    ui, soft = 10 ** (-18 / 20), 10 ** (-22 / 20)
    return {
        # UI: under 80 ms, felt rather than heard.
        "osd-tick": (blip(note(19), 0.03, 0.005, 5, 0.2), 10 ** (-20 / 20), 0.0),
        # Hold to confirm (session card, 1 s): a servo rising for the hold, then a lock-in.
        "hold-charge": (seq([(0, servo(300, 2400, 1.0, 0.9, 11, q=8) * np.linspace(0.3, 1, int(RATE)))], 1.0)
                        + 0.25 * sweep(note(-12), note(0), 1.0, 0.9), 10 ** (-17 / 20), 0.5),
        # Notices.
        "notify-critical": (space(seq([(0, metal(note(18), 0.3, 0.1, index=3)), (0.16, metal(note(18), 0.3, 0.1, index=3)),
                                       (0.32, metal(note(12), 0.7, 0.24, index=3.5)), (0.32, thump(note(-12), 0.3, 0.12)),
                                       (0.32, servo(2000, 600, 0.5, 0.3, 23) * 0.4)], 1.0), 0.25), PEAK, 1.0),
        # Alerts: a three-step figure (root, fifth, octave), three times, each step a blip over a sub.
        "alert": (space(seq([(r * 0.55 + i * 0.12, blip(note(s + 12), 0.18, 0.07, 30 + i) + 0.5 * thump(note(-12), 0.18, 0.05))
                             for r in range(3) for i, s in enumerate((0, 7, 12))], 1.8)), PEAK, 0.6),
        # System moments.
        "power-plug": (space(seq([(0, thump(note(-12), 0.18, 0.06)), (0.02, servo(400, 3000, 0.25, 0.15, 40)),
                                  (0.2, blip(note(24), 0.2, 0.06, 41))], 0.42)), 10 ** (-13 / 20), 0.5),
        "power-unplug": (space(seq([(0, servo(3000, 400, 0.25, 0.15, 42)), (0.18, thump(note(-17), 0.18, 0.06))], 0.4)),
                         10 ** (-13 / 20), 0.5),
        "battery-low": (space(seq([(0, metal(note(0), 0.25, 0.1, index=2)), (0.25, metal(note(-6), 0.35, 0.14, index=2)),
                                   (0.25, thump(note(-18), 0.25, 0.1))], 0.65)), 10 ** (-11 / 20), 0.3),
        "net-up": (space(seq([(0, grains(0.18, 7, 50)), (0.15, blip(note(24), 0.3, 0.09, 51))], 0.48)), 10 ** (-15 / 20), 0.7),
        "net-down": (space(seq([(0, servo(2400, 500, 0.22, 0.12, 52)), (0.15, blip(note(7), 0.25, 0.08, 53))], 0.42)),
                     10 ** (-15 / 20), 0.6),
        "lock": (space(seq([(0, thump(note(-17), 0.18, 0.05)), (0.03, servo(2500, 900, 0.08, 0.04, 60)),
                            (0.07, blip(note(5), 0.08, 0.02, 61))], 0.22)), 10 ** (-13 / 20), 0.0),
        "unlock": (space(seq([(0, servo(900, 2800, 0.1, 0.05, 62)), (0.07, blip(note(12), 0.1, 0.03, 63)),
                              (0.12, blip(note(24), 0.2, 0.07, 64))], 0.36)), 10 ** (-14 / 20), 0.5),
        "screenshot": (space(shutter(8) + 0.4 * seq([(0.07, blip(note(31), 0.08, 0.02, 65))], 0.16)), 10 ** (-14 / 20), 0.3),
        "dnd-on": (space(seq([(0, servo(2000, 500, 0.18, 0.1, 70)), (0.1, blip(note(5), 0.15, 0.05, 71))], 0.28)),
                   10 ** (-16 / 20), 0.0),
        "dnd-off": (space(seq([(0, servo(500, 2000, 0.18, 0.1, 72)), (0.1, blip(note(12), 0.15, 0.05, 73))], 0.28)),
                    10 ** (-16 / 20), 0.0),
    }


def main(argv: list[str]) -> int:
    out = Path(argv[1]) if len(argv) > 1 else Path(__file__).resolve().parents[2] / "assets/sounds"
    out.mkdir(parents=True, exist_ok=True)
    for stem, (y, peak, width) in sounds().items():
        write(out / f"{stem}.wav", y, peak, width)
        print(f"{stem}.wav  {y.size / RATE * 1000:.0f} ms")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
