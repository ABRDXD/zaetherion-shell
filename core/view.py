"""The disposable view: spawned on demand, reaped when closed and idle or under memory pressure (docs/CORE.md §7)."""
from __future__ import annotations

import asyncio
import json
import logging
import os
from pathlib import Path
import select
import time
from typing import Callable

from core.errors import OpError

log = logging.getLogger("fart.view")
PAGES = ("home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex")
READY_TIMEOUT = 12.0
# Most opens find the view warm (docs/COLDSTART.md, approved 7 Nov 2026); PSI pressure still reaps sooner.
REAP_AFTER = 3600.0
SETTLE = 5.0  # closed at least this long before any reap: close animation and preference writes finish
GRACE = 3.0
CRASH_WINDOW = 5.0
CRASH_LIMIT = 3
PSI_TRIGGER = b"some 150000 2000000\0"  # 150 ms stalled within 2 s; unprivileged windows are multiples of 2 s


def descends(pid: int, ancestor: int) -> bool:
    for _ in range(8):
        if pid == ancestor:
            return True
        try:
            pid = int(Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            return False
        if pid <= 1:
            return False
    return False


class PressureTrigger:
    """A PSI memory trigger on /proc/pressure/memory, delivered through epoll to the loop without polling."""

    def __init__(self, loop, callback: Callable[[], None]):
        self.loop = loop
        self.fd = os.open("/proc/pressure/memory", os.O_RDWR | os.O_NONBLOCK | os.O_CLOEXEC)
        try:
            os.write(self.fd, PSI_TRIGGER)
            self.epoll = select.epoll()
            self.epoll.register(self.fd, select.EPOLLPRI)
        except OSError:
            os.close(self.fd)
            raise
        self.callback = callback
        loop.add_reader(self.epoll.fileno(), self._ready)

    def _ready(self):
        events = self.epoll.poll(0)
        if any(mask & (select.EPOLLERR | select.EPOLLHUP) for _, mask in events):
            log.warning("PSI trigger closed by the kernel")
            return self.close()
        if events:
            self.callback()

    def close(self):
        if self.fd < 0:
            return
        self.loop.remove_reader(self.epoll.fileno())
        self.epoll.close()
        os.close(self.fd)
        self.fd = -1


async def spawn_quickshell(entry: Path, env: dict):
    # The view keeps its own Quickshell log; FART_VIEW_STDOUT (tests) also captures its console.
    out = asyncio.subprocess.DEVNULL
    if env.get("FART_VIEW_STDOUT"):
        out = open(env["FART_VIEW_STDOUT"], "ab")
    try:
        return await asyncio.create_subprocess_exec(
            "qs", "-n", "--no-color", "-p", str(entry), env=env, start_new_session=True,
            stdin=asyncio.subprocess.DEVNULL, stdout=out, stderr=asyncio.subprocess.STDOUT)
    finally:
        if out is not asyncio.subprocess.DEVNULL:
            out.close()


def stop_foreign_instance(entry: Path, own_pid: int | None):
    """A view started by the M0/M1 launcher (qs -d) would block `qs -n`; stop only fart-next's own path."""
    try:
        import subprocess
        listed = subprocess.run(["qs", "list", "-a", "-j"], capture_output=True, text=True, timeout=4, check=True)
        instances = json.loads(listed.stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        return
    for item in instances:
        if item.get("config_path") == str(entry) and item.get("pid") != own_pid:
            log.info("stopping a view instance the core did not spawn (pid %s)", item.get("pid"))
            subprocess.run(["qs", "-p", str(entry), "kill"], capture_output=True, timeout=5, check=False)


class ViewManager:
    def __init__(self, clock, scheduler, spawn: Callable, on_change: Callable[[], None],
                 pressure: Callable | None = None, may_reap: Callable[[], bool] = lambda: True,
                 before_spawn: Callable[[], None] = lambda: None):
        self.clock = clock
        self.scheduler = scheduler
        self.spawn = spawn  # async () -> process with .pid, .wait(), .terminate(), .kill()
        self.on_change = on_change
        self.pressure_factory = pressure
        self.may_reap = may_reap
        self.before_spawn = before_spawn
        self.on_closed: list[Callable[[], None]] = []  # panel closed or view gone
        self.process = None
        self.client = None
        self.state = "absent"
        self.open = False
        self.page = ""
        self.cmdline_idle = False  # the panel's command line has focus and no text (Q7: Super+` folds)
        self.closed_since: float | None = None  # boottime
        self.spawning: asyncio.Task | None = None
        self.ready: asyncio.Future | None = None
        self.queued: dict | None = None
        self.spawned_at = 0.0
        self.crashes = 0
        self.reaping = False
        self.trigger = None
        self.checked_foreign = False
        self.foreign_check: asyncio.Future | None = None

    def snapshot(self) -> dict:
        closed = None
        if self.closed_since is not None:
            now = self.clock.now()
            closed = round((now.real - (now.boot - self.closed_since)) * 1000)
        return {"state": self.state, "pid": self.process.pid if self.process else None, "open": self.open,
                "page": self.page, "closedSince": closed}

    def _set(self, **changes):
        for key, value in changes.items():
            setattr(self, key, value)
        self.on_change()

    def start_checks(self):
        """Run the one-off foreign-instance check now, in a thread, so the first open does not wait for it.
        It takes 60–130 ms (`qs list`); the first spawn awaits it only if it is still running."""
        if not self.checked_foreign and self.foreign_check is None:
            self.foreign_check = asyncio.get_running_loop().run_in_executor(None, self.before_spawn)

    # Commands

    async def command(self, action: str, page: str | None = None, from_=None, query: str | None = None,
                      screen: str | None = None, focus: str | None = None, fly: str | None = None):
        if page is not None and page not in PAGES:
            raise OpError("bad-args", f"page must be one of {', '.join(PAGES)}")
        if from_ is not None and not (isinstance(from_, dict) and all(isinstance(from_.get(k), (int, float)) for k in ("x", "y", "width", "height"))):
            raise OpError("bad-args", "from must be {x, y, width, height}")
        if query is not None and not (isinstance(query, str) and len(query) <= 200):
            raise OpError("bad-args", "query must be a string of at most 200 characters")
        if screen is not None and not (isinstance(screen, str) and len(screen) <= 64 and screen.isprintable()):
            raise OpError("bad-args", "screen must be an output name of at most 64 printable characters")
        if focus not in (None, "cmdline"):
            raise OpError("bad-args", "focus must be cmdline")
        if fly is not None and not (isinstance(fly, str) and len(fly) <= 64 and fly.isprintable()):
            raise OpError("bad-args", "fly must be a moon's name of at most 64 printable characters")
        command = {"action": action, "page": page, "from": from_}
        if query is not None:
            command["query"] = query  # the room's filter (clip <words>); M5's view half reads it
        if screen:
            command["screen"] = screen  # the hook's output; the panel opens there (DAILY_DRIVER §2)
        if focus:
            command["focus"] = focus
        if fly is not None:
            command["fly"] = fly  # go <moon>: the view opens the orbit and keys that moon ("" the orbit alone)
        if self.client and not self.client.closed:
            self._send(command)
        elif action != "close" or self.state != "absent" or self.queued is not None:
            # Record intent before yielding. Hello delivers only the latest command.
            self.queued = command
            if action != "close" or self.state == "ready":
                try:
                    await self._ensure()
                except Exception:
                    if self.queued is command:
                        self.queued = None
                    raise
        return self.snapshot()

    async def ensure(self):
        """A connected view, spawned closed if absent: host calls need the adapter, not the panel."""
        if self.client and not self.client.closed:
            return
        await self._ensure()

    def _send(self, command: dict):
        if self.client and not self.client.closed:
            self.client.send({"event": "view.command", "rev": 0, "data": command})
        else:
            self.queued = command

    async def _ensure(self):
        if self.client and self.client.closed:
            self.disconnected(self.client)
        if self.state == "absent":
            if self.crashes >= CRASH_LIMIT:
                raise OpError("unavailable", "the view crashed at start 3 times; run fart-next restart after checking its log")
            self.ready = asyncio.get_running_loop().create_future()
            self._set(state="starting", open=False, page="", closed_since=None)
            self.spawning = asyncio.create_task(self._spawn())
        ready = self.ready
        try:
            await asyncio.wait_for(asyncio.shield(ready), READY_TIMEOUT)
        except asyncio.TimeoutError:
            log.error("the view did not say hello within %.0f s", READY_TIMEOUT)
            if ready is self.ready and not ready.done():
                await self.reap("start timeout", force=True)
            raise OpError("unavailable", "the view did not start; inspect qs log -p <repo>/shell.qml") from None

    async def _spawn(self):
        try:
            if not self.checked_foreign:
                self.start_checks()
                try:
                    await asyncio.shield(self.foreign_check)
                except Exception:
                    self.foreign_check = None  # retried on the next spawn
                    raise
                self.checked_foreign = True
            self.process = await self.spawn()
        except Exception as error:
            self.queued = None
            self.ready.set_exception(OpError("unavailable", f"cannot start the view: {error}"))
            self.ready.exception()
            self._set(state="absent")
            return
        finally:
            self.spawning = None
        self.spawned_at = time.monotonic()
        asyncio.get_running_loop().create_task(self._watch(self.process))
        log.info("view spawned (pid %d)", self.process.pid)

    async def _watch(self, process):
        code = await process.wait()
        if process is not self.process:
            return
        quick = time.monotonic() - self.spawned_at < CRASH_WINDOW
        self.crashes = self.crashes + 1 if quick and not self.reaping else 0
        log.info("view exited (code %s)%s", code, ", reaped" if self.reaping else "")
        self.process, self.client, self.reaping, self.queued = None, None, False, None
        self.cmdline_idle = False
        if self.ready and not self.ready.done():
            self.ready.set_exception(OpError("unavailable", "the view exited during start"))
            self.ready.exception()  # mark retrieved
        self._close_trigger()
        self.scheduler.cancel("view.reap")
        self._set(state="absent", open=False, page="", closed_since=None)
        for callback in self.on_closed:
            callback()

    # From the view

    def hello(self, client) -> bool:
        if not self.process or not descends(client.pid, self.process.pid):
            return False
        self.client = client
        if self.state != "ready":
            self._open_trigger()
            self._set(state="ready")
        if self.ready and not self.ready.done():
            self.ready.set_result(True)
        if self.queued:
            command, self.queued = self.queued, None
            self._send(command)
        return True

    def disconnected(self, client):
        if client is self.client:
            self.client = None
            self.ready = asyncio.get_running_loop().create_future()

    def report(self, open: bool, page: str, cmdline_idle: bool = False):
        if not isinstance(open, bool) or not isinstance(page, str) or not isinstance(cmdline_idle, bool):
            raise OpError("bad-args", "open and cmdlineIdle must be booleans and page a string")
        was_open = self.open
        self.cmdline_idle = open and cmdline_idle
        if open:
            self.scheduler.cancel("view.reap")
            self._set(open=True, page=page, closed_since=None)
        else:
            now = self.clock.now()
            since = self.closed_since if self.closed_since is not None and not was_open else now.boot
            self._set(open=False, page=page, closed_since=since)
            self.scheduler.at("view.reap", since + REAP_AFTER, lambda _: self.check_idle_reap())
            if was_open:
                for callback in self.on_closed:
                    callback()

    # Reaping

    def _closed_for(self) -> float | None:
        if self.state != "ready" or self.open or self.closed_since is None:
            return None
        return self.clock.now().boot - self.closed_since

    def check_idle_reap(self):
        """Called at the closed-idle deadline and when a blocking lease ends."""
        closed = self._closed_for()
        if closed is not None and closed >= REAP_AFTER and self.may_reap():
            asyncio.get_running_loop().create_task(self.reap(f"closed for {REAP_AFTER / 60:.0f} min"))

    def pressure(self):
        closed = self._closed_for()
        if closed is None or not self.may_reap():
            return
        if closed < SETTLE:
            self.scheduler.at("view.reap", self.closed_since + SETTLE, lambda _: self.pressure())
            return
        asyncio.get_running_loop().create_task(self.reap("memory pressure"))

    async def reap(self, reason: str, force: bool = False):
        if force and self.spawning:
            await asyncio.shield(self.spawning)
        process = self.process
        if not process or self.reaping:
            return
        if not force and (self._closed_for() is None or not self.may_reap()):
            return
        log.info("reaping the view: %s", reason)
        self.reaping = True
        try:
            process.terminate()
        except ProcessLookupError:
            return
        try:
            await asyncio.wait_for(asyncio.shield(asyncio.ensure_future(process.wait())), GRACE)
        except asyncio.TimeoutError:
            try:
                process.kill()
            except ProcessLookupError:
                pass

    def reset_crashes(self):
        self.crashes = 0

    def _open_trigger(self):
        if self.pressure_factory and not self.trigger:
            try:
                self.trigger = self.pressure_factory(self.pressure)
            except OSError as error:
                log.warning("no PSI trigger: %s", error.strerror)

    def _close_trigger(self):
        if self.trigger:
            self.trigger.close()
            self.trigger = None
