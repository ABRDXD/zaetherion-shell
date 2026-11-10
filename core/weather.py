"""The machine's weather (atlas #75, docs/OVERDRIVE.md §18): one short weather report for the time since you last looked.

When the view opens, if at least ten minutes have passed since the last report, the core reads the kernel's own
running counters once and compares them with the reading it kept: how busy the processors were (pressure), how often
the scheduler switched (wind), how often memory had to come back from disk (precipitation), how much went over the
network (current), the hottest thermal zone now against then (temperature) and the battery (tide). Deterministic rules
turn those into a sentence ("FAIR, STEADY PRESSURE / A STEADY BREEZE / DRY") and a barometric reading for the
barograph. It is never a diagnosis and never pretends to be one.

It costs nothing in between: the kernel keeps counting, so there is no sampler, no timer and no wake-up. Counters
only, read-only: `/proc/stat`, `/proc/vmstat`, `/proc/net/dev`, `/sys/class/thermal`, `/sys/class/power_supply`.
Never a process, a name, an address or anything typed. `weather.json` keeps the last reading and the last 60 reports.
"""
from __future__ import annotations

from datetime import datetime
import logging
import os
from pathlib import Path

from core.store import read_json, write_json

log = logging.getLogger("fart.weather")
SPAN_MIN = 600.0  # seconds since the last reading before a new report
KEEP = 60  # reports kept
TICKS = os.sysconf("SC_CLK_TCK")

# (upper bound, words). The last bound is infinite.
PRESSURE = ((3, "high pressure, settled"), (10, "fair, steady pressure"), (25, "falling pressure"),
            (50, "low pressure, unsettled"), (float("inf"), "a deep low"))  # busy, % of all cores
WIND = ((4000, "calm"), (12000, "light airs"), (30000, "a steady breeze"), (70000, "gusts"),
        (float("inf"), "a gale"))  # context switches a second
RAIN = ((0.05, "dry"), (1, "drizzle"), (10, "showers"), (float("inf"), "heavy rain"))  # major faults a second
CURRENT = ((5_000, "still water"), (200_000, "a light current"), (3_000_000, "a strong current"),
           (float("inf"), "a flood"))  # network bytes a second
HEAT = ((45, "cool"), (60, "mild"), (75, "warm"), (float("inf"), "hot"))  # the hottest zone, °C


def words(table, value: float) -> str:
    return next(text for bound, text in table if value < bound)


def read_counters(proc: Path = Path("/proc"), sys: Path = Path("/sys")) -> dict:
    """The kernel's counters, as they stand. A source that can't be read is left out."""
    out: dict = {}
    try:
        for line in (proc / "stat").read_text().splitlines():
            parts = line.split()
            if parts and parts[0] == "cpu":
                values = [int(v) for v in parts[1:9]]
                out["cpuTotal"] = sum(values)
                out["cpuIdle"] = values[3] + values[4]  # idle and iowait
            elif parts and parts[0] in ("ctxt", "processes"):
                out["ctxt" if parts[0] == "ctxt" else "forks"] = int(parts[1])
    except (OSError, ValueError, IndexError):
        pass
    try:
        vm = dict(line.split()[:2] for line in (proc / "vmstat").read_text().splitlines() if line.count(" ") >= 1)
        out["majfault"] = int(vm.get("pgmajfault", 0))
        out["swap"] = int(vm.get("pswpin", 0)) + int(vm.get("pswpout", 0))
    except (OSError, ValueError):
        pass
    try:
        total = 0
        for line in (proc / "net/dev").read_text().splitlines()[2:]:
            name, _, rest = line.partition(":")
            fields = rest.split()
            if name.strip() != "lo" and len(fields) >= 9:
                total += int(fields[0]) + int(fields[8])
        out["net"] = total
    except (OSError, ValueError):
        pass
    temps = []
    for zone in sorted((sys / "class/thermal").glob("thermal_zone*")):
        try:
            celsius = int((zone / "temp").read_text()) / 1000
        except (OSError, ValueError):
            continue
        if 0 < celsius < 125:
            temps.append(celsius)
    if temps:
        out["temp"] = round(max(temps), 1)
    for battery in sorted((sys / "class/power_supply").glob("BAT*")):
        try:
            out["battery"] = int((battery / "capacity").read_text())
            out["charging"] = (battery / "status").read_text().strip() in ("Charging", "Full", "Not charging")
        except (OSError, ValueError):
            continue
        break
    return out


def report(before: dict, after: dict, span: float, cpus: int) -> dict | None:
    """The weather between two readings `span` seconds apart, or None when they can't be compared."""
    if span < 1 or not all(k in before and k in after for k in ("cpuTotal", "cpuIdle")):
        return None
    total = after["cpuTotal"] - before["cpuTotal"]
    if total <= 0:
        return None
    busy = 100 * (1 - (after["cpuIdle"] - before["cpuIdle"]) / total)
    awake = total / TICKS / max(1, cpus)  # seconds the machine was awake (the counters stop in suspend)
    rate = lambda key: max(0, after.get(key, 0) - before.get(key, 0)) / max(1.0, awake)
    values = {"busy": round(busy, 1), "hpa": round(1040 - 0.8 * busy), "wakes": round(rate("ctxt")),
              "faults": round(rate("majfault"), 2), "swap": round(rate("swap"), 2), "net": round(rate("net")),
              "forks": round(rate("forks"), 2), "awake": round(awake)}
    pressure = words(PRESSURE, busy)
    wind = words(WIND, values["wakes"])
    rain = "a downpour" if values["swap"] >= 1 else words(RAIN, values["faults"])
    second = []
    if "temp" in after:
        values["temp"] = after["temp"]
        trend = after["temp"] - before.get("temp", after["temp"])
        heat = words(HEAT, after["temp"])
        second.append(heat + (" and warming" if trend >= 5 else " and cooling" if trend <= -5 else ""))
    second.append(words(CURRENT, values["net"]))
    if "battery" in after:
        values["battery"] = after["battery"]
        drop = (before.get("battery", after["battery"]) - after["battery"]) / max(1 / 60, span / 3600)  # % an hour
        values["drain"] = round(drop, 1)
        tide = ("a rising tide" if after.get("charging") and after["battery"] < 100 else
                "slack water" if after.get("charging") or abs(drop) < 1 else
                "the tide going out fast" if drop >= 15 else "an ebbing tide")
        second.append(tide)
    return {"sentence": " / ".join([pressure, wind, rain]), "detail": ", ".join(second), "values": values,
            "categories": {"pressure": pressure, "wind": wind, "rain": rain}}


class Weather:
    def __init__(self, clock, state_dir: Path, proc: Path = Path("/proc"), sys: Path = Path("/sys"), cpus: int | None = None):
        self.clock, self.path, self.proc, self.sys = clock, state_dir / "weather.json", proc, sys
        self.cpus = cpus or os.cpu_count() or 1
        saved = None
        try:
            saved = read_json(self.path, None)
        except ValueError:
            log.warning("weather.json is not JSON; starting empty")
        saved = saved if isinstance(saved, dict) else {}
        self.reading = saved.get("reading") if isinstance(saved.get("reading"), dict) else None
        reports = saved.get("reports")
        self.reports = [r for r in reports if isinstance(r, dict) and isinstance(r.get("sentence"), str)][-KEEP:] if isinstance(reports, list) else []

    def observe(self) -> bool:
        """The view has opened: a report if ten minutes have passed since the last reading. True when one was made."""
        now = self.clock.now()
        counters = read_counters(self.proc, self.sys)
        last = self.reading if self.reading is not None and self.reading.get("bootId") == now.boot_id else None
        if last is not None and now.boot - last.get("boot", now.boot) < SPAN_MIN:
            return False
        made = None
        if last is not None:
            span = now.boot - last["boot"]
            made = report(last.get("counters", {}), counters, span, self.cpus)
            if made:
                made.update(at=round(now.real), span=round(span), day=datetime.fromtimestamp(now.real).date().isoformat())
                self.reports = (self.reports + [made])[-KEEP:]
        self.reading = {"boot": now.boot, "bootId": now.boot_id, "real": now.real, "counters": counters}
        self._save()
        return made is not None

    def now(self) -> dict:
        """The latest report, the barograph (each report's pressure), and for the last reports their span, hottest zone and
        battery: the thermal strata (atlas #16) and the battery ledger (#22). Newest last."""
        recent = self.reports[-24:]
        return {"latest": self.reports[-1] if self.reports else None,
                "barograph": [{"at": r.get("at"), "hpa": r.get("values", {}).get("hpa")} for r in recent],
                "strata": [{"at": r.get("at"), "span": r.get("span"), "temp": r.get("values", {}).get("temp")} for r in recent],
                "ledger": [{"at": r.get("at"), "span": r.get("span"), "battery": r.get("values", {}).get("battery"),
                            "drain": r.get("values", {}).get("drain")} for r in recent],
                "count": len(self.reports)}

    def _save(self):
        try:
            write_json(self.path, {"version": 1, "reading": self.reading, "reports": self.reports})
        except OSError as error:
            log.warning("weather.json not saved: %s", error)
