"""Read-only notification mirror from `busctl --user monitor` (docs/CORE.md §5), feeding the Inbox while another
program (DMS) owns the notification name. It stands aside while our own server is attached (Z163).

Never log notification contents. Image hints are dropped here: the mirror never sees a usable image.
"""
from __future__ import annotations

import asyncio
from collections import OrderedDict
import json
import logging

from core.notifications import Inbox, URGENCIES
from core.track import MATCHES as TRACK_MATCHES

log = logging.getLogger("fart.notifications")
SERVICE = "org.freedesktop.Notifications"
BUS = "org.freedesktop.DBus"
PATH = "/org/freedesktop/Notifications"
PENDING = 128
MAX_LINE = 4 << 20
MATCHES = [f"type='method_call',interface='{SERVICE}',path='{PATH}',member='Notify'",
           f"type='method_return',sender='{SERVICE}'",
           f"type='signal',sender='{SERVICE}',interface='{SERVICE}',member='NotificationClosed'",
           f"type='signal',sender='{BUS}',interface='{BUS}',member='NameOwnerChanged',arg0='{SERVICE}'"]


def hint(hints: dict, name: str):
    value = hints.get(name)
    return value.get("data") if isinstance(value, dict) else value


def action_pairs(flat) -> list[dict]:
    """The wire's [id, label, id, label, …] as [{id, label}]."""
    flat = [str(part) for part in flat] if isinstance(flat, list) else []
    return [{"id": flat[n], "label": flat[n + 1]} for n in range(0, len(flat) - 1, 2)]


class Mirror:
    def __init__(self, inbox: Inbox, run):
        self.inbox = inbox
        self.run = run  # run(argv): fire-and-forget command
        self.owner = ""
        self.pending: OrderedDict = OrderedDict()
        inbox.close_remote = self.close

    @property
    def available(self) -> bool:
        return self.inbox.listening

    def started(self, owner: str, bus_id: str):
        self.owner = owner
        self.pending.clear()
        self.inbox.mirror_started(bus_id, owner)

    def stopped(self):
        self.pending.clear()
        self.inbox.mirror_stopped()

    def close(self, item: dict) -> bool:
        """Ask the host to close an item it still owns; the item then leaves on its NotificationClosed."""
        if not self.owner or item.get("owner") != self.owner:
            return False
        self.run(["busctl", "--user", "call", self.owner, PATH, SERVICE, "CloseNotification", "u", item["id"]])
        return True

    def feed(self, message: dict):
        kind, member, sender = message.get("type"), message.get("member"), message.get("sender")
        data = (message.get("payload") or {}).get("data") or []
        if kind == "signal" and member == "NameOwnerChanged" and sender == BUS:
            if len(data) == 3 and data[0] == SERVICE:
                self.owner = data[2]
                self.pending.clear()
                self.inbox.mirror_owner(self.owner)
        elif self.inbox.serving:
            return  # our own server reports to the Inbox itself
        elif kind == "signal" and member == "NotificationClosed" and sender == self.owner and data:
            self.inbox.remove(str(data[0]), owner=self.owner)
        elif kind == "method_call" and member == "Notify" and message.get("destination") in (self.owner, SERVICE):
            if len(data) != 8 or not isinstance(data[6], dict):
                return
            app, _, _, summary, body, actions, hints, _ = data
            if hint(hints, "transient"):
                return
            app = str(app)
            self.pending[(sender, message.get("cookie"))] = {
                "appName": app, "private": self.inbox.is_private(app), "summary": summary, "body": body,
                "urgency": URGENCIES[hint(hints, "urgency")] if hint(hints, "urgency") in (0, 1, 2) else "normal",
                "actions": action_pairs(actions)}
            if len(self.pending) > PENDING:
                self.pending.popitem(last=False)
        elif kind == "method_return" and sender == self.owner and self.owner:
            row = self.pending.pop((message.get("destination"), message.get("reply_cookie")), None)
            payload = message.get("payload") or {}
            if row and payload.get("type") == "u" and data:
                self.inbox.put(str(data[0]), row, owner=self.owner)


class BusctlSource:
    """Runs busctl monitor for the mirror (and the MPRIS track watch, core/track.py) and restarts it with a backoff."""

    def __init__(self, mirror: Mirror, track=None):
        self.mirror = mirror
        self.track = track
        self.process = None
        self.task = None

    def start(self):
        self.task = asyncio.get_running_loop().create_task(self._run())

    async def stop(self):
        if self.task:
            self.task.cancel()
        if self.process and self.process.returncode is None:
            self.process.terminate()
            await self.process.wait()

    async def _bus_call(self, method, *args) -> str:
        process = await asyncio.create_subprocess_exec(
            "busctl", "--user", "--json=short", "call", BUS, "/org/freedesktop/DBus", BUS, method, *args,
            stdin=asyncio.subprocess.DEVNULL, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        out, _ = await process.communicate()
        try:
            return json.loads(out)["data"][0] if process.returncode == 0 else ""
        except (ValueError, KeyError, IndexError, TypeError):
            return ""

    async def _run(self):
        delay = 1
        while True:
            try:
                bus_id = await self._bus_call("GetId")
                if not bus_id:
                    raise OSError("session bus identity unavailable")
                matches = MATCHES + (TRACK_MATCHES if self.track else [])
                args = ["busctl", "--user", "monitor", "--json=short"] + [f"--match={m}" for m in matches]
                self.process = await asyncio.create_subprocess_exec(
                    *args, stdin=asyncio.subprocess.DEVNULL, stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL, limit=MAX_LINE)
                owner = await self._bus_call("GetNameOwner", "s", SERVICE)
                if await self._bus_call("GetId") != bus_id:
                    # The independent busctl connections straddled a restart.
                    if self.process.returncode is None:
                        self.process.terminate()
                    await self.process.wait()
                    raise OSError("session bus changed while starting the mirror")
                self.mirror.started(owner, bus_id)
                if self.track:
                    self.track.started(await self._mpris_owners())
                started = asyncio.get_running_loop().time()
                await self._read(self.process.stdout)
                await self.process.wait()
                if asyncio.get_running_loop().time() - started > 60:
                    delay = 1
                log.warning("busctl monitor exited (code %s)", self.process.returncode)
            except OSError as error:
                log.warning("cannot start bus monitor: %s", error)
            self.mirror.stopped()
            if self.track:
                self.track.stopped()
            await asyncio.sleep(delay)
            delay = min(60, delay * 2)

    async def _mpris_owners(self) -> dict[str, str]:
        """Players already running when the monitor starts: unique name → well-known name."""
        names = await self._bus_call("ListNames")
        owners = {}
        for name in names if isinstance(names, list) else []:
            if isinstance(name, str) and name.startswith("org.mpris.MediaPlayer2."):
                unique = await self._bus_call("GetNameOwner", "s", name)
                if unique:
                    owners[unique] = name
        return owners

    async def _read(self, stdout: asyncio.StreamReader):
        dropped = 0
        while True:
            try:
                line = await stdout.readline()
            except ValueError:
                dropped += 1
                log.info("dropped an oversized bus message (%d so far)", dropped)
                continue
            if not line:
                return
            try:
                message = json.loads(line)
            except ValueError:
                continue
            if isinstance(message, dict):
                self.mirror.feed(message)
                if self.track:
                    self.track.feed(message)
