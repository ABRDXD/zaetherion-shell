"""Overdrive guard monitors. They run only while Overdrive is requested (docs/CORE.md §6.3)."""
from __future__ import annotations

import asyncio
import json
import logging
import os
from pathlib import Path
import re
import subprocess
from typing import Callable

log = logging.getLogger("fart.guards")
OFF_DEBOUNCE = 2.0
DGPU_INTERVAL = 5.0
FULLSCREEN_DEBOUNCE = 0.1
HYPR_EVENTS = {"fullscreen", "workspace", "workspacev2", "activewindow", "activewindowv2", "focusedmon", "focusedmonv2",
               "closewindow", "movewindow", "movewindowv2", "activespecial", "activespecialv2"}


def find_dgpu() -> Path | None:
    """runtime_status of the display-class PCI device that did not boot the screen."""
    for device in sorted(Path("/sys/bus/pci/devices").glob("*")):
        try:
            if (device / "class").read_text().startswith("0x03") and (device / "boot_vga").read_text().strip() == "0":
                return device / "power/runtime_status"
        except OSError:
            continue
    return None


class Guard:
    name = ""

    def __init__(self, report: Callable[[str, bool], None]):
        self.report = report  # report(name, on)
        self.on = False

    def available(self) -> bool:
        return True

    def start(self) -> bool:
        return False

    def stop(self):
        pass

    def set(self, on: bool):
        if on != self.on:
            self.on = on
            self.report(self.name, on)


class DgpuGuard(Guard):
    name = "dgpu"

    def __init__(self, report, path: Path | None = None):
        super().__init__(report)
        self.path = path or find_dgpu()
        self.handle = None

    def available(self):
        return self.path is not None and self.path.exists()

    def read(self) -> bool:
        try:
            return self.path.read_text().strip() in ("active", "resuming")
        except OSError:
            return False

    def start(self):
        if not self.available():
            return False
        self.on = self.read()
        self._next()
        return self.on

    def _next(self):
        # sysfs runtime_status cannot be polled; reading it never wakes the device.
        self.handle = asyncio.get_running_loop().call_later(DGPU_INTERVAL, self._tick)

    def _tick(self):
        self.set(self.read())
        self._next()

    def stop(self):
        if self.handle:
            self.handle.cancel()
            self.handle = None


def hypr_dir() -> Path | None:
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    return Path(runtime) / "hypr" / signature if signature and runtime else None


def hypr_query(directory: Path, command: str):
    import socket
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(1)
        sock.connect(str(directory / ".socket.sock"))
        sock.sendall(command.encode())
        chunks = []
        while chunk := sock.recv(65536):
            chunks.append(chunk)
    return json.loads(b"".join(chunks))


def any_fullscreen(directory: Path) -> bool:
    monitors = hypr_query(directory, "j/monitors")
    visible = set()
    for monitor in monitors:
        for key in ("activeWorkspace", "specialWorkspace"):
            workspace = monitor.get(key) or {}
            if workspace.get("name"):
                visible.add(workspace.get("id"))
    return any(w.get("hasfullscreen") and w.get("id") in visible for w in hypr_query(directory, "j/workspaces"))


def focused_fullscreen(directory: Path | None = None) -> bool:
    """The focused window is fullscreen (read-only). False when there is no compositor to ask."""
    directory = directory or hypr_dir()
    if not directory:
        return False
    try:
        window = hypr_query(directory, "j/activewindow")
    except (OSError, ValueError) as error:
        log.warning("fullscreen query failed: %s", error)
        return False
    return isinstance(window, dict) and bool(window.get("fullscreen"))


class FullscreenGuard(Guard):
    name = "fullscreen"

    def __init__(self, report, directory: Path | None = None):
        super().__init__(report)
        self.directory = directory or hypr_dir()
        self.task = None
        self.pending = None

    def available(self):
        return bool(self.directory and (self.directory / ".socket2.sock").exists())

    def check(self) -> bool:
        try:
            return any_fullscreen(self.directory)
        except (OSError, ValueError) as error:
            log.warning("fullscreen query failed: %s", error)
            return False

    def start(self):
        if not self.available():
            return False
        self.on = self.check()
        self.task = asyncio.get_running_loop().create_task(self._events())
        return self.on

    async def _events(self):
        try:
            reader, writer = await asyncio.open_unix_connection(str(self.directory / ".socket2.sock"))
        except OSError as error:
            log.warning("no Hyprland event socket: %s", error.strerror)
            return
        try:
            while line := await reader.readline():
                if line.split(b">>", 1)[0].decode(errors="replace") in HYPR_EVENTS:
                    self._soon()
        finally:
            writer.close()

    def _soon(self):
        if self.pending:
            self.pending.cancel()
        self.pending = asyncio.get_running_loop().call_later(FULLSCREEN_DEBOUNCE, lambda: self.set(self.check()))

    def stop(self):
        for handle in (self.task, self.pending):
            if handle:
                handle.cancel()
        self.task = self.pending = None


class BatteryGuard(Guard):
    """UPower OnBattery. The system bus cannot be watched by the user-bus monitor, so gdbus subscribes by AddMatch."""
    name = "battery"
    PATTERN = re.compile(rb"'OnBattery': <(true|false)>")

    def __init__(self, report):
        super().__init__(report)
        self.process = None
        self.task = None

    def read(self):
        try:
            out = subprocess.run(["busctl", "--system", "get-property", "org.freedesktop.UPower", "/org/freedesktop/UPower",
                                  "org.freedesktop.UPower", "OnBattery"], capture_output=True, text=True, timeout=2)
        except (OSError, subprocess.SubprocessError):
            return None
        return out.stdout.strip() == "b true" if out.returncode == 0 else None

    def available(self):
        return self.read() is not None

    def start(self):
        state = self.read()
        if state is None:
            return False
        self.on = state
        self.task = asyncio.get_running_loop().create_task(self._monitor())
        return self.on

    async def _monitor(self):
        try:
            self.process = await asyncio.create_subprocess_exec(
                "gdbus", "monitor", "--system", "--dest", "org.freedesktop.UPower", "--object-path", "/org/freedesktop/UPower",
                stdin=asyncio.subprocess.DEVNULL, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL)
        except OSError as error:
            log.warning("no UPower monitor: %s", error.strerror)
            return
        while line := await self.process.stdout.readline():
            match = self.PATTERN.search(line)
            if match:
                self.set(match.group(1) == b"true")

    def stop(self):
        if self.process and self.process.returncode is None:
            self.process.terminate()
        if self.task:
            self.task.cancel()
        self.process = self.task = None


class SessionGuard(Guard):
    name = "session"

    def __init__(self, report, active: Callable[[], bool] = lambda: False):
        super().__init__(report)
        self.active = active
        self.running = False

    def start(self):
        self.running = True
        self.on = self.active()
        return self.on

    def stop(self):
        self.running = False

    def changed(self):
        if self.running:
            self.set(self.active())


class Guards:
    """Starts and stops every guard together; guard-on reports at once, guard-off after 2 s of quiet."""

    def __init__(self, report: Callable[[str, bool], None], guards: list[Callable] | None = None):
        self.report = report
        self.debounce: dict[str, asyncio.TimerHandle] = {}
        factories = guards or [FullscreenGuard, BatteryGuard, SessionGuard]  # the NVIDIA card is Overdrive's own now (docs/OVERDRIVE.md §33)
        self.items = [factory(self._raw) for factory in factories]
        self.by_name = {guard.name: guard for guard in self.items}
        self._availability = None

    def _raw(self, name: str, on: bool):
        pending = self.debounce.pop(name, None)
        if pending:
            pending.cancel()
        if on:
            self.report(name, True)
        else:
            self.debounce[name] = asyncio.get_running_loop().call_later(OFF_DEBOUNCE, lambda: self._off(name))

    def _off(self, name: str):
        self.debounce.pop(name, None)
        if not self.by_name[name].on:
            self.report(name, False)

    def start(self) -> set[str]:
        self._availability = {guard.name: guard.available() for guard in self.items}
        return {guard.name for guard in self.items if guard.start()}

    def stop(self):
        for guard in self.items:
            guard.stop()
            guard.on = False
        for handle in self.debounce.values():
            handle.cancel()
        self.debounce.clear()

    def availability(self) -> dict:
        return {name: ("available" if ok else "unavailable") for name, ok in (self._availability or {}).items()}
