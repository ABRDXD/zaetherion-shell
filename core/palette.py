"""One persisted palette, plus a connection-owned preview shared by every surface."""
from pathlib import Path

from core.errors import bad_args
from core.palette_catalog import DEFAULT, catalogue, normalize
from core.store import read_json, write_json


MADE = "wall:"
MADE_KEPT = 8


class Palette:
    def __init__(self, state_dir: Path, entries=None):
        self.path = state_dir / "palette.json"
        self.entries = catalogue() if entries is None else entries
        self.on_change = lambda: None
        # Called when the saved palette changes (not on previews): wallpapers that follow it recolour (Z213).
        self.on_choose = lambda: None
        self.owner = None
        self.preview = None
        try:
            saved = read_json(self.path, {})
        except ValueError:
            saved = {}
        name = saved.get("name") if isinstance(saved, dict) else None
        # A palette made from a wallpaper (Z179) is not in any catalogue: its colours are kept with the choice.
        made = saved.get("made") if isinstance(saved, dict) else None
        if isinstance(name, str) and name.startswith(MADE) and isinstance(made, dict) and isinstance(made.get("colors"), dict):
            self.add_made(name, str(made.get("name") or name[len(MADE):]), made["colors"])
        self.name = name if isinstance(name, str) and name in self.entries else DEFAULT

    def add_made(self, key: str, name: str, colors: dict) -> str:
        """A generated palette ("wall:<path>"); the newest few are kept, plus whichever is saved or previewed."""
        self.entries[key] = dict(id=key, name=name, source="Wallpaper", study=False, colors=normalize(colors))
        keep = (key, getattr(self, "name", None), self.preview)
        made = [k for k in self.entries if k.startswith(MADE) and k not in keep]
        for old in made[:-MADE_KEPT] if len(made) > MADE_KEPT else []:
            del self.entries[old]
        return key

    def listing(self) -> list:
        # Generated palettes belong to their wallpaper; only the saved one is listed.
        return [{k: v for k, v in entry.items() if k != "colors"} | {"accent": entry["colors"]["accent"]}
                for key, entry in self.entries.items() if not key.startswith(MADE) or key == self.name]

    def resolve(self, name: str) -> str:
        if not isinstance(name, str):
            raise bad_args("palette name must be text")
        if name in self.entries:
            return name
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
            entry = self.entries[selected]
            made = {"made": {"name": entry["name"], "colors": entry["colors"]}} if selected.startswith(MADE) else {}
            write_json(self.path, {"name": selected, **made})
        saved = selected != self.name
        self.name, self.preview, self.owner = selected, None, None
        if changed:
            self.on_change()
        if saved:
            self.on_choose()
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
