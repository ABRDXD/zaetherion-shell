"""Sessions (M11): one active session at a time, its forced-Silent guard, presets, the debrief and the streak log."""
from __future__ import annotations

from datetime import date, datetime, timedelta
import json
import logging
from pathlib import Path
import re

from core.clock import anchor, span
from core.errors import OpError, bad_args
from core.store import append_line, read_json, write_json

log = logging.getLogger("fart.sessions")
PRESET = re.compile(r"^[a-z0-9][a-z0-9_-]{0,31}$")
MAX_SECONDS = 12 * 3600
# The presets: a name and its usual length. Any other short name still starts a session when a length is given.
PRESETS = {
    "focus": 50 * 60,
    "deep": 90 * 60,
    "study": 2 * 3600,
    "read": 45 * 60,
}
# During a session the host's Do Not Disturb is on (put back afterwards if the session turned it on), and the
# active player is started if it is paused, except for these presets (the user, 10 November).
NO_MUSIC = {"read"}
# A day counts toward the streak with at least this much session time in it, finished or not.
STREAK_SECONDS = 10 * 60
# The streak strip: this many days, oldest first, today last.
DAYS = 14
# Lines read back from the log for the streak (a year of a few sessions a day).
LOG_LINES = 2000


def _day(ms: float) -> date:
    return datetime.fromtimestamp(ms / 1000).date()


def streak(entries: list[dict], today: date) -> dict:
    """Per-day session seconds for the strip, the current run of counted days (today may still be empty) and the best."""
    seconds: dict[date, float] = {}
    for e in entries:
        seconds[_day(e["start"])] = seconds.get(_day(e["start"]), 0) + e["seconds"]
    counted = {d for d, s in seconds.items() if s >= STREAK_SECONDS}
    current, d = 0, today if today in counted else today - timedelta(days=1)
    while d in counted:
        current += 1
        d -= timedelta(days=1)
    best, run, last = 0, 0, None
    for d in sorted(counted):
        run = run + 1 if last is not None and d - last == timedelta(days=1) else 1
        best, last = max(best, run), d
    strip = [round(seconds.get(today - timedelta(days=DAYS - 1 - i), 0) / 60) for i in range(DAYS)]
    return {"current": current, "best": best, "minutes": strip}


def _valid(e) -> bool:
    num = lambda v: isinstance(v, (int, float)) and not isinstance(v, bool) and v >= 0
    return isinstance(e, dict) and isinstance(e.get("preset"), str) and num(e.get("start")) and num(e.get("seconds"))


class Sessions:
    def __init__(self, clock, scheduler, host, state_dir: Path):
        self.clock = clock
        self.scheduler = scheduler
        self.host = host
        self.path = state_dir / "session.json"
        self.log_path = state_dir / "sessions.jsonl"
        self.on_change = lambda: None
        self.on_guard = lambda: None  # the session guard re-reads active()
        # Tasks finished between two moments (ms), for the debrief; the core sets it.
        self.tasks_done = lambda start, end: 0
        # Starts the active player if it is paused; the core sets it (it goes through the view's adapter).
        self.music = lambda: None
        try:
            saved = read_json(self.path, {}) or {}
        except ValueError:
            saved = {}
        self.current = saved.get("active") if isinstance(saved.get("active"), dict) else None
        self.last = saved.get("last") if isinstance(saved.get("last"), dict) else None
        self.entries = self._read_log()
        if self.current:
            self._schedule()

    def _read_log(self) -> list[dict]:
        try:
            lines = self.log_path.read_text().splitlines()[-LOG_LINES:]
        except OSError:
            return []
        out = []
        for line in lines:
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if _valid(e):
                out.append(e)
        return out

    def active(self) -> bool:
        return self.current is not None

    def _left(self, now) -> float:
        return self.current["seconds"] - span(self.current["anchor"], now)

    def _schedule(self):
        now = self.clock.now()
        self.scheduler.at("session.end", now.boot + self._left(now), lambda _: self._finish(True))

    def _persist(self):
        # The debrief is kept without the apps: those stay in memory, read from the host when the session ended.
        last = {k: v for k, v in self.last.items() if k != "apps"} if self.last else None
        write_json(self.path, {"active": self.current, "last": last})

    def snapshot(self) -> dict:
        now = self.clock.now()
        out = {"active": None, "presets": [{"name": k, "seconds": v} for k, v in PRESETS.items()], "last": self.last,
               "streak": streak(self.entries, _day(now.real * 1000))}
        if self.current:
            started = self.current["anchor"]["real"]
            out["active"] = {"preset": self.current["preset"], "startedAt": round(started * 1000),
                             "until": round((now.real + self._left(now)) * 1000), "seconds": round(self.current["seconds"])}
        return out

    def start(self, preset, seconds=None):
        if self.current:
            raise OpError("conflict", "a session is already running; end it first")
        if not isinstance(preset, str) or not PRESET.match(preset):
            raise bad_args("preset must be a short lowercase name")
        if seconds is None:
            if preset not in PRESETS:
                raise bad_args(f"{preset} isn't a preset ({', '.join(PRESETS)}); give it a length")
            seconds = PRESETS[preset]
        if isinstance(seconds, bool) or not isinstance(seconds, (int, float)) or not 60 <= seconds <= MAX_SECONDS:
            raise bad_args(f"seconds must be between 60 and {MAX_SECONDS}")
        self.current = {"preset": preset, "anchor": anchor(self.clock.now()), "seconds": float(seconds)}
        # Do Not Disturb: turned on only if it was off, and remembered, so the end puts back only what it changed.
        self.current["dnd"] = not self.host.dnd() and self.host.set_dnd(True)
        self.last = None
        self._schedule()
        self._persist()
        self.on_change()
        self.on_guard()
        if preset not in NO_MUSIC:
            try:
                self.music()
            except Exception:  # music never stops a session starting
                log.exception("session music")
        return self.snapshot()

    def end(self):
        if not self.current:
            raise OpError("not-found", "no session is running")
        self._finish(False)
        return self.snapshot()

    def dismiss(self):
        """Puts the debrief away."""
        self.last = None
        self._persist()
        self.on_change()
        return self.snapshot()

    def _finish(self, completed: bool):
        if not self.current:
            return
        now = self.clock.now()
        done = min(span(self.current["anchor"], now), self.current["seconds"])
        start, end = round(self.current["anchor"]["real"] * 1000), round(now.real * 1000)
        entry = {"preset": self.current["preset"], "start": start, "end": end, "seconds": round(done), "completed": completed}
        append_line(self.log_path, entry)
        self.entries = (self.entries + [entry])[-LOG_LINES:]
        try:
            tasks = int(self.tasks_done(start, end))
        except Exception:  # the debrief never stops a session ending
            log.exception("tasks for the debrief")
            tasks = 0
        self.last = {**entry, "planned": round(self.current["seconds"]), "tasks": tasks, "apps": self.host.focus(start, end)}
        # Do Not Disturb back first, so the end is heard.
        if self.current.get("dnd") and self.host.dnd():
            self.host.set_dnd(False)
        if completed:
            self.host.alert("Session", f"{self.current['preset']} session complete", "session.end")
        self.current = None
        self.scheduler.cancel("session.end")
        self._persist()
        self.on_change()
        self.on_guard()
