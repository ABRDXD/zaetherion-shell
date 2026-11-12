#!/usr/bin/env python3
"""Run the DMS adapter under Quickshell offscreen against the stand-in DMS, and drive it over `qs ipc`.

Used by tests/test_dms_adapter.py. Nothing real is contacted: DMS_SOCKET points at a stand-in in a private
runtime folder, and the session buses are pointed at nothing. A Unix socket path is limited to 108 bytes, so
the private folder is short and under /tmp (docs/DMS_ADAPTER.md §9).
"""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
TREE = ("view", "adapters", "core", "tools", "assets")
FIXTURE = ROOT / "tests/fixtures/dms/s0-v2.1.0.json"


class Stand:
    """A stand-in DMS as a subprocess, so a test can SIGKILL it."""

    def __init__(self, directory: Path, name: str = "dms-1.sock", script: dict | None = None, fixture: Path = FIXTURE):
        self.path = str(directory / name)
        self.log = str(directory / (name + ".log"))
        Path(self.log).write_text("")
        command = [sys.executable, "-I", str(ROOT / "tools/dms_replay.py"), str(fixture), self.path, "--log", self.log]
        if script is not None:
            script_path = directory / (name + ".script.json")
            script_path.write_text(json.dumps(script))
            command += ["--script", str(script_path)]
        self.process = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(200):
            if os.path.exists(self.path):
                break
            time.sleep(0.02)

    def requests(self):
        return [json.loads(l) for l in Path(self.log).read_text().splitlines() if l.strip()]

    def methods(self):
        return [r["method"] for r in self.requests() if r["event"] == "request"]

    def subscriptions(self):
        return [r["params"].get("services") for r in self.requests() if r.get("method") == "subscribe"]

    def kill(self):
        self.process.send_signal(signal.SIGKILL)
        self.process.wait(5)

    def stop(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(5)
            except subprocess.TimeoutExpired:
                self.process.kill()


class Harness:
    def __init__(self, socket_path: str, directory: Path, harness: str = "AdapterHarness.qml"):
        self.dir = directory
        bundle = directory / "bundle"
        bundle.mkdir()
        for name in TREE:
            shutil.copytree(ROOT / name, bundle / name, ignore=shutil.ignore_patterns("__pycache__"))
        self.entry = bundle / harness
        shutil.copy2(ROOT / "tools/dmstest" / harness, self.entry)
        run = directory / "r"
        run.mkdir(mode=0o700)
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=str(run),
                   XDG_STATE_HOME=str(directory / "s"), XDG_CONFIG_HOME=str(directory / "c"), XDG_CACHE_HOME=str(directory / "k"),
                   FART_STATE_DIR=str(directory / "s/f"), FART_CACHE_DIR=str(directory / "k/f"),
                   FART_CORE_SOCKET=str(directory / "absent.sock"), DMS_SOCKET=socket_path,
                   HYPRLAND_INSTANCE_SIGNATURE="", WAYLAND_DISPLAY="", PIPEWIRE_RUNTIME_DIR="/nonexistent/fart-fixture",
                   DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent/fart-fixture",
                   DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent/fart-fixture")
        self.env = env
        self.log = open(directory / "qs.log", "w")
        self.process = subprocess.Popen(["qs", "-n", "--no-color", "-p", str(self.entry)], env=env, stdin=subprocess.DEVNULL,
                                        stdout=self.log, stderr=subprocess.STDOUT)
        self.wait_for_ipc()

    def wait_for_ipc(self, timeout: float = 15):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.process.poll() is not None:
                raise RuntimeError("qs exited early:\n" + self.output())
            done = self._ipc("call", "t", "state", check=False)
            if done.returncode == 0:
                return
            time.sleep(0.05)
        raise RuntimeError("qs did not answer over ipc:\n" + self.output())

    def _ipc(self, *args, check=True):
        return subprocess.run(["qs", "ipc", "--pid", str(self.process.pid), *args], env=self.env, capture_output=True,
                              text=True, timeout=15, check=False)

    def ipc(self, function: str, *args: str, target: str = "t") -> str:
        done = self._ipc("call", target, function, *args)
        if done.returncode != 0:
            raise RuntimeError(f"ipc {function} failed: {done.stderr or done.stdout}")
        return done.stdout.strip()

    def state(self) -> dict:
        return json.loads(self.ipc("state"))

    def wait_for(self, check, timeout: float = 6.0, step: float = 0.05):
        """Poll state() until check(state) is true; return it, or the last state on timeout (the caller asserts)."""
        deadline = time.time() + timeout
        state = self.state()
        while time.time() < deadline and not check(state):
            time.sleep(step)
            state = self.state()
        return state

    def output(self) -> str:
        self.log.flush()
        return (self.dir / "qs.log").read_text()

    def stop(self):
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(5)
            except subprocess.TimeoutExpired:
                self.process.kill()
        self.log.close()


def private_dir() -> tempfile.TemporaryDirectory:
    return tempfile.TemporaryDirectory(prefix="dms", dir="/tmp", ignore_cleanup_errors=True)
