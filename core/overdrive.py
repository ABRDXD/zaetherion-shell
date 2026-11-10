"""Overdrive: requested{off, timed, panel, sticky} × guards (docs/CORE.md §6). step() is pure and table-tested."""
from __future__ import annotations

from dataclasses import dataclass, field
import logging
from pathlib import Path

from core.clock import anchor, span
from core.errors import OpError, bad_args
from core.store import read_json, write_json

log = logging.getLogger("fart.overdrive")
MODES = ("off", "timed", "panel", "sticky")
GUARDS = ("fullscreen", "battery", "session")
MAX_SECONDS = 12 * 3600


@dataclass(frozen=True)
class State:
    mode: str = "off"
    until: float | None = None  # boottime deadline of a timed lease
    guards: frozenset = field(default_factory=frozenset)

    @property
    def effective(self) -> str:
        return "off" if self.mode == "off" else "suspended" if self.guards else "active"


OFF = State()
START, STOP, DISARM, PUBLISH, PERSIST = ("start_guards",), ("stop_guards",), ("disarm_timeout",), ("publish",), ("persist",)


def arm(until: float) -> tuple:
    return ("arm_timeout", until)


def step(state: State, event: tuple, now: float) -> tuple[State, list[tuple]]:
    """One transition of the table in docs/CORE.md §6.2. now is boottime seconds."""
    kind, mode = event[0], state.mode
    if kind == "request":
        wanted = event[1]
        if wanted == "timed":  # rows 1, 5, 7
            until = now + event[2]
            if mode == "off":
                return State("timed", until), [START, arm(until), PUBLISH, PERSIST]
            return State("timed", until, state.guards), [arm(until), PUBLISH, PERSIST]
        if wanted == "panel":  # rows 2, 3, 8, 9
            if mode != "off":
                return state, []
            if not event[2]:
                return state, [("refuse", "the panel is not open")]
            return State("panel"), [START, PUBLISH, PERSIST]
        if wanted == "sticky":  # rows 4, 6, 9
            if mode == "off":
                return State("sticky"), [START, PUBLISH, PERSIST]
            if mode == "sticky":
                return state, []
            return State("sticky", None, state.guards), ([DISARM] if mode == "timed" else []) + [PUBLISH, PERSIST]
        raise ValueError(wanted)
    if kind == "release":  # rows 10, 17
        if mode == "off":
            return state, []
        return OFF, [STOP] + ([DISARM] if mode == "timed" else []) + [PUBLISH, PERSIST]
    if kind == "timeout":  # rows 11, 16
        return (OFF, [STOP, PUBLISH, PERSIST]) if mode == "timed" else (state, [])
    if kind == "panel_closed":  # rows 12, 13, 16
        return (OFF, [STOP, PUBLISH, PERSIST]) if mode == "panel" else (state, [])
    if kind in ("guard_on", "guard_off"):  # rows 14, 15, 16
        if mode == "off":
            return state, []
        guards = state.guards | {event[1]} if kind == "guard_on" else state.guards - {event[1]}
        if guards == state.guards:
            return state, []
        return State(mode, state.until, frozenset(guards)), [PUBLISH]
    raise ValueError(kind)


class Overdrive:
    """Runs step() against the scheduler, the guard monitors and overdrive.json."""

    def __init__(self, clock, scheduler, guards, state_dir: Path, view_open=lambda: False):
        self.clock = clock
        self.scheduler = scheduler
        self.guards = guards  # .start() -> set of guards already on; .stop(); calls self.guard(name, on)
        self.path = state_dir / "overdrive.json"
        self.view_open = view_open
        self.on_change = lambda: None
        self.on_release = lambda: None
        self.state = OFF
        self.lease = None  # persisted form of a timed lease: {anchor, seconds}
        self.since = clock.now()
        self._restore()

    def _restore(self):  # row 18
        try:
            saved = read_json(self.path, {}) or {}
        except ValueError:
            saved = {}
        now = self.clock.now()
        if saved.get("mode") == "sticky":
            self._apply(("request", "sticky"))
        elif saved.get("mode") == "timed" and isinstance(saved.get("anchor"), dict):
            left = float(saved.get("seconds") or 0) - span(saved["anchor"], now)
            if left > 0:
                self._apply(("request", "timed", left))
                return
        if saved.get("mode") not in (None, "off", "sticky"):
            self._persist()

    def _apply(self, event: tuple):
        now = self.clock.now()
        before = self.state.effective
        self.state, effects = step(self.state, event, now.boot)
        if self.state.effective != before:
            self.since = now
        refused = None
        for effect in effects:
            name = effect[0]
            if name == "start_guards":
                for guard in sorted(self.guards.start()):
                    self.state, _ = step(self.state, ("guard_on", guard), now.boot)
                if self.state.effective != before:
                    self.since = now
            elif name == "stop_guards":
                self.guards.stop()
                self.on_release()
            elif name == "arm_timeout":
                self.lease = {"anchor": anchor(now), "seconds": effect[1] - now.boot}
                self.scheduler.at("overdrive.timeout", effect[1], lambda _: self._apply(("timeout",)))
            elif name == "disarm_timeout":
                self.scheduler.cancel("overdrive.timeout")
            elif name == "persist":
                self._persist()
            elif name == "publish":
                self.on_change()
            elif name == "refuse":
                refused = effect[1]
        if self.state.mode != "timed":
            self.lease = None
            self.scheduler.cancel("overdrive.timeout")
        if refused:
            raise OpError("refused", refused)

    def _persist(self):
        value = {"mode": self.state.mode}
        if self.state.mode == "timed" and self.lease:
            value.update(self.lease)
        write_json(self.path, value)

    # Inputs

    def request(self, mode, seconds=None):
        if mode == "timed":
            if isinstance(seconds, bool) or not isinstance(seconds, (int, float)) or not 1 <= seconds <= MAX_SECONDS:
                raise bad_args(f"seconds must be between 1 and {MAX_SECONDS}")
            self._apply(("request", "timed", float(seconds)))
        elif mode == "panel":
            self._apply(("request", "panel", self.view_open()))
        elif mode == "sticky":
            self._apply(("request", "sticky"))
        else:
            raise bad_args("mode must be timed, panel or sticky")
        return self.snapshot()

    def release(self):
        self._apply(("release",))
        return self.snapshot()

    def panel_closed(self):
        self._apply(("panel_closed",))

    def guard(self, name: str, on: bool):
        self._apply(("guard_on" if on else "guard_off", name))

    def snapshot(self) -> dict:
        now = self.clock.now()
        until = None
        if self.state.mode == "timed" and self.state.until is not None:
            until = round((now.real + self.state.until - now.boot) * 1000)
        since = round((now.real - (now.boot - self.since.boot)) * 1000)
        return {"requested": {"mode": self.state.mode, "until": until}, "effective": self.state.effective,
                "reasons": sorted(self.state.guards), "since": since, "guards": self.guards.availability()}
