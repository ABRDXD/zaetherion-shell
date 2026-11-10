"""The ignite hold (D16): Super+` timing, kept in the core so it works with the view reaped (DAILY_DRIVER §4.6).

`fart-next key down` and `fart-next key up` are the only inputs. The view shows the hold meter from the
`ignite` topic and owns no timing. The Overdrive effect (M8) hangs off the `overdrive` topic, not off this one.

    down ──150 ms──► meter shown ──600 ms──► fired (overdrive.request panel)
      └─ up before 600 ms: ends, nothing fires      └─ up: ends the meter
    no up within 3 s: treated as released (a lost release must not leave the meter up)
    down while held: ignored (the bind does not repeat; a second edge is noise)
    down while the panel is open with the command line focused and empty: folds the panel (Q7), no hold
    a fire while Overdrive is already on releases it instead (hold to ignite, hold to cut; core/app.py)
    down(panel=True): the hold starts inside the open panel (its ignite plate, docs/OVERDRIVE.md §2), so it
    neither folds nor opens the panel; the timing is the same
"""
from __future__ import annotations

import logging
from typing import Callable

log = logging.getLogger("fart.ignite")
METER = 0.150
FIRE = 0.600
LOST = 3.0
KEYS = ("ignite.meter", "ignite.fire", "ignite.lost")


class Ignite:
    def __init__(self, clock, scheduler, open_panel: Callable[[], None], fold_panel: Callable[[], None],
                 may_fold: Callable[[], bool], fire: Callable[[], str]):
        self.clock = clock
        self.scheduler = scheduler
        self.open_panel = open_panel  # opens (or keeps) the panel with the command line focused; never blocks
        self.fold_panel = fold_panel
        self.may_fold = may_fold  # the panel is open and its command line has focus and no text
        self.fire = fire  # requests (or cuts) Overdrive for the panel: "granted", "released", "pending" or "refused"
        self.on_change = lambda: None
        self.phase = "idle"  # idle | pressed | holding | fired
        self.t0 = None  # Now of the press
        self.outcome: str | None = None
        self._last = self.snapshot()

    def snapshot(self) -> dict:
        since = None
        if self.phase in ("holding", "fired") and self.t0 is not None:
            now = self.clock.now()
            since = round((now.real - (now.boot - self.t0.boot)) * 1000)
        return {"holding": self.phase in ("holding", "fired"), "since": since, "fired": self.phase == "fired",
                "outcome": self.outcome if self.phase == "fired" else None}

    def _publish(self):
        snap = self.snapshot()
        if snap != self._last:
            self._last = snap
            self.on_change()

    # Inputs

    def down(self, panel: bool = False) -> dict:
        if self.phase != "idle":
            return {"action": "ignored", **self.snapshot()}
        if not panel and self.may_fold():
            self.fold_panel()
            return {"action": "fold", **self.snapshot()}
        self.t0 = now = self.clock.now()
        self.phase, self.outcome = "pressed", None
        self.scheduler.at("ignite.meter", now.boot + METER, lambda _: self._meter())
        self.scheduler.at("ignite.fire", now.boot + FIRE, lambda _: self._fire())
        self.scheduler.at("ignite.lost", now.boot + LOST, lambda _: self._lost())
        if panel:
            return {"action": "hold", **self.snapshot()}
        self.open_panel()
        return {"action": "open", **self.snapshot()}

    def up(self) -> dict:
        if self.phase == "idle":
            return {"action": "ignored", **self.snapshot()}
        if self.phase != "fired" and self.clock.now().boot - self.t0.boot >= FIRE:
            self._fire()  # the release arrived before the fire deadline was serviced
        fired = self.phase == "fired"
        self._end()
        return {"action": "fired" if fired else "released", **self.snapshot()}

    # Deadlines

    def _meter(self):
        if self.phase == "pressed":
            self.phase = "holding"
            self._publish()

    def _fire(self):
        if self.phase not in ("pressed", "holding"):
            return
        self.phase = "fired"
        try:
            self.outcome = self.fire()
        except Exception:  # a failed effect must not leave the meter up
            log.exception("ignite: the Overdrive request failed")
            self.outcome = "refused"
        self._publish()

    def _lost(self):
        if self.phase != "idle":
            log.info("ignite: no key up within %.0f s; treated as released", LOST)
            self._end()

    def _end(self):
        for key in KEYS:
            self.scheduler.cancel(key)
        self.phase = "idle"
        self._publish()
