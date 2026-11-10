"""Session window adjacency, never process ancestry. RAM only; no titles or contents.

An independent socket2 reader follows guards.py's connection pattern. Retain at most
one day, 512 closed nodes and 2048 focus changes; live nodes survive the horizon.
"""
from __future__ import annotations

import asyncio
import copy
import os
import time

from core.guards import hypr_dir, hypr_query

DAY = 86400


def address(value):
    return str(value or "").removeprefix("0x").lower()


class Genealogy:
    def __init__(self, now=time.time, directory=None):
        self.now = now
        self.directory = directory if directory is not None else hypr_dir()
        self.nodes = []
        self.focus = []
        self.memories = {}
        self.compositions = {}
        self.active = ""
        self.workspace = "1"
        self.serial = 0
        self.revision = 0
        self.on_change = lambda: None
        self.task = None
        self.available = False

    def live(self, addr):
        return next((n for n in reversed(self.nodes) if n["address"] == address(addr) and n["closed"] is None), None)

    def composition(self, workspace):
        return [dict(rect=n["rect"][:]) for n in self.nodes if n["workspace"] == workspace and n["closed"] is None]

    def remember(self, workspace):
        # Freeze the last complete occupied arrangement, not just the final window.
        if not self.composition(workspace) and self.compositions.get(workspace):
            self.memories[workspace] = {"at": self.now(), "rects": self.compositions.pop(workspace)}

    def open(self, addr, workspace, app, rect=None):
        if not addr or self.live(addr):
            return
        workspace = str(workspace)
        self.serial += 1
        parent = self.live(self.active)
        if not parent or parent["workspace"] != workspace:
            parent = next((n for n in reversed(self.nodes) if n["workspace"] == workspace and n["closed"] is None), None)
        self.nodes.append(dict(id=self.serial, address=address(addr), workspace=workspace,
                               app=str(app)[:160], rect=list(rect or [0, 0, 0, 0]),
                               opened=self.now(), closed=None, parent=parent["id"] if parent else None))
        self.memories.pop(workspace, None)
        self.compositions[workspace] = self.composition(workspace)

    def event(self, line):
        kind, sep, payload = line.strip().partition(">>")
        if not sep:
            return False
        changed = True
        if kind == "openwindow":
            fields = payload.split(",", 3)
            if len(fields) < 3:
                return False
            self.open(fields[0], fields[1], fields[2])  # fourth field (title) is discarded
        elif kind == "closewindow":
            node = self.live(payload)
            if not node:
                return False
            node["closed"] = self.now()
            if self.active == node["address"]:
                self.active = ""
            self.remember(node["workspace"])
        elif kind == "activewindowv2":
            addr = address(payload)
            if addr == self.active:
                return False
            self.active = addr
            node = self.live(addr)
            self.focus.append(dict(at=self.now(), address=addr, node=node["id"] if node else None, workspace=node["workspace"] if node else self.workspace))
        elif kind in ("movewindow", "movewindowv2"):
            fields = payload.split(",", 2)
            node = self.live(fields[0])
            if len(fields) < 2 or not node or node["workspace"] == fields[1]:
                return False
            old = node["workspace"]
            node["workspace"] = fields[1]
            self.remember(old)
            self.memories.pop(fields[1], None)
            self.compositions[fields[1]] = self.composition(fields[1])
        elif kind in ("workspace", "workspacev2"):
            self.workspace = payload.split(",", 1)[0]
        else:
            changed = False
        if changed:
            self.prune()
            self.revision += 1
            self.on_change()
        return changed

    def reconcile(self, clients, discover=True):
        """Whitelist geometry/class only. Startup/reconnection has no invented launch links."""
        present = set()
        for client in clients:
            addr = address(client.get("address"))
            if not addr:
                continue
            present.add(addr)
            ws = str((client.get("workspace") or {}).get("id", "1"))
            rect = list(client.get("at", [0, 0]))[:2] + list(client.get("size", [0, 0]))[:2]
            if len(rect) != 4 or not all(isinstance(v, (int, float)) for v in rect):
                rect = [0, 0, 0, 0]
            if not self.live(addr) and not discover:
                continue  # socket2 may still contain this window's opening event
            if not self.live(addr):
                self.open(addr, ws, client.get("class", ""), rect)
                self.nodes[-1]["parent"] = None  # observed, not witnessed opening
            node = self.live(addr)
            if discover and node["workspace"] != ws:
                old = node["workspace"]
                node["workspace"] = ws
                self.remember(old)
            node["rect"] = rect
            node["app"] = str(client.get("class", ""))[:160]
        for node in self.nodes:
            if discover and node["closed"] is None and node["address"] not in present:
                node["closed"] = self.now()
                self.remember(node["workspace"])
        for ws in {n["workspace"] for n in self.nodes if n["closed"] is None}:
            self.memories.pop(ws, None)
            # Preserve the fuller floor plan while windows are being removed.
            current = self.composition(ws)
            if len(current) >= len(self.compositions.get(ws, [])):
                self.compositions[ws] = current
        self.prune()
        self.revision += 1
        self.on_change()

    def prune(self):
        cutoff = self.now() - DAY
        closed = [n for n in self.nodes if n["closed"] is not None and n["closed"] >= cutoff][-512:]
        keep = {n["id"] for n in closed}
        self.nodes = [n for n in self.nodes if n["closed"] is None or n["id"] in keep]
        ids = {n["id"] for n in self.nodes}
        for node in self.nodes:
            if node["parent"] not in ids:
                node["parent"] = None
        self.focus = [f for f in self.focus if f["at"] >= cutoff][-2048:]
        self.memories = {k: v for k, v in self.memories.items() if v["at"] >= cutoff}

    def snapshot(self):
        self.prune()
        return copy.deepcopy(dict(at=self.now(), revision=self.revision, available=self.available,
                                  nodes=self.nodes, focus=self.focus, memories=self.memories,
                                  active=self.active, workspace=self.workspace))

    def start(self):
        if self.task is None and self.directory and os.environ.get("FART_HOST") != "fixture":
            self.task = asyncio.get_running_loop().create_task(self._events())

    async def _events(self):
        while True:
            writer = None
            try:
                reader, writer = await asyncio.open_unix_connection(str(self.directory / ".socket2.sock"))
                self.reconcile(await asyncio.to_thread(hypr_query, self.directory, "j/clients"))
                self.available = True
                self.on_change()
                while line := await reader.readline():
                    raw = line.decode(errors="replace")
                    kind = raw.partition(">>")[0]
                    if kind == "activewindow":
                        # Legacy class/title event has no address. Read address only; never retain title.
                        active = await asyncio.to_thread(hypr_query, self.directory, "j/activewindow")
                        self.event("activewindowv2>>" + address(active.get("address")))
                    elif self.event(raw) and kind in ("openwindow", "closewindow", "movewindow", "movewindowv2"):
                        self.reconcile(await asyncio.to_thread(hypr_query, self.directory, "j/clients"), discover=False)
            except (OSError, ValueError):
                pass
            finally:
                if writer:
                    writer.close()
                    await writer.wait_closed()
                self.available = False
                self.on_change()
            await asyncio.sleep(1)

    def stop(self):
        if self.task:
            self.task.cancel()
            self.task = None
