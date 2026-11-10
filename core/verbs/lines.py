"""One-line summaries shared by the verbs and `fart-next status`. `now` is epoch seconds."""
from __future__ import annotations

from core.verbs.base import clock


def timers_line(snap: dict) -> str:
    parts = []
    p, s, c = snap["pomodoro"], snap["stopwatch"], snap["countdown"]
    if c["done"]:
        parts.append("countdown DONE")
    elif c["running"] or c["elapsed"] > 0:
        parts.append(f"countdown {clock(c['duration'] - c['elapsed'])} left{'' if c['running'] else ' (paused)'}")
    if p["running"] or p["elapsed"] > 0:
        parts.append(f"pomodoro {p['phase']} {clock(p['duration'] - p['elapsed'])} left, cycle {p['cycle'] + 1}"
                     f"{'' if p['running'] else ' (paused)'}")
    if s["running"] or s["elapsed"] > 0:
        parts.append(f"stopwatch {clock(s['elapsed'])}{'' if s['running'] else ' (paused)'}")
    return "; ".join(parts) or "idle"


def overdrive_line(snap: dict, now: float) -> str:
    mode = snap["requested"]["mode"]
    if mode == "off":
        return "off"
    text = mode
    if snap["requested"]["until"]:
        text += f", {clock(snap['requested']['until'] / 1000 - now)} left"
    text += f" · {snap['effective']}"
    if snap["reasons"]:
        text += ": " + ", ".join(snap["reasons"])
    return text


def session_line(snap: dict, now: float) -> str:
    active = snap["active"]
    if not active:
        return "none"
    return f"{active['preset']}, {clock(active['until'] / 1000 - now)} left"
