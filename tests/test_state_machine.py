"""Drive the real core, CoreClient and room loader through the private socket."""
import time
import unittest

from tools.measure.fixture import private_core


class FixtureStateTests(unittest.TestCase):
    def test_open_room_close(self):
        with private_core() as f:
            self.assertEqual(f.state()["state"], "absent")
            for page in ("home", "tasks"):
                f.request("view.open", page=page)
                f.wait_state(True, page)
            f.request("view.close")
            self.assertIsNotNone(f.wait_state(False, "tasks")["closedSince"])

    def test_rapid_reversals(self):
        with private_core() as f:
            f.request("view.open", page="home")
            pid = f.wait_state(True, "home")["pid"]
            for page in ("media", "devices", "home", "tasks") * 2:
                f.request("view.open", page=page)
                f.request("view.close")
            f.request("view.open", page="timers")
            self.assertEqual(f.wait_state(True, "timers")["pid"], pid)
            time.sleep(.3)
            final = f.state()
            self.assertEqual((final["state"], final["open"], final["page"]), ("ready", True, "timers"))

    def test_reap_and_cold_reopen(self):
        with private_core(reap_after=1) as f:
            f.request("view.open", page="home")
            pid = f.wait_state(True, "home")["pid"]
            f.request("view.close")
            f.wait_state(False, "home")
            deadline = time.monotonic() + 6
            while time.monotonic() < deadline and f.state()["state"] != "absent":
                time.sleep(.05)
            self.assertEqual(f.state()["state"], "absent")
            f.request("view.open", page="performance")
            self.assertNotEqual(f.wait_state(True, "performance")["pid"], pid)
