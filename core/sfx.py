"""Sound cues (D19): the one gate, the one player, and an `sfx.cue` event per cue (docs/M5-COMMAND.md §5).

Every cue plays here, through the host profile, so one place applies the policy and alarms sound with the
view reaped. Alerts (a timer, a pomodoro phase, a session) come from the core's own subsystems. UI cues
follow the host's own controls (DAILY_DRIVER Q9): the profile maps each to the file the host plays for
the same moment. The view reports the moments only it sees (`sfx.play`); it never plays a sound itself.

The gate, in order: the cue is on (FART's timer-sound setting for alerts, a per-cue switch for UI cues,
each on until switched off), no session is quieting it, the host's sfx are not muted and the host is not
in DND. A cue the host has no file for is not audible ("no-sound").
"""
from __future__ import annotations

from dataclasses import dataclass
import logging
from pathlib import Path
import time

from core.errors import OpError, bad_args
from core.store import read_json, write_json

log = logging.getLogger("fart.sfx")


@dataclass(frozen=True)
class Cue:
    name: str
    kind: str  # alert | ui
    session: bool  # still audible while a session runs (it belongs to the session)
    summary: str


CUES = {cue.name: cue for cue in (
    Cue("timer.done", "alert", False, "a countdown finished"),
    Cue("pomodoro.phase", "alert", True, "a pomodoro phase ended"),
    Cue("session.end", "alert", True, "a session completed"),
    Cue("ui.click", "ui", False, "a button or row was pressed"),
    Cue("ui.key", "ui", False, "a key was typed into the command line"),
    Cue("ui.switch", "ui", False, "a switch or tab changed"),
    Cue("ui.error", "ui", False, "an input was refused, or a command-line verb failed"),
    Cue("cmd.run", "ui", False, "a command-line verb ran"),
    Cue("orbit.out", "ui", False, "the camera pulled back to the orbit (a room switch, or the orbit opening)"),
    Cue("orbit.land", "ui", False, "the camera dived into a room"),
    Cue("orbit.hover", "ui", False, "the highlight moved to another room on the orbit"),
    Cue("ignite", "ui", False, "Overdrive ignited: a lease started (FART's own sound, docs/OVERDRIVE.md)"),
    Cue("overdrive.off", "ui", False, "Overdrive spun down: its lease ended, FART is back in Silent"),
    # Overdrive's material sounds (docs/OVERDRIVE_IDEAS.md #47): one per kind of physical event, never for values.
    Cue("foley.pin", "ui", False, "a stalk or shelf was pinned in place"),
    Cue("foley.relay", "ui", False, "the orbit locked: a resonance, a chord"),
    Cue("foley.paper", "ui", False, "a sheet sheared"),
    Cue("foley.ruler", "ui", False, "a ruler stroke was read"),
    Cue("foley.splice", "ui", False, "a cut at the end of a room switch"),
    # Quiet telemetry (#48): the machine, heard only when something is out of the ordinary (core/quiet.py).
    Cue("quiet.thrash", "ui", False, "memory is being fought over: major faults and swapping jumped"),
    Cue("quiet.burst", "ui", False, "network traffic jumped"),
    Cue("quiet.device", "ui", False, "a USB device appeared or went"),
    # Each room's chord (#46), panned from where its tile stands on the orbit (#49): one switch, not nine.
    *(Cue(f"chord.{n}.{pan}", "ui", False, "a room's chord on arrival") for n in range(10) for pan in "lcr"),
)}
VIEW_CUES = ("ui.click", "ui.key", "ui.switch", "ui.error", "orbit.out", "orbit.land", "orbit.hover",
             "foley.pin", "foley.relay", "foley.paper", "foley.ruler", "foley.splice",
             *(f"chord.{n}.{pan}" for n in range(10) for pan in "lcr"))  # cmd.run and the alerts are the core's own


class Sfx:
    def __init__(self, host, clock=None, state_dir: Path | None = None, sound_on=lambda: False, session_active=lambda: False):
        self.host = host
        self.clock = clock
        self.path = state_dir / "sfx.json" if state_dir else None
        self.sound_on = sound_on  # FART's timer-sound setting
        self.session_active = session_active
        self.on_cue = lambda event: None
        self.on_change = lambda: None
        self.seq = 0
        self.enabled = {name: True for name, cue in CUES.items() if cue.kind == "ui"}
        self._load()

    def _load(self):
        if not self.path:
            return
        try:
            saved = read_json(self.path, {}) or {}
        except ValueError:
            log.warning("sfx.json is not JSON; every UI cue stays on")
            return
        cues = saved.get("cues") if isinstance(saved, dict) else None
        for name, on in (cues.items() if isinstance(cues, dict) else ()):
            if name in self.enabled and isinstance(on, bool):
                self.enabled[name] = on

    def snapshot(self) -> dict:
        sound = self.sound_on()
        return {"cues": [{"name": c.name, "kind": c.kind, "session": c.session, "summary": c.summary,
                          "enabled": sound if c.kind == "alert" else self.enabled[c.name]} for c in CUES.values()]}

    def configure(self, cues):
        if not isinstance(cues, dict) or not all(isinstance(v, bool) for v in cues.values()):
            raise bad_args("cues must map cue names to true or false")
        unknown = [name for name in cues if name not in self.enabled]
        if unknown:
            raise bad_args(f"only UI cues are switched here ({', '.join(self.enabled)}); alerts follow the timer sound setting")
        self.enabled.update(cues)
        if self.path:
            write_json(self.path, {"version": 1, "cues": self.enabled})
        self.on_change()
        return self.snapshot()

    def decide(self, cue: Cue, sound: bool | None = None) -> tuple[bool, str | None, float]:
        """(audible, the reason it is not, gain). Host settings are read only for a cue that is on."""
        on = (self.sound_on() if sound is None else sound) if cue.kind == "alert" else self.enabled[cue.name]
        if not on:
            return False, "off", 0.0
        if self.session_active() and not cue.session:
            return False, "session", 0.0
        muted, volume = self.host.profile.sfx()
        if muted or volume <= 0:
            return False, "muted", 0.0
        if self.host.profile.dnd():
            return False, "dnd", 0.0
        return True, None, volume

    def emit(self, name: str, sound: bool | None = None) -> dict:
        cue = CUES.get(name)
        if cue is None:
            raise bad_args(f"unknown cue {name!r}")
        audible, reason, gain = self.decide(cue, sound)
        if audible:
            command = self.host.profile.play_command(cue.name, gain)
            if command:
                self.host.run(command)
            else:
                audible, reason, gain = False, "no-sound", 0.0
        self.seq += 1
        now = self.clock.now().real if self.clock else time.time()
        event = {"cue": cue.name, "seq": self.seq, "at": round(now * 1000),
                 "audible": audible, "reason": reason, "gain": round(gain, 3)}
        self.on_cue(event)
        return event

    def emit_from_view(self, cue):
        """sfx.play: the view reports a UI moment the core cannot see. Alerts and cmd.run are the core's alone."""
        if cue not in VIEW_CUES:
            raise OpError("refused", f"the view reports only {', '.join(VIEW_CUES)}")
        return self.emit(cue)

    async def play_exhibit(self, path):
        """Temporary score audio shares the UI gate; caller owns termination and unlink."""
        import asyncio
        audible, _, gain = self.decide(CUES["foley.paper"])
        if not audible:
            return None
        command = getattr(self.host.profile, "play_file_command", lambda path, gain: None)(path, gain)
        if not command:
            return None
        try:
            return await asyncio.create_subprocess_exec(*command,
                                                        stdout=asyncio.subprocess.DEVNULL,
                                                        stderr=asyncio.subprocess.DEVNULL)
        except OSError:
            return None
