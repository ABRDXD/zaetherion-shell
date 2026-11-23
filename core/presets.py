"""Saved looks (Z180): a wallpaper, a palette, the island's form and the host's theme, stored together.

Each part may be empty ("leave it alone"). The core keeps the list in presets.json; previewing and applying are
done by core/app.py through the palette, island and wallpaper owners and one host call, so this module only stores.
"""
from __future__ import annotations

import re
from pathlib import Path

from core.errors import OpError, bad_args
from core.store import read_json, write_json

FIELDS = ("wallpaper", "palette", "islandForm", "hostTheme")
MAX_LOOKS = 64
NAME = re.compile(r"^[^\x00-\x1f]{1,48}$")


def clean(look: dict) -> dict:
    return {key: look.get(key) if isinstance(look.get(key), str) else "" for key in FIELDS}


class Presets:
    def __init__(self, state_dir: Path):
        self.path = state_dir / "presets.json"
        self.on_change = lambda: None
        self.preview = None
        self.owner = None
        try:
            saved = read_json(self.path, {})
        except ValueError:
            saved = {}
        looks = saved.get("looks") if isinstance(saved, dict) else None
        self.looks = []
        for look in looks if isinstance(looks, list) else []:
            if isinstance(look, dict) and isinstance(look.get("name"), str) and NAME.fullmatch(look["name"]) \
                    and not self._find_exact(look["name"]):
                self.looks.append({"name": look["name"], **clean(look)})

    def _find_exact(self, name: str):
        return next((look for look in self.looks if look["name"].casefold() == name.casefold()), None)

    def resolve(self, name: str) -> dict:
        if not isinstance(name, str) or not name.strip():
            raise bad_args("preset name must be text")
        look = self._find_exact(name.strip())
        if look:
            return look
        partial = [look for look in self.looks if name.strip().casefold() in look["name"].casefold()]
        if len(partial) == 1:
            return partial[0]
        raise bad_args("unknown or ambiguous preset; use look list")

    def snapshot(self) -> dict:
        return dict(looks=[dict(look) for look in self.looks], preview=self.preview)

    def save(self, name: str, look: dict) -> dict:
        if not isinstance(name, str) or not NAME.fullmatch(name.strip()):
            raise bad_args("a preset name is 1 to 48 characters")
        name = name.strip()
        existing = self._find_exact(name)
        if existing:
            existing.update(clean(look))
        else:
            if len(self.looks) >= MAX_LOOKS:
                raise OpError("refused", f"at most {MAX_LOOKS} presets")
            self.looks.append({"name": name, **clean(look)})
        self._save()
        return self.snapshot()

    def rename(self, name: str, new: str) -> dict:
        look = self.resolve(name)
        if not isinstance(new, str) or not NAME.fullmatch(new.strip()):
            raise bad_args("a preset name is 1 to 48 characters")
        clash = self._find_exact(new.strip())
        if clash and clash is not look:
            raise OpError("refused", f"a preset called {new.strip()} exists")
        if self.preview == look["name"]:
            self.preview = new.strip()
        look["name"] = new.strip()
        self._save()
        return self.snapshot()

    def delete(self, name: str) -> dict:
        look = self.resolve(name)
        self.looks.remove(look)
        if self.preview == look["name"]:
            self.preview, self.owner = None, None
        self._save()
        return self.snapshot()

    def mark_preview(self, name, owner):
        if name != self.preview or owner is not self.owner:
            self.preview, self.owner = name, owner
            self.on_change()

    def cancel(self, owner=None) -> bool:
        """True when this owner's preview ended (the caller then ends the parts' previews)."""
        if self.preview is not None and (owner is None or owner is self.owner):
            self.preview, self.owner = None, None
            self.on_change()
            return True
        return False

    def _save(self):
        write_json(self.path, {"looks": self.looks})
        self.on_change()
