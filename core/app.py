"""Wires the core's subsystems to the protocol: topics and the operation table of docs/CORE.md §2.4."""
from __future__ import annotations

import asyncio
from functools import partial
import logging
import os
from pathlib import Path

from core.command import Commands
from core.exhibit import Exhibit
from core.discovery import Discovery
from core.errors import OpError
from core.genealogy import Genealogy
from core.guards import BatteryGuard, FullscreenGuard, Guards, SessionGuard, focused_fullscreen
from core.hostcalls import HostCalls
from core.ignite import LOST, Ignite
from core.notifications import Mirror
from core.journey import Journey
from core.weather import Weather
from core.telemetry import Telemetry
from core.buses import Buses
from core.orrery import Orrery
from core.quiet import Quiet
from core.overdrive import Overdrive
from core.protocol import PROTOCOL, Server
from core.sessions import Sessions
from core.skywatch import SkyWatch
from core.sfx import Sfx
from core.tasks import Tasks
from core.timers import Timers
from core.track import Track
from core.view import ViewManager

log = logging.getLogger("fart.core")
VERSION = "0.2.0"
SKY_START_DELAY = 3.0  # seconds after start-up before the sky watch computes its first events


def rss_kib() -> int:
    try:
        for line in Path("/proc/self/status").read_text().splitlines():
            if line.startswith("VmRSS:"):
                return int(line.split()[1])
    except OSError:
        pass
    return 0


class Core:
    def __init__(self, clock, scheduler, host, state_dir: Path, spawn, pressure=None, guard_types=None, before_spawn=lambda: None):
        self.clock = clock
        self.host = host
        self.started = clock.now()
        self.stopping = asyncio.Event()
        self.supervisor = None  # core/supervisor.py, attached by fartd when it supervises dms
        self.server = server = Server()
        state_dir.mkdir(parents=True, exist_ok=True, mode=0o700)

        self.genealogy = Genealogy()
        self.genealogy.on_change = partial(server.publish, "genealogy")
        server.topic("genealogy", self.genealogy.snapshot)
        self.genealogy.start()
        self.timers = Timers(clock, scheduler, host, state_dir)
        self.tasks = Tasks(clock, state_dir)
        self.sessions = Sessions(clock, scheduler, host, state_dir)
        self.sessions.tasks_done = self.tasks.done_between
        self.sessions.music = self._session_music
        self.discovery = Discovery(state_dir, clock)
        self.sky = SkyWatch(clock, scheduler, getattr(host.profile, "location", lambda: None), self.discovery)
        self.mirror = Mirror(clock, scheduler, host.run, state_dir)
        self.view = ViewManager(clock, scheduler, spawn, lambda: server.publish("view"), pressure,
                                may_reap=lambda: self.overdrive.state.mode == "off", before_spawn=before_spawn)
        types = guard_types or [FullscreenGuard, BatteryGuard, SessionGuard]
        types = [partial(SessionGuard, active=self.sessions.active) if t is SessionGuard else t for t in types]
        self.guards = Guards(lambda name, on: self.overdrive.guard(name, on), types)
        self.overdrive = Overdrive(clock, scheduler, self.guards, state_dir, view_open=lambda: self.view.open)
        self.view.on_closed.append(self.overdrive.panel_closed)
        self.hostcalls = HostCalls(self.view)
        server.on_disconnect.append(self.hostcalls.disconnected)
        self.overdrive.on_release = self.view.check_idle_reap
        session_guard = self.guards.by_name.get("session")
        if session_guard:
            self.sessions.on_guard = session_guard.changed

        for name, owner in (("timers", self.timers), ("tasks", self.tasks), ("notifications", self.mirror),
                            ("overdrive", self.overdrive), ("session", self.sessions), ("view", self.view)):
            server.topic(name, owner.snapshot)
            if name != "view":
                owner.on_change = partial(server.publish, name)
        server.topic("core", self.core_snapshot)
        server.on_disconnect.append(self.view.disconnected)
        self.sfx = host.sfx = Sfx(host, clock, state_dir, sound_on=lambda: self.timers.state["config"]["sound"],
                                  session_active=self.sessions.active)
        self.sfx.on_change = partial(server.publish, "sfx")
        self.sfx.on_cue = self.push_cue
        server.topic("sfx", self.sfx.snapshot)
        # Overdrive's own two sounds (docs/OVERDRIVE.md §2): the ignition when a lease starts, the spin-down when
        # it ends, by any route (the hold, a verb, the CLI, a timeout, the panel closing). A guard suspending
        # or resuming a lease that stays requested is silent.
        # The rooms you visit and in what order, for the orbit's laws (docs/OVERDRIVE_IDEAS.md).
        self.journey = Journey(clock, scheduler, state_dir)
        self.journey.on_change = partial(server.publish, "journey")
        server.topic("journey", self.journey.snapshot)
        self.view.on_closed.append(self.journey.closed)
        # Discovery (M15, core/discovery.py): what its triggers read, and the archive's fragments as a topic.
        d = self.discovery
        d.streak = lambda: self.sessions.snapshot()["streak"]["current"]
        d.visits = lambda: dict(self.journey.state["visits"])
        d.track_at = lambda: (self.track.current or {}).get("at")
        d.on_change = partial(server.publish, "discovery")
        server.topic("discovery", d.snapshot)
        publish_session = self.sessions.on_change
        self.sessions.on_change = lambda: (publish_session(), d.check())
        # The machine, heard only when something is out of the ordinary (docs/OVERDRIVE_IDEAS.md #48).
        self.quiet = Quiet(clock, scheduler, active=lambda: self.overdrive.state.effective == "active" and self.view.open,
                           emit=self.sfx.emit)
        self.view.on_closed.append(self.quiet.sync)
        self._overdrive_off = self.overdrive.state.mode == "off"
        self._publish_overdrive = self.overdrive.on_change
        self.overdrive.on_change = self._overdrive_changed
        self._publish_timers, self._sound = self.timers.on_change, self.timers.state["config"]["sound"]
        self._done = self._done_marks()
        self.track = Track(clock)
        self.track.on_change = partial(server.publish, "track")
        self.track.on_track = self._track_changed
        server.topic("track", self.track.snapshot)
        self.fullscreen_focused = focused_fullscreen  # read only when a track changes with the view absent
        self.timers.on_change = self._timers_changed
        self.exhibit = Exhibit(self)
        self.view.on_closed.append(self.exhibit.stop)
        self.commands = Commands(self, state_dir, on_result=self.command_cue)
        self.ignite = Ignite(clock, scheduler, open_panel=self._ignite_open, fold_panel=self._ignite_fold,
                             may_fold=lambda: self.view.state == "ready" and self.view.open and self.view.cmdline_idle,
                             fire=self._ignite_fire)
        self.ignite.on_change = partial(server.publish, "ignite")
        server.topic("ignite", self.ignite.snapshot)
        self._ignite_pending: float | None = None  # boottime until which a fire waits for the panel to open
        self.view.on_closed.append(self._ignite_closed)
        # The telemetry orrery (M12, Claude B): the processes as bodies, sampled only when the Performance room asks
        # and only while Overdrive is in effect; forgotten when the view closes (docs/OVERDRIVE.md §15).
        self.orrery = Orrery(clock, active=lambda: self.overdrive.state.effective == "active")
        self.view.on_closed.append(self.orrery.forget)
        # The machine's weather since you last looked (Claude B, atlas #75, docs/OVERDRIVE.md §18): the kernel's
        # counters read once when the view opens, a report per ten minutes at most; no timer of its own.
        self.weather = Weather(clock, state_dir)
        # Live counters for interrupt rainfall and the network letterpress (Claude B, docs/OVERDRIVE.md §31): pulled by
        # the rooms' strata, read only while Overdrive is in effect, forgotten when the view closes.
        self.telemetry = Telemetry(clock, active=lambda: self.overdrive.state.effective == "active")
        self.view.on_closed.append(self.telemetry.forget)
        # The USB buses as wired, for Devices' schematic (Claude B, atlas #21, docs/OVERDRIVE.md §38): read-only sysfs,
        # pulled by the stratum, only while Overdrive is in effect; nothing kept.
        self.buses = Buses(active=lambda: self.overdrive.state.effective == "active")
        self.discovery.bump("core.starts")
        # The first event search (~15 ms) waits until a cold open is over.
        asyncio.get_running_loop().call_later(SKY_START_DELAY, self.sky.start)
        self._register()

    def _overdrive_changed(self):
        self._publish_overdrive()
        self.quiet.sync()
        if self.overdrive.state.effective != "active" and hasattr(self, "exhibit"):
            self.exhibit.stop()
        off = self.overdrive.state.mode == "off"
        if off != self._overdrive_off:
            self._overdrive_off = off
            self.sfx.emit("overdrive.off" if off else "ignite")

    def attach_supervisor(self, supervisor):
        """The `supervisor` topic carries the state; each change of fortune is also pushed once as
        `supervisor.event` (down, up, retry, failed, stopped), like a sound cue: never replayed."""
        self.supervisor = supervisor
        self.server.topic("supervisor", supervisor.snapshot)
        supervisor.on_change = partial(self.server.publish, "supervisor")
        supervisor.on_event = self._supervisor_event

    def _supervisor_event(self, event: dict):
        for client in [c for c in self.server.clients if "supervisor" in c.topics]:
            self.server.push(client, "supervisor.event", event)

    def core_snapshot(self) -> dict:
        return {"version": VERSION, "protocol": PROTOCOL, "pid": os.getpid(), "host": self.host.name,
                "startedAt": round(self.started.real * 1000)}

    def status(self) -> dict:
        now = self.clock.now()
        supervised = {"supervisor": self.supervisor.snapshot()} if self.supervisor else {}
        return {"core": {"pid": os.getpid(), "rssKiB": rss_kib(), "uptime": round(now.boot - self.started.boot), "host": self.host.name},
                **supervised, "view": self.view.snapshot(), "timers": self.timers.summary(), "tasks": self.tasks.summary(),
                "notifications": self.mirror.summary(), "overdrive": self.overdrive.snapshot(), "session": self.sessions.snapshot()}

    def _register(self):
        op = self.server.op
        op("hello", self.hello)
        op("exhibit.prepare", lambda peer, reduced=True, metadata=None: self.exhibit.prepare(reduced, metadata))
        op("exhibit.start", lambda peer: self.exhibit.start())
        op("exhibit.stop", lambda peer: self.exhibit.stop())
        op("status", lambda peer: self.status())
        op("shutdown", self.shutdown)
        op("view.open", self.view_open)
        op("view.close", lambda peer: self.view.command("close"))
        op("view.toggle", self.view_toggle)
        op("view.state", self.view_state)
        op("host.done", self.hostcalls.done)

        t = self.timers
        op("timer.start", lambda peer, kind, seconds=None, focus=None: (t.start(kind, seconds, focus), t.snapshot())[1])
        op("timer.toggle", lambda peer, kind: (t.toggle(kind), t.snapshot())[1])
        op("timer.add", lambda peer, kind, seconds: (t.add(kind, seconds), t.snapshot())[1])
        op("timer.lap", lambda peer: (t.lap(), t.snapshot())[1])
        op("timer.reset", lambda peer, kind: (t.reset(kind), t.snapshot())[1])
        op("timer.ack", lambda peer, kind=None: (t.ack(kind), t.snapshot())[1])
        op("timer.configure", lambda peer, pomodoro=None, sound=None: (t.configure(pomodoro, sound), t.snapshot())[1])

        k = self.tasks
        op("task.add", lambda peer, text, list=None, due=None, index=None: k.add(text, list, due, index))
        op("task.update", lambda peer, id, **changes: k.update(id, **self._only(changes, "text", "done", "due", "list")))
        op("task.move", lambda peer, id, index: k.move(id, index))
        op("task.remove", lambda peer, id: k.remove(id))
        op("task.restore", lambda peer, task, index=None: k.restore(task, index))
        op("list.add", lambda peer, name: k.list_add(name))
        op("list.rename", lambda peer, id, name: k.list_rename(id, name))
        op("list.remove", lambda peer, id: k.list_remove(id))

        m = self.mirror
        op("notif.markAllRead", lambda peer: m.mark_all_read())
        op("notif.dismiss", lambda peer, id: m.dismiss(id))
        op("notif.clear", lambda peer: m.clear())
        op("notif.privateApps", lambda peer, apps=None: m.private_apps(apps))

        op("overdrive.request", lambda peer, mode, seconds=None: self.overdrive.request(mode, seconds))
        op("overdrive.release", lambda peer: self.overdrive.release())
        op("journey.forget", lambda peer: self.journey.forget())
        op("session.start", lambda peer, preset, seconds=None: self.sessions.start(preset, seconds))
        op("session.end", lambda peer: self.sessions.end())
        op("session.dismiss", lambda peer: self.sessions.dismiss())
        op("discovery.bump", lambda peer, counter, by=1: self.discovery.bump(counter, by))
        op("discovery.seen", lambda peer, id: self.discovery.seen(id))
        op("sky.now", lambda peer, tracks=False: self.sky.now(tracks is True))
        op("orrery.sample", lambda peer: self.orrery.sample())
        op("weather.now", lambda peer: self.weather.now())
        op("telemetry.sample", lambda peer: self.telemetry.sample())
        op("telemetry.sched", lambda peer: self.telemetry.sched())
        op("telemetry.disk", lambda peer: self.telemetry.disk())
        op("telemetry.gpu", lambda peer: self.telemetry.gpu())
        op("telemetry.swap", lambda peer: self.telemetry.swap())
        op("telemetry.thermal", lambda peer: self.telemetry.thermal())
        op("bus.usb", lambda peer: self.buses.usb())

        op("sfx.play", lambda peer, cue: self.sfx.emit_from_view(cue) if peer is self.view.client else self._refuse("only the view reports UI cues"))
        op("sfx.configure", lambda peer, cues: self.sfx.configure(cues))

        c = self.commands
        op("cmd.run", lambda peer, line, fallthrough=None, record=None: c.run(line, peer.kind, fallthrough, record))
        op("cmd.complete", lambda peer, text: c.complete(text))
        op("cmd.history", lambda peer, prefix="", limit=100: c.recent(prefix, limit))

        # panel: the view's own ignite plate (the panel is open, so the press neither folds nor opens it).
        op("key.down", lambda peer, panel=False: self.ignite.down(panel=bool(panel) and peer is self.view.client))
        op("key.up", lambda peer: self.ignite.up())

    # Sound cues (core/sfx.py)

    def push_cue(self, event: dict):
        """An impulse, not state: sent to sfx subscribers as it happens and never replayed."""
        for client in [c for c in self.server.clients if "sfx" in c.topics]:
            self.server.push(client, "sfx.cue", event)

    def command_cue(self, source: str, result: dict):
        if source == "view" and result.get("tone") in ("ok", "error") and not result.get("fallthrough"):
            self.sfx.emit("cmd.run" if result["ok"] else "ui.error")

    def _timers_changed(self):
        # The alert cues' switch is the timer sound setting, so the sfx snapshot follows that one value.
        self._publish_timers()
        if self.timers.state["config"]["sound"] != self._sound:
            self._sound = self.timers.state["config"]["sound"]
            self.server.publish("sfx")
        done, before = self._done_marks(), self._done
        self._done = done
        if any(mark and mark != was for mark, was in zip(done, before)):  # a DONE appeared, not one restored
            self._satellite_spawn("DONE")

    # Satellites with the view reaped (DAILY_DRIVER §5): spawn it closed, so only the satellite shows.

    def _done_marks(self) -> tuple:
        state = self.timers.state
        return (state["countdown"]["done"], state["pomodoro"]["done"])

    def _session_music(self):
        """A session started: the active player plays, if it is paused (through the view's adapter). Only while the
        view is alive: a session never spawns it (it holds the satellites back too)."""
        if self.view.state == "absent":
            return
        async def run():
            try:
                player = await self.hostcalls.call("media", None, read="active", ready="active", hold=0)
                if isinstance(player, dict) and player.get("playing") is False:
                    await self.hostcalls.call("media", "togglePlaying", read="active", ready="active", hold=0)
            except Exception as error:  # no view, no player: the session goes on in silence
                log.info("session music: %s", error)
        task = asyncio.get_running_loop().create_task(run())
        self.tasks_running = getattr(self, "tasks_running", set())
        self.tasks_running.add(task)
        task.add_done_callback(self.tasks_running.discard)

    def _track_changed(self):
        """The Q8 satellite with the view reaped. While the view is alive it follows host.media itself."""
        self.discovery.check()
        if self.view.state != "absent" or self.sessions.active() or self.fullscreen_focused():
            return
        self._satellite_spawn("track")

    def _satellite_spawn(self, why: str):
        """The view, spawned closed when absent. The normal closed-idle reap still applies."""
        if self.view.state != "absent":
            return
        log.info("spawning the view closed for a satellite (%s)", why)
        task = asyncio.get_running_loop().create_task(self.view.ensure())
        task.add_done_callback(lambda t: t.cancelled() or not t.exception() or log.warning("satellite spawn: %s", t.exception()))

    @staticmethod
    def _only(args: dict, *allowed) -> dict:
        unknown = set(args) - set(allowed)
        if unknown:
            raise OpError("bad-args", f"unexpected {', '.join(sorted(unknown))}")
        return args

    # Connection and view operations

    def hello(self, peer, client, protocol, pid=None):
        if protocol != PROTOCOL:
            raise OpError("protocol", f"this core speaks protocol {PROTOCOL}")
        if client not in ("cli", "view"):
            raise OpError("bad-args", "client must be cli or view")
        if client == "view" and not self.view.hello(peer):
            raise OpError("refused", "only the view this core spawned may connect as the view")
        peer.kind = client
        return {"core": self.core_snapshot()}

    def shutdown(self, peer):
        self.stopping.set()
        return {}

    def _before_open(self):
        if not (self.view.state == "ready" and self.view.open):
            command = getattr(self.host.profile, "before_open_command", lambda: None)()
            self.host.run(command)

    async def view_open(self, peer, page=None, screen=None, **extra):
        self._only(extra, "from")
        self._before_open()
        return await self.view.command("open", page or self.view.page or "home", extra.get("from"), screen=screen or None)

    async def view_toggle(self, peer, page=None, screen=None, **extra):
        self._only(extra, "from")
        if self.view.state == "ready" and self.view.open:
            return await self.view.command("close")
        self._before_open()
        return await self.view.command("open", page or self.view.page or "home", extra.get("from"), screen=screen or None)

    @staticmethod
    def _refuse(message: str):
        raise OpError("refused", message)

    def view_state(self, peer, open, page, cmdlineIdle=False):
        if peer is not self.view.client:
            raise OpError("refused", "only the view reports view state")
        was_open = self.view.open
        self.view.report(open, page, cmdlineIdle)
        self.journey.report(open, page)
        if open and not was_open:
            self.weather.observe()
            self.discovery.bump("view.opens")
        self.quiet.sync()
        if open and self._ignite_pending is not None:
            pending, self._ignite_pending = self._ignite_pending, None
            if self.clock.now().boot <= pending:
                self._ignite_request()

    # The ignite hold (core/ignite.py)

    def _ignite_open(self):
        self._ignite_pending = None
        self._before_open()
        task = asyncio.get_running_loop().create_task(
            self.view.command("open", self.view.page or "home", focus="cmdline"))
        task.add_done_callback(lambda t: t.cancelled() or not t.exception() or log.warning("ignite: %s", t.exception()))

    def _ignite_fold(self):
        task = asyncio.get_running_loop().create_task(self.view.command("close"))
        task.add_done_callback(lambda t: t.cancelled() or not t.exception() or log.warning("ignite: %s", t.exception()))

    def _ignite_fire(self) -> str:
        if not self.view.open:
            # A cold press: the view is still starting or unfolding. Fire when it reports open, if that is
            # within the hold's lost-release window of the press.
            self._ignite_pending = self.ignite.t0.boot + LOST
            return "pending"
        return self._ignite_request()

    def _ignite_request(self) -> str:
        # The same hold cuts a running Overdrive (docs/OVERDRIVE.md §2): hold to ignite, hold to cut.
        if self.overdrive.state.mode != "off":
            self.overdrive.release()
            return "released"
        try:
            self.overdrive.request("panel")
        except OpError as error:
            log.info("ignite: overdrive refused: %s", error)
            return "refused"
        return "granted"

    def _ignite_closed(self):
        self._ignite_pending = None

    async def close(self):
        self.exhibit.stop()
        await self.view.reap("core shutdown", force=True)
        if self.supervisor:
            await self.supervisor.stop()  # after the panel: dms and its whole tree (docs/SUPERVISOR.md §6)
        self.guards.stop()
        self.genealogy.stop()
        self.quiet.stop()
        self.journey.flush()
        self.mirror.flush()
        self.discovery.flush()
