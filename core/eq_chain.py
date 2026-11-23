"""The equaliser's chain, worked out on paper (Z50, Z173): bands, presets, the biquads' response, the gains the
running chain is given, and the text of the PipeWire filter-chain config. Pure: no process, no file, no clock.

The graph, per channel: a copy of each input, a mixer per output channel (stereo, or mono as half of each, with
the headroom folded in), then ten peaking biquads. The capture side is a WirePlumber smart filter, so it sits in
front of whatever the default sink is and is never the default itself.
"""
from __future__ import annotations

from functools import lru_cache
import math

FREQUENCIES = (31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000)
MIN_GAIN, MAX_GAIN = -12, 12
Q = 1.41  # one octave per band
RATE = 48000  # for the response only; PipeWire works the coefficients out at the graph's own rate
CHANNELS = ("L", "R")
NODE_NAME = "zaetherion_eq"  # the capture node (the sink streams play into), and the prefix of the playback one
FLAT = "Flat"
CUSTOM = "Custom"
# Our own values, in dB at FREQUENCIES (owner, 13 November 2026: Flat plus a few). Not taken from anyone's set.
PRESETS = {
    FLAT: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    "Bass": (6, 5, 4, 2, 0, 0, 0, 0, 0, 0),
    "Treble": (0, 0, 0, 0, 0, 0, 2, 4, 5, 6),
    "Vocal": (-2, -2, -1, 0, 2, 3, 3, 2, 0, -1),
    "Loudness": (5, 4, 2, 0, -1, -1, 0, 2, 3, 4),
}


def clamp_gain(gain) -> int:
    """A band's gain in whole dB within MIN_GAIN..MAX_GAIN. Not a number raises ValueError."""
    value = float(gain)
    if math.isnan(value):
        raise ValueError("gain is not a number")
    return int(round(max(MIN_GAIN, min(MAX_GAIN, value))))


def preset_named(name: str) -> str | None:
    """The preset's own spelling, matched without case, or None."""
    for preset in PRESETS:
        if preset.lower() == str(name).strip().lower():
            return preset
    return None


def preset_for(bands) -> str:
    """The preset these bands are, or Custom."""
    for name, gains in PRESETS.items():
        if tuple(bands) == gains:
            return name
    return CUSTOM


def peaking(freq: float, gain_db: float, q: float = Q, rate: int = RATE) -> tuple[float, ...]:
    """RBJ cookbook peaking biquad (the same as PipeWire's bq_peaking), normalised: b0, b1, b2, a1, a2."""
    if gain_db == 0:
        return (1.0, 0.0, 0.0, 0.0, 0.0)
    a = 10 ** (gain_db / 40)
    w0 = 2 * math.pi * freq / rate
    alpha = math.sin(w0) / (2 * q)
    cos = math.cos(w0)
    a0 = 1 + alpha / a
    return ((1 + alpha * a) / a0, -2 * cos / a0, (1 - alpha * a) / a0, -2 * cos / a0, (1 - alpha / a) / a0)


def magnitude_db(coefficients, freq: float, rate: int = RATE) -> float:
    b0, b1, b2, a1, a2 = coefficients
    w = 2 * math.pi * freq / rate
    z1, z2 = complex(math.cos(-w), math.sin(-w)), complex(math.cos(-2 * w), math.sin(-2 * w))
    return 20 * math.log10(abs((b0 + b1 * z1 + b2 * z2) / (1 + a1 * z1 + a2 * z2)))


def response(bands, freqs) -> list[float]:
    """The ten bands' combined gain in dB at each frequency."""
    filters = [peaking(f, g) for f, g in zip(FREQUENCIES, bands) if g]
    return [sum(magnitude_db(c, f) for c in filters) for f in freqs]


GRID = tuple(20 * 1000 ** (i / 239) for i in range(240))  # 20 Hz to 20 kHz, log spaced


def headroom(bands) -> float:
    """How far the chain lowers its input so the loudest boost cannot clip: the response's peak, never below 0."""
    return _headroom(tuple(bands))


@lru_cache(maxsize=32)
def _headroom(bands: tuple) -> float:
    if not any(bands):
        return 0.0
    return round(max(0.0, max(response(bands, GRID))), 1)


def mixer_gains(mono: bool, head_db: float) -> dict:
    """The four mixer controls: each output channel takes its own input (stereo) or half of both (mono), lowered
    by the headroom."""
    level = 10 ** (-head_db / 20)
    if mono:
        own = other = level / 2
    else:
        own, other = level, 0.0
    return {"mixL:Gain 1": own, "mixL:Gain 2": other, "mixR:Gain 1": other, "mixR:Gain 2": own}


def params(bands, mono: bool) -> list:
    """Everything the running chain is told on each change, as pw-cli's Props params list: [name, value, ...]."""
    values = dict(mixer_gains(mono, headroom(bands)))
    for channel in CHANNELS:
        for index, gain in enumerate(bands):
            values[f"eq{channel}_{index + 1}:Gain"] = float(gain)
    return [item for name, value in values.items() for item in (name, round(value, 6))]


def props_text(bands, mono: bool) -> str:
    """The argument to `pw-cli set-param <node> Props`."""
    items = params(bands, mono)
    return "{ params = [ " + " ".join(f'"{items[i]}" {items[i + 1]}' for i in range(0, len(items), 2)) + " ] }"


def _controls(values: dict) -> str:
    return "{ " + " ".join(f'"{name}" = {value}' for name, value in values.items()) + " }"


def config_text(bands, mono: bool) -> str:
    """The `pipewire -c` config of the chain's own process, starting at the given state."""
    mix = mixer_gains(mono, headroom(bands))
    nodes = ["{ type = builtin name = inL label = copy }", "{ type = builtin name = inR label = copy }"]
    for channel in CHANNELS:
        mine = {f"Gain {n}": round(mix[f"mix{channel}:Gain {n}"], 6) for n in (1, 2)}
        nodes.append(f"{{ type = builtin name = mix{channel} label = mixer control = {_controls(mine)} }}")
    links = ['{ output = "inL:Out" input = "mixL:In 1" }', '{ output = "inR:Out" input = "mixL:In 2" }',
             '{ output = "inL:Out" input = "mixR:In 1" }', '{ output = "inR:Out" input = "mixR:In 2" }']
    for channel in CHANNELS:
        previous = f"mix{channel}:Out"
        for index, (freq, gain) in enumerate(zip(FREQUENCIES, bands)):
            name = f"eq{channel}_{index + 1}"
            nodes.append(f"{{ type = builtin name = {name} label = bq_peaking "
                         f"control = {_controls({'Freq': float(freq), 'Q': Q, 'Gain': float(gain)})} }}")
            links.append(f'{{ output = "{previous}" input = "{name}:In" }}')
            previous = f"{name}:Out"
    last = len(FREQUENCIES)
    indent = "\n" + " " * 16
    return f"""# Written by ZAETHERION's core for its own equaliser process (docs/DECISIONS.md Z173). Rewritten at each start.
context.properties = {{
    log.level = 2
    support.dbus = false
}}
context.spa-libs = {{
    audio.convert.* = audioconvert/libspa-audioconvert
    support.*       = support/libspa-support
}}
context.modules = [
    {{ name = libpipewire-module-protocol-native }}
    {{ name = libpipewire-module-client-node }}
    {{ name = libpipewire-module-adapter }}
    {{ name = libpipewire-module-filter-chain
        args = {{
            node.description = "ZAETHERION equaliser"
            media.name = "ZAETHERION equaliser"
            filter.graph = {{
                nodes = [{indent}{indent.join(nodes)}
                ]
                links = [{indent}{indent.join(links)}
                ]
                inputs = [ "inL:In" "inR:In" ]
                outputs = [ "eqL_{last}:Out" "eqR_{last}:Out" ]
            }}
            audio.channels = 2
            audio.position = [ FL FR ]
            capture.props = {{
                node.name = "{NODE_NAME}"
                media.class = Audio/Sink
                filter.smart = true
                filter.smart.name = "{NODE_NAME}"
            }}
            playback.props = {{
                node.name = "{NODE_NAME}.output"
                node.passive = true
            }}
        }}
    }}
]
"""
