"""Suspend-proof time: boottime anchors, a realtime fallback across reboots, and one timerfd scheduler.

asyncio's own timers run on CLOCK_MONOTONIC, which stops during suspend, so no user-visible
deadline is ever scheduled on them.
"""
from __future__ import annotations

from dataclasses import dataclass
import errno
import os
from pathlib import Path
import time
from typing import Callable, NamedTuple


class Now(NamedTuple):
    boot: float  # CLOCK_BOOTTIME seconds: counts suspend, ignores wall-clock changes
    real: float  # epoch seconds
    boot_id: str


class SystemClock:
    def __init__(self):
        self.boot_id = Path("/proc/sys/kernel/random/boot_id").read_text().strip()

    def now(self) -> Now:
        return Now(time.clock_gettime(time.CLOCK_BOOTTIME), time.time(), self.boot_id)


def anchor(now: Now) -> dict:
    return {"boot": now.boot, "real": now.real, "bootId": now.boot_id}


def span(start: dict, now: Now) -> float:
    if start.get("bootId") == now.boot_id:
        return now.boot - start["boot"]
    return max(0.0, now.real - start["real"])


@dataclass
class Run:
    """Elapsed time that survives suspend, core restarts and (by realtime) reboots."""
    running: bool = False
    elapsed: float = 0.0
    anchor: dict | None = None

    @classmethod
    def since(cls, elapsed: float, now: Now) -> Run:
        """A run that already has elapsed seconds behind it and keeps counting from now."""
        return cls(True, max(0.0, elapsed), anchor(now))

    def value(self, now: Now) -> float:
        if not self.running or not self.anchor:
            return self.elapsed
        return self.elapsed + max(0.0, span(self.anchor, now))

    def start(self, now: Now):
        if not self.running:
            self.running, self.anchor = True, anchor(now)

    def pause(self, now: Now):
        if self.running:
            self.elapsed, self.running, self.anchor = self.value(now), False, None

    def reset(self, elapsed: float = 0.0):
        self.running, self.elapsed, self.anchor = False, elapsed, None

    def rebase(self, now: Now) -> bool:
        # Fold a foreign-boot anchor once; afterwards only boottime arithmetic applies.
        if self.running and self.anchor and self.anchor.get("bootId") != now.boot_id:
            self.elapsed, self.anchor = self.value(now), anchor(now)
            return True
        return False

    def deadline(self, target: float, now: Now) -> float:
        """The boottime at which value() reaches target (only meaningful while running)."""
        return now.boot + (target - self.value(now))

    def to_json(self) -> dict:
        return {"running": self.running, "elapsed": self.elapsed, "anchor": self.anchor}

    @classmethod
    def from_json(cls, value) -> Run:
        value = value if isinstance(value, dict) else {}
        run = cls(bool(value.get("running")), float(value.get("elapsed") or 0), value.get("anchor"))
        if run.running and not isinstance(run.anchor, dict):
            run.running = False
        return run


class Scheduler:
    """Keyed boottime deadlines; subclasses decide how the earliest one wakes the loop."""

    def __init__(self, clock):
        self.clock = clock
        self.pending: dict[str, tuple[float, Callable[[Now], None]]] = {}
        self.clock_set: list[Callable[[], None]] = []

    def at(self, key: str, boot: float, callback: Callable[[Now], None]):
        self.pending[key] = (boot, callback)
        self._arm(self.next())

    def cancel(self, key: str):
        if self.pending.pop(key, None) is not None:
            self._arm(self.next())

    def next(self) -> float | None:
        return min((boot for boot, _ in self.pending.values()), default=None)

    def fire_due(self):
        now = self.clock.now()
        due = sorted((boot, key) for key, (boot, _) in self.pending.items() if boot <= now.boot)
        for _, key in due:
            entry = self.pending.pop(key, None)
            if entry:
                entry[1](now)
        self._arm(self.next())

    def realtime_changed(self):
        for callback in list(self.clock_set):
            callback()

    def _arm(self, boot: float | None):
        pass


class TimerfdScheduler(Scheduler):
    """One CLOCK_BOOTTIME timerfd armed to the earliest deadline, plus a wall-clock-change watch."""

    def __init__(self, clock, loop):
        super().__init__(clock)
        flags = os.TFD_NONBLOCK | os.TFD_CLOEXEC
        self.fd = os.timerfd_create(time.CLOCK_BOOTTIME, flags=flags)
        self.realtime = os.timerfd_create(time.CLOCK_REALTIME, flags=flags)
        loop.add_reader(self.fd, self._expired)
        loop.add_reader(self.realtime, self._realtime)
        self._watch_realtime()

    def _arm(self, boot):
        # 0 disarms; a deadline already past fires at once (1 ns after epoch of the clock).
        initial = 0 if boot is None else max(boot, 1e-9)
        os.timerfd_settime(self.fd, flags=os.TFD_TIMER_ABSTIME, initial=initial)

    def _expired(self):
        try:
            os.read(self.fd, 8)
        except BlockingIOError:
            pass
        self.fire_due()

    def _watch_realtime(self):
        far = time.time() + 10 * 365 * 86400
        os.timerfd_settime(self.realtime, flags=os.TFD_TIMER_ABSTIME | os.TFD_TIMER_CANCEL_ON_SET, initial=far)

    def _realtime(self):
        try:
            os.read(self.realtime, 8)
        except BlockingIOError:
            return
        except OSError as error:
            if error.errno != errno.ECANCELED:
                raise
        self._watch_realtime()
        self.realtime_changed()
        self.fire_due()
