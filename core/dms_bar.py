"""DMS's own bar: off while the resident view (island and FART) is up, back on whenever it is gone for long.

Interim, until ZÆTHERION's resident UI replaces DMS's (docs/DECISIONS.md Z159, Z224). DMS's `bar hide` IPC refuses an
island-style bar (BAR_IS_ISLAND), and `settings set` cannot change the bar list, so the core edits the Main Bar in
DMS's settings file. DMS watches that file and applies the change at once (checked in nested Hyprland, 12 and 22
November 2026); a DMS that is down reads it when it starts. Only the Main Bar's `enabled` and `visible` are touched.

Z224: the bar is turned off (`enabled`), not just hidden (`visible`), and before the core starts DMS, so DMS never
makes it: about 57 MiB of DMS's memory (docs/measurements/dms-trim-b051233.txt). Made and turned off later saves only
~14 MiB, so the bar comes back only when the view has been gone SHOW_AFTER seconds (a failed start, given-up
restarts), not for the second a crashed view takes to restart. The core's stop turns it back on after DMS has
stopped, so a DMS started without ZÆTHERION (another session) has its bar.
"""
from __future__ import annotations

import json
import logging
import os
from pathlib import Path

log = logging.getLogger("fart.dmsbar")
BAR_ID = "default"  # DMS's "Main Bar"
SHOW_AFTER = 15.0  # seconds without a ready view before the bar comes back (the view's start limit is 12 s)
TIMER = "dms.bar.show"
ON = {"enabled": True, "visible": True}
OFF = {"enabled": False}  # `visible` is left as it is: an off bar is never made


def settings_path() -> Path:
    config = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(config) / "dms" / "settings.json"


def set_on(path: Path, on: bool) -> bool:
    """True when the file was changed. Written the way DMS writes it (2-space JSON, atomic replace)."""
    settings = json.loads(path.read_text())
    bar = next((b for b in settings.get("barConfigs") or [] if isinstance(b, dict) and b.get("id") == BAR_ID), None)
    want = ON if on else OFF
    if bar is None or all(bar.get(key, True) is value for key, value in want.items()):
        return False
    bar.update(want)
    temp = path.with_name(f".{path.name}.zaetherion")
    temp.write_text(json.dumps(settings, indent=2, ensure_ascii=False))
    os.chmod(temp, path.stat().st_mode & 0o777)
    os.replace(temp, path)
    return True


class DmsBar:
    """`prepare` before DMS starts, `sync` on every change of the view, `release` once DMS has stopped.
    Without a scheduler (tests of the file alone) a view that is not ready brings the bar back at once."""

    def __init__(self, path: Path | None = None, clock=None, scheduler=None):
        self.path = path or settings_path()
        self.clock, self.scheduler = clock, scheduler
        self.want_hidden: bool | None = None
        self.applied: bool | None = None  # True: off in the file; False: on; None: not written yet (or failed)
        self.show_at: float | None = None  # boottime the bar comes back unless the view is ready by then

    def snapshot(self) -> dict:
        return {"wantHidden": self.want_hidden, "applied": self.applied, "showAt": self.show_at}

    def prepare(self):
        """Off before DMS starts (the resident view is about to), and back on unless the view is ready in time:
        the view isn't ready yet, so the bar is wanted back (even if the view never reports a state at all)."""
        self.want_hidden = False
        self._apply(True)
        self._arm()

    def sync(self, hidden: bool):
        self.want_hidden = hidden
        if hidden:
            self._disarm()
            self._apply(True)
        elif self.applied is not False:
            self._arm()

    def release(self):
        """On again, now (the core is stopping and DMS with it)."""
        self.want_hidden = False
        self._disarm()
        self._apply(False)

    def _arm(self):
        clock, scheduler = self.clock, self.scheduler
        if clock is None or scheduler is None:
            self._apply(False)
        elif self.show_at is None:
            self.show_at = clock.now().boot + SHOW_AFTER
            scheduler.at(TIMER, self.show_at, self._due)

    def _disarm(self):
        if self.show_at is not None and self.scheduler is not None:
            self.scheduler.cancel(TIMER)
        self.show_at = None

    def _due(self, _now=None):
        self.show_at = None
        if self.want_hidden is False:
            log.info("DMS bar: no view for %.0f s, turning the bar back on", SHOW_AFTER)
            self._apply(False)

    def _apply(self, hidden: bool):
        if self.applied is hidden:
            return
        try:
            changed = set_on(self.path, not hidden)
        except (OSError, ValueError) as error:
            log.warning("DMS bar: cannot turn it %s: %s", "off" if hidden else "on", error)
            return
        self.applied = hidden
        if changed:
            log.info("DMS bar %s", "off" if hidden else "on")
