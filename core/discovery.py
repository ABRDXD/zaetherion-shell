"""Discovery (M15): counters, and the declarative triggers that find the archive's fragments.

A fragment is a data file in assets/fragments/<id>.json: {"when": {...}, "whisper": "...", "text": "..."}. Every
condition in `when` must hold at once:
    "counter": name, "atLeast": n     a discovery counter (sky events, starts, opens) has reached n (default 1)
    "hours": [from, to]               the local hour is in [from, to)
    "streak": n                       the session streak is at least n days
    "uptime": hours                   the machine has been up (suspend included) at least this long
    "listening": true                 a track started playing in the last quarter of an hour
    "visits": {"room": n}             the room has been entered at least n times
Triggers are checked when something they read changes: a counter bump, the panel opening, a session ending, a new
track. At most one fragment is found per check, so each gets its own whisper. What is kept on disk is counters and
the ids found with their times; never what was playing, never anything a room holds.
"""
from __future__ import annotations

import asyncio
from datetime import datetime
import json
import logging
from pathlib import Path
import re

from core.errors import bad_args
from core.store import read_json, write_json

log = logging.getLogger("fart.discovery")
NAME = re.compile(r"^[a-z0-9][a-z0-9_.-]{0,63}$")
SAVE_AFTER = 5.0
FRAGMENTS = Path(__file__).resolve().parents[1] / "assets/fragments"
LISTENING = 15 * 60
KEYS = {"counter", "atLeast", "hours", "streak", "uptime", "listening", "visits"}


def load(directory: Path = FRAGMENTS) -> dict:
    """The registry: id → fragment, from the data files. A file that doesn't parse or names an unknown condition is
    left out with a warning, so one bad fragment never stops the rest."""
    out = {}
    for path in sorted(directory.glob("*.json")):
        fid = path.stem
        try:
            data = json.loads(path.read_text())
            when = data["when"]
            if not NAME.match(fid) or not isinstance(when, dict) or not when or set(when) - KEYS:
                raise ValueError("unknown condition")
            if not isinstance(data.get("whisper"), str) or not isinstance(data.get("text"), str):
                raise ValueError("a whisper and a text are needed")
        except (OSError, ValueError, KeyError, TypeError) as error:
            log.warning("fragment %s left out: %s", fid, error)
            continue
        out[fid] = {"when": when, "whisper": data["whisper"][:120], "text": data["text"][:2000]}
    return out


def holds(when: dict, facts: dict) -> bool:
    """facts: {counters, hour, streak, uptime, listening, visits}."""
    if "counter" in when and facts["counters"].get(when["counter"], 0) < when.get("atLeast", 1):
        return False
    if "hours" in when:
        a, b = when["hours"]
        hour = facts["hour"]
        if not (a <= hour < b if a <= b else hour >= a or hour < b):
            return False
    if "streak" in when and facts["streak"] < when["streak"]:
        return False
    if "uptime" in when and facts["uptime"] < when["uptime"] * 3600:
        return False
    if when.get("listening") and not facts["listening"]:
        return False
    for room, n in (when.get("visits") or {}).items():
        if facts["visits"].get(room, 0) < n:
            return False
    return True


class Discovery:
    def __init__(self, state_dir: Path, clock=None, registry: dict | None = None):
        self.path = state_dir / "discovery.json"
        self.clock = clock
        self.registry = load() if registry is None else registry
        self.on_change = lambda: None
        # What the triggers read, set by the core once the rest of it exists.
        self.streak = lambda: 0
        self.visits = lambda: {}
        self.track_at = lambda: None
        try:
            saved = read_json(self.path, {}) or {}
        except ValueError:
            saved = {}
        counters = saved.get("counters") if isinstance(saved.get("counters"), dict) else {}
        self.counters = {k: v for k, v in counters.items() if isinstance(v, int) and NAME.match(k)}
        found = saved.get("found") if isinstance(saved.get("found"), dict) else {}
        self.found = {k: v for k, v in found.items() if k in self.registry and isinstance(v, int)}
        # Found but not yet whispered: the view says when it has shown one (discovery.seen).
        unseen = saved.get("unseen") if isinstance(saved.get("unseen"), list) else []
        self.unseen = [k for k in unseen if k in self.found][:16]
        self.pending = None

    def bump(self, counter, by=1):
        if not isinstance(counter, str) or not NAME.match(counter):
            raise bad_args("counter must be a short lowercase name")
        if isinstance(by, bool) or not isinstance(by, int) or not 1 <= by <= 1000:
            raise bad_args("by must be an integer from 1 to 1000")
        self.counters[counter] = self.counters.get(counter, 0) + by
        self._save_soon()
        self.check()
        return {"counter": counter, "value": self.counters[counter]}

    def _save_soon(self):
        if not self.pending:
            try:
                self.pending = asyncio.get_running_loop().call_later(SAVE_AFTER, self.flush)
            except RuntimeError:  # no loop (a plain test): save now
                self.flush()

    def facts(self) -> dict:
        now = self.clock.now() if self.clock else None
        real = now.real if now else datetime.now().timestamp()
        at = self.track_at()
        return {"counters": self.counters, "hour": datetime.fromtimestamp(real).hour, "streak": self.streak(),
                "uptime": now.boot if now else 0, "visits": self.visits(),
                "listening": isinstance(at, (int, float)) and 0 <= real - at / 1000 <= LISTENING}

    def check(self):
        """Finds at most one fragment whose conditions all hold now."""
        try:
            facts = self.facts()
        except Exception:  # a trigger's source never stops a bump or an open
            log.exception("discovery facts")
            return None
        for fid, fragment in self.registry.items():
            if fid not in self.found and holds(fragment["when"], facts):
                self.found[fid] = round(((self.clock.now().real if self.clock else datetime.now().timestamp())) * 1000)
                self.unseen.append(fid)
                self._save_soon()
                self.on_change()
                return fid
        return None

    def snapshot(self) -> dict:
        found = sorted(self.found.items(), key=lambda kv: kv[1])
        items = [{"id": k, "at": at, "whisper": self.registry[k]["whisper"], "text": self.registry[k]["text"]} for k, at in found]
        first = self.unseen[0] if self.unseen else None
        return {"found": items, "latest": items[-1] if items else None, "total": len(self.registry),
                "whisper": {"id": first, "text": self.registry[first]["whisper"]} if first else None}

    def seen(self, id):
        """The view has whispered this one."""
        if id in self.unseen:
            self.unseen.remove(id)
            self._save_soon()
            self.on_change()
        return self.snapshot()

    def flush(self):
        if self.pending:
            self.pending.cancel()
            self.pending = None
        write_json(self.path, {"counters": self.counters, "found": self.found, "unseen": self.unseen})
