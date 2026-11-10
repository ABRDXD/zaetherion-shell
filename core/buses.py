"""The machine's USB buses as they are wired (Claude B; docs/OVERDRIVE.md §38, atlas #21 Bus Topology).

Pulled by Devices' schematic (`bus.usb`, every few seconds while its stratum exists), read only while Overdrive is in
effect. Read-only sysfs: `/sys/bus/usb/devices` (each device's bus, port path, speed, port count, class, its interfaces'
classes and its product string) and the root hubs' place on the PCI bus (their controller). Nothing is written, nothing
is kept between readings, and nothing leaves the panel.

A reading is {running, controllers: [{pci, hubs: [{bus, speed, ports}]}], devices: [{path, bus, parent, port, kind,
speed, product, ports}]}: `path` is the kernel's port path (`1-3`, `1-3.2`), `parent` the hub it hangs from (`usb1` for
a root hub's port), `kind` read from the classes (HUB, RADIO, NETWORK, VIDEO, AUDIO, STORAGE, INPUT, DEVICE).
"""
from __future__ import annotations

import os
from pathlib import Path
from typing import Callable

SYS = Path("/sys/bus/usb/devices")
# Interface classes, in the order a device's kind is decided.
KINDS = (("09", "HUB"), ("0e", "VIDEO"), ("01", "AUDIO"), ("08", "STORAGE"), ("0a", "NETWORK"), ("02", "NETWORK"),
         ("e0", "RADIO"), ("03", "INPUT"))


def _read(path: Path) -> str:
    try:
        return path.read_text().strip()
    except OSError:
        return ""


def _int(text: str, default: int = 0) -> int:
    try:
        return int(float(text))
    except ValueError:
        return default


def kind_of(device_class: str, interfaces: set[str]) -> str:
    classes = {device_class} | interfaces
    for code, kind in KINDS:
        if code in classes:
            return kind
    return "DEVICE"


def parent_of(name: str) -> str:
    """`1-3.2` hangs from `1-3`; `1-3` from the root hub `usb1`."""
    bus, _, chain = name.partition("-")
    return name.rsplit(".", 1)[0] if "." in chain else "usb" + bus


def read_usb(root: Path = SYS) -> dict:
    controllers: dict[str, dict] = {}
    devices = []
    try:
        names = sorted(p.name for p in root.iterdir())
    except OSError:
        return {"controllers": [], "devices": []}
    for name in names:
        if ":" in name:
            continue   # an interface, read through its device
        d = root / name
        speed = _int(_read(d / "speed"))
        ports = _int(_read(d / "maxchild"))
        if name.startswith("usb"):
            bus = _int(name[3:])
            # The controller: the PCI device the root hub hangs from.
            pci = os.path.basename(os.path.dirname(os.path.realpath(d)))
            controllers.setdefault(pci, {"pci": pci, "hubs": []})["hubs"].append({"bus": bus, "speed": speed, "ports": ports})
            continue
        interfaces = {_read(i / "bInterfaceClass") for i in d.glob(name + ":*")} - {""}
        port = name.rsplit(".", 1)[-1].partition("-")[2] if "." not in name else name.rsplit(".", 1)[1]
        devices.append({"path": name, "bus": _int(name.partition("-")[0]), "parent": parent_of(name), "port": _int(port),
                        "kind": kind_of(_read(d / "bDeviceClass"), interfaces), "speed": speed,
                        "product": _read(d / "product")[:40], "ports": ports})
    out = sorted(controllers.values(), key=lambda c: min(h["bus"] for h in c["hubs"]))
    for c in out:
        c["hubs"].sort(key=lambda h: h["bus"])
    return {"controllers": out, "devices": devices}


class Buses:
    def __init__(self, active: Callable[[], bool], root: Path = SYS):
        self.active, self.root = active, root

    def usb(self) -> dict:
        if not self.active():
            return {"running": False}
        return {"running": True, **read_usb(self.root)}
