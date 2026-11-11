"""Supervision of the session's long-lived children (docs/SUPERVISOR.md).

Three layers, so each can be tested alone:
  Machine   the pure state machine: TABLE maps (state, event) to (next state, actions).
  Child     the driver: runs the actions through its ports, the scheduler and the clock.
  DmsPorts  the real world for `dms run`: spawn, find, probe, signal and sweep process trees.

The finished slice is the `dms` child. The panel keeps core/view.py until it is moved onto this
vocabulary (docs/SUPERVISOR.md §9).
"""
from __future__ import annotations

import asyncio
import logging
import os
from pathlib import Path
import signal
import time
from typing import Callable, NamedTuple

log = logging.getLogger("fart.supervisor")

STATES = ("stopped", "starting", "up", "crashed", "backoff", "stopping", "failed")
EVENTS = ("start", "stop", "spawned", "adopted", "spawn_failed", "ready", "start_timeout", "exited",
          "swept", "timer", "stable")
RETRY = "backoff|failed"  # decided by the policy's limit when the row fires

# (state, event) -> (next state, actions). The same table is printed in docs/SUPERVISOR.md §2 and
# tests/test_core_supervisor.py checks the two against each other. A pair without a row is ignored.
TABLE: dict[tuple[str, str], tuple[str, tuple[str, ...]]] = {
    ("stopped", "start"): ("starting", ("launch",)),
    ("stopped", "spawned"): ("stopping", ("sweep",)),
    ("stopped", "adopted"): ("stopping", ("sweep",)),
    ("starting", "spawned"): ("starting", ("probe",)),
    ("starting", "adopted"): ("starting", ("watch", "probe")),
    ("starting", "spawn_failed"): (RETRY, ("fail",)),
    ("starting", "ready"): ("up", ("arm_stable", "note_up")),
    ("starting", "start_timeout"): ("crashed", ("fail", "cancel", "note_down", "sweep")),
    ("starting", "exited"): ("crashed", ("fail", "cancel", "note_down", "sweep")),
    ("starting", "stop"): ("stopping", ("cancel", "sweep")),
    ("up", "exited"): ("crashed", ("fail", "cancel", "note_down", "sweep")),
    ("up", "stable"): ("up", ("reset",)),
    ("up", "stop"): ("stopping", ("cancel", "sweep")),
    ("crashed", "swept"): (RETRY, ()),
    ("crashed", "stop"): ("stopping", ("sweep",)),
    ("backoff", "timer"): ("starting", ("cancel", "launch")),
    ("backoff", "start"): ("starting", ("cancel", "launch")),
    ("backoff", "stop"): ("stopped", ("cancel", "note_stopped")),
    ("failed", "start"): ("starting", ("reset", "launch")),
    ("failed", "stop"): ("stopped", ("note_stopped",)),
    ("stopping", "swept"): ("stopped", ("note_stopped",)),
    ("stopping", "spawned"): ("stopping", ("sweep",)),
    ("stopping", "adopted"): ("stopping", ("sweep",)),
}


class Policy(NamedTuple):
    delays: tuple[float, ...] = (0.25, 1.0, 2.0, 4.0, 8.0, 16.0, 30.0)  # by consecutive failure; the last repeats
    stable: float = 60.0      # up this long: the failure count returns to zero
    handover: float = 3.0     # least wait after a clean exit: an owner restart brings its own dms (0.36 s measured)
    peek: float = 0.1         # while waiting, look this often for a dms someone else started…
    peek_slow: float = 1.0    # …and this often once the handover time has passed
    limit: int | None = None  # consecutive failures before giving up; None never gives up (dms: Z11, Z35)


class Machine:
    """Pure: no clock, no processes. step() returns the actions for the driver to run, in order."""

    def __init__(self, policy: Policy = Policy()):
        self.policy = policy
        self.state = "stopped"
        self.failures = 0
        self.clean = False  # the last failure was a clean exit: someone may be bringing a new dms

    def step(self, event: str, clean: bool = False) -> tuple[str, ...]:
        row = TABLE.get((self.state, event))
        if row is None:
            return ()
        target, actions = row
        if "fail" in actions:
            self.failures += 1
            self.clean = clean
        if "reset" in actions:
            self.failures = 0
        if target == RETRY:
            if self.policy.limit is not None and self.failures >= self.policy.limit:
                target, actions = "failed", actions + ("gave_up",)
            else:
                target, actions = "backoff", actions + ("schedule",)
        self.state = target
        return tuple(a for a in actions if a not in ("fail", "reset"))

    def delay(self) -> float:
        delays = self.policy.delays
        wait = delays[min(max(self.failures, 1), len(delays)) - 1]
        return max(wait, self.policy.handover) if self.clean else wait


def classify(code: int | None, ui_seen: bool, ui_alive: bool) -> dict:
    """What went down, from the one exit event DMS gives for both crashes (docs/F1_RECON.md).
    DMS mirrors a dead UI's status (137, 143); a DMS that dies first leaves its UI running.
    code is None for a dms that was not our child: there is no exit status to read."""
    if code is not None and code < 0:
        return {"what": "dms", "signal": _signal_name(-code)}
    if code == 0:
        return {"what": "stopped", "code": 0}  # on purpose: dms restart, dms kill, a TERM
    if ui_alive:
        return {"what": "dms"} if code is None else {"what": "dms", "code": code}
    if code is None:
        return {"what": "unknown"}
    if not ui_seen:
        return {"what": "dms", "code": code}
    if code > 128 and code - 128 in set(signal.Signals):
        return {"what": "resident", "signal": _signal_name(code - 128)}
    return {"what": "resident", "code": code}  # 255 when the UI lost its compositor


def _signal_name(number: int) -> str:
    try:
        return signal.Signals(number).name
    except ValueError:
        return f"signal {number}"


class Ident(NamedTuple):
    """A process named so that a reused pid is never mistaken for it."""
    pid: int
    start: int  # starttime from /proc/<pid>/stat


class Child:
    """Drives one supervised child. Every method runs on the event loop."""

    def __init__(self, name: str, clock, scheduler, ports, policy: Policy = Policy(),
                 on_change: Callable[[], None] = lambda: None, on_event: Callable[[dict], None] = lambda _: None):
        self.name, self.clock, self.scheduler, self.ports = name, clock, scheduler, ports
        self.machine = Machine(policy)
        self.on_change, self.on_event = on_change, on_event
        self.process = None             # ours, when we spawned it
        self.root: Ident | None = None  # the dms we supervise, ours or adopted
        self.ui: Ident | None = None
        self.owned = False
        self.session = False            # root leads its own session, so the session id names its tree
        self.cause: dict = {}
        self.last: dict | None = None   # the last outage, for a resident that starts after it (Z127)
        self.since: float | None = None    # boottime it came up
        self.down_at: float | None = None
        self.retry_at: float | None = None
        self.was_up = False
        self._backoff_from = 0.0
        self._stopped = asyncio.Event()
        self._stopped.set()
        self._launching: asyncio.Task | None = None
        self._probing: asyncio.Task | None = None
        self._unwatch: Callable[[], None] | None = None
        self._sweeps = 0
        self._sweep_lock = asyncio.Lock()
        self._tasks: set[asyncio.Task] = set()

    @property
    def state(self) -> str:
        return self.machine.state

    def _key(self, timer: str) -> str:
        return f"supervisor.{self.name}.{timer}"

    def snapshot(self) -> dict:
        now = self.clock.now()
        real = lambda boot: None if boot is None else round((now.real - (now.boot - boot)) * 1000)
        up = self.state == "up" and self.root is not None
        return {"state": self.state, "pid": self.root.pid if self.root else None, "owned": self.owned,
                "socket": self.ports.socket(self.root) if up else None, "since": real(self.since) if up else None,
                "failures": self.machine.failures, "retryAt": real(self.retry_at) if self.state == "backoff" else None,
                "last": self.last}

    def start(self):
        self._dispatch("start")

    async def stop(self):
        self._dispatch("stop")
        await self._stopped.wait()

    # The machine

    def _dispatch(self, event: str, clean: bool = False):
        before = self.state
        actions = self.machine.step(event, clean)
        if self.state != "stopped":
            self._stopped.clear()
        if before != self.state:
            log.info("%s: %s -> %s (%s)", self.name, before, self.state, event)
        for action in actions:
            getattr(self, "_do_" + action)()
        self.on_change()

    def _spawn_task(self, coroutine) -> asyncio.Task:
        task = asyncio.get_running_loop().create_task(coroutine)
        self._tasks.add(task)
        task.add_done_callback(self._tasks.discard)
        return task

    def _emit(self, event: str, **data):
        message = {"child": self.name, "event": event, "at": round(self.clock.now().real * 1000), **data}
        log.info("%s: %s", self.name, " ".join(f"{k}={v}" for k, v in message.items() if k not in ("child", "at")))
        self.on_event(message)

    # Actions

    def _do_launch(self):
        self.retry_at = None
        self._launching = self._spawn_task(self._launch())

    async def _launch(self):
        """Adopt a dms that already runs, else spawn ours. Never a second one: it would take dms.path
        and the keybinds (docs/F1_RECON.md)."""
        outcome = "spawn_failed"
        try:
            if not self.ports.session_alive():
                raise RuntimeError("the compositor is gone")
            foreign = self.ports.find_foreign()
            if foreign:
                session = self.ports.leads_session(foreign)
                self.process, self.root, self.ui, self.owned, self.session = None, foreign, None, False, session
                outcome = "adopted"
            else:
                process = await self.ports.spawn()
                self.process, self.root, self.ui = process, self.ports.ident(process.pid), None
                self.owned = self.session = True
                self._spawn_task(self._watch(process))
                outcome = "spawned"
        except Exception as error:
            log.warning("%s: cannot start: %s", self.name, error)
            if outcome == "spawn_failed":
                self.process = self.root = self.ui = None
        finally:
            self._launching = None
        self._dispatch(outcome)

    async def _watch(self, process):
        code = await process.wait()
        if process is self.process:
            self._exited(self.root, code)

    def _exited(self, root: Ident | None, code: int | None):
        if root != self.root or self.state not in ("starting", "up"):
            return
        self.cause = classify(code, self.ui is not None, bool(self.ui and self.ports.alive(self.ui)))
        self._dispatch("exited", clean=self.cause["what"] in ("stopped", "unknown"))

    def _do_watch(self):
        root = self.root
        assert root
        self._unwatch = self.ports.watch(root, lambda: self._exited(root, None))

    def _do_probe(self):
        assert self.root
        self._probing = self._spawn_task(self._probe(self.root))

    async def _probe(self, root: Ident):
        for _ in range(self.ports.ready_attempts):
            ui = self.ports.probe(root)
            if root != self.root or self.state != "starting":
                return
            if ui:
                self.ui = ui
                self._dispatch("ready")
                return self._look()
            await self.ports.sleep()
        self.cause = {"what": "dms", "hung": True}
        self._dispatch("start_timeout")

    def _look(self):
        """Another dms next to ours is only reported (docs/OPEN.md 18): at ready and once more when stable."""
        if self.state != "up" or not self.root:
            return
        others = self.ports.others(self.root)
        if others:
            self._emit("duplicate", pids=[ident.pid for ident in others])

    def _do_arm_stable(self):
        self.scheduler.at(self._key("stable"), self.clock.now().boot + self.machine.policy.stable, lambda _: self._stable())

    def _stable(self):
        self._dispatch("stable")
        self._look()

    def _do_cancel(self):
        for timer in ("stable", "retry", "peek"):
            self.scheduler.cancel(self._key(timer))
        self.retry_at = None
        if self._probing and self._probing is not asyncio.current_task():
            self._probing.cancel()
        self._probing = None
        if self._unwatch:
            self._unwatch()
            self._unwatch = None

    def _do_schedule(self):
        wait = self.machine.delay()
        self._backoff_from = self.clock.now().boot
        self.retry_at = self._backoff_from + wait
        self.scheduler.at(self._key("retry"), self.retry_at, lambda _: self._dispatch("timer"))
        self._arm_peek()
        self._emit("retry", inSeconds=wait, failures=self.machine.failures)

    def _arm_peek(self):
        policy, now = self.machine.policy, self.clock.now().boot
        step = policy.peek if now - self._backoff_from < policy.handover else policy.peek_slow
        if self.retry_at is not None and now + step < self.retry_at:
            self.scheduler.at(self._key("peek"), now + step, lambda _: self._peek())

    def _peek(self):
        """The wait ends at once when a dms someone else started shows up (an owner restart: 0.36 s)."""
        if self.state != "backoff":
            return
        if self.ports.find_foreign():
            return self._dispatch("timer")
        self._arm_peek()

    def _do_sweep(self):
        self._sweeps += 1
        self._spawn_task(self._sweep())

    async def _sweep(self):
        """Stop the root if it still runs, then everything left of its tree. One at a time; `swept` once all ran."""
        try:
            async with self._sweep_lock:
                if self._launching:
                    await asyncio.wait([self._launching])  # a spawn in flight must land before it can be stopped
                root = self.root
                if root:
                    left = await self.ports.sweep(root, {self.ui} if self.ui else set(), self.session)
                    if left:
                        log.error("%s: could not stop pids %s", self.name, ", ".join(str(i.pid) for i in left))
                    if root == self.root:
                        self.process = self.root = self.ui = None
        except Exception:
            log.exception("%s: sweep failed", self.name)
        finally:
            self._sweeps -= 1
        if not self._sweeps:
            self._dispatch("swept")

    def _do_note_up(self):
        now = self.clock.now().boot
        down_for = None if self.down_at is None else round(now - self.down_at, 2)
        self.since, self.down_at, self.was_up = now, None, True
        if self.last and "upAt" not in self.last:
            self.last = dict(self.last, upAt=round(self.clock.now().real * 1000), owned=self.owned)
        self._emit("up", pid=self.root.pid if self.root else None, owned=self.owned, downFor=down_for)

    def _do_note_down(self):
        if self.down_at is None:
            self.down_at = self.clock.now().boot
        cause = dict(self.cause, wasUp=self.was_up, failures=self.machine.failures)
        if self.was_up:
            self.last = dict(cause, downAt=round(self.clock.now().real * 1000))
        self.was_up = False
        self._emit("down", **cause)

    def _do_gave_up(self):
        self._emit("failed", failures=self.machine.failures)

    def _do_note_stopped(self):
        self.was_up, self.down_at = False, None
        self._stopped.set()
        self._emit("stopped")


class Supervisor:
    """The children by name; the `supervisor` topic. Stopped in reverse order of starting."""

    def __init__(self):
        self.children: dict[str, Child] = {}
        self.on_change: Callable[[], None] = lambda: None
        self.on_event: Callable[[dict], None] = lambda _: None

    def add(self, child: Child) -> Child:
        child.on_change = lambda: self.on_change()
        child.on_event = lambda event: self.on_event(event)
        self.children[child.name] = child
        return child

    def snapshot(self) -> dict:
        return {"children": {name: child.snapshot() for name, child in self.children.items()}}

    def start(self):
        for child in self.children.values():
            child.start()

    async def stop(self):
        for child in reversed(list(self.children.values())):
            await child.stop()


# The real world

TERM_WAIT = 3.0   # dms exits 0.57 s after TERM, taking its UI with it (docs/F1_RECON.md)
SWEEP_WAIT = 2.0  # what is left gets TERM and this long
KILL_WAIT = 1.0   # then KILL
READY_TIMEOUT = 10.0
PROBE_STEP = 0.05
UI_NAMES = ("qs", "quickshell")


class Stat(NamedTuple):
    comm: str
    state: str
    ppid: int
    sid: int
    start: int


def read_stat(pid: int) -> Stat | None:
    try:
        text = Path(f"/proc/{pid}/stat").read_text()
        fields = text.rsplit(")", 1)[1].split()
        return Stat(text[text.index("(") + 1:text.rindex(")")], fields[0], int(fields[1]), int(fields[3]), int(fields[19]))
    except (OSError, ValueError, IndexError):
        return None


def process_table() -> dict[int, Stat]:
    table = {}
    for entry in os.scandir("/proc"):
        if entry.name.isdigit():
            stat = read_stat(int(entry.name))
            if stat:
                table[int(entry.name)] = stat
    return table


def family(roots: set[Ident], sid: int | None) -> dict[Ident, str]:
    """The live processes under any of roots, and every member of session sid (an orphan keeps its
    session), with their names. Apps the owner starts from the shell are in neither set:
    Quickshell.execDetached gives them a session of their own and parent 1 (docs/SUPERVISOR.md §6)."""
    table = process_table()
    children: dict[int, list[int]] = {}
    for pid, stat in table.items():
        children.setdefault(stat.ppid, []).append(pid)
    found: set[int] = set()
    stack = [root.pid for root in roots if root.pid in table and table[root.pid].start == root.start]
    if sid:
        stack += [pid for pid, stat in table.items() if stat.sid == sid]
    while stack:
        pid = stack.pop()
        if pid in found or pid <= 1 or pid == os.getpid():
            continue
        found.add(pid)
        stack += children.get(pid, [])
    return {Ident(pid, table[pid].start): table[pid].comm for pid in found if table[pid].state != "Z"}


class DmsPorts:
    """`dms run` as the supervisor sees it. The UI directory and the log travel in the environment
    (DMS_SHELL_DIR, DMS_LOG_FILE), not as flags: an owner restart starts a new dms that inherits the
    environment but not the flags (docs/SUPERVISOR.md §5)."""

    ready_attempts = round(READY_TIMEOUT / PROBE_STEP)

    def __init__(self, env: dict, runtime: Path, log_file: Path, ui_dir: Path | None = None,
                 session_alive: Callable[[], bool] = lambda: True):
        self.env = dict(env, DMS_LOG_FILE=str(log_file))
        if ui_dir:
            self.env["DMS_SHELL_DIR"] = str(ui_dir)
        self.runtime = runtime  # $XDG_RUNTIME_DIR: where DMS keeps dms-<pid>.{pid,sock,…} and dms.path
        self.session_alive = session_alive

    async def spawn(self):
        return await asyncio.create_subprocess_exec(
            "dms", "run", env=self.env, cwd="/", start_new_session=True, stdin=asyncio.subprocess.DEVNULL,
            stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)

    async def sleep(self):
        await asyncio.sleep(PROBE_STEP)

    def ident(self, pid: int) -> Ident:
        stat = read_stat(pid)
        return Ident(pid, stat.start if stat else 0)

    def alive(self, ident: Ident) -> bool:
        stat = read_stat(ident.pid)
        return bool(stat and stat.start == ident.start and stat.state != "Z")

    def leads_session(self, ident: Ident) -> bool:
        stat = read_stat(ident.pid)
        return bool(stat and stat.sid == ident.pid)

    def socket(self, root: Ident) -> str:
        return str(self.runtime / f"dms-{root.pid}.sock")

    def running(self) -> list[Ident]:
        """The dms shells of this runtime folder, oldest first, by their pid files. Stale files are
        common, so the process is checked; one-shot commands (`dms cl copy`) write no pid file."""
        found = []
        for path in self.runtime.glob("dms-*.pid"):
            try:
                pid = int(path.name[4:-4])
                stat = read_stat(pid)
                if stat and stat.comm == "dms" and stat.state != "Z" and os.stat(f"/proc/{pid}").st_uid == os.getuid():
                    found.append(Ident(pid, stat.start))
            except (OSError, ValueError):
                continue
        return sorted(found, key=lambda ident: ident.start)

    def find_foreign(self) -> Ident | None:
        """Asked only while we have no dms of our own: the newest one running, if any."""
        running = self.running()
        return running[-1] if running else None

    def others(self, root: Ident) -> list[Ident]:
        return [ident for ident in self.running() if ident != root]

    def probe(self, root: Ident) -> Ident | None:
        """Up means the backend socket exists and the UI runs. The UI is forked from a side thread,
        so it is found by parent pid, not through /proc/<pid>/task/<pid>/children."""
        if not Path(self.socket(root)).exists():
            return None
        for pid, stat in process_table().items():
            if stat.ppid == root.pid and stat.comm in UI_NAMES and stat.state != "Z":
                return Ident(pid, stat.start)
        return None

    def watch(self, root: Ident, gone: Callable[[], None]) -> Callable[[], None]:
        """Tell when a process that is not our child exits: its pidfd turns readable."""
        loop = asyncio.get_running_loop()
        try:
            fd = os.pidfd_open(root.pid)
        except OSError:
            return loop.call_soon(gone).cancel
        if not self.alive(root):  # gone, or the pid was reused, between finding it and opening it
            os.close(fd)
            return loop.call_soon(gone).cancel
        closed = False

        def close():
            nonlocal closed
            if not closed:
                closed = True
                loop.remove_reader(fd)
                os.close(fd)

        def readable():
            close()
            gone()

        loop.add_reader(fd, readable)
        return close

    def _signal(self, ident: Ident, signum: int):
        if not self.alive(ident):
            return
        try:
            os.kill(ident.pid, signum)
        except ProcessLookupError:
            pass
        except PermissionError:  # a helper that became root (pkexec): it ends with its parent, or is reported
            log.info("pid %d is not ours to signal", ident.pid)

    async def _gone(self, idents, timeout: float):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline and any(self.alive(ident) for ident in idents):
            await asyncio.sleep(PROBE_STEP)

    async def sweep(self, root: Ident, known: set[Ident], session: bool) -> list[Ident]:
        """TERM the root and give it time: that is the only clean way down, and it takes the UI along.
        Then whatever is left of the tree gets TERM, then KILL. Returns what survived."""
        sid = root.pid if session else None
        if self.alive(root):
            self._signal(root, signal.SIGTERM)
            await self._gone({root}, TERM_WAIT)
        for signum, wait in ((signal.SIGTERM, SWEEP_WAIT), (signal.SIGKILL, KILL_WAIT)):
            left = family(known | {root}, sid)
            if not left:
                return []
            log.info("sweeping with %s: %s", signal.Signals(signum).name,
                     ", ".join(f"{name} {ident.pid}" for ident, name in sorted(left.items())))
            for ident in left:
                self._signal(ident, signum)
            await self._gone(left, wait)
        return sorted(family(known | {root}, sid))


class SessionWatch:
    """Knows when the compositor is gone: Hyprland's event socket closes and cannot be opened again.
    Nothing is polled."""

    RECHECK = 0.2

    def __init__(self, directory: Path, on_gone: Callable[[], None]):
        # Resolved: a socket address holds 107 bytes, and a symlinked runtime folder (tests) can exceed that.
        self.path = Path(os.path.realpath(directory)) / ".socket2.sock"
        self.on_gone = on_gone
        self.gone = False
        self.closed = False  # the connection ended and has not been reopened yet
        self.task: asyncio.Task | None = None

    def alive(self) -> bool:
        return not (self.gone or self.closed)

    def start(self):
        self.task = asyncio.get_running_loop().create_task(self._run())

    async def _run(self):
        connected = False
        while True:
            try:
                reader, writer = await asyncio.open_unix_connection(str(self.path))
            except OSError as error:
                if not connected:
                    log.warning("no session watch (%s): the session ends only by signal or shutdown", error)
                    return
                break  # it was there and now refuses: the compositor is gone
            connected, self.closed = True, False
            try:
                while await reader.read(65536):
                    pass
            except OSError:
                pass
            finally:
                writer.close()
            self.closed = True  # nothing is started meanwhile
            await asyncio.sleep(self.RECHECK)  # a closed connection alone is not proof; try once more
        self.gone = True
        log.info("the compositor is gone: ending the session")
        self.on_gone()

    def stop(self):
        if self.task:
            self.task.cancel()
