"""Quiet telemetry (docs/OVERDRIVE_IDEAS.md #48): the machine heard only when something is out of the ordinary.

While Overdrive is in effect and the panel is open, a counter sample every two seconds is compared with its own recent
past. Normal values make no sound, however large; only a sharp departure does, once, on the way up:

- `quiet.thrash`: brushed noise, when major page faults and swapping jump (memory is being fought over);
- `quiet.burst`: a narrow click train, when network traffic jumps;
- `quiet.device`: a low double pulse, when a USB device appears or goes.

The deviation is robust (median and median absolute deviation over the last two minutes), so one spike doesn't move
the baseline and a machine that is busy all day stays silent. Each kind can sound once per COOLDOWN and all of them
once per QUIET_GAP. Every sample reads only totals: `/proc/vmstat`, `/proc/net/dev` summed over every interface but
loopback, and the names of the entries in `/sys/bus/usb/devices`. Nothing is written to disk and nothing runs in Silent.
"""
from __future__ import annotations

from collections import deque
import logging
from pathlib import Path
from statistics import median
from typing import Callable

log = logging.getLogger("fart.quiet")
KEY = "quiet.sample"
INTERVAL = 2.0
WINDOW = 60  # samples: two minutes
WARM = 15  # samples before anything can sound: half a minute
DEVIATIONS = 6.0
NORMAL = 1.4826  # scales the median absolute deviation to a standard deviation
THRASH_FLOOR = 40.0  # faults and swapped pages per second that are never worth a sound
BURST_FLOOR = 8 * 1024 * 1024.0  # bytes per second, likewise
COOLDOWN = 30.0  # seconds between two sounds of one kind
QUIET_GAP = 8.0  # seconds between any two sounds
FAULTS = ("pgmajfault", "pswpin", "pswpout")


class Deviation:
    """One rate against its recent past. `push` is true only on the sample that crosses the line going up."""

    def __init__(self, floor: float):
        self.floor = floor
        self.values: deque[float] = deque(maxlen=WINDOW)
        self.high = False

    def push(self, value: float) -> bool:
        high = False
        if len(self.values) >= WARM:
            middle = median(self.values)
            spread = NORMAL * median(abs(v - middle) for v in self.values)
            high = value > middle + max(self.floor, DEVIATIONS * spread)
        self.values.append(value)
        crossed = high and not self.high
        self.high = high
        return crossed


class Quiet:
    def __init__(self, clock, scheduler, active: Callable[[], bool], emit: Callable[[str], object],
                 proc: Path = Path("/proc"), usb: Path = Path("/sys/bus/usb/devices")):
        self.clock, self.scheduler, self.active, self.emit = clock, scheduler, active, emit
        self.proc, self.usb = proc, usb
        self.running = False
        self._reset()

    def _reset(self):
        self.last: tuple[float, float, float] | None = None  # boot, faults, bytes
        self.devices: frozenset[str] | None = None
        self.thrash, self.burst = Deviation(THRASH_FLOOR), Deviation(BURST_FLOOR)
        self.sounded: dict[str, float] = {}
        self.any_sounded = float("-inf")

    def sync(self):
        """Call whenever Overdrive or the panel changes: sampling runs exactly while both are on."""
        if self.active() == self.running:
            return
        self.running = not self.running
        if self.running:
            self._arm(self.clock.now().boot)
        else:
            self.stop()

    def stop(self):
        self.running = False
        self.scheduler.cancel(KEY)
        self._reset()

    def _arm(self, boot: float):
        self.scheduler.at(KEY, boot + INTERVAL, self._tick)

    def _tick(self, now):
        if not self.running:
            return
        if not self.active():
            self.stop()
            return
        self.sample(now.boot)
        self._arm(now.boot)

    def read(self) -> tuple[float, float] | None:
        try:
            vmstat = dict(line.split()[:2] for line in (self.proc / "vmstat").read_text().splitlines() if line.strip())
            faults = sum(float(vmstat.get(name, 0)) for name in FAULTS)
            traffic = 0.0
            for line in (self.proc / "net/dev").read_text().splitlines()[2:]:
                name, _, fields = line.partition(":")
                if name.strip() != "lo":
                    numbers = fields.split()
                    traffic += float(numbers[0]) + float(numbers[8])
        except (OSError, ValueError, IndexError) as error:
            log.debug("quiet: unreadable counters: %s", error)
            return None
        return faults, traffic

    def read_devices(self) -> frozenset[str] | None:
        try:
            return frozenset(p.name for p in self.usb.iterdir() if ":" not in p.name)
        except OSError:
            return None

    def sample(self, boot: float):
        counters = self.read()
        devices = self.read_devices()
        if devices is not None:
            if self.devices is not None and devices != self.devices:
                self._sound("quiet.device", boot)
            self.devices = devices
        if counters is None:
            self.last = None
            return
        faults, traffic = counters
        if self.last is not None:
            at, last_faults, last_traffic = self.last
            elapsed = boot - at
            # Across a stall or a suspend the rate means nothing; counters only go down if they were reset.
            if 0 < elapsed <= 3 * INTERVAL and faults >= last_faults and traffic >= last_traffic:
                if self.thrash.push((faults - last_faults) / elapsed):
                    self._sound("quiet.thrash", boot)
                if self.burst.push((traffic - last_traffic) / elapsed):
                    self._sound("quiet.burst", boot)
        self.last = (boot, faults, traffic)

    def _sound(self, cue: str, boot: float):
        if boot - self.sounded.get(cue, float("-inf")) < COOLDOWN or boot - self.any_sounded < QUIET_GAP:
            return
        self.sounded[cue] = self.any_sounded = boot
        self.emit(cue)
