"""The launcher's apps half in the core (S6, docs/S6_LAUNCHER.md §4): the list the view indexes, launch history,
frecency, matching and the session blocklist.

The adapter reads the installed apps (the core never parses .desktop files); the view hands their plain rows to
`apps.index` whenever the list changes and asks `launcher.query` on each key. A launch goes through
`launcher.launch`, which may refuse it (a Session's blocklist, Z102) and records it, and only then does the view
start the app through its adapter.

Ranking is DMS's (AppSearchService, v2.1.0, Z161): a text score (core/matching.py) plus a frecency bonus and a
recency bonus. History is kept per app id as launches per local day, so the old launcher's counts (Z136,
`{app name: {date: count}}`) import without loss; they are matched to ids by name once the list arrives.
"""
from __future__ import annotations

from datetime import datetime, timedelta
import logging
from pathlib import Path

from core import inline, matching
from core.errors import OpError, bad_args
from core.store import read_json, write_json

log = logging.getLogger("fart.launcher")

DAY_MS = 86_400_000
KEEP_DAYS = 365  # launch days kept per app; older ones no longer count
# DMS's frecency: a weight by days since the last launch, times the launches (at most SAMPLE of them).
BUCKETS = ((4, 100), (14, 70), (31, 50), (90, 30))
OLDEST_WEIGHT = 10
SAMPLE = 10
FRECENCY_CAP = 2000
RECENCY = ((1, 1500), (7, 1000), (30, 500))  # (days since the last launch under, bonus)
MAX_ENTRIES = 4000
MAX_FIELD = 512
MAX_QUERY = 1000  # a long sum is a real query (owner, 15 Nov 2026); as long as a command line
MAX_LIMIT = 50

DEFAULTS = {
    "rows": 6,  # Z75
    "terminal": "kitty",  # for apps that ask for one and for `>cmd`; the owner's Super+Return terminal
    "search": "brave",  # `?term`'s engine (Z28), a key of core.inline.ENGINES
    "browser": "",  # the program `?term` opens its page in; "" is the desktop's default (xdg-open)
    "hidden": [],  # app ids never shown
    # Z102's starter set, matched against an app's name or id while a Session runs.
    "blocklist": ["steam", "discord", "lutris", "heroic", "itch", "bottles", "prismlauncher"],
}
ROWS = range(3, 13)


def _text(value, limit=MAX_FIELD) -> str:
    return value[:limit] if isinstance(value, str) else ""


class App:
    __slots__ = ("id", "name", "description", "icon", "terminal", "index")

    def __init__(self, row: dict):
        self.id = row["id"]
        self.name = _text(row.get("name")) or self.id
        generic, comment = _text(row.get("genericName")), _text(row.get("comment"))
        self.description = generic or comment
        self.icon = _text(row.get("icon"))
        self.terminal = row.get("terminal") is True
        keywords = row.get("keywords") if isinstance(row.get("keywords"), list) else []
        self.index = matching.Indexed(self.name, generic, comment, self.id,
                                      [_text(k, 64) for k in keywords[:32] if isinstance(k, str)])


class Launcher:
    def __init__(self, clock, state_dir: Path, imported=lambda: None, session_active=lambda: False,
                 verb=lambda text: None):
        self.clock = clock
        self.verb = verb  # text → {verb, usage, summary} when the line is a FART verb (core/command.py), else None
        self.session_active = session_active
        self.on_change = lambda: None
        self.history_path = state_dir / "launches.json"
        self.settings_path = state_dir / "launcher.json"
        self.apps: dict[str, App] = {}
        self.settings = self._load_settings()
        self.history, self.pending = self._load_history(imported)

    # Settings (Z176: each gets a control in FART's settings)

    def _load_settings(self) -> dict:
        try:
            saved = read_json(self.settings_path, {}) or {}
        except ValueError as error:
            log.warning("%s; using defaults", error)
            saved = {}
        settings = {key: (list(value) if isinstance(value, list) else value) for key, value in DEFAULTS.items()}
        for key, value in (saved.items() if isinstance(saved, dict) else ()):
            try:
                settings[key] = self._valid(key, value)
            except OpError:
                log.warning("launcher.json: ignoring %s", key)
        return settings

    @staticmethod
    def _valid(key, value):
        if key == "rows":
            if isinstance(value, int) and not isinstance(value, bool) and value in ROWS:
                return value
            raise bad_args(f"rows must be {ROWS.start}–{ROWS.stop - 1}")
        if key == "terminal":
            if isinstance(value, str) and value.strip() and len(value) <= 128:
                return value.strip()
            raise bad_args("terminal must be a program name")
        if key == "search":
            if value in inline.ENGINES:
                return value
            raise bad_args(f"search must be one of {', '.join(inline.ENGINES)}")
        if key == "browser":
            if isinstance(value, str) and len(value) <= 128 and not value.strip().startswith("-"):
                return value.strip()
            raise bad_args("browser must be a program name, or empty for the default")
        if key in ("hidden", "blocklist"):
            if isinstance(value, list) and len(value) <= 500 and all(isinstance(v, str) and 0 < len(v) <= MAX_FIELD for v in value):
                return list(dict.fromkeys(value))
            raise bad_args(f"{key} must be a list of names")
        raise bad_args(f"no launcher setting {key!r}")

    def configure(self, **changes) -> dict:
        valid = {key: self._valid(key, value) for key, value in changes.items()}
        if any(self.settings[key] != value for key, value in valid.items()):
            self.settings.update(valid)
            write_json(self.settings_path, self.settings)
            self.on_change()
        return self.snapshot()

    def snapshot(self) -> dict:
        return {"settings": {k: (list(v) if isinstance(v, list) else v) for k, v in self.settings.items()},
                "apps": len(self.apps), "remembered": len(self.history), "importPending": len(self.pending)}

    # History

    def _load_history(self, imported) -> tuple[dict, dict]:
        try:
            saved = read_json(self.history_path, None)
        except ValueError as error:
            log.warning("%s; starting empty", error)
            saved = {}
        if saved is None:  # first start: take the old launcher's counts once (Z136)
            pending = self._import(imported)
            self._write({}, pending)
            return {}, pending
        saved = saved if isinstance(saved, dict) else {}
        history = {app: record for app, record in (saved.get("apps") or {}).items()
                   if isinstance(app, str) and self._record_ok(record)}
        pending = {name: days for name, days in (saved.get("pending") or {}).items()
                   if isinstance(name, str) and self._days_ok(days)}
        return history, pending

    @staticmethod
    def _days_ok(days) -> bool:
        return isinstance(days, dict) and all(Launcher._day(d) is not None and isinstance(n, int) and not isinstance(n, bool)
                                              and n > 0 for d, n in days.items())

    def _record_ok(self, record) -> bool:
        return isinstance(record, dict) and self._days_ok(record.get("days")) and isinstance(record.get("last"), (int, float))

    def _import(self, imported) -> dict:
        """{lower-cased name: {date: launches}}. Names that differ only in case are one app counted twice by the old
        launcher, so the larger count per day wins rather than the sum."""
        try:
            stats = imported()
        except Exception:
            log.exception("reading the old launch counts failed")
            stats = None
        pending: dict[str, dict[str, int]] = {}
        for name, days in (stats.items() if isinstance(stats, dict) else ()):
            if not isinstance(name, str) or not name.strip() or not isinstance(days, dict):
                continue
            merged = pending.setdefault(name.strip().lower(), {})
            for day, count in days.items():
                if self._day(day) is not None and isinstance(count, int) and not isinstance(count, bool) and count > 0:
                    merged[day] = max(merged.get(day, 0), count)
        pending = {name: days for name, days in pending.items() if days}
        if pending:
            log.info("imported launch counts for %d apps (matched by name when the app list arrives)", len(pending))
        return pending

    @staticmethod
    def _day(text):
        try:
            return datetime.strptime(text, "%Y-%m-%d").date()
        except (TypeError, ValueError):
            return None

    def _write(self, history=None, pending=None):
        write_json(self.history_path, {"version": 1, "apps": self.history if history is None else history,
                                       "pending": self.pending if pending is None else pending})

    def _today(self):
        return datetime.fromtimestamp(self.clock.now().real).date()

    def _prune(self, days: dict) -> dict:
        oldest = self._today() - timedelta(days=KEEP_DAYS)
        return {d: n for d, n in days.items() if (self._day(d) or oldest) > oldest}

    def _adopt_pending(self) -> bool:
        """Old counts whose name now names an indexed app move to that app's id."""
        by_name: dict[str, list[App]] = {}
        for app in self.apps.values():
            by_name.setdefault(app.name.strip().lower(), []).append(app)
        moved = False
        for name in [n for n in self.pending if n in by_name]:
            days = self.pending.pop(name)
            for app in by_name[name]:
                record = self.history.setdefault(app.id, {"days": {}, "last": 0})
                for day, count in days.items():
                    record["days"][day] = record["days"].get(day, 0) + count
                latest = max(datetime.strptime(d, "%Y-%m-%d") for d in days)
                noon = latest.replace(hour=12).timestamp() * 1000
                record["last"] = max(record["last"], noon)
            moved = True
        return moved

    def frecency(self, app_id: str) -> tuple[float, float]:
        """(frecency bonus, recency bonus) after DMS's calculateFrecency and its recency step."""
        record = self.history.get(app_id)
        if not record:
            return 0.0, 0.0
        launches = sum(self._prune(record["days"]).values())
        if launches == 0:
            return 0.0, 0.0
        days = (self.clock.now().real * 1000 - record["last"]) / DAY_MS
        weight = next((w for limit, w in BUCKETS if days <= limit), OLDEST_WEIGHT)
        recency = next((bonus for limit, bonus in RECENCY if days < limit), 0)
        return min(weight * min(launches, SAMPLE), FRECENCY_CAP), float(recency)

    def forget(self) -> dict:
        """Frecency reset (a setting, Z176). Unmatched imported counts go too."""
        self.history, self.pending = {}, {}
        self._write()
        self.on_change()
        return self.snapshot()

    # The app list, from the view

    def index(self, entries) -> dict:
        if not isinstance(entries, list) or len(entries) > MAX_ENTRIES:
            raise bad_args(f"entries must be a list of at most {MAX_ENTRIES} apps")
        apps: dict[str, App] = {}
        for row in entries:
            if isinstance(row, dict) and isinstance(row.get("id"), str) and 0 < len(row["id"]) <= MAX_FIELD:
                apps.setdefault(row["id"], App(row))
        self.apps = apps
        if self.pending and self._adopt_pending():
            self._write()
        self.on_change()
        return {"apps": len(apps)}

    # Ranking

    def _blocked(self, app: App) -> bool:
        if not self.session_active():
            return False
        name, ident = app.name.lower(), app.id.lower()
        return any(word.lower() in name or word.lower() in ident for word in self.settings["blocklist"])

    def _row(self, app: App, score: float, kind: str | None) -> dict:
        return {"kind": "app", "id": app.id, "name": app.name, "description": app.description, "icon": app.icon,
                "score": round(score, 3), "match": kind, "blocked": self._blocked(app), "ready": True}

    def query(self, text: str = "", limit=None) -> dict:
        if not isinstance(text, str) or len(text) > MAX_QUERY:
            raise bad_args(f"text must be a string of at most {MAX_QUERY} characters")
        if limit is None:
            limit = self.settings["rows"]
        if isinstance(limit, bool) or not isinstance(limit, int) or not 1 <= limit <= MAX_LIMIT:
            raise bad_args(f"limit must be 1–{MAX_LIMIT}")
        line = text.strip()
        if line.startswith((">", "?")):  # Z28: a prefix line is only its own row, never apps
            return {"text": text, "rows": [self._prefixed(line)], "total": 1}
        rows = self._inline(line)[:limit]
        apps = self._apps(line.lower())
        return {"text": text, "rows": rows + [self._row(app, score, kind) for score, app, kind in apps[:limit - len(rows)]],
                "total": len(rows) + len(apps)}

    def _apps(self, query: str) -> list:
        hidden = set(self.settings["hidden"])
        scored = []
        for app in self.apps.values():
            if app.id in hidden:
                continue
            bonus = sum(self.frecency(app.id))
            if not query:
                scored.append((bonus, app, None))  # Z75: nothing typed shows the most frecent apps
                continue
            match = matching.score(app.index, query)
            if match:
                scored.append((match[1] + bonus, app, match[0]))
        scored.sort(key=lambda item: (-item[0], item[1].name.lower(), item[1].id))
        return scored

    # Inline rows (Z27, Z28, Z195): above the apps, kind tells the view what Enter does.

    @staticmethod
    def _inline_row(kind: str, name: str, description: str, ready: bool = True) -> dict:
        return {"kind": kind, "id": kind, "name": name, "description": description, "icon": "", "score": None,
                "match": None, "blocked": False, "ready": ready}

    def _prefixed(self, line: str) -> dict:
        rest = line[1:].strip()
        if line.startswith(">"):
            return self._inline_row("command", f"> {rest}" if rest else "> …",
                                    f"RUN IN {self.settings['terminal'].upper()}" if rest else "TYPE A COMMAND", bool(rest))
        engine = inline.ENGINES[self.settings["search"]][0].upper()
        return self._inline_row("search", f"? {rest}" if rest else "? …",
                                engine if rest else f"TYPE TO SEARCH · {engine}", bool(rest))

    def _inline(self, line: str) -> list[dict]:
        rows = []
        if (value := inline.calc(line)) is not None:
            rows.append(self._inline_row("calc", f"{line} = {value}", "ENTER COPIES"))
        elif conversion := inline.convert(line):
            rows.append(self._inline_row("convert", f"{conversion['amount']} {conversion['source']} = "
                                         f"{conversion['value']} {conversion['target']}", "ENTER COPIES"))
        if verb := self.verb(line):
            rows.append(self._inline_row("verb", line, f"FART · {verb['usage']}"))
        return rows

    def act(self, kind, text) -> dict:
        """What Enter on an inline row does, worked out again from the text: {"argv"} for the adapter to start,
        or {"copy"} for the clipboard. Verbs run in the core (core/app.py); an app goes through `launch`."""
        if not isinstance(text, str) or len(text) > MAX_QUERY:
            raise bad_args(f"text must be a string of at most {MAX_QUERY} characters")
        line = text.strip()
        rest = line[1:].strip()
        if kind == "command" and line.startswith(">") and rest:
            # Z195: the terminal stays open on a shell after the command, so its output can be read.
            return {"argv": [self.settings["terminal"], "-e", "sh", "-c", 'eval "$1"; exec "${SHELL:-sh}"', "sh", rest]}
        if kind == "search" and line.startswith("?") and rest:
            url = inline.search_url(self.settings["search"], rest)
            return {"argv": [self.settings["browser"] or "xdg-open", url]}
        if kind == "calc" and (value := inline.calc(line)) is not None:
            return {"copy": value}
        if kind == "convert" and (conversion := inline.convert(line)):
            return {"copy": conversion["value"]}
        raise OpError("not-inline", f"{text!r} is not a {kind} line")

    # Launching

    def launch(self, app_id) -> dict:
        """Refuses a blocked app during a Session (Z102), records the launch, and tells the view how to start it."""
        app = self.apps.get(app_id) if isinstance(app_id, str) else None
        if app is None:
            raise OpError("unknown-app", f"no app {app_id!r} in the list")
        if self._blocked(app):
            raise OpError("blocked", "> BLOCKED · SESSION")
        now_ms = self.clock.now().real * 1000
        record = self.history.setdefault(app.id, {"days": {}, "last": 0})
        today = self._today().isoformat()
        record["days"] = self._prune({**record["days"], today: record["days"].get(today, 0) + 1})
        record["last"] = now_ms
        self._write()
        self.on_change()
        return {"id": app.id, "terminal": self.settings["terminal"] if app.terminal else None}
