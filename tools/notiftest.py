#!/usr/bin/env python3
"""A private session bus, a private core and the view that core spawns, for the notification tests
(tests/test_notification_server.py).

Nothing of the desktop is contacted: the bus is a dbus-daemon started here, the core runs the fixture host
profile in a private folder, and every sender (`notify-send`, `gdbus`) is given that bus's address. The core only
accepts the view it spawned itself, so the harness is its resident view (Z159) rather than a process of ours.
"""
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import dmstest  # noqa: E402

SERVICE = "org.freedesktop.Notifications"
OBJECT = "/org/freedesktop/Notifications"
NEEDS = ("qs", "dbus-daemon", "busctl", "gdbus", "notify-send")
NOWHERE = "unix:path=/nonexistent/fart-fixture"
HARNESS = "NotificationHarness.qml"


def missing() -> list[str]:
    return [tool for tool in NEEDS if not shutil.which(tool)]


class Bus:
    def __init__(self):
        out = subprocess.run(["dbus-daemon", "--session", "--fork", "--print-address=1", "--print-pid=1"],
                             capture_output=True, text=True, check=True).stdout.split()
        self.address, self.pid = out[0], int(out[1])
        self.env = dict(os.environ, DBUS_SESSION_BUS_ADDRESS=self.address, DBUS_SYSTEM_BUS_ADDRESS=NOWHERE)

    def stop(self):
        try:
            os.kill(self.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass

    def send(self, *args: str, wait: bool = True):
        """notify-send on this bus. With wait=False the running sender is returned (it waits for an action)."""
        argv = ["notify-send", *args]
        if not wait:
            return subprocess.Popen(argv, env=self.env, stdout=subprocess.PIPE, text=True)
        return subprocess.run(argv, env=self.env, capture_output=True, text=True, timeout=10, check=True).stdout.strip()

    def call(self, method: str, *args: str) -> str:
        return subprocess.run(["gdbus", "call", "--session", "--dest", SERVICE, "--object-path", OBJECT, "--method",
                               f"{SERVICE}.{method}", *args], env=self.env, capture_output=True, text=True, timeout=10).stdout.strip()


class Core:
    """fartd with the fixture host profile, the bus mirror on, and `view` as its resident view."""

    def __init__(self, directory: Path, bus: Bus, view: "View"):
        self.runtime = directory / "cr"
        self.runtime.mkdir(mode=0o700, exist_ok=True)
        self.socket = self.runtime / "core.sock"
        self.env = dict(view.env, HOME=str(directory / "h"), XDG_DATA_HOME=str(directory / "h/data"),
                        DBUS_SESSION_BUS_ADDRESS=bus.address, DBUS_SYSTEM_BUS_ADDRESS=NOWHERE,
                        FART_RUNTIME_DIR=str(self.runtime), FART_STATE_DIR=str(directory / "cs"), FART_HOST="fixture",
                        FART_FIXTURE_LOG=str(directory / "fixture.jsonl"), FART_NOTIFICATION_SERVER="1",
                        FART_RESIDENT_VIEW="1", FART_VIEW_ENTRY=str(view.entry), FART_VIEW_STDOUT=str(view.dir / "qs.log"))
        for name in ("FART_CORE_SOCKET", "FART_SUPERVISE", "FART_MIRROR", "FART_LOG"):
            self.env.pop(name, None)
        self.process = subprocess.Popen([sys.executable, "-I", str(ROOT / "core/fartd.py")], env=self.env,
                                        stdin=subprocess.DEVNULL)
        deadline = time.time() + 10
        while not self.socket.exists():
            if self.process.poll() is not None or time.time() > deadline:
                raise RuntimeError("the core did not start: " + self.log())
            time.sleep(0.05)

    def request(self, op: str, **args):
        """One operation as the command-line client would send it."""
        with socket.socket(socket.AF_UNIX) as sock:
            sock.settimeout(5)
            sock.connect(str(self.socket))
            lines = sock.makefile("rw")
            for number, (name, body) in enumerate((("hello", {"client": "cli", "protocol": 1}), (op, args)), 1):
                lines.write(json.dumps({"id": number, "op": name, "args": body}) + "\n")
                lines.flush()
                reply = json.loads(lines.readline())
            return reply.get("result")

    def view_pid(self) -> int:
        return (self.request("status") or {}).get("view", {}).get("pid") or 0

    def log(self) -> str:
        path = self.runtime / "core.log"
        return path.read_text() if path.exists() else ""

    def stop(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(10)
            except subprocess.TimeoutExpired:
                self.process.kill()


class SpawnedView:
    """Stands for the Popen object of a view the core started."""

    def __init__(self, pid: int):
        self.pid = pid

    def poll(self):
        try:
            os.kill(self.pid, 0)
        except ProcessLookupError:
            return 1
        return None


class View(dmstest.Harness):
    """The harness as the core's resident view: prepared here, started and restarted by the core."""

    def __init__(self, directory: Path, harness: str = HARNESS):
        self.prepare("", directory, harness)
        self.log = open(directory / "qs.log", "a")   # the core appends the view's console here
        self.process = None

    def attach(self, core: Core, after: int = 0, timeout: float = 15):
        """Follow the view the core is running now (a pid other than `after`) and wait until it answers."""
        deadline = time.time() + timeout
        pid = core.view_pid()
        while pid in (0, after) and time.time() < deadline:
            time.sleep(0.05)
            pid = core.view_pid()
        if pid in (0, after):
            raise RuntimeError("the core started no view: " + core.log()[-1500:])
        self.process = SpawnedView(pid)
        self.wait_for_ipc()
        return self

    def kill(self):
        os.kill(self.process.pid, signal.SIGKILL)

    def stop(self):
        self.log.close()   # the core stops its own view
