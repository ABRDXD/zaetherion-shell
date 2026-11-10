"""The telemetry orrery's sampler (M12, docs/OVERDRIVE.md §15): the machine's processes as bodies, about once a second.

Pulled, never pushed: the Performance room's orrery asks `orrery.sample` once a second while it exists, and each
answer is measured against the one before. Nothing is read unless Overdrive is in effect (the core's lease is
active), and the state is dropped when the view closes, when Overdrive is not in effect, or after a gap. So the
sampler costs nothing in Silent, and it never runs on a timer of its own.

Each sample reads, read-only, `/proc/stat` (the fork counter), `/proc/uptime`, and `/proc/<pid>/stat` and `statm`
of every process: the command name (`comm`, 15 characters at most), CPU time, start time, flags and resident
pages. **Never `cmdline`, `environ`, file descriptors or window titles.** Nothing goes to disk.

A body is {id, pid, name, cpu (% of one core since the last sample), rss (MiB), growth (MiB/s, smoothed), age (s),
born}. The shown set has hysteresis, so bodies don't flicker in and out at its edge: the heaviest SHOW enter, and
a body leaves only when it falls below KEEP or its process ends. An ended shown body is reported once in `exits`.
`forks` is how many processes were created since the last sample, counted by the kernel, so short-lived ones
that started and ended between samples are counted too.
"""
from __future__ import annotations

import logging
import math
import os
from pathlib import Path
from typing import Callable, NamedTuple

log = logging.getLogger("fart.orrery")
SHOW = 16  # bodies that enter the shown set
KEEP = 24  # a shown body stays while it ranks at least this high
STALE = 5.0  # seconds without a sample after which the next one starts fresh
GROWTH_TAU = 15.0  # seconds: the smoothing of memory growth
BORN_WITHIN = 2.0  # seconds: a new process this young counts as born, not just newly heavy
CPU_WEIGHT = 40.0  # one per cent of a core weighs as much as this many MiB, for the ranking
PF_KTHREAD = 0x00200000
PAGE_MIB = os.sysconf("SC_PAGE_SIZE") / (1024 * 1024)
TICKS = os.sysconf("SC_CLK_TCK")


class Process(NamedTuple):
    name: str
    ticks: int  # utime + stime, in clock ticks
    start: int  # start time after boot, in clock ticks (with the pid, the process's identity)
    rss: float  # MiB


class Reading(NamedTuple):
    processes: dict[int, Process]
    forks: int | None  # processes created since boot
    uptime: float | None  # seconds since boot


def parse_stat(text: str) -> tuple[str, int, int, int] | None:
    """(name, ticks, start, flags) from a /proc/<pid>/stat line, or None if it doesn't parse.

    The name is between the first "(" and the last ")" and may hold spaces or parentheses; the fields after it are
    fixed (proc(5)): flags is the 9th field, utime and stime the 14th and 15th, starttime the 22nd."""
    open_at, close_at = text.find("("), text.rfind(")")
    if open_at < 0 or close_at < open_at:
        return None
    fields = text[close_at + 2:].split()
    try:
        return text[open_at + 1:close_at], int(fields[11]) + int(fields[12]), int(fields[19]), int(fields[6])
    except (ValueError, IndexError):
        return None


def read_proc(proc: Path = Path("/proc")) -> Reading:
    """Every user process that can be read now (kernel threads have no memory of their own and are skipped)."""
    processes: dict[int, Process] = {}
    for entry in os.scandir(proc):
        if not entry.name.isdigit():
            continue
        try:
            with open(f"{entry.path}/stat", "rb") as f:
                stat = parse_stat(f.read().decode("utf-8", "replace"))
            if stat is None or stat[3] & PF_KTHREAD:
                continue
            with open(f"{entry.path}/statm", "rb") as f:
                pages = int(f.read().split()[1])
        except (OSError, ValueError, IndexError):
            continue  # gone, or not ours to read
        if pages > 0:
            processes[int(entry.name)] = Process(stat[0], stat[1], stat[2], pages * PAGE_MIB)
    forks = uptime = None
    try:
        for line in (proc / "stat").read_text().splitlines():
            if line.startswith("processes "):
                forks = int(line.split()[1])
                break
        uptime = float((proc / "uptime").read_text().split()[0])
    except (OSError, ValueError, IndexError):
        pass
    return Reading(processes, forks, uptime)


class Orrery:
    def __init__(self, clock, active: Callable[[], bool] = lambda: True, reader: Callable[[], Reading] = read_proc):
        self.clock = clock
        self.active = active  # Overdrive is in effect
        self.reader = reader
        self.forget()

    def forget(self):
        """Drop everything measured; the next sample starts fresh."""
        self.last: dict[int, Process] = {}
        self.last_at: float | None = None
        self.last_forks: int | None = None
        self.growth: dict[tuple[int, int], float] = {}
        self.shown: dict[tuple[int, int], str] = {}

    def sample(self) -> dict:
        if not self.active():
            self.forget()
            return {"running": False}
        now = self.clock.now().boot
        if self.last_at is not None and not 0 < now - self.last_at <= STALE:
            self.forget()
        try:
            reading = self.reader()
        except OSError as error:
            log.warning("orrery: /proc unreadable: %s", error)
            reading = Reading({}, None, None)
        seconds = now - self.last_at if self.last_at is not None else None
        alpha = 1 - math.exp(-seconds / GROWTH_TAU) if seconds else 0.0
        bodies, growth = [], {}
        for pid, p in reading.processes.items():
            key = (pid, p.start)
            before = self.last.get(pid)
            cpu = rate = 0.0
            same = before is not None and before.start == p.start
            if before is not None and same and seconds:
                cpu = 100.0 * max(0, p.ticks - before.ticks) / TICKS / seconds
                rate = (p.rss - before.rss) / seconds
            growth[key] = self.growth.get(key, 0.0) + alpha * (rate - self.growth.get(key, 0.0)) if same else 0.0
            age = max(0.0, reading.uptime - p.start / TICKS) if reading.uptime is not None else None
            bodies.append({"id": f"{pid}:{p.start}", "pid": pid, "name": p.name, "cpu": round(cpu, 1), "rss": round(p.rss, 1),
                           "growth": round(growth[key], 3), "age": None if age is None else round(age, 1),
                           "born": self.last_at is not None and not same and age is not None and age <= BORN_WITHIN,
                           "key": key})
        bodies.sort(key=lambda b: b["cpu"] * CPU_WEIGHT + b["rss"], reverse=True)
        # The shown set: the top SHOW, plus any shown before that still ranks within KEEP.
        rank = {b["key"]: i for i, b in enumerate(bodies)}
        keep = {k for k in self.shown if rank.get(k, KEEP) < KEEP}
        chosen = [b for i, b in enumerate(bodies) if i < SHOW or b["key"] in keep]
        exits = [{"id": f"{k[0]}:{k[1]}", "name": name} for k, name in self.shown.items() if k not in rank]
        forks = reading.forks - self.last_forks if reading.forks is not None and self.last_forks is not None else 0
        total = {"cpu": round(sum(b["cpu"] for b in bodies), 1), "rss": round(sum(b["rss"] for b in bodies), 1), "count": len(bodies)}
        self.shown = {b["key"]: b["name"] for b in chosen}
        self.last, self.last_at, self.last_forks, self.growth = reading.processes, now, reading.forks, growth
        for b in chosen:
            del b["key"]
        return {"running": True, "warm": seconds is not None, "at": now, "bodies": chosen, "exits": exits,
                "forks": max(0, forks), "total": total}
