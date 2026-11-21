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


class Player:
    """A process the core may have to stop: a long sound the view cancels (core/sfx.py STOPPABLE)."""
    __slots__ = ("process", "stopped")

    def __init__(self):
        self.process = None
        self.stopped = False  # stop() came before the process existed

    def stop(self):
        self.stopped = True
        if self.process is not None and self.process.returncode is None:
            try:
                self.process.terminate()
            except ProcessLookupError:
                pass


async def _run(argv: list[str], player: Player | None = None):
    try:
        process = await asyncio.create_subprocess_exec(*argv, stdin=asyncio.subprocess.DEVNULL,
                                                       stdout=asyncio.subprocess.DEVNULL,
                                                       stderr=asyncio.subprocess.DEVNULL)
        if player is not None:
            player.process = process
            if player.stopped:
                player.stop()
        await process.wait()
    except OSError as error:
        log.warning("cannot run %s: %s", argv[0], error.strerror)


class Host:
    def __init__(self, profile):
        self.profile = profile
        self.tasks: set[asyncio.Task] = set()
        self.players: dict[str, Player | bool] = {}  # key -> the live stoppable process (True under a recording profile)
        self.sfx = Sfx(self)  # the core replaces it with one that knows sessions and the sound setting

    @property
    def name(self) -> str:
        return self.profile.name

    def run(self, argv: list[str] | None, key: str | None = None):
        """Runs argv without waiting. A `key` makes it stoppable: it replaces the one before it and `stop(key)` ends it."""
        if not argv:
            return
        if key is not None:
            self.stop(key)
        record = getattr(self.profile, "record", None)
        if record:
            record(argv)
            if key is not None:
                self.players[key] = True
            return
        player = Player() if key is not None else None
        task = asyncio.get_running_loop().create_task(_run(argv, player))
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)
        if player is not None:
            self.players[key] = player
            task.add_done_callback(lambda _: self.players.get(key) is player and self.players.pop(key))

    def stop(self, key: str):
        """SIGTERM to the keyed process; nothing if it never ran or has already ended."""
        player = self.players.pop(key, None)
        if player is True:
            self.profile.record(["stop", key])
        elif player is not None:
            player.stop()

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

    def alert(self, summary: str, body: str, cue: str | None = None, sound: bool | None = None, image: str | None = None):
        """Notify always; the cue goes through the sfx gate (core/sfx.py). `sound` overrides FART's setting; `image`
        is a picture file to show with it."""
        self.run(self.profile.notify_command(summary, body, image) if image else self.profile.notify_command(summary, body))
        if cue:
            self.sfx.emit(cue, sound)
