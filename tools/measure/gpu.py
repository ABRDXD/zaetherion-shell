"""GPU load while a sample runs: each card as a whole, and the measured process's own share.

Whole-card load comes from sysfs (`gpu_busy_percent`) where the driver has it. The NVIDIA card has no such file and is
never asked: nvidia-smi can wake a sleeping card or keep it from suspending, and an awake card suspends Overdrive through
its dGPU guard. Instead each sample records whether the card was awake, from its runtime power status, which doesn't wake it.
The process's own share is the difference in its
`drm-engine-*` nanoseconds in `/proc/<pid>/fdinfo`, per device, where the driver reports them.
"""
from pathlib import Path
import threading
import time

VENDORS = {"0x10de": "nvidia", "0x1002": "amd", "0x8086": "intel"}


def parse_fdinfo(text):
    """(device, client id, engine nanoseconds), or None for a descriptor that is not a DRM client."""
    device, client, total, found = None, None, 0, False
    for line in text.splitlines():
        key, _, value = line.partition(":")
        value = value.strip()
        if key == "drm-pdev":
            device = value
        elif key == "drm-client-id":
            client = value
        elif key.startswith("drm-engine-") and not key.startswith("drm-engine-capacity"):
            total += int(value.split()[0])
            found = True
    return (device, client, total) if found and client is not None else None


def engine_time(pid, proc=Path("/proc")):
    """Nanoseconds of GPU engine time per device; a client open on several descriptors counts once."""
    clients = {}
    try:
        entries = list((proc / str(pid) / "fdinfo").iterdir())
    except OSError:
        return {}
    for entry in entries:
        try:
            parsed = parse_fdinfo(entry.read_text())
        except (OSError, ValueError):
            continue
        if parsed:
            clients[parsed[:2]] = parsed[2]
    devices = {}
    for (device, _), nanoseconds in clients.items():
        devices[device] = devices.get(device, 0) + nanoseconds
    return devices


def cards(drm=Path("/sys/class/drm")):
    found = {}
    for card in sorted(drm.glob("card[0-9]")):
        try:
            found[card.name] = (VENDORS.get((card / "device/vendor").read_text().strip(), "unknown"), card)
        except OSError:
            continue
    return found


def card_awake(card):
    """True or False from the runtime power status, None if unreadable. Reading it doesn't wake the card."""
    try:
        return (card / "device/power/runtime_status").read_text().strip() == "active"
    except OSError:
        return None


def card_busy(vendor, card):
    """Percent busy, or None where sysfs doesn't say (the NVIDIA card)."""
    try:
        return float((card / "device/gpu_busy_percent").read_text())
    except (OSError, ValueError):
        return None


class GpuWatch:
    """`with GpuWatch(pid) as watch:` samples the cards once a second; `watch.result` is ready after the block."""

    def __init__(self, pid, interval=1.0):
        self.pid, self.interval = pid, interval
        self.cards = cards()
        self.samples = {name: [] for name in self.cards}
        self.awake = {name: [] for name in self.cards}
        self.result = None
        self._stop = threading.Event()

    def _run(self):
        while not self._stop.wait(self.interval):
            for name, (vendor, card) in self.cards.items():
                self.awake[name].append(card_awake(card))
                value = card_busy(vendor, card)
                if value is not None:
                    self.samples[name].append(value)

    def __enter__(self):
        self.started, self.first = time.monotonic(), engine_time(self.pid)
        self.thread = threading.Thread(target=self._run, daemon=True)
        self.thread.start()
        return self

    def __exit__(self, *_):
        self._stop.set()
        self.thread.join()
        elapsed = time.monotonic() - self.started
        last = engine_time(self.pid)
        self.result = {
            "cards": {name: dict(vendor=self.cards[name][0], samples=len(values), awake=sum(a is True for a in self.awake[name]),
                                 checks=len(self.awake[name]),
                                 busy_mean=round(sum(values) / len(values), 1) if values else None,
                                 busy_peak=max(values) if values else None) for name, values in self.samples.items()},
            "process_percent": {device: round((last[device] - self.first.get(device, 0)) / elapsed / 1e7, 1) for device in last},
        }
        return False
