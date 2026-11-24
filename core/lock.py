"""The session lock's state (S7, docs/LOCK.md): whether ZÆTHERION's lock is up, kept where a restarted core or view finds it.

`lock.engage` (DMS's custom lock command runs `zaetherion lock`; idle, logind and sleep all reach it that way) puts the
lock up; only `lock.release` from the view that holds it, after PAM said yes, takes it down. The state is written to
`locked` in the runtime folder **before** it is published, so a core that dies keeps it and a respawned view re-locks.
The core never unlocks by itself: no timeout, no other op.
"""
from __future__ import annotations

import json
import logging
import os
import time
from pathlib import Path

from core.errors import OpError, bad_args

log = logging.getLogger("fart.lock")
REASONS = ("command", "idle", "logind", "sleep", "session")


class Lock:
    def __init__(self, runtime_dir: Path, unlocked=lambda: None, clock=time.time):
        self.path = runtime_dir / "locked"
        self.on_change = lambda: None
        self.unlocked = unlocked  # tells logind (and so DMS) the session is unlocked
        self.clock = clock
        self.state = {"locked": False, "since": None, "reason": None}
        try:
            saved = json.loads(self.path.read_text())
        except FileNotFoundError:
            saved = None
        except (OSError, ValueError):
            saved = {}  # a marker we can't read still means locked: never open the session on a bad file
        if saved is not None:
            saved = saved if isinstance(saved, dict) else {}
            since = saved.get("since")
            reason = saved.get("reason")
            self.state = {"locked": True,
                          "since": since if isinstance(since, (int, float)) and not isinstance(since, bool) else None,
                          "reason": reason if reason in REASONS else "command"}
            log.warning("locked at start (marker %s)", self.path)

    def snapshot(self) -> dict:
        return dict(self.state)

    @property
    def locked(self) -> bool:
        return self.state["locked"]

    def _write(self, value: dict):
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        temp = self.path.with_name(f".locked.{os.getpid()}.tmp")
        with open(os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_CLOEXEC, 0o600), "w") as out:
            out.write(json.dumps(value))
            out.flush()
            os.fsync(out.fileno())
        os.replace(temp, self.path)

    def engage(self, reason="command") -> dict:
        if reason not in REASONS:
            raise bad_args("reason must be one of " + ", ".join(REASONS))
        if self.locked:
            return self.snapshot()  # one lock; a second request changes nothing
        state = {"locked": True, "since": round(self.clock() * 1000), "reason": reason}
        self._write(state)  # first: a crash after this still finds the lock
        self.state = state
        log.info("locked (%s)", reason)
        self.on_change()
        return self.snapshot()

    def release(self, peer_kind: str) -> dict:
        """Only the view, after PAM: no other client and no other path takes the lock down."""
        if peer_kind != "view":
            raise OpError("refused", "only the view that holds the lock releases it")
        if not self.locked:
            raise OpError("refused", "the session is not locked")
        try:
            self.path.unlink()
        except FileNotFoundError:
            pass
        self.state = {"locked": False, "since": None, "reason": None}
        log.info("unlocked")
        self.on_change()
        try:
            self.unlocked()
        except Exception:
            log.exception("telling logind the session is unlocked")
        return self.snapshot()
