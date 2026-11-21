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
from core.capture import Capture
from core.clips import Clips
from core.equalizer import Equalizer
from core.errors import OpError
from core.genealogy import Genealogy
from core.guards import BatteryGuard, FullscreenGuard, Guards, SessionGuard, focused_fullscreen
from core.hostcalls import HostCalls
from core.island import Island
from core.launcher import Launcher
from core.palette import MADE as MADE_PALETTE, Palette
from core.wallpaper import Wallpaper, kind_of
from core.typeset import face_of, layers_for as plate_layers, typeset_targets
from core.presets import Presets
from core.ignite import LOST, Ignite
from core.notification_mirror import Mirror
from core.notifications import Inbox
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
from core.view import ViewManager, toggle_target

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
    def __init__(self, clock, scheduler, host, state_dir: Path, spawn, pressure=None, guard_types=None, before_spawn=lambda: None,
                 resident_view: bool = False, dms_bar=None):
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
        self.island = Island(state_dir)
        self.clips = Clips(state_dir)  # quick paste's settings; the history is DMS's (Z202)
        self.palette = Palette(state_dir)
        # The launcher's apps (S6): the old launcher's counts come from the host profile, once (Z136).
        self.launcher = Launcher(clock, state_dir, imported=getattr(host.profile, "launch_history", lambda: None),
                                 session_active=self.sessions.active, verb=lambda text: self.commands.inline(text))
        self.wallpaper = Wallpaper(state_dir)
        # Typeset plates follow the saved palette's accent (Z213): one lock, so a palette change, a choice and a
        # preset never apply wallpapers over each other.
        self.wallpaper_lock = asyncio.Lock()
        self.wallpaper_follows = set()
        self.palette.on_choose = self._palette_chosen
        self.presets = Presets(state_dir)
        # The host's own theme as the view's adapter reports it (Z180); only presets use it.
        self.host_theme = dict(available=False, current="", error="")
        self.equalizer = Equalizer(state_dir)  # its chain only in a session that runs it (fartd attaches it)
        # Screenshots, OCR, QR, Lens and recording (S9, Z221); its frozen grabs live in the runtime dir, never on disk.
        self.capture = Capture(Path(os.environ.get("XDG_RUNTIME_DIR") or state_dir) / "zaetherion",
                               alert=lambda summary, body, image=None: host.alert(summary, body, image=image))
        self.sessions.tasks_done = self.tasks.done_between
        self.sessions.music = self._session_music
        self.discovery = Discovery(state_dir, clock)
        self.sky = SkyWatch(clock, scheduler, getattr(host.profile, "location", lambda: None), self.discovery)
        self.inbox = Inbox(clock, scheduler, state_dir)
        self.mirror = Mirror(self.inbox, host.run)
        self.view = ViewManager(clock, scheduler, spawn, self._view_changed, pressure,
                                may_reap=lambda: self.overdrive.state.mode == "off", before_spawn=before_spawn,
                                resident=resident_view)
        self.dms_bar = dms_bar  # core/dms_bar.py: hidden while a resident view is up (Z159)
        types = guard_types or [FullscreenGuard, BatteryGuard, SessionGuard]
        types = [partial(SessionGuard, active=self.sessions.active) if t is SessionGuard else t for t in types]
        self.guards = Guards(lambda name, on: self.overdrive.guard(name, on), types)
        self.overdrive = Overdrive(clock, scheduler, self.guards, state_dir, view_open=lambda: self.view.open)
        self.view.on_closed.append(self.overdrive.panel_closed)
        self.hostcalls = HostCalls(self.view)
        server.on_disconnect.append(self.hostcalls.disconnected)
        server.on_disconnect.append(self.inbox.disconnected)
        self.inbox.on_sound = lambda urgency: self.sfx.emit(f"notify.{urgency}")
        self.inbox.on_dnd = lambda on: self.sfx.emit("dnd.on" if on else "dnd.off")
        server.on_disconnect.append(self.palette.cancel)
        self.view.on_closed.append(self.palette.cancel)
        server.on_disconnect.append(self.wallpaper.cancel)
        self.view.on_closed.append(self.wallpaper.cancel)
        server.on_disconnect.append(self.presets_cancel_for)
        self.view.on_closed.append(self.presets_cancel_for)
        self.overdrive.on_release = self.view.check_idle_reap
        session_guard = self.guards.by_name.get("session")
        if session_guard:
            self.sessions.on_guard = session_guard.changed

        for name, owner in (("timers", self.timers), ("tasks", self.tasks), ("notifications", self.inbox),
                            ("overdrive", self.overdrive), ("session", self.sessions), ("island", self.island), ("clips", self.clips), ("palette", self.palette),
                            ("wallpaper", self.wallpaper),
                            ("equalizer", self.equalizer), ("launcher", self.launcher), ("capture", self.capture), ("view", self.view)):
            server.topic(name, owner.snapshot)
            if name != "view":
                owner.on_change = partial(server.publish, name)
        server.topic("presets", self.presets_snapshot)
        self.presets.on_change = partial(server.publish, "presets")
        server.topic("core", self.core_snapshot)
        # Always offered, so a view can subscribe whether or not this core supervises DMS: it reads DMS's socket
        # here (children.dms.socket, docs/SUPERVISOR.md §13), which changes with every DMS restart.
        server.topic("supervisor", lambda: self.supervisor.snapshot() if self.supervisor else {"children": {}})
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
        supervisor.on_change = partial(self.server.publish, "supervisor")
        supervisor.on_event = self._supervisor_event

    def _view_changed(self):
        self.server.publish("view")
        if self.dms_bar:
            self.dms_bar.sync(self.view.state == "ready")

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
                "notifications": self.inbox.summary(), "overdrive": self.overdrive.snapshot(), "session": self.sessions.snapshot()}

    def _register(self):
        op = self.server.op
        op("hello", self.hello)
        op("palette.list", lambda peer: self.palette.listing())
        op("palette.choose", lambda peer, name: self.palette.choose(name))
        op("palette.preview", lambda peer, name: self.palette.preview_name(name, peer))
        op("palette.cancel", lambda peer: self.palette.cancel(peer))
        w = self.wallpaper
        op("wallpaper.list", lambda peer: w.listing())
        op("wallpaper.preview", self.wallpaper_preview)
        op("wallpaper.cancel", self.wallpaper_cancel)
        op("wallpaper.colours", self.wallpaper_colours)
        op("wallpaper.folder", lambda peer, folder: w.set_folder(folder))
        op("wallpaper.choose", lambda peer, name: self.wallpaper_choose(w.resolve(name)))
        op("wallpaper.report", self.wallpaper_report)
        op("wallpaper.typeset", self.wallpaper_typeset)
        op("hosttheme.report", self.host_theme_report)
        p = self.presets
        op("presets.save", lambda peer, name: (p.save(name, self.current_look()), self.presets_snapshot())[1])
        op("presets.rename", lambda peer, name, new: (p.rename(name, new), self.presets_snapshot())[1])
        op("presets.delete", lambda peer, name: (p.delete(name), self.presets_snapshot())[1])
        op("presets.preview", self.presets_preview)
        op("presets.cancel", lambda peer: (self.presets_cancel_for(peer), self.presets_snapshot())[1])
        op("presets.apply", lambda peer, name: self.presets_apply(name))
        e = self.equalizer
        op("eq.enable", lambda peer, on: e.set_on(on))
        op("eq.band", lambda peer, index, gain: e.set_band(index, gain))
        op("eq.preset", lambda peer, name: e.apply_preset(name))
        op("eq.mono", lambda peer, on: e.set_mono(on))
        op("clips.set", lambda peer, key, value: self.clips.set(key, value))
        op("island.rest", lambda peer, item, mode: self.island.set_rest(**{item: mode}))
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

        n = self.inbox
        op("notif.markAllRead", lambda peer: n.mark_all_read())
        op("notif.dismiss", lambda peer, id: n.dismiss(id))
        op("notif.clear", lambda peer: n.clear())
        op("notif.privateApps", lambda peer, apps=None: n.private_apps(apps))
        op("notif.dnd", lambda peer, on: n.set_dnd(on))
        # Our own notification server, in the view (Z166).
        op("notif.serve", lambda peer, ids=None: n.serve(peer, ids))
        op("notif.ingest", lambda peer, **fields: n.ingest(peer, **fields))
        op("notif.image", lambda peer, id: n.image(peer, id))
        op("notif.closed", lambda peer, id: n.closed(peer, id))

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
        op("sfx.stop", lambda peer, cue: self.sfx.stop_from_view(cue) if peer is self.view.client else self._refuse("only the view stops UI cues"))
        op("sfx.configure", lambda peer, cues: self.sfx.configure(cues))

        a = self.launcher
        op("apps.index", lambda peer, entries: a.index(entries) if peer.kind == "view" else self._refuse("only the view indexes apps"))
        op("launcher.query", lambda peer, text="", limit=None: a.query(text, limit))
        op("launcher.launch", lambda peer, id: a.launch(id))
        op("launcher.act", lambda peer, kind, text: self._launcher_act(kind, text))
        op("launcher.configure", lambda peer, **changes: a.configure(**changes))
        op("launcher.forget", lambda peer: a.forget())

        c = self.commands
        op("cmd.run", lambda peer, line, fallthrough=None, record=None: c.run(line, peer.kind, fallthrough, record))
        op("cmd.complete", lambda peer, text: c.complete(text))
        op("launcher.page", lambda peer, verb: c.page(verb))
        op("cmd.history", lambda peer, prefix="", limit=100: c.recent(prefix, limit))

        # panel: the view's own ignite plate (the panel is open, so the press neither folds nor opens it).
        op("key.down", lambda peer, panel=False: self.ignite.down(panel=bool(panel) and peer is self.view.client))
        op("key.up", lambda peer: self.ignite.up())

    async def _launcher_act(self, kind, text) -> dict:
        """Enter on an inline row: a FART verb runs here, as if typed on the command line; the rest is the launcher's."""
        if kind == "verb":
            if not isinstance(text, str) or not self.commands.inline(text):
                raise OpError("not-inline", f"{text!r} is not a FART verb line")
            return {"result": await self.commands.run(text, "view", fallthrough=False)}
        return self.launcher.act(kind, text)

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
        target = toggle_target(self.view.state == "ready" and self.view.open, self.view.page, page)
        if target is None:
            return await self.view.command("close")
        self._before_open()
        return await self.view.command("open", target, extra.get("from"), screen=screen or None)

    async def wallpaper_choose(self, path: str) -> dict:
        """Through the view's adapter; the host stays the authority for what is applied (Z178)."""
        self.wallpaper.can_apply()
        await self._apply_wallpaper(path)
        await self._wallpaper_palette(path)
        return self.wallpaper.snapshot()

    async def wallpaper_typeset(self, peer=None, name=None) -> dict:
        """Typeset a picture (the named one, else the current) into a plate beside it and show it (Z215)."""
        w = self.wallpaper
        source = w.resolve(name) if name else w.host["current"]
        if not source:
            raise OpError("refused", "no wallpaper to typeset; name one")
        if kind_of(Path(source)) != "image":
            raise OpError("refused", "only pictures can be typeset")
        if plate_layers(source) is not None:
            raise OpError("refused", "this is already a typeset plate; it follows the palette")
        if w.typesetting:
            raise OpError("refused", "already typesetting " + Path(w.typesetting).name)
        face, layers = typeset_targets(source)
        from adapters.common import typeset_make  # the generator is known only there
        w.typeset_state(source)
        try:
            await typeset_make.make(source, face, layers)
        except RuntimeError as error:
            w.typeset_state("", str(error))
            raise OpError("failed", str(error))
        w.typeset_state("")
        if w.host["available"] and not w.host["perScreen"]:
            await self._apply_wallpaper(str(face))
        else:
            w.on_change()  # the folder has a new file even when the host can't show it
        return w.snapshot()

    async def _apply_wallpaper(self, path: str):
        """Set a wallpaper on the host; a typeset plate is set as its copy in the saved palette's accent (Z213)."""
        async with self.wallpaper_lock:
            target = path
            layers = plate_layers(path)
            if layers is not None:
                from adapters.common import typeset_tint  # ImageMagick is known only there
                accent = self.palette.entries[self.palette.name]["colors"]["accent"]
                try:
                    target = await typeset_tint.recolour(layers, accent)
                except (RuntimeError, ValueError, OSError) as error:
                    log.warning("wallpaper plate %s kept its own colour: %s", path, error)
                    target = face_of(path)  # the plate as drawn, in its own accent
            await self.hostcalls.call("wallpaper", "set", [target], ready="available", hold=0)
            self.wallpaper.applied(target)

    def _palette_chosen(self):
        """The saved palette changed: a typeset plate on the host recolours to it (previews don't, Z213)."""
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            return
        task = loop.create_task(self._wallpaper_follow())
        self.wallpaper_follows.add(task)
        task.add_done_callback(self.wallpaper_follows.discard)

    async def _wallpaper_follow(self):
        w = self.wallpaper
        current = w.host["current"]
        if not current or plate_layers(current) is None or not w.host["available"] or w.host["perScreen"]:
            return
        try:
            await self._apply_wallpaper(current)
        except OpError as error:
            log.warning("wallpaper plate did not follow the palette: %s", error)

    async def wallpaper_preview(self, peer, name):
        path = self.wallpaper.resolve(name)
        self.wallpaper.preview_name(path, peer)
        await self._wallpaper_palette(path, peer)
        return self.wallpaper.snapshot()

    def wallpaper_cancel(self, peer):
        if (self.palette.preview or "").startswith(MADE_PALETTE):
            self.palette.cancel(peer)
        return self.wallpaper.cancel(peer)

    def wallpaper_colours(self, peer, on):
        result = self.wallpaper.set_colours(on)
        if not on and (self.palette.preview or "").startswith(MADE_PALETTE):
            self.palette.cancel()
        return result

    def host_theme_report(self, peer, available=False, current="", error=""):
        if peer is not self.view.client:
            raise OpError("refused", "only the view reports the host's theme")
        state = dict(available=bool(available), current=current if isinstance(current, str) else "",
                     error=error if isinstance(error, str) else "")
        if state != self.host_theme:
            self.host_theme = state
            self.server.publish("presets")
        return state

    # Presets (Z180): a look is stored by core/presets.py and previewed or applied through its parts' owners.

    def current_look(self) -> dict:
        return dict(wallpaper=self.wallpaper.host["current"], palette=self.palette.name,
                    islandForm=self.island.state["form"], hostTheme=self.host_theme["current"])

    def _missing(self, look: dict) -> list:
        missing = []
        if look["wallpaper"] and not Path(look["wallpaper"]).is_file():
            missing.append("wallpaper")
        if look["palette"] and look["palette"] not in self.palette.entries:
            missing.append("palette")
        if look["hostTheme"] and not self.host_theme["available"]:
            missing.append("hostTheme")
        return missing

    def presets_snapshot(self) -> dict:
        looks = []
        for look in self.presets.looks:
            entry = self.palette.entries.get(look["palette"])
            looks.append(dict(look, missing=self._missing(look), paletteName=entry["name"] if entry else "",
                              swatch=[entry["colors"][r] for r in ("background", "surface", "accent", "highlight")] if entry else []))
        return dict(looks=looks, preview=self.presets.preview, current=self.current_look(), hostTheme=dict(self.host_theme))

    def presets_preview(self, peer, name):
        look = self.presets.resolve(name)
        if look["palette"] in self.palette.entries:
            self.palette.preview_name(look["palette"], peer)
        elif self.palette.owner is peer:
            self.palette.cancel(peer)
        if look["islandForm"]:
            self.island.preview_form(look["islandForm"], peer)
        else:
            self.island.cancel(peer)
        self.presets.mark_preview(look["name"], peer)
        return self.presets_snapshot()

    def presets_cancel_for(self, owner=None):
        """Disconnect (owner) or fold (no owner): a preset's preview ends with all its parts."""
        if self.presets.cancel(owner):
            self.palette.cancel(owner)
            self.island.cancel(owner)
        elif owner is None:
            self.island.cancel()

    async def presets_apply(self, name) -> dict:
        look = dict(self.presets.resolve(name))
        applied, skipped = [], []
        self.presets.cancel()
        self.island.cancel()
        if look["palette"]:
            if look["palette"] in self.palette.entries:
                self.palette.choose(look["palette"])
                applied.append("palette")
            else:
                skipped.append("palette")
        if look["islandForm"]:
            self.island.set(form=look["islandForm"])
            applied.append("islandForm")
        if look["wallpaper"]:
            w = self.wallpaper
            if Path(look["wallpaper"]).is_file() and w.host["available"] and not w.host["perScreen"]:
                await self._apply_wallpaper(look["wallpaper"])  # the preset's palette wins over colours from the wallpaper
                applied.append("wallpaper")
            else:
                skipped.append("wallpaper")
        if look["hostTheme"]:
            if self.host_theme["available"]:
                await self.hostcalls.call("hostTheme", "set", [look["hostTheme"]], ready="available", hold=0)
                applied.append("hostTheme")
            else:
                skipped.append("hostTheme")
        self.server.publish("presets")
        return dict(name=look["name"], applied=applied, skipped=skipped)

    async def _wallpaper_palette(self, path: str, peer=None):
        """With colours on: a palette from the image, previewed with it (peer) or saved with it (Z179)."""
        w = self.wallpaper
        # A typeset plate follows the palette and never makes one (Z213): no loop between the two.
        if not w.colours or kind_of(Path(path)) != "image" or plate_layers(path) is not None:
            return
        key = MADE_PALETTE + path
        if key not in self.palette.entries:
            from adapters.common import wallpaper_colors  # matugen is known only there, like palette_sources
            try:
                colours = await wallpaper_colors.colors_for(path)
            except RuntimeError as error:
                w.colours_result(str(error))
                return
            self.palette.add_made(key, Path(path).stem, colours)
        w.colours_result("")
        if peer is None:
            self.palette.choose(key)
        elif w.preview == path and w.owner is peer:  # a later hover won meanwhile: leave its preview
            self.palette.preview_name(key, peer)

    def wallpaper_report(self, peer, available=False, current="", perScreen=False, error=""):
        if peer is not self.view.client:
            raise OpError("refused", "only the view reports the host's wallpaper")
        return self.wallpaper.report(available, current, perScreen, error)

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
        await self.capture.stop()  # a running recording is finished, not lost
        await self.equalizer.close()  # the owner's routing is back before anything else stops
        await self.view.stop()  # the view's end shows DMS's bar again (_view_changed), before DMS stops
        if self.supervisor:
            await self.supervisor.stop()  # after the panel: dms and its whole tree (docs/SUPERVISOR.md §6)
        self.guards.stop()
        self.genealogy.stop()
        self.quiet.stop()
        self.journey.flush()
        self.inbox.flush()
        self.discovery.flush()
