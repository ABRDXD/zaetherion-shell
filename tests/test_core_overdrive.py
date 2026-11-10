"""The lease × guard transition table of docs/CORE.md §6.2, plus scripted sequences."""
from pathlib import Path
import tempfile
import unittest

from core_fakes import fakes
from core.errors import OpError
from core.overdrive import GUARDS, MODES, Overdrive, State, step

NOW = 1000.0
STATES = {"off": State(), "timed": State("timed", NOW + 600), "panel": State("panel"), "sticky": State("sticky")}
EVENTS = {
    "request timed": ("request", "timed", 60.0),
    "request panel (open)": ("request", "panel", True),
    "request panel (closed)": ("request", "panel", False),
    "request sticky": ("request", "sticky"),
    "release": ("release",),
    "timeout": ("timeout",),
    "panel closed": ("panel_closed",),
    "guard on": ("guard_on", "fullscreen"),
    "guard off": ("guard_off", "fullscreen"),
}
# (from mode, event) -> (to mode, effect names). Rows reference the table numbers.
TABLE = {
    ("off", "request timed"): ("timed", ["start_guards", "arm_timeout", "publish", "persist"]),  # 1
    ("off", "request panel (open)"): ("panel", ["start_guards", "publish", "persist"]),  # 2
    ("off", "request panel (closed)"): ("off", ["refuse"]),  # 3
    ("off", "request sticky"): ("sticky", ["start_guards", "publish", "persist"]),  # 4
    ("timed", "request timed"): ("timed", ["arm_timeout", "publish", "persist"]),  # 5
    ("timed", "request sticky"): ("sticky", ["disarm_timeout", "publish", "persist"]),  # 6
    ("panel", "request sticky"): ("sticky", ["publish", "persist"]),  # 6
    ("panel", "request timed"): ("timed", ["arm_timeout", "publish", "persist"]),  # 7
    ("sticky", "request timed"): ("timed", ["arm_timeout", "publish", "persist"]),  # 7
    ("timed", "request panel (open)"): ("timed", []),  # 8
    ("timed", "request panel (closed)"): ("timed", []),  # 8
    ("sticky", "request panel (open)"): ("sticky", []),  # 8
    ("sticky", "request panel (closed)"): ("sticky", []),  # 8
    ("panel", "request panel (open)"): ("panel", []),  # 9
    ("panel", "request panel (closed)"): ("panel", []),  # 9
    ("sticky", "request sticky"): ("sticky", []),  # 9
    ("timed", "release"): ("off", ["stop_guards", "disarm_timeout", "publish", "persist"]),  # 10
    ("panel", "release"): ("off", ["stop_guards", "publish", "persist"]),  # 10
    ("sticky", "release"): ("off", ["stop_guards", "publish", "persist"]),  # 10
    ("timed", "timeout"): ("off", ["stop_guards", "publish", "persist"]),  # 11
    ("panel", "timeout"): ("panel", []),
    ("sticky", "timeout"): ("sticky", []),
    ("panel", "panel closed"): ("off", ["stop_guards", "publish", "persist"]),  # 12
    ("timed", "panel closed"): ("timed", []),  # 13
    ("sticky", "panel closed"): ("sticky", []),  # 13
    ("off", "release"): ("off", []),  # 17
    ("off", "timeout"): ("off", []),  # 16
    ("off", "panel closed"): ("off", []),  # 16
    ("off", "guard on"): ("off", []),  # 16
    ("off", "guard off"): ("off", []),  # 16
}


class TransitionTableTests(unittest.TestCase):
    def test_every_row(self):
        for mode in MODES:
            for guards in (frozenset(), frozenset({"fullscreen"})):
                if mode == "off" and guards:
                    continue  # unreachable: guards are cleared with the monitors
                state = State(STATES[mode].mode, STATES[mode].until, guards)
                for name, event in EVENTS.items():
                    with self.subTest(mode=mode, guards=set(guards), event=name):
                        after, effects = step(state, event, NOW)
                        names = [e[0] for e in effects]
                        if name.startswith("guard") and mode != "off":  # rows 14, 15
                            on = name == "guard on"
                            self.assertEqual(after.mode, mode)
                            self.assertEqual("fullscreen" in after.guards, on)
                            self.assertEqual(names, [] if ("fullscreen" in guards) == on else ["publish"])
                            continue
                        expected_mode, expected = TABLE[(mode, name)]
                        self.assertEqual(after.mode, expected_mode)
                        self.assertEqual(names, expected)
                        if expected_mode == "off":
                            self.assertEqual(after.guards, frozenset())
                        elif names and "start_guards" not in names:
                            self.assertEqual(after.guards, guards)  # rows 5-7 keep the guard set

    def test_effective_state(self):
        self.assertEqual(State().effective, "off")
        self.assertEqual(State("sticky").effective, "active")
        self.assertEqual(State("sticky", None, frozenset({"battery"})).effective, "suspended")

    def test_guards_start_only_from_off_and_always_stop_on_the_way_back(self):
        for mode, state in STATES.items():
            for event in EVENTS.values():
                after, effects = step(state, event, NOW)
                names = [e[0] for e in effects]
                self.assertEqual("start_guards" in names, mode == "off" and after.mode != "off")
                self.assertEqual("stop_guards" in names, mode != "off" and after.mode == "off")

    def test_timed_lease_deadline(self):
        after, effects = step(State(), ("request", "timed", 1200.0), NOW)
        self.assertEqual(after.until, NOW + 1200)
        self.assertIn(("arm_timeout", NOW + 1200), effects)


class FakeGuards:
    def __init__(self):
        self.on = set()
        self.running = False
        self.starts = self.stops = 0

    def start(self):
        self.running = True
        self.starts += 1
        return set(self.on)

    def stop(self):
        self.running = False
        self.stops += 1

    def availability(self):
        return {g: "available" for g in GUARDS}


class SequenceTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.state = Path(temp.name)
        self.clock, self.scheduler, _, _ = fakes()
        self.guards = FakeGuards()
        self.view_open = False

    def overdrive(self):
        return Overdrive(self.clock, self.scheduler, self.guards, self.state, view_open=lambda: self.view_open)

    def test_ignite_fullscreen_then_timeout_while_suspended(self):
        od = self.overdrive()
        self.assertEqual(od.request("timed", 1200)["effective"], "active")
        od.guard("fullscreen", True)
        self.assertEqual((od.snapshot()["effective"], od.snapshot()["reasons"]), ("suspended", ["fullscreen"]))
        self.clock.advance(1200)  # the lease keeps counting while suspended
        self.assertEqual(od.snapshot()["requested"]["mode"], "off")
        self.assertFalse(self.guards.running)

    def test_request_while_a_guard_is_on_is_accepted_suspended(self):
        self.guards.on = {"battery"}
        snap = self.overdrive().request("sticky")
        self.assertEqual((snap["effective"], snap["reasons"]), ("suspended", ["battery"]))

    def test_sticky_suspends_and_resumes(self):
        od = self.overdrive()
        od.request("sticky")
        od.guard("battery", True)
        od.guard("battery", False)
        self.assertEqual(od.snapshot()["effective"], "active")
        self.clock.advance(86400)
        self.assertEqual(od.snapshot()["requested"]["mode"], "sticky")

    def test_panel_needs_an_open_view_and_ends_with_it(self):
        od = self.overdrive()
        with self.assertRaises(OpError):
            od.request("panel")
        self.view_open = True
        od.request("panel")
        od.panel_closed()
        self.assertEqual(od.snapshot()["requested"]["mode"], "off")
        self.assertEqual((self.guards.starts, self.guards.stops), (1, 1))

    def test_restart_restores_timed_and_sticky_but_never_panel(self):
        od = self.overdrive()
        od.request("timed", 600)
        self.clock.advance(100)
        again = self.overdrive()
        self.assertEqual(again.snapshot()["requested"]["mode"], "timed")
        self.assertAlmostEqual(again.state.until - self.clock.boot, 500)
        self.clock.advance(500)
        self.assertEqual(again.snapshot()["requested"]["mode"], "off")
        again.request("sticky")
        self.assertEqual(self.overdrive().snapshot()["requested"]["mode"], "sticky")
        self.view_open = True
        self.overdrive().release()
        od = self.overdrive()
        od.request("panel")
        self.assertEqual(self.overdrive().snapshot()["requested"]["mode"], "off")

    def test_expired_lease_after_restart_is_off(self):
        self.overdrive().request("timed", 60)
        self.clock.reboot(120)
        self.assertEqual(self.overdrive().snapshot()["requested"]["mode"], "off")

    def test_bad_requests(self):
        od = self.overdrive()
        for mode, seconds in (("timed", 0), ("timed", None), ("forever", None)):
            with self.assertRaises(OpError):
                od.request(mode, seconds)


if __name__ == "__main__":
    unittest.main()
