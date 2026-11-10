"""The journey (docs/OVERDRIVE_IDEAS.md): which rooms were visited, in what order and for how long.

The orbit's laws read it: rooms you bounce between grow a Lagrange shelf, habits bend stalks and lock into resonance,
the room you live in stops drifting. It is fed by the view's own reports (view.state), so it costs nothing while
the panel is closed. Only room ids, counts and times are kept, never what was in a room; `journey.forget` wipes it.
Old links fade by a tenth or so a day, so the shape follows how you work now.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta
import logging
from pathlib import Path

from core.store import read_json, write_json

log = logging.getLogger("fart.journey")
ROOMS = ("home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex")
DECAY = 0.92  # of each link and each room's time, per day
KEEP_DAYS = 30
RECENT = 48
SESSION_GAP = 600.0  # seconds between a close and the next open that still count as one journey
RESONANCE_WINDOW = 3600.0
RESONANCE_REPEATS = 3
SAVE_AFTER = 5.0


def empty() -> dict:
    return {"version": 1, "edges": {}, "seconds": {}, "visits": {}, "hours": {}, "days": {}, "recent": [], "decayed": None}


def clean(saved) -> dict:
    """What can be used of a saved file; anything else starts empty."""
    state = empty()
    if not isinstance(saved, dict):
        return state
    number = lambda v: isinstance(v, (int, float)) and not isinstance(v, bool) and v >= 0
    edge = lambda k: isinstance(k, str) and k.count(">") == 1 and all(p in ROOMS for p in k.split(">"))
    for key in ("edges", "seconds", "visits"):
        value = saved.get(key)
        if isinstance(value, dict):
            state[key] = {k: v for k, v in value.items() if number(v) and (edge(k) if key == "edges" else k in ROOMS)}
    hours = saved.get("hours")
    if isinstance(hours, dict):
        state["hours"] = {k: v for k, v in hours.items() if k in ROOMS and isinstance(v, list) and len(v) == 24 and all(number(n) for n in v)}
    days = saved.get("days")
    if isinstance(days, dict):
        state["days"] = {d: {k: n for k, n in v.items() if k in ROOMS and number(n)} for d, v in days.items() if isinstance(d, str) and isinstance(v, dict)}
    recent = saved.get("recent")
    if isinstance(recent, list):
        state["recent"] = [[r[0], r[1]] for r in recent if isinstance(r, list) and len(r) == 2 and r[0] in ROOMS and number(r[1])][-RECENT:]
    if isinstance(saved.get("decayed"), str):
        state["decayed"] = saved["decayed"]
    return state


def resonance(recent: list, now: float) -> list:
    """The three-room loop repeated most in the last hour, if any has come round at least three times."""
    rooms = [room for room, at in recent if now - at <= RESONANCE_WINDOW]
    counts: dict[tuple, int] = {}
    for a, b, c in zip(rooms, rooms[1:], rooms[2:]):
        if a != b and b != c and a != c:
            # The same loop entered at another point is the same loop.
            turn = min((a, b, c), (b, c, a), (c, a, b))
            counts[turn] = counts.get(turn, 0) + 1
    if not counts:
        return []
    best, seen = max(sorted(counts.items()), key=lambda item: item[1])
    # Every step along the loop is one window of three, so n times round is 3n - 2 windows.
    return list(best) if seen >= RESONANCE_REPEATS * 3 - 2 else []


class Journey:
    def __init__(self, clock, scheduler, state_dir: Path):
        self.clock = clock
        self.scheduler = scheduler
        self.path = state_dir / "journey.json"
        self.on_change = lambda: None
        try:
            self.state = clean(read_json(self.path, None))
        except ValueError:
            log.warning("journey.json is not JSON; starting a new journey")
            self.state = empty()
        self.current: str | None = None
        self.arrived: float | None = None  # boottime of the current visit
        self.last: str | None = None  # the room before this one, while the journey is unbroken
        self.left: float | None = None  # boottime the panel last closed

    # Inputs

    def report(self, open: bool, page: str):
        now = self.clock.now()
        if not open:
            self._leave(now)
            return
        if page not in ROOMS or page == self.current:
            return
        self._decay(now)
        before = self.current or (self.last if self.left is not None and now.boot - self.left <= SESSION_GAP else None)
        self._leave(now)
        self.left = None
        state = self.state
        if before and before != page:
            key = f"{before}>{page}"
            state["edges"][key] = state["edges"].get(key, 0.0) + 1.0
        local = datetime.fromtimestamp(now.real)
        state["visits"][page] = state["visits"].get(page, 0) + 1
        hours = state["hours"].setdefault(page, [0] * 24)
        hours[local.hour] += 1
        day = state["days"].setdefault(local.date().isoformat(), {})
        day[page] = day.get(page, 0) + 1
        state["recent"] = (state["recent"] + [[page, round(now.real, 1)]])[-RECENT:]
        self.current, self.arrived = page, now.boot
        self._changed(now)

    def closed(self):
        """The view went away (closed, crashed or reaped)."""
        self._leave(self.clock.now())

    def forget(self) -> dict:
        self.state = empty()
        self.current = self.arrived = self.last = self.left = None
        self.scheduler.cancel("journey.save")
        write_json(self.path, self.state)
        self.on_change()
        return self.snapshot()

    def flush(self):
        self.scheduler.cancel("journey.save")
        write_json(self.path, self.state)

    # Inside

    def _leave(self, now):
        if self.current is None:
            return
        spent = max(0.0, now.boot - self.arrived)
        self.state["seconds"][self.current] = self.state["seconds"].get(self.current, 0.0) + spent
        self.last, self.current, self.arrived = self.current, None, None
        self.left = now.boot
        self._changed(now)

    def _decay(self, now):
        today = datetime.fromtimestamp(now.real).date()
        state = self.state
        stamp = today.isoformat()
        if state["decayed"] == stamp:
            return
        try:
            days = max(0, (today - date.fromisoformat(state["decayed"])).days) if state["decayed"] else 0
        except ValueError:
            days = 0
        if days:
            factor = DECAY ** days
            state["edges"] = {k: v * factor for k, v in state["edges"].items() if v * factor >= 0.05}
            state["seconds"] = {k: v * factor for k, v in state["seconds"].items()}
        oldest = (today - timedelta(days=KEEP_DAYS)).isoformat()
        state["days"] = {d: v for d, v in state["days"].items() if d >= oldest}
        state["decayed"] = stamp

    def _changed(self, now):
        self.on_change()
        self.scheduler.at("journey.save", now.boot + SAVE_AFTER, lambda _: self.flush())

    # Output

    def trend(self) -> dict:
        """For each room, -1..1: how its use over the last week compares with the week before."""
        today = datetime.fromtimestamp(self.clock.now().real).date()
        recent, earlier = {}, {}
        for stamp, rooms in self.state["days"].items():
            try:
                age = (today - date.fromisoformat(stamp)).days
            except ValueError:
                continue
            bucket = recent if 0 <= age < 7 else earlier if 7 <= age < 14 else None
            if bucket is not None:
                for room, count in rooms.items():
                    bucket[room] = bucket.get(room, 0) + count
        return {room: round((recent.get(room, 0) - earlier.get(room, 0)) / max(1, recent.get(room, 0) + earlier.get(room, 0)), 3)
                for room in set(recent) | set(earlier)}

    def snapshot(self) -> dict:
        state = self.state
        joined: dict[tuple, float] = {}
        for key, weight in state["edges"].items():
            a, b = key.split(">")
            if "home" in (a, b):
                continue  # Home is the centre of the system: a shelf needs two orbits
            pair = (min(a, b), max(a, b))
            joined[pair] = joined.get(pair, 0.0) + weight
        pairs = sorted(joined.items(), key=lambda item: (-item[1], item[0]))[:12]
        seconds = state["seconds"]
        favourite = max(sorted(seconds), key=lambda room: seconds[room]) if seconds else None
        peak = {room: max(max(hours), 1) for room, hours in state["hours"].items()}
        return {"pairs": [{"a": a, "b": b, "weight": round(weight, 2)} for (a, b), weight in pairs],
                "visits": state["visits"], "seconds": {k: round(v) for k, v in seconds.items()},
                "favourite": favourite if favourite and seconds[favourite] >= 600 else None,
                "trend": self.trend(), "hours": {room: [round(n / peak[room], 3) for n in hours] for room, hours in state["hours"].items()},
                "hour": datetime.fromtimestamp(self.clock.now().real).hour,
                "resonance": resonance(state["recent"], self.clock.now().real),
                # The False Room (W1) reads the last hops and how often each hop has been made.
                "recent": [list(r) for r in state["recent"][-12:]],
                "edges": {k: round(v, 2) for k, v in state["edges"].items()}}
