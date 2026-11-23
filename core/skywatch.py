"""The sky watch: where the user is, what the sky is doing there, and its events into discovery (M10).

- `now()` answers the view's `sky.now`: the astronomical clock's snapshot (core/sky.py), the place, and the
  next events. Home asks once a minute while its clock is on screen; nothing is pushed, so a view that
  isn't showing Home costs nothing.
- Events (moon phases, sunrise and sunset, conjunctions) are scheduled one at a time on the boottime
  scheduler: a wake-up per event, a few a day, never a poll. Each one that fires bumps a discovery counter
  (`sky.<kind>`; a conjunction also `sky.conjunction.<a>-<b>`). An event slept through (more than `STALE`
  late at wake-up) is skipped, not counted: discovery records what the machine was awake for.

The place is the host's (`HostProfile.location()`), read at each use so a change in the host's settings
applies at once. Without one, the fallback is the system time zone's reference city from the tz database
(zone1970.tab), which is right to a few hundred kilometres within most zones; failing that, 0° 0° and
"source": "none", which the clock shows.
"""
from __future__ import annotations

from datetime import datetime, timezone
import logging
from pathlib import Path
import re

from core import sky

log = logging.getLogger("fart.sky")

UNIX_J2000 = 946728000.0          # 2000-01-01 12:00 UTC
HORIZON = 2.0                      # days of events computed at a time
SOON = 1.5                         # days of upcoming events `now()` lists
STALE = 600.0                      # seconds: an event later than this at wake-up was slept through
ZONE_TAB = Path("/usr/share/zoneinfo/zone1970.tab")
LOCALTIME = Path("/etc/localtime")
_COORD = re.compile(r"^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$")


def jd_of(real: float) -> float:
    return sky.J2000 + (real - UNIX_J2000) / 86400.0


def _dms(sign: str, d: str, m: str, s: str | None) -> float:
    value = int(d) + int(m) / 60 + (int(s) if s else 0) / 3600
    return -value if sign == "-" else value


def zone_place(zone_tab: Path = ZONE_TAB, localtime: Path = LOCALTIME, zone: str | None = None) -> dict | None:
    """The reference city of the system time zone, from zone1970.tab (ISO 6709 coordinates)."""
    if zone is None:
        try:
            target = str(localtime.resolve())
        except OSError:
            return None
        if "zoneinfo/" not in target:
            return None
        zone = target.split("zoneinfo/", 1)[1]
    try:
        rows = zone_tab.read_text().splitlines()
    except OSError:
        return None
    for row in rows:
        fields = row.split("\t")
        if row.startswith("#") or len(fields) < 3 or fields[2] != zone:
            continue
        m = _COORD.match(fields[1])
        if not m:
            return None
        return {"lat": round(_dms(m[1], m[2], m[3], m[4]), 4), "lon": round(_dms(m[5], m[6], m[7], m[8]), 4),
                "name": zone.rsplit("/", 1)[-1].replace("_", " "), "source": "timezone"}
    return None


class SkyWatch:
    def __init__(self, clock, scheduler, locate, discovery, zone=zone_place):
        self.clock = clock
        self.scheduler = scheduler
        self.locate = locate              # () -> {"lat", "lon", "name"} | None (the host profile's location)
        self.discovery = discovery
        self.zone = zone
        self.queue: list[dict] = []       # computed, not yet fired, in time order
        self.last: dict | None = None     # the last event that fired
        self.computed_to = 0.0            # JD up to which `queue` is complete
        scheduler.clock_set.append(self.rearm)

    def place(self) -> dict:
        try:
            host = self.locate()
        except Exception:  # a host profile's bug must not take the core down
            log.exception("the host's location failed")
            host = None
        if isinstance(host, dict):
            try:
                lat, lon = float(host["lat"]), float(host["lon"])
                if -90 <= lat <= 90 and -180 <= lon <= 180:
                    return {"lat": lat, "lon": lon, "name": str(host.get("name") or ""), "source": "host"}
            except (KeyError, TypeError, ValueError):
                pass
        return self.zone() or {"lat": 0.0, "lon": 0.0, "name": "", "source": "none"}

    # The view's question

    def now(self, tracks: bool = False) -> dict:
        """The clock's sky; with `tracks`, also each body's path from 12 h before to 12 h after (every 15 min)."""
        now = self.clock.now()
        place = self.place()
        snap = sky.snapshot(datetime.fromtimestamp(now.real, timezone.utc), place["lat"], place["lon"])
        jd = jd_of(now.real)
        self._extend(jd + SOON, place)
        snap["place"] = place
        snap["next"] = [self._public(e, jd) for e in self.queue if jd <= e["jd"] < jd + SOON]
        snap["last"] = self.last
        if tracks:
            snap["tracks"] = sky.tracks(jd, place["lat"], place["lon"])
        return snap

    # Events

    def start(self):
        self.rearm()

    def rearm(self):
        """Recompute from now (at start, and when the wall clock jumps), then wait for the first event."""
        self.queue, self.computed_to = [], 0.0
        self._arm()

    def _extend(self, until: float, place: dict):
        if until <= self.computed_to:
            return
        start = max(self.computed_to, jd_of(self.clock.now().real))
        found = sky.events(start, until + 0.5, place["lat"], place["lon"])
        self.queue = sorted(self.queue + found, key=lambda e: e["jd"])
        self.computed_to = until + 0.5

    def _arm(self):
        now = self.clock.now()
        jd = jd_of(now.real)
        self.queue = [e for e in self.queue if e["jd"] > jd]
        if not self.queue:
            self._extend(jd + HORIZON, self.place())
            self.queue = [e for e in self.queue if e["jd"] > jd]
        if not self.queue:
            # A sky with nothing in two days (a polar night, no phase): look again then.
            self.scheduler.at("sky", now.boot + HORIZON * 86400, lambda _now: self.rearm())
            return
        due = self.queue[0]
        self.scheduler.at("sky", now.boot + (due["jd"] - jd) * 86400, lambda fired: self._fire(due, fired))

    def _fire(self, event: dict, now):
        late = (jd_of(now.real) - event["jd"]) * 86400
        if self.queue and self.queue[0] is event:
            self.queue.pop(0)
        if late <= STALE:
            self.last = self._public(event, None)
            try:
                self.discovery.bump("sky." + event["kind"])
                if event["kind"] == "conjunction":
                    self.discovery.bump("sky.conjunction." + "-".join(event["bodies"]))
            except Exception:
                log.exception("discovery refused a sky event")
        self._arm()

    @staticmethod
    def _public(event: dict, jd: float | None) -> dict:
        out = {k: v for k, v in event.items() if k != "jd"}
        out["at"] = sky.from_julian_day(event["jd"]).isoformat(timespec="seconds")
        if jd is not None:
            out["inSeconds"] = round((event["jd"] - jd) * 86400)
        return out
