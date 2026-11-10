"""Read-only notification mirror from `busctl --user monitor` (docs/CORE.md §5). The host stays the authority.

Never log notification contents. Image hints are dropped before anything is kept. Private apps are mirrored in
memory but never written to disk.
"""
from __future__ import annotations

import asyncio
from collections import OrderedDict
import json
import logging
from pathlib import Path

from core.errors import OpError, bad_args
from core.store import read_json, write_json
from core.track import MATCHES as TRACK_MATCHES

log = logging.getLogger("fart.notifications")
SERVICE = "org.freedesktop.Notifications"
BUS = "org.freedesktop.DBus"
PATH = "/org/freedesktop/Notifications"
KEEP = 100
PENDING = 128
TTL = 24 * 3600
MAX_LINE = 4 << 20
SAVE_AFTER = 1.0
MATCHES = [f"type='method_call',interface='{SERVICE}',path='{PATH}',member='Notify'",
           f"type='method_return',sender='{SERVICE}'",
           f"type='signal',sender='{SERVICE}',interface='{SERVICE}',member='NotificationClosed'",
           f"type='signal',sender='{BUS}',interface='{BUS}',member='NameOwnerChanged',arg0='{SERVICE}'"]
CONTRACT_FIELDS = ("id", "appName", "summary", "body", "time", "urgency", "read", "hasActions")


def hint(hints: dict, name: str):
    value = hints.get(name)
    return value.get("data") if isinstance(value, dict) else value


class Mirror:
    def __init__(self, clock, scheduler, run, state_dir: Path):
        self.clock = clock
        self.scheduler = scheduler
        self.run = run  # run(argv): fire-and-forget command
        self.path = state_dir / "notifications.json"
        self.config_path = state_dir / "core.json"
        self.on_change = lambda: None
        self.available = False
        self.owner = ""
        self.pending: OrderedDict = OrderedDict()
        self.items: list[dict] = []
        self.save_handle = None
        self.private = self._load_private()
        try:
            saved = read_json(self.path, {}) or {}
        except ValueError:
            saved = {}
        self.saved_bus = saved.get("busId")
        self.saved_owner = saved.get("owner") or ""
        self.items = [i for i in saved.get("items") or [] if isinstance(i, dict) and isinstance(i.get("id"), str)][-KEEP:]
        self._expire()

    # Configuration

    def _load_private(self) -> set[str]:
        try:
            config = read_json(self.config_path, {}) or {}
        except ValueError:
            config = {}
        return {str(app).lower() for app in config.get("privateApps") or []}

    def private_apps(self, apps=None):
        if apps is not None:
            if not isinstance(apps, list) or not all(isinstance(a, str) and 0 < len(a) <= 256 for a in apps):
                raise bad_args("apps must be a list of app names")
            try:
                config = read_json(self.config_path, {}) or {}
            except ValueError:
                config = {}
            config["privateApps"] = sorted({a.strip() for a in apps if a.strip()})
            private = {a.lower() for a in config["privateApps"]}
            for item in (*self.items, *self.pending.values()):
                if item["appName"].lower() in private:
                    item["private"] = True
            # Purge before publishing the new policy. A later opt-out only
            # changes the handling of future notifications.
            self.flush()
            write_json(self.config_path, config)
            self.private = private
        return {"apps": sorted(self.private)}

    # The busctl stream

    def started(self, owner: str, bus_id: str):
        """Only restore IDs issued by this owner in this bus lifetime."""
        self.owner = owner
        if (bus_id, owner) != (self.saved_bus, self.saved_owner):
            self.items = []
            self.pending.clear()
            self.saved_bus, self.saved_owner = bus_id, owner
            self._save()
        self.available = True
        self.on_change()

    def stopped(self):
        self.available = False
        self.items, self.pending = [], OrderedDict()
        self.on_change()

    def feed(self, message: dict):
        kind, member, sender = message.get("type"), message.get("member"), message.get("sender")
        data = (message.get("payload") or {}).get("data") or []
        if kind == "signal" and member == "NameOwnerChanged" and sender == BUS:
            if len(data) == 3 and data[0] == SERVICE:
                self.owner = self.saved_owner = data[2]
                self.pending.clear()
                self.items = []
                self._changed()
        elif kind == "signal" and member == "NotificationClosed" and sender == self.owner and data:
            nid = str(data[0])
            if any(i["id"] == nid for i in self.items):
                self.items = [i for i in self.items if i["id"] != nid]
                self._changed()
        elif kind == "method_call" and member == "Notify" and message.get("destination") in (self.owner, SERVICE):
            if len(data) != 8 or not isinstance(data[6], dict):
                return
            app, _, _, summary, body, actions, hints, _ = data
            if hint(hints, "transient"):
                return
            app = str(app)[:256] or "System"
            self.pending[(sender, message.get("cookie"))] = {
                "appName": app, "private": app.lower() in self.private, "summary": str(summary)[:512], "body": str(body)[:2000],
                "urgency": "critical" if hint(hints, "urgency") == 2 else "normal", "hasActions": bool(actions)}
            if len(self.pending) > PENDING:
                self.pending.popitem(last=False)
        elif kind == "method_return" and sender == self.owner and self.owner:
            row = self.pending.pop((message.get("destination"), message.get("reply_cookie")), None)
            payload = message.get("payload") or {}
            if row and payload.get("type") == "u" and data:
                nid = str(data[0])
                now = self.clock.now()
                kept = [i for i in self.items if i["id"] != nid]
                kept.append({"id": nid, "owner": self.owner, **row, "time": round(now.real * 1000), "read": False})
                self.items = kept[-KEEP:]
                self._changed()

    # Contract operations

    def snapshot(self) -> dict:
        items = [{k: i.get(k) for k in CONTRACT_FIELDS} for i in self.items] if self.available else []
        return {"available": self.available, "items": items, "unread": sum(not i["read"] for i in items)}

    def summary(self) -> dict:
        snap = self.snapshot()
        return {"available": snap["available"], "count": len(snap["items"]), "unread": snap["unread"]}

    def mark_all_read(self):
        if any(not i["read"] for i in self.items):
            self.items = [{**i, "read": True} for i in self.items]
            self._changed()

    def dismiss(self, id):
        item = next((i for i in self.items if i["id"] == str(id)), None)
        if not item:
            raise OpError("not-found", "no such notification")
        if item.get("owner") and item["owner"] == self.owner:
            # The item leaves on the host's NotificationClosed, as before.
            self.run(["busctl", "--user", "call", self.owner, PATH, SERVICE, "CloseNotification", "u", item["id"]])
        else:
            self.items = [i for i in self.items if i is not item]
            self._changed()

    def clear(self):
        self.items = []
        self._changed()

    # Persistence and expiry

    def _changed(self):
        self._expire(schedule_only=True)
        self._save()
        self.on_change()

    def _save(self):
        if self.save_handle is None:
            try:
                loop = asyncio.get_running_loop()
            except RuntimeError:
                return self.flush()
            self.save_handle = loop.call_later(SAVE_AFTER, self.flush)

    def flush(self):
        if self.save_handle:
            self.save_handle.cancel()
            self.save_handle = None
        kept = [{k: v for k, v in i.items() if k != "private"} for i in self.items if not i.get("private")]
        write_json(self.path, {"busId": self.saved_bus, "owner": self.saved_owner, "items": kept})

    def _expire(self, schedule_only=False):
        now = self.clock.now()
        cutoff = (now.real - TTL) * 1000
        if not schedule_only:
            fresh = [i for i in self.items if isinstance(i.get("time"), (int, float)) and i["time"] > cutoff]
            if len(fresh) != len(self.items):
                self.items = fresh
                self._save()
                self.on_change()
        if self.items:
            oldest = min(i["time"] for i in self.items)
            self.scheduler.at("notifications.expire", now.boot + oldest / 1000 + TTL - now.real, lambda _: self._expire())
        else:
            self.scheduler.cancel("notifications.expire")


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
