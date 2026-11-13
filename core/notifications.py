"""The Inbox: the one list of notifications (Z163). It is fed by our own notification server in the view
(`notif.serve`, `notif.ingest`, `notif.closed`) or, while another program owns the name, by the busctl mirror
(core/notification_mirror.py). It keeps 24 hours, at most KEEP items, newest last.

Never log notification contents. Private apps and transient items are held in memory but never written to disk,
and neither are their images.
"""
from __future__ import annotations

import asyncio
from pathlib import Path
import re

from core.errors import OpError, bad_args
from core.store import read_json, write_json

KEEP = 100
TTL = 24 * 3600
SAVE_AFTER = 1.0
URGENCIES = ("low", "normal", "critical")
MAX_ACTIONS = 8
CAPS = {"appName": 256, "summary": 512, "body": 2000, "icon": 1024, "image": 1024, "reply": 64, "action": 128}
SERVER_ID = re.compile(r"[A-Za-z0-9_-]{1,64}")  # also a safe file name for the item's picture
NO_TIMEOUT = -1  # the sender left the showing time to us
CONTRACT_FIELDS = ("id", "appName", "summary", "body", "time", "urgency", "read", "hasActions", "actions", "reply",
                   "icon", "image", "timeout", "live")
UNWRITTEN = ("private", "transient")  # item flags that keep it off the disk
# What a row saved by an older core may lack.
DEFAULTS = {"actions": [], "hasActions": False, "reply": "", "icon": "", "image": "", "timeout": NO_TIMEOUT,
            "read": False, "private": False, "transient": False}


def text(value, cap: int) -> str:
    return (value if isinstance(value, str) else "")[:cap]


def clean_actions(actions) -> list[dict]:
    rows = [a for a in actions if isinstance(a, dict)] if isinstance(actions, list) else []
    return [{"id": text(a.get("id"), CAPS["action"]), "label": text(a.get("label"), CAPS["action"])}
            for a in rows[:MAX_ACTIONS]]


class Inbox:
    def __init__(self, clock, scheduler, state_dir: Path):
        self.clock = clock
        self.scheduler = scheduler
        self.path = state_dir / "notifications.json"
        self.config_path = state_dir / "core.json"
        self.images = state_dir / "notification-images"
        self.on_change = lambda: None
        self.close_remote = lambda item: False  # the mirror's: True when the host will close the item itself
        self.on_sound = lambda urgency: None  # a notification that should be heard arrived at our server
        self.mirroring = False
        self.server = None  # the client whose view runs our notification server
        self.holder_pid = 0  # the process that owns the notification name on the bus; 0 while unknown
        self.save_handle = None
        config = self._config()
        self.private = {str(app).lower() for app in config.get("privateApps") or []}
        self.dnd = config.get("dnd") is True
        try:
            saved = read_json(self.path, {}) or {}
        except ValueError:
            saved = {}
        self.saved_bus = saved.get("busId")
        self.saved_owner = saved.get("owner") or ""
        rows = [i for i in saved.get("items") or [] if isinstance(i, dict) and isinstance(i.get("id"), str)]
        self.items: list[dict] = [{**DEFAULTS, **i, "live": False} for i in rows[-KEEP:]]
        self._expire()
        self._sweep_images()

    # State

    @property
    def serving(self) -> bool:
        """Our server is attached and it is the one the bus delivers to (another program may still hold the name)."""
        return self.server is not None and self.server.pid == self.holder_pid

    @property
    def listening(self) -> bool:
        return self.serving or self.mirroring

    def snapshot(self) -> dict:
        items = [{k: i.get(k) for k in CONTRACT_FIELDS} for i in self.items] if self.listening else []
        return {"available": self.listening, "source": "server" if self.serving else "mirror", "dnd": self.dnd,
                "items": items, "unread": sum(not i["read"] for i in items)}

    def summary(self) -> dict:
        snap = self.snapshot()
        return {"available": snap["available"], "source": snap["source"], "dnd": snap["dnd"],
                "count": len(snap["items"]), "unread": snap["unread"]}

    def find(self, id) -> dict:
        item = next((i for i in self.items if i["id"] == str(id)), None)
        if not item:
            raise OpError("not-found", "no such notification")
        return item

    # Configuration

    def _config(self) -> dict:
        try:
            config = read_json(self.config_path, {})
        except ValueError:
            config = {}
        return config if isinstance(config, dict) else {}

    def is_private(self, app: str) -> bool:
        return app.lower() in self.private

    def private_apps(self, apps=None):
        if apps is not None:
            if not isinstance(apps, list) or not all(isinstance(a, str) and 0 < len(a) <= 256 for a in apps):
                raise bad_args("apps must be a list of app names")
            config = self._config()
            config["privateApps"] = sorted({a.strip() for a in apps if a.strip()})
            private = {a.lower() for a in config["privateApps"]}
            for item in self.items:
                if item["appName"].lower() in private:
                    item["private"] = True
                    item["image"] = "" if item["image"] == str(self._image_path(item["id"])) else item["image"]
            # Purge before publishing the new policy. A later opt-out only
            # changes the handling of future notifications.
            self.flush()
            self._sweep_images()
            write_json(self.config_path, config)
            self.private = private
        return {"apps": sorted(self.private)}

    def set_dnd(self, on):
        if not isinstance(on, bool):
            raise bad_args("on must be true or false")
        if on != self.dnd:
            config = self._config()
            config["dnd"] = on
            write_json(self.config_path, config)
            self.dnd = on
            self.on_change()
        return {"dnd": self.dnd}

    # Feeding (the mirror and our server both end here)

    def put(self, id: str, fields: dict, owner: str = "", live: bool = False, transient: bool = False) -> dict:
        """Add an item, or replace the one with the same id (the sender's replace-id); newest last."""
        app = text(fields.get("appName"), CAPS["appName"]) or "System"
        timeout = fields.get("timeout")
        actions = clean_actions(fields.get("actions"))
        item = {"id": id, "appName": app, "summary": text(fields.get("summary"), CAPS["summary"]),
                "body": text(fields.get("body"), CAPS["body"]),
                "urgency": fields.get("urgency") if fields.get("urgency") in URGENCIES else "normal",
                "actions": actions, "hasActions": bool(actions), "reply": text(fields.get("reply"), CAPS["reply"]),
                "icon": text(fields.get("icon"), CAPS["icon"]), "image": text(fields.get("image"), CAPS["image"]),
                "timeout": timeout if isinstance(timeout, int) and not isinstance(timeout, bool) and timeout >= 0 else NO_TIMEOUT,
                "time": round(self.clock.now().real * 1000), "read": False, "live": live,
                "private": bool(fields.get("private")) or self.is_private(app), "transient": transient}
        if owner:
            item["owner"] = owner
        self.items = ([i for i in self.items if i["id"] != id] + [item])[-KEEP:]
        self._changed()
        return item

    def remove(self, id: str, owner: str | None = None) -> bool:
        kept = [i for i in self.items if i["id"] != id or (owner is not None and i.get("owner") != owner)]
        return self._keep(kept)

    def _keep(self, kept: list[dict]) -> bool:
        if len(kept) == len(self.items):
            return False
        self.items = kept
        self._changed()
        return True

    # The mirror's source

    def mirror_started(self, bus_id: str, owner: str):
        """Mirrored IDs only mean something to the owner that issued them, in that bus lifetime."""
        self.mirroring = True
        if (bus_id, owner) != (self.saved_bus, self.saved_owner):
            self.saved_bus, self.saved_owner = bus_id, owner
            if not self._keep([i for i in self.items if not i.get("owner")]):
                self._save()
        self.on_change()

    def mirror_owner(self, owner: str):
        self.saved_owner = owner
        self.holder_pid = 0
        if not self._keep([i for i in self.items if not i.get("owner")]):
            self._save()
            self.on_change()

    def name_holder(self, pid: int):
        """The mirror found which process owns the name. If it is our server, anything mirrored from it is a double."""
        self.holder_pid = pid
        if not (self.serving and self._keep([i for i in self.items if not i.get("owner")])):
            self.on_change()

    def mirror_stopped(self):
        self.mirroring = False
        if not self._keep([i for i in self.items if not i.get("owner")]):
            self.on_change()

    # Our server's source (adapters/dms/NotificationServer.qml)

    def serve(self, client, ids=None):
        """The view started our server. `ids` are the items it still holds live."""
        if ids is not None and not (isinstance(ids, list) and all(isinstance(i, str) for i in ids)):
            raise bad_args("ids must be a list of notification ids")
        self.server = client
        held = set(ids or [])
        self.items = [{**i, "live": i["id"] in held} for i in self.items]
        self._changed()
        return self.snapshot()

    def _served(self, client):
        if client is not self.server:
            raise OpError("not-serving", "only the notification server may do this")

    def ingest(self, client, id=None, transient=False, silent=False, **fields):
        """`silent`: the sender plays its own sound (the suppress-sound hint)."""
        self._served(client)
        if not isinstance(id, str) or not SERVER_ID.fullmatch(id):
            raise bad_args("id must be 1 to 64 letters, digits, - or _")
        arrival = all(i["id"] != id for i in self.items)  # not a replace-id
        item = self.put(id, fields, live=True, transient=transient is True)
        if arrival and silent is not True and self._heard(item["urgency"]):
            self.on_sound(item["urgency"])
        writable = not any(item[flag] for flag in UNWRITTEN)
        if writable:
            self.images.mkdir(parents=True, exist_ok=True, mode=0o700)
        return {"imagePath": str(self._image_path(id)) if writable else ""}

    def _heard(self, urgency: str) -> bool:
        """Low urgency is silent; do-not-disturb lets only critical through (Z165, Z167)."""
        return urgency == "critical" or (urgency == "normal" and not self.dnd)

    def image(self, client, id):
        """The server wrote the item's picture to the path `ingest` gave it."""
        self._served(client)
        item = self.find(id)
        path = self._image_path(item["id"])
        if any(item[flag] for flag in UNWRITTEN) or not path.is_file():
            path.unlink(missing_ok=True)
            raise OpError("refused", "no image is kept for this notification")
        item["image"] = str(path)
        self._changed()

    def closed(self, client, id):
        self._served(client)
        self.remove(str(id))

    def disconnected(self, client):
        if client is self.server:
            self.server = None
            self.items = [{**i, "live": False} for i in self.items if not i["transient"]]
            self._changed()

    # Contract operations

    def mark_all_read(self):
        if any(not i["read"] for i in self.items):
            self.items = [{**i, "read": True} for i in self.items]
            self._changed()

    def dismiss(self, id):
        item = self.find(id)
        if not self.close_remote(item):
            self.remove(item["id"])

    def clear(self):
        self.items = []
        self._changed()

    # Persistence, images and expiry

    def _image_path(self, id: str) -> Path:
        return self.images / (id + ".png")

    def _sweep_images(self):
        """Delete every kept picture whose item is gone."""
        if not self.images.is_dir():
            return
        wanted = {i["image"] for i in self.items}
        for file in self.images.iterdir():
            if str(file) not in wanted:
                file.unlink(missing_ok=True)

    def _changed(self):
        self._expire(schedule_only=True)
        self._sweep_images()
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
        kept = [{k: v for k, v in i.items() if k not in (*UNWRITTEN, "live")}
                for i in self.items if not any(i.get(flag) for flag in UNWRITTEN)]
        write_json(self.path, {"busId": self.saved_bus, "owner": self.saved_owner, "items": kept})

    def _expire(self, schedule_only=False):
        now = self.clock.now()
        cutoff = (now.real - TTL) * 1000
        if not schedule_only:
            fresh = [i for i in self.items if isinstance(i.get("time"), (int, float)) and i["time"] > cutoff]
            if len(fresh) != len(self.items):
                self.items = fresh
                self._sweep_images()
                self._save()
                self.on_change()
        if self.items:
            oldest = min(i["time"] for i in self.items)
            self.scheduler.at("notifications.expire", now.boot + oldest / 1000 + TTL - now.real, lambda _: self._expire())
        else:
            self.scheduler.cancel("notifications.expire")
