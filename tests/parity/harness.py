"""The parity harness (Z226 stage 0): drives a core over its socket only, so the same checks run against the
Python core and fartd-cpp (docs/CPP_CORE.md, docs/PARITY_HARNESS.md).

Which core: FART_PARITY_CORE unset or "python" runs `python3 -I core/fartd.py`; any other value is the path of a
core binary (fartd-cpp). Each core runs on private directories with the fixture host: no view, no bus, no host
actions, and a fixed time zone unless a check asks for another.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
PROTOCOL = 1
DEFAULT_TZ = "Asia/Kolkata"  # the owner's zone, no DST; DST runs pass their own
START_TIMEOUT = 10.0
REPLY_TIMEOUT = 10.0


def core_command(which: str | None = None) -> list[str]:
    which = which if which is not None else os.environ.get("FART_PARITY_CORE", "python")
    if which in ("", "python"):
        return [sys.executable, "-I", str(ROOT / "core/fartd.py")]
    path = Path(which).expanduser()
    if not path.is_file() or not os.access(path, os.X_OK):
        raise FileNotFoundError(f"FART_PARITY_CORE={which!r} is not an executable core")
    return [str(path.resolve())]


def core_name(which: str | None = None) -> str:
    which = which if which is not None else os.environ.get("FART_PARITY_CORE", "python")
    return "python" if which in ("", "python") else Path(which).name


class CoreGone(RuntimeError):
    pass


class Core:
    """One core process on its own temporary home. Use as a context manager, or start()/stop()."""

    def __init__(self, which: str | None = None, tz: str = DEFAULT_TZ, env: dict | None = None, seed: dict | None = None):
        self.command = core_command(which)
        self.name = core_name(which)
        self.tz = tz
        self.extra_env = env or {}
        self.seed = seed or {}  # {path relative to the state dir: text or JSON value}, written before the start
        self.process: subprocess.Popen | None = None
        self.temp: tempfile.TemporaryDirectory | None = None

    # Directories -------------------------------------------------------------------------------------------
    def _layout(self):
        self.temp = tempfile.TemporaryDirectory(prefix="parity-")
        base = Path(self.temp.name)
        self.base = base
        self.home = base / "home"
        self.runtime = base / "run"
        self.state_dir = self.home / "state/fart-next"
        self.cache_dir = self.home / "cache/fart-next"
        self.fixture_log = base / "fixture.jsonl"
        self.log_path = base / "core.log"
        self.runtime.mkdir(mode=0o700)
        self.state_dir.mkdir(parents=True, mode=0o700)
        for relative, content in self.seed.items():
            path = self.state_dir / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content if isinstance(content, str) else json.dumps(content))
        no_bus = f"unix:path={base}/no-bus"
        # Only what a core needs: inherited FART_* settings could enable the supervisor or the resident view.
        self.env = dict(PATH=os.environ.get("PATH", os.defpath), HOME=str(self.home), TZ=self.tz, LANG="C.UTF-8",
                        XDG_RUNTIME_DIR=str(self.runtime), XDG_STATE_HOME=str(self.home / "state"),
                        XDG_CACHE_HOME=str(self.home / "cache"), XDG_CONFIG_HOME=str(self.home / "config"),
                        XDG_DATA_HOME=str(self.home / "data"),
                        DBUS_SESSION_BUS_ADDRESS=no_bus, DBUS_SYSTEM_BUS_ADDRESS=no_bus,
                        FART_RUNTIME_DIR=str(self.runtime), FART_STATE_DIR=str(self.state_dir),
                        FART_CACHE_DIR=str(self.cache_dir), FART_HOST="fixture", FART_MIRROR="0",
                        FART_FIXTURE_LOG=str(self.fixture_log), FART_VIEW_ENTRY=str(base / "no-view.qml"))
        self.env.update(self.extra_env)  # the caller's settings win (a nested check passes its own view and PATH)

    @property
    def socket_path(self) -> Path:
        return self.runtime / "core.sock"

    # Process -----------------------------------------------------------------------------------------------
    def start(self) -> "Core":
        if self.temp is None:
            self._layout()
        log = self.log_path.open("ab")
        self.process = subprocess.Popen(self.command, env=self.env, cwd="/", stdin=subprocess.DEVNULL,
                                        stdout=subprocess.DEVNULL, stderr=log, start_new_session=True)
        log.close()
        deadline = time.monotonic() + START_TIMEOUT
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise CoreGone(f"{self.name} exited with {self.process.returncode}:\n{self.log()}")
            try:
                self.connect().close()
                return self
            except (FileNotFoundError, ConnectionRefusedError):
                time.sleep(0.02)
        raise CoreGone(f"{self.name} did not open its socket in {START_TIMEOUT} s:\n{self.log()}")

    def stop(self, timeout: float = 5.0) -> int | None:
        """SIGTERM, as the session does; returns the exit code."""
        if self.process and self.process.poll() is None:
            self.process.send_signal(signal.SIGTERM)
            try:
                self.process.wait(timeout)
            except subprocess.TimeoutExpired:
                os.killpg(self.process.pid, signal.SIGKILL)
                self.process.wait()
        return self.process.returncode if self.process else None

    def restart(self) -> "Core":
        self.stop()
        return self.start()

    def close(self):
        self.stop()
        if self.temp:
            self.temp.cleanup()
            self.temp = None

    def __enter__(self):
        return self.start()

    def __exit__(self, *exc):
        self.close()

    # Reading what the core left behind ------------------------------------------------------------------------
    def log(self) -> str:
        try:
            return self.log_path.read_text(errors="replace")
        except FileNotFoundError:
            return ""

    def state_bytes(self, relative: str) -> bytes | None:
        try:
            return (self.state_dir / relative).read_bytes()
        except FileNotFoundError:
            return None

    def state(self, relative: str):
        data = self.state_bytes(relative)
        return None if data is None else json.loads(data)

    def state_files(self) -> dict[str, bytes]:
        return {str(p.relative_to(self.state_dir)): p.read_bytes()
                for p in sorted(self.state_dir.rglob("*")) if p.is_file()}

    def host_calls(self) -> list:
        try:
            return [json.loads(line) for line in self.fixture_log.read_text().splitlines()]
        except FileNotFoundError:
            return []

    def wait_host_call(self, predicate, timeout: float = 5.0):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            for call in self.host_calls():
                if predicate(call):
                    return call
            time.sleep(0.02)
        raise AssertionError(f"no matching host call in {timeout} s; saw {self.host_calls()}")

    # Clients -----------------------------------------------------------------------------------------------
    def connect(self) -> "Peer":
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.settimeout(REPLY_TIMEOUT)
        try:
            sock.connect(str(self.socket_path))
        except OSError:
            sock.close()
            raise
        return Peer(sock)

    def client(self, kind: str = "cli") -> "Peer":
        peer = self.connect()
        peer.hello(kind)
        return peer


class Peer:
    """One socket connection. Replies are matched by id; events received meanwhile are kept in order."""

    def __init__(self, sock: socket.socket):
        self.sock = sock
        self.buffer = b""
        self.next_id = 1
        self.events: list[dict] = []
        self.transcript: list[tuple[str, dict]] = []  # ("sent"|"got", message), for parity diffs

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    def send_raw(self, data: bytes):
        self.sock.sendall(data)

    def send(self, message: dict):
        self.transcript.append(("sent", message))
        self.sock.sendall(json.dumps(message, separators=(",", ":"), ensure_ascii=False).encode() + b"\n")

    def read_line(self, timeout: float = REPLY_TIMEOUT) -> bytes:
        deadline = time.monotonic() + timeout
        while b"\n" not in self.buffer:
            left = deadline - time.monotonic()
            if left <= 0:
                raise TimeoutError("no line from the core")
            self.sock.settimeout(left)
            chunk = self.sock.recv(65536)
            if not chunk:
                raise CoreGone("the core closed the connection")
            self.buffer += chunk
        line, self.buffer = self.buffer.split(b"\n", 1)
        return line + b"\n"

    def read(self, timeout: float = REPLY_TIMEOUT) -> dict:
        message = json.loads(self.read_line(timeout))
        self.transcript.append(("got", message))
        return message

    def closed_by_core(self, timeout: float = 2.0) -> bool:
        """True when the core closes this connection within the timeout (after flushing what it had)."""
        return self.until_closed(timeout)[1]

    def until_closed(self, timeout: float = 2.0) -> tuple[list[dict], bool]:
        """What the core still sends, and whether it then closes this connection within the timeout."""
        got, deadline = [], time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                got.append(self.read(deadline - time.monotonic()))
            except (CoreGone, ConnectionResetError):
                return got, True
            except (TimeoutError, socket.timeout):
                break
        return got, False

    def call(self, op: str, **args) -> dict:
        """Send a request and return the whole reply ({id, ok, result|error}); events met on the way are kept."""
        request_id = self.next_id
        self.next_id += 1
        self.send({"id": request_id, "op": op, "args": args})
        while True:
            message = self.read()
            if "event" in message:
                self.events.append(message)
            elif message.get("id") == request_id:
                return message

    def request(self, op: str, **args):
        """A request that must succeed; returns its result."""
        reply = self.call(op, **args)
        if not reply.get("ok"):
            raise AssertionError(f"{op} failed: {reply.get('error')}")
        return reply["result"]

    def error(self, op: str, **args) -> str:
        """A request that must fail; returns its error code."""
        reply = self.call(op, **args)
        if reply.get("ok"):
            raise AssertionError(f"{op} unexpectedly succeeded: {reply.get('result')}")
        return reply["error"]["code"]

    def notify(self, op: str, **args):
        """A request without an id: the core sends nothing back."""
        self.send({"op": op, "args": args})

    def hello(self, kind: str = "cli") -> dict:
        return self.request("hello", client=kind, protocol=PROTOCOL)

    def subscribe(self, *topics: str) -> dict:
        return self.request("subscribe", topics=list(topics))

    def event(self, topic: str, predicate=lambda data: True, timeout: float = 5.0) -> dict:
        """The next event on a topic whose data matches (already-received events first). Returns the message."""
        for i, message in enumerate(self.events):
            if message["event"] == topic and predicate(message["data"]):
                del self.events[: i + 1]
                return message
        self.events.clear()
        deadline = time.monotonic() + timeout
        while True:
            left = deadline - time.monotonic()
            if left <= 0:
                raise AssertionError(f"no matching {topic} event in {timeout} s")
            try:
                message = self.read(left)
            except (TimeoutError, socket.timeout):
                raise AssertionError(f"no matching {topic} event in {timeout} s") from None
            if message.get("event") == topic and predicate(message["data"]):
                return message
            if "event" in message:
                continue

    def drain(self, quiet: float = 0.2) -> list[dict]:
        """Every message that arrives until the line goes quiet."""
        got = []
        while True:
            try:
                got.append(self.read(quiet))
            except (TimeoutError, socket.timeout):
                return got


def available_cores() -> list[str]:
    """Cores the diff tool can compare: Python always, fartd-cpp when built (core-cpp/build/fartd-cpp)."""
    cores = ["python"]
    built = ROOT / "core-cpp/build/fartd-cpp"
    if built.is_file() and os.access(built, os.X_OK):
        cores.append(str(built))
    return cores


def have_tz(name: str) -> bool:
    return Path("/usr/share/zoneinfo", name).is_file()


def which(tool: str) -> bool:
    return shutil.which(tool) is not None
