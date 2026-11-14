"""The wallpaper folder, recent choices and a connection-owned preview (Z177, Z178).

The host owns the applied wallpaper: the view reports what its adapter sees (`wallpaper.report`), and choosing goes
through a host call. The core only scans a plain folder of files, so it knows nothing about any desktop shell.
"""
from __future__ import annotations

import os
from pathlib import Path

from core.errors import OpError, bad_args
from core.store import read_json, write_json

IMAGE = {"jpg", "jpeg", "png", "bmp", "gif", "webp", "jxl", "avif", "heif", "exr", "svg"}
VIDEO = {"mp4", "webm", "mkv", "mov", "m4v", "avi"}
RECENT = 12
DEFAULT_FOLDER = "~/Pictures/Wallpapers"  # Z84


def kind_of(path: Path) -> str | None:
    ext = path.suffix[1:].lower()
    return "image" if ext in IMAGE else "video" if ext in VIDEO else None


class Wallpaper:
    def __init__(self, state_dir: Path, home: Path | None = None):
        self.path = state_dir / "wallpaper.json"
        self.home = home or Path.home()
        self.on_change = lambda: None
        self.owner = None
        self.preview = None
        self.host = dict(available=False, current="", perScreen=False, error="")
        try:
            saved = read_json(self.path, {})
        except ValueError:
            saved = {}
        saved = saved if isinstance(saved, dict) else {}
        folder = saved.get("folder")
        self.folder = folder if isinstance(folder, str) and folder.strip() else DEFAULT_FOLDER
        recent = saved.get("recent")
        self.recent = [p for p in recent if isinstance(p, str)][:RECENT] if isinstance(recent, list) else []

    # The folder

    def folder_path(self) -> Path:
        text = self.folder
        return self.home / text[2:] if text == "~" or text.startswith("~/") else Path(text)

    def scan(self) -> list[dict]:
        """Files directly in the folder, by name; missing or unreadable folders give an empty list."""
        entries = []
        try:
            with os.scandir(self.folder_path()) as it:
                for item in it:
                    path = Path(item.path)
                    kind = kind_of(path)
                    if kind is None or item.name.startswith(".") or not item.is_file():
                        continue
                    try:
                        stat = item.stat()
                    except OSError:
                        continue
                    entries.append(dict(name=path.stem, file=item.name, path=str(path), kind=kind,
                                        size=stat.st_size, mtime=round(stat.st_mtime * 1000)))
        except OSError:
            return []
        return sorted(entries, key=lambda e: e["file"].casefold())

    def listing(self) -> dict:
        folder = self.folder_path()
        return dict(folder=self.folder, exists=folder.is_dir(), entries=self.scan())

    def resolve(self, name: str) -> str:
        """An absolute path inside the folder, a file name, or a name; partial names must match one file."""
        if not isinstance(name, str) or not name.strip():
            raise bad_args("wallpaper name must be text")
        entries = self.scan()
        if not entries:
            raise OpError("refused", f"no wallpapers in {self.folder}")
        wanted = name.strip()
        for entry in entries:
            if wanted == entry["path"]:
                return entry["path"]
        key = wanted.casefold()
        exact = [e for e in entries if key in (e["file"].casefold(), e["name"].casefold())]
        if len(exact) == 1:
            return exact[0]["path"]
        partial = [e for e in entries if key in e["file"].casefold()]
        if len(partial) == 1:
            return partial[0]["path"]
        raise bad_args("unknown or ambiguous wallpaper; use wall list" if not partial
                       else f"{len(partial)} wallpapers match; be more exact")

    def step(self, direction: int) -> str:
        """The next or previous file after the host's current one, wrapping."""
        entries = self.scan()
        if not entries:
            raise OpError("refused", f"no wallpapers in {self.folder}")
        paths = [e["path"] for e in entries]
        index = paths.index(self.host["current"]) if self.host["current"] in paths else (-1 if direction > 0 else 0)
        return paths[(index + direction) % len(paths)]

    def set_folder(self, folder: str) -> dict:
        if not isinstance(folder, str) or not folder.strip() or len(folder) > 1024:
            raise bad_args("folder must be a path")
        folder = folder.strip()
        if folder != self.folder:
            self.folder, self.preview, self.owner = folder, None, None
            self._save()
            self.on_change()
        return self.snapshot()

    # State

    def snapshot(self) -> dict:
        return dict(folder=self.folder, exists=self.folder_path().is_dir(), recent=list(self.recent),
                    preview=self.preview, **self.host)

    def report(self, available=False, current="", perScreen=False, error="") -> dict:
        """What the view's adapter sees; the host stays the authority for the applied wallpaper."""
        state = dict(available=bool(available), current=current if isinstance(current, str) else "",
                     perScreen=bool(perScreen), error=error if isinstance(error, str) else "")
        if state != self.host:
            self.host = state
            self.on_change()
        return self.snapshot()

    def applied(self, path: str) -> dict:
        """After the host set it: remember it, end any preview."""
        self.recent = [path, *[p for p in self.recent if p != path]][:RECENT]
        self.preview, self.owner = None, None
        self._save()
        self.host = {**self.host, "current": path}
        self.on_change()
        return self.snapshot()

    def can_apply(self) -> None:
        if not self.host["available"]:
            raise OpError("refused", str(self.host["error"]) or "the host can't set wallpapers")
        if self.host["perScreen"]:
            raise OpError("refused", "the host sets a wallpaper per screen; turn that off there first")

    def preview_name(self, name: str, owner) -> dict:
        path = self.resolve(name)
        if path != self.preview or owner is not self.owner:
            self.preview, self.owner = path, owner
            self.on_change()
        return self.snapshot()

    def cancel(self, owner=None) -> dict:
        if self.preview is not None and (owner is None or owner is self.owner):
            self.preview, self.owner = None, None
            self.on_change()
        return self.snapshot()

    def _save(self):
        write_json(self.path, {"folder": self.folder, "recent": self.recent})
