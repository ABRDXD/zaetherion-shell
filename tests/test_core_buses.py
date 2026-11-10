"""core/buses.py: the USB buses as wired (atlas #21), read from a fake sysfs tree."""
import os
from pathlib import Path
import tempfile
import unittest

import core_fakes
from core.app import Core
from core.buses import Buses, kind_of, parent_of, read_usb
from core.guards import SessionGuard


class FakeSys:
    """devices/pci0000:00/<pci>/usbN (root hubs) and their devices, linked into bus/usb/devices as the kernel does."""

    def __init__(self, root: Path):
        self.devices = root / "devices/pci0000:00"
        self.bus = root / "bus/usb/devices"
        self.bus.mkdir(parents=True)

    def hub(self, pci, n, speed, ports):
        d = self.devices / pci / f"usb{n}"
        d.mkdir(parents=True)
        (d / "speed").write_text(f"{speed}\n")
        (d / "maxchild").write_text(f"{ports}\n")
        (d / "bDeviceClass").write_text("09\n")
        os.symlink(d, self.bus / f"usb{n}")
        return d

    def device(self, under: Path, name, cls, interfaces, speed, product, ports=0):
        d = under / name
        d.mkdir(parents=True)
        (d / "speed").write_text(f"{speed}\n")
        (d / "maxchild").write_text(f"{ports}\n")
        (d / "bDeviceClass").write_text(f"{cls}\n")
        (d / "product").write_text(f"{product}\n")
        for k, c in enumerate(interfaces):
            i = d / f"{name}:1.{k}"
            i.mkdir()
            (i / "bInterfaceClass").write_text(f"{c}\n")
            os.symlink(i, self.bus / i.name)
        os.symlink(d, self.bus / name)
        return d


class BusTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.sys = FakeSys(Path(self.tmp.name))
        usb1 = self.sys.hub("0000:06:00.3", 1, 480, 4)
        self.sys.hub("0000:06:00.3", 2, 10000, 2)
        self.sys.hub("0000:08:00.4", 3, 480, 1)
        self.sys.device(usb1, "1-1", "00", ["03", "03"], 12, "Receiver")
        hub = self.sys.device(usb1, "1-2", "09", ["09"], 480, "Hub", ports=4)
        self.sys.device(hub, "1-2.3", "00", ["08"], 480, "Stick")
        self.sys.device(usb1, "1-4", "e0", ["e0", "e0"], 12, "Bluetooth Radio")

    def tearDown(self):
        self.tmp.cleanup()

    def test_kinds_and_parents(self):
        self.assertEqual([kind_of(c, set(i)) for c, i in (("00", ["03"]), ("ef", ["0e", "fe"]), ("e0", ["e0"]), ("00", ["0a", "e0"]), ("09", []), ("ff", ["ff"]))],
                         ["INPUT", "VIDEO", "RADIO", "NETWORK", "HUB", "DEVICE"])
        self.assertEqual([parent_of(n) for n in ("1-3", "1-3.2", "1-3.2.1", "10-1")], ["usb1", "1-3", "1-3.2", "usb10"])

    def test_controllers_hubs_and_devices(self):
        got = read_usb(self.sys.bus)
        self.assertEqual([c["pci"] for c in got["controllers"]], ["0000:06:00.3", "0000:08:00.4"])
        self.assertEqual(got["controllers"][0]["hubs"], [{"bus": 1, "speed": 480, "ports": 4}, {"bus": 2, "speed": 10000, "ports": 2}])
        by = {d["path"]: d for d in got["devices"]}
        self.assertEqual(sorted(by), ["1-1", "1-2", "1-2.3", "1-4"])
        self.assertEqual((by["1-2.3"]["parent"], by["1-2.3"]["port"], by["1-2.3"]["kind"]), ("1-2", 3, "STORAGE"))
        self.assertEqual((by["1-2"]["kind"], by["1-2"]["ports"], by["1-4"]["kind"], by["1-1"]["port"]), ("HUB", 4, "RADIO", 1))

    def test_nothing_outside_overdrive(self):
        on = [False]
        buses = Buses(active=lambda: on[0], root=self.sys.bus)
        self.assertEqual(buses.usb(), {"running": False})
        on[0] = True
        self.assertEqual(len(buses.usb()["devices"]), 4)

    def test_a_missing_tree_is_empty(self):
        self.assertEqual(read_usb(Path(self.tmp.name) / "absent"), {"controllers": [], "devices": []})


class CoreBuses(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, _, host = core_fakes.fakes()

        async def spawn():
            raise OSError("no view in this test")
        self.core = Core(self.clock, scheduler, host, Path(self.temp.name), spawn=spawn, guard_types=[SessionGuard])

    async def test_the_op_reads_only_under_an_active_lease(self):
        usb = self.core.server.ops["bus.usb"]
        self.assertEqual(usb(None), {"running": False})
        self.core.overdrive.request("sticky")
        self.assertTrue(usb(None)["running"])


if __name__ == "__main__":
    unittest.main()
