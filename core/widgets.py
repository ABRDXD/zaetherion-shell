"""Desktop widgets' layout (Z46, Z85, Z86): where each widget sits on each monitor, per layout preset.

Stored in the state directory as widgets.json. A pose is on the display's 12-column grid: the first column (0-11),
the span in columns, the centre's height as a share of the screen's height, and the angle in degrees. Layouts are
named presets ("Default" first); each holds a pose per monitor (by connector name) and widget. A monitor with no
saved pose shows the widget at its default pose. `shown` turns them all off and on, keeping every pose. Face settings are kept beside the layouts and are never changed
by placing a widget (resetting the face keeps the pose).
"""
from __future__ import annotations

import logging
import re
from pathlib import Path

from core.errors import bad_args
from core.store import read_json, write_json

log = logging.getLogger("fart.widgets")

COLUMNS = 12
WIDGETS = {"clock": {"minSpan": 3}}
DEFAULT_POSE = {"column": 2, "span": 8, "y": 0.42, "angle": 0}
FACE = {"spacing": "original", "date": "full", "hours": 24, "ink": "original"}
DEFAULT_LAYOUT = "Default"
MAX_LAYOUTS = 12
MAX_MONITORS = 16
NAME = re.compile(r"[^\x00-\x1f]{1,32}")
MONITOR = re.compile(r"[A-Za-z0-9_.:-]{1,64}")


def clean_pose(widget: str, pose) -> dict | None:
    """A saved or sent pose, checked; None when it isn't one."""
    if not isinstance(pose, dict):
        return None
    column, span, y, angle = (pose.get(k) for k in ("column", "span", "y", "angle"))
    if not (isinstance(column, int) and isinstance(span, int) and isinstance(angle, int)):
        return None
    if any(isinstance(v, bool) for v in (column, span, angle, y)) or not isinstance(y, (int, float)):
        return None
    if not (WIDGETS[widget]["minSpan"] <= span <= COLUMNS and 0 <= column <= COLUMNS - span):
        return None
    if not (0.0 <= y <= 1.0 and -180 <= angle <= 180):
        return None
    return {"column": column, "span": span, "y": round(float(y), 4), "angle": angle}


class Widgets:
    def __init__(self, state_dir: Path):
        self.path = state_dir / "widgets.json"
        self.on_change = lambda: None
        try:
            saved = read_json(self.path, {}) or {}
        except ValueError as error:
            log.warning("%s; using defaults", error)
            saved = {}
        if not isinstance(saved, dict):
            saved = {}
        layouts: dict = {}
        saved_layouts = saved.get("layouts")
        for name, monitors in (saved_layouts.items() if isinstance(saved_layouts, dict) else ()):
            if not (isinstance(name, str) and NAME.fullmatch(name)) or not isinstance(monitors, dict) or len(layouts) >= MAX_LAYOUTS:
                continue
            kept = {}
            for monitor, poses in monitors.items():
                if not (isinstance(monitor, str) and MONITOR.fullmatch(monitor)) or not isinstance(poses, dict):
                    continue
                good = {w: p for w, p in ((w, clean_pose(w, p)) for w, p in poses.items() if w in WIDGETS) if p}
                if good and len(kept) < MAX_MONITORS:
                    kept[monitor] = good
            layouts[name] = kept
        layouts.setdefault(DEFAULT_LAYOUT, {})
        layout = saved.get("layout")
        face = saved.get("face")
        face = face if isinstance(face, dict) else {}
        shown = saved.get("shown")
        self.state = {
            "version": 1,
            "shown": shown if isinstance(shown, bool) else True,
            "layout": layout if isinstance(layout, str) and layout in layouts else DEFAULT_LAYOUT,
            "layouts": layouts,
            "face": {k: face[k] if face.get(k) in self._face_choices(k) else v for k, v in FACE.items()},
        }

    @staticmethod
    def _face_choices(key):
        return {"spacing": ("close", "original", "wide"), "date": ("full", "short"), "hours": (12, 24),
                "ink": ("original", "copper", "tide")}[key]

    def snapshot(self) -> dict:
        layout = self.state["layouts"][self.state["layout"]]
        return {"shown": self.state["shown"], "layout": self.state["layout"], "layouts": list(self.state["layouts"]),
                "monitors": {m: dict(p) for m, p in layout.items()}, "defaults": {w: dict(DEFAULT_POSE) for w in WIDGETS},
                "columns": COLUMNS, "minSpan": {w: spec["minSpan"] for w, spec in WIDGETS.items()},
                "face": dict(self.state["face"])}

    def pose(self, monitor: str, widget: str = "clock") -> dict:
        return dict(self.state["layouts"][self.state["layout"]].get(monitor, {}).get(widget, DEFAULT_POSE))

    def _commit(self):
        write_json(self.path, self.state)
        self.on_change()

    def place(self, monitor, widget, column, span, y, angle) -> dict:
        if widget not in WIDGETS:
            raise bad_args(f"widget: {widget!r} is not one of " + ", ".join(WIDGETS))
        if not isinstance(monitor, str) or not MONITOR.fullmatch(monitor):
            raise bad_args("monitor must be a connector name")
        pose = clean_pose(widget, {"column": column, "span": span, "y": y, "angle": angle})
        if pose is None:
            raise bad_args(f"a {widget} pose is column 0-{COLUMNS - 1}, span {WIDGETS[widget]['minSpan']}-{COLUMNS} "
                           f"within the grid, y 0-1 and angle -180 to 180")
        layout = self.state["layouts"][self.state["layout"]]
        if monitor not in layout and len(layout) >= MAX_MONITORS:
            raise bad_args(f"at most {MAX_MONITORS} monitors in a layout")
        if layout.get(monitor, {}).get(widget) != pose:
            layout.setdefault(monitor, {})[widget] = pose
            self._commit()
        return self.snapshot()

    def show(self, on) -> dict:
        """Widgets on or off on every screen (owner, 24 Nov: from the desktop menu and the editor). Poses are kept."""
        if not isinstance(on, bool):
            raise bad_args("on must be true or false")
        if on != self.state["shown"]:
            self.state["shown"] = on
            self._commit()
        return self.snapshot()

    def use_layout(self, name) -> dict:
        """Switch to a layout preset; a new name starts as a copy of the current one."""
        if not isinstance(name, str) or not NAME.fullmatch(name.strip()):
            raise bad_args("a layout name is 1-32 characters")
        name = name.strip()
        layouts = self.state["layouts"]
        if name not in layouts:
            if len(layouts) >= MAX_LAYOUTS:
                raise bad_args(f"at most {MAX_LAYOUTS} layouts")
            current = layouts[self.state["layout"]]
            layouts[name] = {m: {w: dict(p) for w, p in poses.items()} for m, poses in current.items()}
        elif name == self.state["layout"]:
            return self.snapshot()
        self.state["layout"] = name
        self._commit()
        return self.snapshot()

    def reset_face(self) -> dict:
        """The face's defaults; every pose stays as it is."""
        if self.state["face"] != FACE:
            self.state["face"] = dict(FACE)
            self._commit()
        return self.snapshot()
