"""The core's route to the host: a profile beside the QML adapter, plus FART's alert policy (D19)."""
from __future__ import annotations

import asyncio
import importlib.util
import logging
from pathlib import Path

from core.sfx import Sfx

ROOT = Path(__file__).resolve().parents[1]
log = logging.getLogger("fart.host")


def load_profile(name: str):
    """adapters/<name>/core.py:HostProfile. Host knowledge never lives in core/."""
    path = ROOT / "adapters" / name / "core.py"
    if not name.isidentifier() or not path.is_file():
        raise ValueError(f"unknown host profile {name!r}")
    spec = importlib.util.spec_from_file_location(f"fart_host_{name}", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.HostProfile()


async def _run(argv: list[str]):
    try:
        process = await asyncio.create_subprocess_exec(*argv, stdin=asyncio.subprocess.DEVNULL,
                                                       stdout=asyncio.subprocess.DEVNULL,
                                                       stderr=asyncio.subprocess.DEVNULL)
        await process.wait()
    except OSError as error:
        log.warning("cannot run %s: %s", argv[0], error.strerror)


class Host:
    def __init__(self, profile):
        self.profile = profile
        self.tasks: set[asyncio.Task] = set()
        self.sfx = Sfx(self)  # the core replaces it with one that knows sessions and the sound setting

    @property
    def name(self) -> str:
        return self.profile.name

    def run(self, argv: list[str] | None):
        if not argv:
            return
        record = getattr(self.profile, "record", None)
        if record:
            record(argv)
            return
        task = asyncio.get_running_loop().create_task(_run(argv))
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)

    def dnd(self) -> bool:
        reader = getattr(self.profile, "dnd", None)
        try:
            return bool(reader()) if reader else False
        except Exception:
            log.exception("the host's Do Not Disturb")
            return False

    def set_dnd(self, on: bool) -> bool:
        """Turns the host's Do Not Disturb on or off (a session, M11). True if the host did it."""
        writer = getattr(self.profile, "set_dnd", None)
        if writer is None:
            return False
        try:
            return writer(bool(on)) is True
        except Exception:
            log.exception("setting the host's Do Not Disturb")
            return False

    def focus(self, start_ms: int, end_ms: int) -> list | None:
        """The host's own focus tracker, read-only (M11's debrief): [[app class, seconds]] over the span, most first,
        at most four; None when the host keeps none, or it is missing or locked. Never window titles."""
        reader = getattr(self.profile, "focus", None)
        if reader is None:
            return None
        try:
            found = reader(start_ms, end_ms)
        except Exception:  # a host's tracker never stops a session ending
            log.exception("the host's focus tracker")
            return None
        if not isinstance(found, list):
            return None
        out = [[str(c)[:32], int(s)] for c, s in found if isinstance(c, str) and isinstance(s, (int, float)) and s > 0]
        return sorted(out, key=lambda r: -r[1])[:4]

    def alert(self, summary: str, body: str, cue: str | None = None, sound: bool | None = None):
        """Notify always; the cue goes through the sfx gate (core/sfx.py). `sound` overrides FART's setting."""
        self.run(self.profile.notify_command(summary, body))
        if cue:
            self.sfx.emit(cue, sound)
