"""Pomodoro, stopwatch and countdown, kept on boottime anchors so they survive suspend (docs/CORE.md §3)."""
from __future__ import annotations

import copy
import logging
import math
from pathlib import Path

from core.clock import Now, Run
from core.errors import bad_args
from core.store import publish_new, read_json, write_json

log = logging.getLogger("fart.timers")
KINDS = ("pomodoro", "stopwatch", "countdown")
LATE = 60.0  # beyond this, a deadline passed while the machine slept: no sound, pomodoro pauses
MAX_SECONDS = 7 * 86400
DEFAULT_CONFIG = {"pomodoro": {"focus": 1500, "break": 300, "longBreak": 900, "cycles": 4}, "sound": False}
PHASE_LABEL = {"focus": "Focus", "break": "Break", "longBreak": "Long break"}


def ago(seconds: float) -> str:
    minutes = max(1, round(seconds / 60))
    return f"{minutes} min" if minutes < 60 else f"{minutes // 60} h {minutes % 60} min"


def config_from_settings(path: Path) -> dict:
    """The view's version 1 timer settings (settings.json), read once at migration."""
    config = copy.deepcopy(DEFAULT_CONFIG)
    try:
        settings = read_json(path, {}) or {}
    except ValueError:
        return config
    old = (settings.get("time") or {}).get("pomodoro") or {}
    for new, key in (("focus", "focus"), ("break", "breakTime"), ("longBreak", "longBreak"), ("cycles", "cyclesBeforeLongBreak")):
        if isinstance(old.get(key), int) and old[key] > 0:
            config["pomodoro"][new] = old[key]
    config["sound"] = (settings.get("sounds") or {}).get("pomodoro") is True
    return config


def migrate_v1(old: dict, config: dict, now: Now) -> dict:
    """Version 1 (TimerService): epoch seconds for pomodoro/countdown, 10 ms units for the stopwatch."""
    timer = old.get("timer") or {}
    state = fresh(config)
    pomodoro, stopwatch, countdown = (timer.get(k) or {} for k in KINDS)
    lengths = state["pomodoro"]["lengths"]
    cycle = int(pomodoro.get("cycle") or 0) % lengths["cycles"]
    phase = "focus" if not pomodoro.get("isBreak") else "longBreak" if cycle + 1 >= lengths["cycles"] else "break"
    state["pomodoro"].update(phase=phase, cycle=cycle, duration=lengths[phase])
    if pomodoro.get("running"):
        state["pomodoro"]["run"] = Run.since(now.real - float(pomodoro.get("start") or now.real), now)
    if stopwatch.get("running"):
        state["stopwatch"]["run"] = Run.since((now.real * 100 - float(stopwatch.get("start") or 0)) / 100, now)
    else:
        state["stopwatch"]["run"] = Run(False, max(0.0, float(stopwatch.get("elapsed") or 0) / 100))
    state["stopwatch"]["laps"] = [float(lap) / 100 for lap in stopwatch.get("laps") or [] if isinstance(lap, (int, float))]
    duration = countdown.get("duration")
    state["countdown"]["duration"] = float(duration) if isinstance(duration, (int, float)) and duration > 0 else 0.0
    if countdown.get("running") and state["countdown"]["duration"] > 0:
        state["countdown"]["run"] = Run.since(now.real - float(countdown.get("start") or now.real), now)
    return state


def fresh(config: dict) -> dict:
    lengths = dict(config["pomodoro"])
    return {
        "config": config,
        "pomodoro": {"phase": "focus", "cycle": 0, "duration": lengths["focus"], "lengths": lengths, "run": Run(),
                     "done": None},  # the last phase that ended unacknowledged: {phase, next, at, late}
        "stopwatch": {"run": Run(), "laps": []},
        "countdown": {"duration": 0.0, "run": Run(), "done": None},
    }


def seconds_arg(value, name="seconds", minimum=1) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise bad_args(f"{name} must be a number")
    if not minimum <= value <= MAX_SECONDS:
        raise bad_args(f"{name} must be between {minimum} and {MAX_SECONDS}")
    return float(value)


def kind_arg(kind) -> str:
    if kind not in KINDS:
        raise bad_args(f"kind must be one of {', '.join(KINDS)}")
    return kind


class Timers:
    def __init__(self, clock, scheduler, host, state_dir: Path):
        self.clock = clock
        self.scheduler = scheduler
        self.host = host
        self.path = state_dir / "timers.json"
        self.settings_path = state_dir / "settings.json"
        self.on_change = lambda: None
        self.state = self._load()
        scheduler.clock_set.append(lambda: self.on_change())
        self._schedule()

    # Persistence

    def _load(self) -> dict:
        now = self.clock.now()
        try:
            raw = read_json(self.path)
        except ValueError:
            log.error("timers.json is invalid; kept aside as timers.json.invalid")
            publish_new(self.path.with_name("timers.json.invalid"), self.path.read_text())
            raw = None
        if raw is None or not isinstance(raw, dict):
            state = fresh(config_from_settings(self.settings_path))
        elif "version" not in raw:
            publish_new(self.path.with_name("timers.v1.json"), raw)
            state = migrate_v1(raw, config_from_settings(self.settings_path), now)
            log.info("migrated timers.json from version 1")
        else:
            state = self._parse(raw)
            rebased = False
            for kind in KINDS:
                if state[kind]["run"].rebase(now):
                    rebased = True
            if not rebased:
                return state
        self._write(state)
        return state

    def _parse(self, raw: dict) -> dict:
        config = copy.deepcopy(DEFAULT_CONFIG)
        config["pomodoro"].update({k: v for k, v in (raw.get("config") or {}).get("pomodoro", {}).items()
                                   if k in config["pomodoro"] and isinstance(v, int) and v > 0})
        config["sound"] = (raw.get("config") or {}).get("sound") is True
        state = fresh(config)
        pomodoro = raw.get("pomodoro") or {}
        lengths = dict(config["pomodoro"])
        lengths.update({k: v for k, v in (pomodoro.get("lengths") or {}).items() if k in lengths and isinstance(v, (int, float)) and v > 0})
        phase = pomodoro.get("phase") if pomodoro.get("phase") in PHASE_LABEL else "focus"
        state["pomodoro"].update(phase=phase, cycle=int(pomodoro.get("cycle") or 0), lengths=lengths,
                                 duration=float(pomodoro.get("duration") or lengths[phase]), run=Run.from_json(pomodoro.get("run")),
                                 done=pomodoro.get("done") if isinstance(pomodoro.get("done"), dict) else None)
        stopwatch = raw.get("stopwatch") or {}
        state["stopwatch"].update(run=Run.from_json(stopwatch.get("run")), laps=[float(x) for x in stopwatch.get("laps") or []])
        countdown = raw.get("countdown") or {}
        state["countdown"].update(duration=float(countdown.get("duration") or 0), run=Run.from_json(countdown.get("run")),
                                  done=countdown.get("done") if isinstance(countdown.get("done"), dict) else None)
        return state

    def _write(self, state: dict):
        value = {"version": 2, "config": state["config"]}
        for kind in KINDS:
            value[kind] = {k: (v.to_json() if isinstance(v, Run) else v) for k, v in state[kind].items()}
        write_json(self.path, value)

    def _commit(self):
        self._schedule()
        self._write(self.state)
        self.on_change()

    # Snapshot

    def snapshot(self) -> dict:
        now = self.clock.now()
        p, s, c = (self.state[k] for k in KINDS)
        return {
            "at": round(now.real * 1000),
            "sound": self.state["config"]["sound"],
            "config": copy.deepcopy(self.state["config"]),
            "pomodoro": {"running": p["run"].running, "phase": p["phase"], "cycle": p["cycle"], "elapsed": p["run"].value(now),
                         "duration": p["duration"], "lengths": dict(p["lengths"]), "done": dict(p["done"]) if p["done"] else None},
            "stopwatch": {"running": s["run"].running, "elapsed": s["run"].value(now), "laps": list(s["laps"])},
            "countdown": {"running": c["run"].running, "elapsed": c["run"].value(now), "duration": c["duration"],
                          "done": dict(c["done"]) if c["done"] else None},
        }

    def summary(self) -> dict:
        snap = self.snapshot()
        return {kind: {"running": snap[kind]["running"], "elapsed": round(snap[kind]["elapsed"], 2)} for kind in KINDS} | {
            "done": snap["countdown"]["done"] is not None, "pomodoroDone": snap["pomodoro"]["done"] is not None}

    # Operations (docs/CORE.md §2.4)

    def start(self, kind, seconds=None, focus=None):
        now = self.clock.now()
        kind = kind_arg(kind)
        state = self.state[kind]
        if kind == "countdown":
            state.update(duration=seconds_arg(seconds), done=None)
        elif kind == "pomodoro":
            lengths = dict(self.state["config"]["pomodoro"])
            if focus is not None:
                lengths["focus"] = seconds_arg(focus, "focus")
            state.update(phase="focus", cycle=0, lengths=lengths, duration=lengths["focus"], done=None)
        else:
            state["laps"] = []
        state["run"] = Run()
        state["run"].start(now)
        self._commit()

    def toggle(self, kind):
        now = self.clock.now()
        kind = kind_arg(kind)
        state = self.state[kind]
        run = state["run"]
        if kind == "countdown":
            if state["duration"] <= 0:
                return
            if state["done"]:
                state["done"] = None
                run.reset()
        if run.running:
            run.pause(now)
        else:
            if kind == "stopwatch" and run.value(now) == 0:
                state["laps"] = []
            run.start(now)
        self._commit()

    def add(self, kind, seconds):
        if kind_arg(kind) != "countdown":
            raise bad_args("only a countdown can be extended")
        seconds = seconds_arg(seconds)
        state = self.state["countdown"]
        if state["done"]:
            state.update(done=None, duration=0.0)
            state["run"].reset()
        state["duration"] = min(MAX_SECONDS, state["duration"] + seconds)
        self._commit()

    def lap(self):
        state = self.state["stopwatch"]
        value = state["run"].value(self.clock.now())
        if value > 0:
            state["laps"].append(value)
            self._commit()

    def reset(self, kind):
        kind = kind_arg(kind)
        state = self.state[kind]
        state["run"].reset()
        if kind == "pomodoro":
            lengths = dict(self.state["config"]["pomodoro"])
            state.update(phase="focus", cycle=0, lengths=lengths, duration=lengths["focus"], done=None)
        elif kind == "stopwatch":
            state["laps"] = []
        else:
            state.update(duration=0.0, done=None)
        self._commit()

    def ack(self, kind=None):
        """Clears DONE: a countdown's, a pomodoro phase's, or (no kind) both."""
        if kind is not None:
            kind_arg(kind)
        changed = False
        countdown = self.state["countdown"]
        if kind in (None, "countdown") and countdown["done"]:
            # Back to a full, ready countdown of the same length.
            countdown["done"] = None
            countdown["run"].reset()
            changed = True
        pomodoro = self.state["pomodoro"]
        if kind in (None, "pomodoro") and pomodoro["done"]:
            pomodoro["done"] = None  # the next phase keeps running
            changed = True
        if changed:
            self._commit()

    def configure(self, pomodoro=None, sound=None):
        config = self.state["config"]
        if pomodoro is not None:
            if not isinstance(pomodoro, dict):
                raise bad_args("pomodoro must be an object")
            update = {}
            for key, value in pomodoro.items():
                if key not in config["pomodoro"]:
                    raise bad_args(f"unknown pomodoro setting {key!r}")
                if key == "cycles":
                    if not isinstance(value, int) or isinstance(value, bool) or not 1 <= value <= 12:
                        raise bad_args("cycles must be an integer from 1 to 12")
                    update[key] = value
                else:
                    update[key] = int(seconds_arg(value, key, minimum=60))
            config["pomodoro"].update(update)
            state = self.state["pomodoro"]
            state["lengths"] = dict(config["pomodoro"])
            # The running phase keeps its length; an idle pomodoro shows the new one.
            if not state["run"].running and state["run"].elapsed == 0:
                state["duration"] = state["lengths"][state["phase"]]
        if sound is not None:
            if not isinstance(sound, bool):
                raise bad_args("sound must be true or false")
            config["sound"] = sound
        self._commit()

    def running(self) -> list[str]:
        return [kind for kind in KINDS if self.state[kind]["run"].running]

    # Deadlines

    def _schedule(self):
        now = self.clock.now()
        for kind, due in (("pomodoro", self._pomodoro_due), ("countdown", self._countdown_due)):
            state = self.state[kind]
            if state["run"].running:
                self.scheduler.at("timer." + kind, state["run"].deadline(state["duration"], now), due)
            else:
                self.scheduler.cancel("timer." + kind)

    def _pomodoro_due(self, now: Now):
        state = self.state["pomodoro"]
        late = state["run"].value(now) - state["duration"]
        if late < 0:
            return self._schedule()
        ended = state["phase"]
        lengths = state["lengths"]
        if ended == "focus":
            state["phase"] = "longBreak" if state["cycle"] + 1 >= lengths["cycles"] else "break"
        else:
            state["phase"] = "focus"
            state["cycle"] = (state["cycle"] + 1) % lengths["cycles"]
        state["duration"] = lengths[state["phase"]]
        state["run"] = Run()
        state["done"] = {"phase": ended, "next": state["phase"], "at": round((now.real - late) * 1000), "late": round(late, 3)}
        if late > LATE:
            self.host.alert("Pomodoro", f"{PHASE_LABEL[ended]} ended {ago(late)} ago · paused")
        else:
            # Anchor the next phase at the true boundary so wake latency never accumulates.
            state["run"] = Run.since(late, now)
            minutes = math.floor(state["duration"] / 60)
            message = {"focus": f"🔴 Focus: {minutes} minutes", "break": f"☕ Break: {minutes} minutes",
                       "longBreak": f"🌿 Long break: {minutes} minutes"}[state["phase"]]
            self.host.alert("Pomodoro", message, "pomodoro.phase", self.state["config"]["sound"])
        self._commit()

    def _countdown_due(self, now: Now):
        state = self.state["countdown"]
        late = state["run"].value(now) - state["duration"]
        if late < 0:
            return self._schedule()
        state["run"].reset(state["duration"])
        state["done"] = {"at": round((now.real - late) * 1000), "late": round(late, 3)}
        if late > LATE:
            self.host.alert("Timers", f"⏰ Countdown finished {ago(late)} ago")
        else:
            self.host.alert("Timers", "⏰ Countdown finished", "timer.done", self.state["config"]["sound"])
        self._commit()
