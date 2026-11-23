"""Which parity checks are still owed, by the stage of docs/CPP_CORE.md that moves them. A stage cannot merge
while its ops or topics are listed here: each stage's port moves them out by adding scenarios.

tests/test_parity_coverage.py keeps this honest: every op the Python core registers and every topic it offers is
either covered by a scenario or listed here, never both, and nothing here is unknown to the core.
"""
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]

PENDING_OPS = {
    "2a": ("view.open", "view.close", "view.toggle", "view.state", "host.done", "key.down", "key.up"),
    "3a": ("sfx.play", "sfx.stop", "sfx.configure", "eq.enable", "eq.band", "eq.preset", "eq.mono"),
    "3b": ("notif.dismiss", "notif.clear", "notif.dnd", "notif.serve", "notif.ingest", "notif.image", "notif.closed",
           "apps.index", "launcher.query", "launcher.launch", "launcher.act", "launcher.configure", "launcher.forget",
           "launcher.page"),
    "3c": ("palette.list", "palette.choose", "palette.preview", "palette.cancel", "wallpaper.list", "wallpaper.preview",
           "wallpaper.cancel", "wallpaper.colours", "wallpaper.folder", "wallpaper.choose", "wallpaper.report",
           "wallpaper.typeset", "hosttheme.report", "presets.save", "presets.rename", "presets.delete", "presets.preview",
           "presets.cancel", "presets.apply"),
    "4": ("exhibit.prepare", "exhibit.start", "exhibit.stop", "overdrive.request", "overdrive.release", "journey.forget",
          "discovery.bump", "discovery.seen", "sky.now", "orrery.sample", "weather.now", "telemetry.sample",
          "telemetry.sched", "telemetry.disk", "telemetry.gpu", "telemetry.swap", "telemetry.thermal", "bus.usb"),
}

# A topic counts as covered when a scenario other than protocol_subscribe (which only snapshots them all) checks it.
PENDING_TOPICS = {
    "2a": ("view", "ignite"),
    "2b": ("supervisor",),
    "3a": ("sfx", "equalizer"),
    "3b": ("notifications", "launcher", "track"),
    "3c": ("palette", "wallpaper", "presets", "capture"),
    "4": ("overdrive", "journey", "discovery", "genealogy"),
}

# Owed checks that aren't one op or topic (Claude B's review, 23 Nov; docs/PARITY_HARNESS.md).
PENDING_OTHER = {
    "2a": ("nested Hyprland run with the real view against the core", "spawn/reap/restart timing (asyncio vs QProcess)"),
    "2b": ("DMS settings.json byte-equal after a bar off/on round-trip (core/dms_bar.py, style 'dms' in the corpus)",),
    "3b": ("regex corpus: inline and matching ranks equal",),
    "4": ("exhibit score equal (sha256 of the 'exhibit' JSON style)", "sky figures equal"),
}


def registered_ops() -> set[str]:
    """The Python core's ops, read from its source (the registry is app.py's _register plus the protocol's own)."""
    names = set(re.findall(r'\bop\("([a-z_.]+)"', (ROOT / "core/app.py").read_text()))
    names |= set(re.findall(r'self\.op\("([a-z_.]+)"', (ROOT / "core/protocol.py").read_text()))
    return names


def pending_ops() -> dict[str, str]:
    return {op: stage for stage, ops in PENDING_OPS.items() for op in ops}


def pending_topics() -> dict[str, str]:
    return {t: stage for stage, topics in PENDING_TOPICS.items() for t in topics}
