"""Quick paste's settings (S3, Z184): published as `clips`, changed from FART's Clips tab.

What Enter does, how many rows show, whether pictures show. The history itself is DMS's (Z202): DMS records it,
keeps it and holds its own settings (`clipboard.getConfig` / `setConfig`), so the core runs no recorder.
"""
from __future__ import annotations

import logging
from pathlib import Path

from core.errors import bad_args
from core.store import read_json, write_json

log = logging.getLogger("fart.clips")

DEFAULTS = {"enterPastes": False, "rows": 6, "showImages": True}


def valid(key, value) -> bool:
    if key in ("enterPastes", "showImages"):
        return isinstance(value, bool)
    if key == "rows":
        return isinstance(value, int) and not isinstance(value, bool) and 4 <= value <= 10
    return False


class Clips:
    def __init__(self, state_dir: Path):
        self.path = state_dir / "clips.json"
        self.on_change = lambda: None
        try:
            saved = read_json(self.path, {}) or {}
        except ValueError as error:
            log.warning("%s; using defaults", error)
            saved = {}
        self.state = dict(DEFAULTS)
        for key, value in (saved.items() if isinstance(saved, dict) else ()):
            if valid(key, value):
                self.state[key] = value

    def snapshot(self) -> dict:
        return dict(self.state)

    def set(self, key, value) -> dict:
        if not valid(key, value):
            raise bad_args(f"clips {key}: {value!r} is not allowed")
        if self.state[key] != value:
            self.state[key] = value
            write_json(self.path, self.state)
            self.on_change()
        return self.snapshot()
