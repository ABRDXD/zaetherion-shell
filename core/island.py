"""The island's settings (Z155): one value for every surface, kept by the core and published as `island`.

The view reads them from the topic; the owner changes them with the `island` verb, from the command line or
`zaetherion island ...`. Stored in the state directory as island.json.
"""
from __future__ import annotations

import logging
from pathlib import Path

from core.errors import bad_args
from core.store import read_json, write_json

log = logging.getLogger("fart.island")

# What shows at rest (Z201): each item's mode; hovered, everything shows. The default is the owner's rest (B).
REST_MODES = {"power": ("always", "matters", "hover"), "network": ("always", "matters", "hover"),
              "battery": ("always", "matters", "hover"), "inbox": ("always", "matters", "unread", "dot", "hover")}
REST_PRESETS = {
    "today": {"power": "always", "network": "always", "battery": "always", "inbox": "always"},
    "a": {"power": "hover", "network": "matters", "battery": "matters", "inbox": "matters"},
    "b": {"power": "hover", "network": "always", "battery": "always", "inbox": "dot"},
    "c": {"power": "hover", "network": "matters", "battery": "always", "inbox": "unread"},
}
DEFAULTS = {"form": "angular", "edge": "top", "placement": "notch", "screen": "", "rest": dict(REST_PRESETS["b"])}
CHOICES = {"form": ("angular", "fluid"), "edge": ("top", "bottom"), "placement": ("notch", "floating")}


class Island:
    def __init__(self, state_dir: Path):
        self.path = state_dir / "island.json"
        self.on_change = lambda: None
        try:
            saved = read_json(self.path, {}) or {}
        except ValueError as error:
            log.warning("%s; using defaults", error)
            saved = {}
        self.state = dict(DEFAULTS)
        self.state["rest"] = dict(DEFAULTS["rest"])
        for key, value in saved.items():
            if key == "rest" and isinstance(value, dict):
                for item, mode in value.items():
                    if mode in REST_MODES.get(item, ()):
                        self.state["rest"][item] = mode
            elif self._valid(key, value):
                self.state[key] = value

    @staticmethod
    def _valid(key, value) -> bool:
        if key == "screen":
            return isinstance(value, str) and len(value) <= 64
        return key in CHOICES and value in CHOICES[key]

    # A preset previews its form (Z180) the way the palette previews colours: owned, never written.
    preview = None
    owner = None

    def snapshot(self) -> dict:
        snapshot = {**self.state, "rest": dict(self.state["rest"])}
        if self.preview:
            snapshot.update(form=self.preview, savedForm=self.state["form"])
        return snapshot

    def preview_form(self, form, owner) -> dict:
        if not self._valid("form", form):
            raise bad_args(f"island form: {form!r} is not one of " + ", ".join(CHOICES["form"]))
        if form != self.preview or owner is not self.owner:
            self.preview, self.owner = form, owner
            self.on_change()
        return self.snapshot()

    def set_rest(self, **modes) -> dict:
        """Each item's mode at rest (power, network, battery, inbox)."""
        for item, mode in modes.items():
            if mode not in REST_MODES.get(item, ()):
                raise bad_args(f"island rest {item}: {mode!r} is not one of " + ", ".join(REST_MODES.get(item, ("power", "network", "battery", "inbox"))))
        rest = {**self.state["rest"], **modes}
        if rest != self.state["rest"]:
            self.state["rest"] = rest
            write_json(self.path, self.state)
            self.on_change()
        return self.snapshot()

    def cancel(self, owner=None) -> dict:
        if self.preview is not None and (owner is None or owner is self.owner):
            self.preview, self.owner = None, None
            self.on_change()
        return self.snapshot()

    def set(self, **changes) -> dict:
        for key, value in changes.items():
            if not self._valid(key, value):
                raise bad_args(f"island {key}: {value!r} is not one of " + ", ".join(CHOICES.get(key, ("a screen name",))))
        if any(self.state[key] != value for key, value in changes.items()):
            self.state.update(changes)
            write_json(self.path, self.state)
            self.on_change()
        return self.snapshot()
