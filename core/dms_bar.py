"""DMS's own bar, hidden while the resident view (island and FART) is up and shown whenever it is not.

Interim, until ZÆTHERION's resident UI replaces DMS's (docs/DECISIONS.md Z159). DMS's `bar hide` IPC refuses an
island-style bar (BAR_IS_ISLAND), and `settings set` cannot change the bar list, so the core sets `visible` on the
Main Bar in DMS's settings file. DMS watches that file and applies the change at once (checked in nested Hyprland,
12 November 2026); a DMS that is down reads it when it starts. Only that one field is touched.
"""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path

log = logging.getLogger("fart.dmsbar")
BAR_ID = "default"  # DMS's "Main Bar"


def settings_path() -> Path:
    config = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(config) / "dms" / "settings.json"


def set_visible(path: Path, visible: bool) -> bool:
    """True when the file was changed. Written the way DMS writes it (2-space JSON, atomic replace)."""
    settings = json.loads(path.read_text())
    bar = next((b for b in settings.get("barConfigs") or [] if isinstance(b, dict) and b.get("id") == BAR_ID), None)
    if bar is None or bar.get("visible", True) is visible:
        return False
    bar["visible"] = visible
    temp = path.with_name(f".{path.name}.zaetherion")
    temp.write_text(json.dumps(settings, indent=2, ensure_ascii=False))
    os.chmod(temp, path.stat().st_mode & 0o777)
    os.replace(temp, path)
    return True


class DmsBar:
    def __init__(self, path: Path | None = None):
        self.path = path or settings_path()
        self.want_hidden: bool | None = None
        self.applied: bool | None = None

    def snapshot(self) -> dict:
        return {"wantHidden": self.want_hidden, "applied": self.applied}

    def sync(self, hidden: bool):
        self.want_hidden = hidden
        if self.applied is hidden:
            return
        try:
            changed = set_visible(self.path, not hidden)
        except (OSError, ValueError) as error:
            log.warning("DMS bar: cannot %s it: %s", "hide" if hidden else "show", error)
            return
        self.applied = hidden
        if changed:
            log.info("DMS bar %s", "hidden" if hidden else "shown")
