"""The supervisor's transition table and its driver, with fake processes and the fake clock (docs/SUPERVISOR.md)."""
import asyncio
import logging
from pathlib import Path
import unittest

from core_fakes import fakes
from core.supervisor import EVENTS, RETRY, STATES, TABLE, Child, Ident, Machine, Policy, Supervisor, classify

logging.getLogger("fart.supervisor").setLevel(logging.CRITICAL)
DOC = Path(__file__).resolve().parents[1] / "docs" / "SUPERVISOR.md"


def documented_table() -> dict:
    """The rows between the table markers of docs/SUPERVISOR.md: | state | event | next | actions |."""
    text = DOC.read_text()
    body = text.split("<!-- table:start -->")[1].split("<!-- table:end -->")[0]
    rows = {}
    for line in body.splitlines():
        cells = [cell.strip().strip("`") for cell in line.strip().strip("|").split("|")]
        if len(cells) < 4 or cells[0] in ("State", "") or set(cells[0]) <= {"-"}:
            continue
        actions = tuple(a.strip().strip("`") for a in cells[3].split(",") if a.strip(" `—"))
        rows[(cells[0], cells[1])] = (cells[2].replace(" or ", "|"), actions)
    return rows


class TableTests(unittest.TestCase):
    def test_the_document_and_the_code_hold_the_same_table(self):
        self.assertEqual(documented_table(), TABLE)

    def test_rows_use_known_states_events_and_actions(self):
        for (state, event), (target, actions) in TABLE.items():
            self.assertIn(state, STATES)
            self.assertIn(event, EVENTS)
            self.assertIn(target, STATES + (RETRY,))
            for action in actions:
                self.assertTrue(action in ("fail", "reset") or hasattr(Child, "_do_" + action), action)
        self.assertEqual({state for state, _ in TABLE}, set(STATES))
        self.assertEqual({event for _, event in TABLE}, set(EVENTS))

    def test_every_row_moves_the_machine_as_written(self):
        for (state, event), (target, actions) in TABLE.items():
            for limit in (None, 1):
                with self.subTest(state=state, event=event, limit=limit):
                    machine = Machine(Policy(limit=limit))
                    machine.state, machine.failures = state, limit or 0
                    done = machine.step(event)
                    if target == RETRY:
                        self.assertEqual(machine.state, "failed" if limit else "backoff")
                        self.assertEqual(done[-1], "gave_up" if limit else "schedule")
                    else:
                        self.assertEqual(machine.state, target)
                        self.assertEqual(done, tuple(a for a in actions if a not in ("fail", "reset")))

    def test_a_pair_without_a_row_changes_nothing(self):
        for state in STATES:
            for event in EVENTS:
                if (state, event) not in TABLE:
                    machine = Machine()
                    machine.state, machine.failures = state, 2
                    self.assertEqual(machine.step(event), ())
                    self.assertEqual((machine.state, machine.failures), (state, 2))

    def test_every_state_can_be_reached_and_stop_always_ends_stopped(self):
        reached, frontier = {"stopped"}, ["stopped"]
        while frontier:
            state = frontier.pop()
            for (source, _), (target, _) in TABLE.items():
                for name in target.split("|"):
                    if source == state and name not in reached:
                        reached.add(name)
                        frontier.append(name)
        self.assertEqual(reached, set(STATES))
        for state in STATES:
            machine = Machine()
            machine.state = state
            machine.step("stop")
            if machine.state == "stopping":
                machine.step("swept")
            self.assertEqual(machine.state, "stopped", state)

    def test_a_process_that_arrives_late_is_never_left_running(self):
        # A spawn or an adoption can land only while starting, or after a stop overtook it.
        for state in ("stopped", "stopping"):
            for event in ("spawned", "adopted"):
                self.assertEqual(TABLE[(state, event)], ("stopping", ("sweep",)))

    def test_nothing_is_started_while_a_tree_is_still_being_stopped(self):
        # crashed is left only by `swept` (or stop): the orphaned UI is gone before the next dms starts.
        self.assertEqual({event for state, event in TABLE if state == "crashed"}, {"swept", "stop"})
        launching = {key for key, (_, actions) in TABLE.items() if "launch" in actions}
        self.assertEqual({state for state, _ in launching}, {"stopped", "backoff", "failed"})

    def test_backoff_grows_holds_and_resets(self):
        machine = Machine(Policy(delays=(0.25, 1.0, 2.0), handover=3.0))
        waits = []
        for _ in range(5):
            machine.state = "up"
            machine.step("exited")
            machine.step("swept")
            waits.append(machine.delay())
        self.assertEqual(waits, [0.25, 1.0, 2.0, 2.0, 2.0])
        machine.state = "up"
        machine.step("stable")
        machine.step("exited", clean=True)
        self.assertEqual((machine.failures, machine.delay()), (1, 3.0))  # a clean exit waits out the handover

    def test_what_went_down(self):
        cases = [
            ((-9, True, True), {"what": "dms", "signal": "SIGKILL"}),       # dms killed: the UI is orphaned
            ((-1, True, True), {"what": "dms", "signal": "SIGHUP"}),
            ((2, True, True), {"what": "dms", "code": 2}),                  # dms died by itself, UI still there
            ((137, True, False), {"what": "resident", "signal": "SIGKILL"}),  # dms mirrors the dead UI
            ((143, True, False), {"what": "resident", "signal": "SIGTERM"}),
            ((1, True, False), {"what": "resident", "code": 1}),
            ((255, True, False), {"what": "resident", "code": 255}),        # not a signal: the UI lost its compositor
            ((1, False, False), {"what": "dms", "code": 1}),                # failed before any UI ran
            ((0, True, False), {"what": "stopped", "code": 0}),             # dms restart, dms kill
            ((0, True, True), {"what": "stopped", "code": 0}),              # …even if the UI is a moment behind
            ((None, True, False), {"what": "unknown"}),                     # an adopted dms: no exit status
            ((None, True, True), {"what": "dms"}),                          # …but its UI outlived it
        ]
        for args, expected in cases:
            self.assertEqual(classify(*args), expected, args)


class FakeProcess:
    def __init__(self, pid):
        self.pid = pid
        self.exit = asyncio.get_running_loop().create_future()

    async def wait(self):
        return await asyncio.shield(self.exit)

    def die(self, code):
        if not self.exit.done():
            self.exit.set_result(code)


class FakePorts:
    ready_attempts = 3

    def __init__(self):
        self.processes: list[FakeProcess] = []
        self.live: set[Ident] = set()
        self.foreign: Ident | None = None
        self.ready = True          # the probe finds a UI
        self.fail_spawn = False
        self.session = True
        self.swept: list[tuple] = []
        self.watched: dict = {}
        self.gate: asyncio.Event | None = None  # holds a spawn in flight

    def session_alive(self):
        return self.session

    def find_foreign(self):
        return self.foreign if self.foreign in self.live else None

    def others(self, root):
        return [self.foreign] if self.foreign in self.live and self.foreign != root else []

    async def spawn(self):
        if self.gate:
            await self.gate.wait()
        if self.fail_spawn:
            raise FileNotFoundError("dms")
        process = FakeProcess(1000 + 10 * len(self.processes))
        self.processes.append(process)
        self.live.add(Ident(process.pid, 1))
        return process

    async def sleep(self):
        await asyncio.sleep(0)

    def ident(self, pid):
        return Ident(pid, 1)

    def alive(self, ident):
        return ident in self.live

    def leads_session(self, ident):
        return True

    def socket(self, root):
        return f"dms-{root.pid}.sock"

    def probe(self, root):
        if not self.ready or root not in self.live:
            return None
        ui = Ident(root.pid + 1, 1)
        self.live.add(ui)
        return ui

    def watch(self, root, gone):
        self.watched[root] = gone
        return lambda: self.watched.pop(root, None)

    async def sweep(self, root, known, session):
        self.swept.append((root, frozenset(known), session))
        for ident in {root, *known}:
            self.live.discard(ident)
        for process in self.processes:
            if process.pid == root.pid:
                process.die(0)
        return []

    # What the world does to the child

    def kill_ui(self, process, code=137):
        self.live.discard(Ident(process.pid + 1, 1))
        self.live.discard(Ident(process.pid, 1))
        process.die(code)

    def kill_dms(self, process, code=-9):
        self.live.discard(Ident(process.pid, 1))  # the UI stays: an orphan
        process.die(code)

    def appear(self, pid=5000):
        self.foreign = Ident(pid, 7)
        self.live.add(self.foreign)
        return self.foreign


class ChildTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.clock, self.scheduler, _, _ = fakes()
        self.ports = FakePorts()
        self.events = []
        self.child = Child("dms", self.clock, self.scheduler, self.ports, on_event=self.events.append)

    async def settle(self):
        for _ in range(12):
            await asyncio.sleep(0)

    def names(self):
        return [event["event"] for event in self.events]

    async def up(self):
        self.child.start()
        await self.settle()
        self.assertEqual(self.child.state, "up")
        return self.ports.processes[-1]

    async def test_start_comes_up_and_reports_it(self):
        process = await self.up()
        snapshot = self.child.snapshot()
        self.assertEqual((snapshot["pid"], snapshot["owned"], snapshot["socket"]), (process.pid, True, f"dms-{process.pid}.sock"))
        self.assertEqual(self.names(), ["up"])
        self.assertIsNone(self.events[0]["downFor"])

    async def test_a_ui_crash_is_named_swept_and_restarted_after_the_first_delay(self):
        first = await self.up()
        self.ports.kill_ui(first)
        await self.settle()
        self.assertEqual(self.child.state, "backoff")
        down = self.events[1]
        self.assertEqual((down["event"], down["what"], down["signal"], down["wasUp"]), ("down", "resident", "SIGKILL", True))
        self.assertEqual(len(self.ports.swept), 1)
        self.assertEqual(self.events[2]["inSeconds"], 0.25)
        self.assertEqual(len(self.ports.processes), 1)  # not before the delay
        self.clock.advance(0.25)
        await self.settle()
        self.assertEqual(self.child.state, "up")
        self.assertEqual(len(self.ports.processes), 2)
        self.assertEqual(self.events[-1]["downFor"], 0.25)
        last = self.child.snapshot()["last"]
        self.assertEqual((last["what"], last["owned"]), ("resident", True))
        self.assertIn("upAt", last)

    async def test_a_dms_crash_leaves_an_orphan_ui_that_is_swept_before_the_restart(self):
        first = await self.up()
        orphan = Ident(first.pid + 1, 1)
        self.ports.kill_dms(first)
        await self.settle()
        self.assertEqual(self.events[1]["what"], "dms")
        self.assertEqual(self.ports.swept[0], (Ident(first.pid, 1), frozenset({orphan}), True))
        self.assertNotIn(orphan, self.ports.live)

    async def test_quick_crashes_back_off_and_a_stable_minute_resets(self):
        process = await self.up()
        waits = []
        for _ in range(4):
            self.ports.kill_ui(process)
            await self.settle()
            waits.append(self.events[-1]["inSeconds"])
            self.clock.advance(waits[-1])
            await self.settle()
            process = self.ports.processes[-1]
        self.assertEqual(waits, [0.25, 1.0, 2.0, 4.0])
        self.assertEqual(self.child.snapshot()["failures"], 4)
        self.clock.advance(60)
        await self.settle()
        self.assertEqual(self.child.snapshot()["failures"], 0)
        self.ports.kill_ui(process)
        await self.settle()
        self.assertEqual(self.events[-1]["inSeconds"], 0.25)

    async def test_dms_never_gives_up_but_a_limited_child_does(self):
        self.ports.fail_spawn = True
        self.child.start()
        for _ in range(12):
            await self.settle()
            self.clock.advance(30)
        await self.settle()
        self.assertEqual(self.child.state, "backoff")
        self.assertGreaterEqual(self.child.snapshot()["failures"], 10)
        limited = Child("panel", self.clock, self.scheduler, self.ports, Policy(limit=3), on_event=self.events.append)
        limited.start()
        for _ in range(4):
            await self.settle()
            self.clock.advance(30)
        self.assertEqual(limited.state, "failed")
        self.assertEqual([e["event"] for e in self.events if e["child"] == "panel"][-1], "failed")
        self.ports.fail_spawn = False
        limited.start()  # the owner asks again
        await self.settle()
        self.assertEqual(limited.state, "up")

    async def test_an_owner_restart_is_adopted_at_once_and_not_doubled(self):
        first = await self.up()
        self.ports.kill_ui(first, code=0)  # dms restart: the old one exits 0
        await self.settle()
        self.assertEqual((self.events[1]["what"], self.events[2]["inSeconds"]), ("stopped", 3.0))
        self.clock.advance(0.3)
        await self.settle()
        self.assertEqual(self.child.state, "backoff")  # nothing there yet: keep waiting
        new = self.ports.appear()  # the owner's new dms
        self.clock.advance(0.1)
        await self.settle()
        self.assertEqual(self.child.state, "up")
        self.assertEqual(len(self.ports.processes), 1)  # no second dms
        up = self.events[-1]
        self.assertEqual((up["event"], up["owned"], up["pid"], up["downFor"]), ("up", False, new.pid, 0.4))
        last = self.child.snapshot()["last"]
        self.assertEqual((last["what"], last["owned"]), ("stopped", False))  # restarted by the owner, not a crash
        self.assertNotIn("duplicate", self.names())
        self.clock.advance(10)  # the cancelled retry never spawns a second one
        await self.settle()
        self.assertEqual((self.child.state, len(self.ports.processes)), ("up", 1))

    async def test_a_dms_stopped_on_purpose_comes_back_after_the_handover_wait(self):
        first = await self.up()
        self.ports.kill_ui(first, code=0)
        await self.settle()
        self.clock.advance(2.9)
        await self.settle()
        self.assertEqual((self.child.state, len(self.ports.processes)), ("backoff", 1))
        self.clock.advance(0.1)
        await self.settle()
        self.assertEqual((self.child.state, len(self.ports.processes), self.child.snapshot()["owned"]), ("up", 2, True))

    async def test_a_dms_started_by_hand_during_a_long_wait_is_adopted(self):
        self.child = Child("dms", self.clock, self.scheduler, self.ports, Policy(delays=(8.0,)), on_event=self.events.append)
        first = await self.up()
        self.ports.kill_ui(first)
        await self.settle()
        self.assertEqual(self.events[-1]["inSeconds"], 8.0)
        self.clock.advance(4.0)  # past the handover time: the look slows to once a second
        await self.settle()
        self.ports.appear()
        self.clock.advance(0.5)
        await self.settle()
        self.assertEqual(self.child.state, "backoff")
        self.clock.advance(0.5)
        await self.settle()
        self.assertEqual((self.child.state, self.child.snapshot()["owned"], len(self.ports.processes)), ("up", False, 1))

    async def test_when_the_adopted_dms_is_killed_its_tree_is_swept_and_ours_starts(self):
        new = self.ports.appear()
        self.child.start()
        await self.settle()
        self.assertEqual((self.child.state, self.child.snapshot()["owned"], self.ports.processes), ("up", False, []))
        self.ports.live.discard(new)  # its UI (5001) stays behind
        self.ports.watched[new]()
        await self.settle()
        self.assertEqual(self.child.state, "backoff")
        self.assertEqual((self.events[-2]["what"], self.events[-1]["inSeconds"]), ("dms", 0.25))
        self.assertEqual(self.ports.swept[-1], (new, frozenset({Ident(new.pid + 1, 1)}), True))
        self.clock.advance(0.25)
        await self.settle()
        self.assertEqual((self.child.state, self.child.snapshot()["owned"]), ("up", True))

    async def test_when_the_adopted_dms_just_goes_the_next_one_gets_the_handover_wait(self):
        new = self.ports.appear()
        self.child.start()
        await self.settle()
        self.ports.live.discard(Ident(new.pid + 1, 1))
        self.ports.live.discard(new)
        self.ports.watched[new]()  # no exit status and no orphan: a restart or a UI crash, we cannot tell
        await self.settle()
        self.assertEqual((self.events[-2]["what"], self.events[-1]["inSeconds"]), ("unknown", 3.0))
        self.ports.appear(6000)  # restarted by the owner again
        self.clock.advance(0.1)
        await self.settle()
        self.assertEqual((self.child.state, self.child.snapshot()["pid"], self.ports.processes), ("up", 6000, []))

    async def test_a_dms_that_never_comes_ready_is_killed_and_retried(self):
        self.ports.ready = False
        self.child.start()
        await self.settle()
        self.assertEqual(self.child.state, "backoff")
        self.assertTrue(self.events[0]["hung"])
        self.assertFalse(self.events[0]["wasUp"])
        self.assertEqual(self.ports.swept[0][0], Ident(1000, 1))
        self.assertNotIn(Ident(1000, 1), self.ports.live)

    async def test_a_second_dms_next_to_ours_is_reported(self):
        process = await self.up()
        self.assertNotIn("duplicate", self.names())
        stray = self.ports.appear()
        self.clock.advance(60)  # the look when stable
        await self.settle()
        self.assertEqual((self.events[-1]["event"], self.events[-1]["pids"]), ("duplicate", [stray.pid]))
        self.assertEqual((self.child.state, self.child.snapshot()["pid"]), ("up", process.pid))  # reported, not touched
        self.assertIn(stray, self.ports.live)

    async def test_stop_from_any_state_leaves_nothing(self):
        async def crashed():
            process = await self.up()
            self.ports.kill_ui(process)  # not settled: still sweeping

        async def backoff():
            await crashed()
            await self.settle()

        async def adopted():
            self.ports.appear()
            self.child.start()
            await self.settle()

        async def starting():
            self.ports.gate = asyncio.Event()  # the spawn is in flight when stop arrives
            self.child.start()
            await self.settle()
            asyncio.get_running_loop().call_soon(self.ports.gate.set)

        for prepare in (self.up, crashed, backoff, adopted, starting):
            with self.subTest(state=prepare.__name__):
                await self.asyncSetUp()
                await prepare()
                await asyncio.wait_for(self.child.stop(), 1)
                self.assertEqual(self.child.state, "stopped")
                self.assertEqual(self.ports.live, set())
                self.assertEqual(self.ports.watched, {})
                self.assertEqual(self.names()[-1], "stopped")
                self.clock.advance(120)  # no timer brings it back
                await self.settle()
                self.assertEqual(self.child.state, "stopped")
                self.assertEqual(self.ports.live, set())
                self.assertEqual(self.scheduler.pending, {})

    async def test_nothing_starts_once_the_compositor_is_gone(self):
        self.ports.session = False
        self.child.start()
        await self.settle()
        self.assertEqual((self.child.state, self.ports.processes), ("backoff", []))

    async def test_the_supervisor_publishes_children_and_stops_them(self):
        changes = []
        supervisor = Supervisor()
        supervisor.add(self.child)
        supervisor.on_change = lambda: changes.append(supervisor.snapshot()["children"]["dms"]["state"])
        supervisor.on_event = self.events.append
        supervisor.start()
        await self.settle()
        await supervisor.stop()
        self.assertEqual([s for i, s in enumerate(changes) if i == 0 or s != changes[i - 1]], ["starting", "up", "stopping", "stopped"])
        self.assertEqual(self.names(), ["up", "stopped"])


if __name__ == "__main__":
    unittest.main()
