"""Clips settings and the clipboard recorders (S3, Z184): published as `clips`, changed from FART's Clips tab.

The settings are quick paste's (what Enter does, how many rows, images shown) and the history's (how many entries
are kept, whether images are recorded). The recorders are the processes that record the clipboard; their command
lines come from the host profile (`clip_recorders(keep, images)`), since core/ never names a host tool. A core runs
them only once attached (fartd, FART_CLIP_RECORDER=1, which the session sets once its own recorder lines are gone);
until then the history settings are shown as the session's and are not applied. Each recorder is restarted after
it stops by itself, with a back-off, and given up after four stops in a minute; all of them stop with the core.
"""
from __future__ import annotations

import asyncio
import logging
from pathlib import Path

from core.errors import bad_args
from core.store import read_json, write_json

log = logging.getLogger("fart.clips")

DEFAULTS = {"enterPastes": False, "rows": 6, "showImages": True, "keep": 750, "recordImages": True}
KEEP = (100, 250, 750, 1500)
BACKOFF = (1.0, 2.0, 4.0)
FAILURE_WINDOW = 60.0


def valid(key, value) -> bool:
    if key in ("enterPastes", "showImages", "recordImages"):
        return isinstance(value, bool)
    if key == "rows":
        return isinstance(value, int) and not isinstance(value, bool) and 4 <= value <= 10
    if key == "keep":
        return value in KEEP and not isinstance(value, bool)
    return False


class Clips:
    def __init__(self, state_dir: Path):
        self.path = state_dir / "clips.json"
        self.on_change = lambda: None
        try:
            saved = read_json(self.path, {}) or {}
        except ValueError as error:
            log.warning("%s; using defaults", error)
            saved = {}
        self.state = dict(DEFAULTS)
        for key, value in (saved.items() if isinstance(saved, dict) else ()):
            if valid(key, value):
                self.state[key] = value
        self.recorders = None  # a function (keep, images) -> [argv, ...], given by attach()
        self.status = "session"  # session (not ours) | on | retrying | failed
        self.error = ""
        self._runner = None
        self._restart = None
        self._closing = False

    def snapshot(self) -> dict:
        return {**self.state, "keepChoices": list(KEEP), "recording": self.status, "error": self.error}

    def set(self, key, value) -> dict:
        if not valid(key, value):
            raise bad_args(f"clips {key}: {value!r} is not allowed")
        if self.state[key] != value:
            self.state[key] = value
            write_json(self.path, self.state)
            if key in ("keep", "recordImages"):
                self._reload()
            self.on_change()
        return self.snapshot()

    # The recorders

    def attach(self, recorders):
        """This core records the clipboard (fartd): start the recorders the host profile names."""
        self.recorders = recorders
        self._reload()

    def _reload(self):
        if self.recorders is None or self._closing:
            return
        if self._runner is not None:
            self._runner.cancel()  # its finally starts the new set
            return
        self._runner = asyncio.get_running_loop().create_task(self._run())

    def _status(self, status: str, error: str = ""):
        if (status, error) != (self.status, self.error):
            self.status, self.error = status, error
            self.on_change()

    async def _run(self):
        loop = asyncio.get_running_loop()
        stops = []
        processes = []
        try:
            while True:
                recorders = self.recorders
                if recorders is None:
                    return
                argvs = recorders(self.state["keep"], self.state["recordImages"])
                try:
                    processes = [await asyncio.create_subprocess_exec(*argv, stdin=asyncio.subprocess.DEVNULL,
                                 stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
                                 for argv in argvs]
                except OSError as error:
                    reason = str(error)
                else:
                    self._status("on")
                    done, _ = await asyncio.wait([asyncio.ensure_future(p.wait()) for p in processes],
                                                 return_when=asyncio.FIRST_COMPLETED)
                    reason = f"a recorder exited ({next(iter(done)).result()})"
                await self._stop(processes)
                log.warning("clipboard recorder stopped: %s", reason)
                now = loop.time()
                stops = [t for t in stops if now - t < FAILURE_WINDOW] + [now]
                if len(stops) > len(BACKOFF):
                    self._status("failed", reason)
                    return
                self._status("retrying", reason)
                await asyncio.sleep(BACKOFF[len(stops) - 1])
        except asyncio.CancelledError:
            pass
        finally:
            await self._stop(processes)
            self._runner = None
            if not self._closing and self.status != "failed":
                self._reload()  # cancelled for new settings: start again with them

    @staticmethod
    async def _stop(processes):
        for process in processes:
            if process.returncode is None:
                try:
                    process.terminate()
                except ProcessLookupError:
                    pass
        for process in processes:
            try:
                await asyncio.wait_for(process.wait(), 2)
            except asyncio.TimeoutError:
                process.kill()
                await process.wait()

    async def close(self):
        self._closing = True
        if self._runner is not None:
            self._runner.cancel()
            try:
                await self._runner
            except asyncio.CancelledError:
                pass
