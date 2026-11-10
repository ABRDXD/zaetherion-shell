"""Shared fakes for core tests: a controllable clock, its scheduler and the fixture host profile."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from core.clock import Now, Scheduler
from core.host import Host, load_profile


class FakeClock:
    """boot and real advance together, as they do across a real suspend; only monotonic (unused) would stop."""

    def __init__(self, boot=1000.0, real=1_793_900_000.0, boot_id="boot-a"):
        self.boot, self.real, self.boot_id = boot, real, boot_id
        self.scheduler = None

    def now(self):
        return Now(self.boot, self.real, self.boot_id)

    def advance(self, seconds):
        self.boot += seconds
        self.real += seconds
        if self.scheduler:
            self.scheduler.fire_due()

    def suspend(self, seconds):
        self.advance(seconds)

    def set_realtime(self, delta):
        self.real += delta
        if self.scheduler:
            self.scheduler.realtime_changed()

    def reboot(self, offline_seconds, boot_id="boot-b"):
        self.real += offline_seconds
        self.boot, self.boot_id = 5.0, boot_id


def fakes():
    clock = FakeClock()
    clock.scheduler = Scheduler(clock)
    profile = load_profile("fixture")
    profile.log = None
    return clock, clock.scheduler, profile, Host(profile)
