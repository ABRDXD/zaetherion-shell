"""One persisted palette, plus a connection-owned preview shared by every surface."""
from pathlib import Path

from core.errors import bad_args
from core.palette_catalog import DEFAULT, catalogue
from core.store import read_json, write_json


class Palette:
    def __init__(self, state_dir: Path, entries=None):
        self.path = state_dir / "palette.json"
        self.entries = catalogue() if entries is None else entries
        self.on_change = lambda: None
        self.owner = None
        self.preview = None
        try:
            saved = read_json(self.path, {})
        except ValueError:
            saved = {}
        name = saved.get("name") if isinstance(saved, dict) else None
        self.name = name if isinstance(name, str) and name in self.entries else DEFAULT

    def listing(self) -> list:
        return [{k: v for k, v in entry.items() if k != "colors"} | {"accent": entry["colors"]["accent"]}
                for entry in self.entries.values()]

    def resolve(self, name: str) -> str:
        if not isinstance(name, str):
            raise bad_args("palette name must be text")
        matches = [key for key, entry in self.entries.items()
                   if name.casefold() in (key.casefold(), entry["name"].casefold())]
        if len(matches) != 1:
            raise bad_args("unknown or ambiguous palette; use a name or qualified id from palette list")
        return matches[0]

    def snapshot(self) -> dict:
        active = self.preview or self.name
        return dict(name=self.name, effective=active, preview=self.preview is not None,
                    colors=dict(self.entries[active]["colors"]), savedColors=dict(self.entries[self.name]["colors"]))

    def choose(self, name: str) -> dict:
        selected = self.resolve(name)
        changed = selected != self.name or self.preview is not None
        if selected != self.name:
            write_json(self.path, {"name": selected})
        self.name, self.preview, self.owner = selected, None, None
        if changed:
            self.on_change()
        return self.snapshot()

    def preview_name(self, name: str, owner) -> dict:
        selected = self.resolve(name)
        changed = selected != self.preview
        self.preview, self.owner = selected, owner
        if changed:
            self.on_change()
        return self.snapshot()

    def cancel(self, owner=None) -> dict:
        if self.preview is not None and (owner is None or owner is self.owner):
            self.preview, self.owner = None, None
            self.on_change()
        return self.snapshot()
