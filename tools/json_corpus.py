#!/usr/bin/env python3
"""The JSON writer's corpus (Z226 stage 0): what Python's json writes, in every style the desktop runtime uses, so
fartd-cpp's writer can be checked byte for byte without Python (docs/PARITY_HARNESS.md §JSON).

    tools/json_corpus.py            write tests/parity/json_corpus.json
    tools/json_corpus.py --check    exit 1 if the checked-in corpus differs from what this Python writes

Each case: "input" is the value in Python's compact form (floats in repr, so it reads back exactly; keys in
insertion order), and "out" maps each style to Python's bytes (as text). "round" cases give Python's round(x, n)
as repr text: the core rounds before writing in many places (ms times, elapsed, uptime).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import sys

ROOT = Path(__file__).resolve().parents[1]
CORPUS = ROOT / "tests/parity/json_corpus.json"

# Where each style is written (core/… and adapters/…); fartd-cpp needs every one of them.
STYLES = {
    "store": dict(separators=(",", ":")),  # store.write_json / append_line: state files, sessions.jsonl
    "protocol": dict(separators=(",", ":"), ensure_ascii=False),  # protocol.encode: every line on the socket
    "dms": dict(indent=2, ensure_ascii=False),  # dms_bar: the owner's DMS settings.json
    "exhibit": dict(sort_keys=True, separators=(",", ":")),  # exhibit's score seed (SHA-256 of this)
    "default": dict(),  # fixture log lines, capture's selector spec
}


def write(value, style: str) -> str:
    return json.dumps(value, **STYLES[style])


def floats() -> list[float]:
    edge = [0.0, -0.0, 1.0, -1.0, 0.1, 0.2, 0.1 + 0.2, 1 / 3, 2 / 3, 1e16, 1e17, 1.5e16, 123456789012345680.0, 1e22,
            1e-4, 1e-5, 1e-7, 5e-324, 2.2250738585072014e-308, 1.7976931348623157e308, 9007199254740993.0,
            0.000123, 123.456, 1e15, 999999999999999.9, 1e21, 1e-6, 1.25, 2.5, 3.5, -2.5, 1795430819.2579703,
            1795430819258.0, 0.015, 1.005, 2.675, 10.0, 100.0, 1e100, 12.0e-3]
    rng = random.Random(226)
    rand = [rng.uniform(-1e6, 1e6) for _ in range(40)] + [rng.random() for _ in range(30)] \
        + [rng.uniform(0, 1e12) for _ in range(20)] + [math.ldexp(rng.random(), rng.randint(-1060, 1020)) for _ in range(30)]
    return edge + rand


def ints() -> list[int]:
    return [0, -1, 1, 255, 2 ** 31 - 1, -2 ** 31, 2 ** 53, 2 ** 53 + 1, 2 ** 63 - 1, -2 ** 63, 1795430819258]


STRINGS = ["", "plain", "naïve café", "☕ “quotes” ‘single’", "tab\there", "new\nline", "cr\rlf", "nul\0byte",
           "\x01\x1f\x7f", "back\\slash", 'quote"inside', "slash/forward", "\u2028\u2029", "emoji 🪐 astral",
           "\ufeffbom", "Ä\u0308 combining", "</script>", "ZÆTHERION", "日本語", "\U0001F600 pair"]


def values() -> list:
    out: list = [None, True, False, [], {}, [[]], {"": ""}]
    out += ints() + floats() + STRINGS
    out += [
        {"b": 1, "a": 2, "c": {"z": 0, "y": [1, 1.0, "1"]}},  # insertion order vs sort_keys
        {"version": 1, "lists": [{"id": "default", "name": "Tasks"}], "tasks": [
            {"id": "t0a1b2c3d", "list": "default", "text": "milk ☕", "done": False, "due": "2026-11-25",
             "created": 1795430819258, "doneAt": None}]},
        {"countdown": {"running": True, "elapsed": 12.345678901234567, "duration": 300.0, "done": None}},
        {"nested": [[1, [2, [3, [4, {"deep": [5.5]}]]]]], "empty": {"a": [], "b": {}}},
        {"10": "ten", "9": "nine", "a1": 1, "A1": 2, "é": 3, "e": 4},  # sort_keys orders code points, not numbers
        {"settings": {"barConfigs": [{"id": "default", "enabled": False, "visible": True, "position": 0,
                                      "spacing": 4.0, "widgets": ["clock", "music"]}], "fontScale": 1.1}},
    ]
    return out


def round_cases() -> list[dict]:
    cases = []
    for x in (0.5, 1.5, 2.5, -0.5, -1.5, 0.125, 0.375, 2.675, 1.005, 0.015, 1795430819.2579703, 12.344999999999999,
              1e16 + 0.5, 0.1 + 0.2, 1234.5678, -0.0):
        for n in (None, 0, 1, 2, 3):
            got = round(x) if n is None else round(x, n)
            cases.append({"x": repr(x), "n": n, "out": repr(got)})
    return cases


def build() -> dict:
    cases = []
    for value in values():
        text = json.dumps(value, separators=(",", ":"))
        cases.append({"input": text, "out": {style: write(value, style) for style in STYLES}})
    exhibit = {"seed": "exhibit", "rooms": ["home", "perf"], "weights": [0.5, 1.25, 1e-7]}
    return {
        "python": sys.version.split()[0],
        "styles": {name: {k: list(v) if isinstance(v, tuple) else v for k, v in kw.items()} for name, kw in STYLES.items()},
        "notes": ["protocol lines are this text encoded UTF-8 with errors='backslashreplace', plus a newline",
                  "dms has no trailing newline (dms_bar.py); the serpantinum adapter adds one",
                  "exhibit: sha256 of the exhibit text, UTF-8; see sha256 below for one case"],
        "cases": cases,
        "round": round_cases(),
        "sha256": {"value": json.dumps(exhibit, separators=(",", ":")),
                   "digest": hashlib.sha256(write(exhibit, "exhibit").encode()).hexdigest()},
    }


def render(corpus: dict) -> str:
    return json.dumps(corpus, indent=1, ensure_ascii=True) + "\n"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    text = render(build())
    if args.check:
        if not CORPUS.exists() or CORPUS.read_text() != text:
            print(f"{CORPUS.relative_to(ROOT)} differs from what Python {sys.version.split()[0]} writes; rerun without --check")
            return 1
        print(f"corpus matches ({len(build()['cases'])} values × {len(STYLES)} styles)")
        return 0
    CORPUS.write_text(text)
    print(f"wrote {CORPUS.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
