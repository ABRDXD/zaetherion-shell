"""The FART core daemon: python3 -I core/fartd.py (docs/CORE.md §1)."""
from __future__ import annotations

import sys

# asyncio imports ssl when it can, mapping OpenSSL (~5 MiB RSS); the core never uses TLS.
sys.modules.setdefault("ssl", None)

import asyncio  # noqa: E402
import fcntl  # noqa: E402
import logging  # noqa: E402
import os  # noqa: E402
from pathlib import Path  # noqa: E402
import signal  # noqa: E402
import socket  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))  # -I leaves the script directory off sys.path

from core.app import Core  # noqa: E402
from core.clock import SystemClock, TimerfdScheduler  # noqa: E402
from core.host import Host, load_profile  # noqa: E402
from core.notifications import BusctlSource  # noqa: E402
from core.protocol import MAX_LINE  # noqa: E402
from core.supervisor import Child, DmsPorts, SessionWatch, Supervisor  # noqa: E402
from core.view import PressureTrigger, spawn_quickshell, stop_foreign_instance  # noqa: E402

LOG_KEEP = 256 * 1024
log = logging.getLogger("fart.core")


def runtime_dir() -> Path:
    path = Path(os.environ.get("FART_RUNTIME_DIR") or Path(os.environ["XDG_RUNTIME_DIR"]) / "fart-next")
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    return path


def setup_logging(path: Path):
    try:
        data = path.read_bytes()
        if len(data) > LOG_KEEP:
            path.write_bytes(data[-LOG_KEEP:])
    except FileNotFoundError:
        pass
    handler = logging.FileHandler(path) if os.environ.get("FART_LOG") != "-" else logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s"))
    logging.basicConfig(level=logging.INFO, handlers=[handler])
    if path.exists():
        os.chmod(path, 0o600)


def listening_socket(path: Path) -> tuple[socket.socket, bool]:
    """An inherited systemd socket (LISTEN_FDS) or our own; the second value says whether we own the path."""
    if os.environ.get("LISTEN_PID") == str(os.getpid()) and int(os.environ.get("LISTEN_FDS") or 0) >= 1:
        return socket.socket(fileno=3), False
    try:
        path.unlink()  # stale: we hold the single-instance lock
    except FileNotFoundError:
        pass
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    old = os.umask(0o177)
    try:
        sock.bind(str(path))
    finally:
        os.umask(old)
    sock.listen(16)
    return sock, True


def supervise(core: Core, scheduler, env: dict, runtime: Path) -> SessionWatch | None:
    """FART_SUPERVISE=dms: the core starts `dms run`, restarts it and ends with the compositor
    (docs/SUPERVISOR.md). Off unless asked for, until the session is switched over from tools/session-start."""
    if os.environ.get("FART_SUPERVISE") != "dms":
        return None
    watch = None
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if signature:
        watch = SessionWatch(Path(os.environ["XDG_RUNTIME_DIR"]) / "hypr" / signature, core.stopping.set)
        watch.start()
    resident = os.environ.get("FART_RESIDENT_DIR")  # unset until S3: DMS runs its own UI
    ports = DmsPorts(env, Path(os.environ["XDG_RUNTIME_DIR"]), runtime / "dms.log", Path(resident) if resident else None,
                     session_alive=watch.alive if watch else lambda: True)
    supervisor = Supervisor()
    supervisor.add(Child("dms", core.clock, scheduler, ports))
    core.attach_supervisor(supervisor)
    supervisor.start()
    return watch


async def serve(runtime: Path, state_dir: Path):
    loop = asyncio.get_running_loop()
    clock = SystemClock()
    scheduler = TimerfdScheduler(clock, loop)
    host = Host(load_profile(os.environ["FART_HOST"]))
    sock_path = runtime / "core.sock"
    entry = Path(os.environ.get("FART_VIEW_ENTRY") or ROOT / "shell.qml")
    env = dict(os.environ, FART_CORE_SOCKET=str(sock_path), FART_STATE_DIR=str(state_dir))
    core = Core(clock, scheduler, host, state_dir, spawn=lambda: spawn_quickshell(entry, env),
                pressure=lambda callback: PressureTrigger(loop, callback), before_spawn=lambda: stop_foreign_instance(entry, None))
    sock, owned = listening_socket(sock_path)
    server = await asyncio.start_unix_server(core.server.handle, sock=sock, limit=MAX_LINE)
    core.view.start_checks()  # off the first open's path (docs/CORE.md §7)
    for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        loop.add_signal_handler(signum, core.stopping.set)
    watch = supervise(core, scheduler, env, runtime)
    source = None
    if os.environ.get("FART_MIRROR") != "0":
        source = BusctlSource(core.mirror, core.track)
        source.start()
    log.info("core %s up (pid %d, host %s, state %s)", core.core_snapshot()["version"], os.getpid(), host.name, state_dir)
    await core.stopping.wait()
    log.info("core stopping")
    server.close()
    if watch:
        watch.stop()
    await core.close()
    if source:
        await source.stop()
    if owned:
        try:
            sock_path.unlink()
        except FileNotFoundError:
            pass
    await asyncio.sleep(0)  # let the shutdown reply flush


def main():
    state = os.environ.get("FART_STATE_DIR")
    if not state or not os.environ.get("FART_HOST"):
        # Until cutover the default state would be the archive's own; never write it by accident.
        raise SystemExit("fartd: set FART_STATE_DIR and FART_HOST (fart-next does this)")
    runtime = runtime_dir()
    lock = (runtime / "core.lock").open("a")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit("fartd: another core is already running")
    setup_logging(runtime / "core.log")
    try:
        asyncio.run(serve(runtime, Path(state)))
    except Exception:
        log.exception("core failed")
        raise


if __name__ == "__main__":
    main()
