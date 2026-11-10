"""Private core and offscreen fixture view shared by measurements and state tests."""
from contextlib import ExitStack, contextmanager
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.fart_next import try_connect
from tools.smoke import TREE

PAGES = ("home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex")


class Fixture:
    def __init__(self, process, connection, env):
        self.process = process
        self.request = connection.request
        self.env = env
        self.log = Path(env["FART_VIEW_STDOUT"])

    def state(self):
        return self.request("status")["view"]

    def wait_state(self, opened, page):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            state = self.state()
            if (state["state"], state["open"], state["page"]) == ("ready", opened, page):
                return state
            time.sleep(0.02)
        raise RuntimeError(f"expected ready/open={opened}/{page}, last state {state}")

    def navigate(self):
        for page in PAGES:
            self.request("view.open", page=page)
            self.wait_state(True, page)
            time.sleep(0.25)  # allow the room loader and the frame it scheduled to finish


def stop(process):
    if process.poll() is None:
        process.terminate()  # core handles SIGTERM and joins its view
    process.wait(timeout=8)


def desktop_env(env):
    """Put the fixture view on the caller's Wayland display (private runtime dir, absolute socket)."""
    display = os.environ.get("WAYLAND_DISPLAY")
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not display or not runtime:
        raise RuntimeError("desktop measurement needs WAYLAND_DISPLAY and XDG_RUNTIME_DIR")
    env = dict(env, QT_QPA_PLATFORM="wayland", WAYLAND_DISPLAY=os.path.join(runtime, display),
               QSG_RHI_PROFILE="1", FART_FRAME_PROBE="1")
    env.pop("QT_QUICK_BACKEND")
    return env


@contextmanager
def private_core(*, reap_after=None, source=ROOT, desktop=False, cache_home=None, extra_env=None):
    """A private core and fixture view built from `source` (a checkout), offscreen unless `desktop`."""
    source = Path(source).resolve()  # the core runs with the private base as its cwd
    with ExitStack() as stack:
        base = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="fart-m3-")))
        bundle = base / "bundle"
        bundle.mkdir()
        for name in TREE:
            path = Path(source) / name
            if path.is_dir():
                shutil.copytree(path, bundle / name, ignore=shutil.ignore_patterns("__pycache__"))
            else:
                shutil.copy2(path, bundle / name)
        shutil.copy2(ROOT / "tools/measure/FixtureView.qml", bundle)
        runtime = base / "run"
        runtime.mkdir(mode=0o700)
        env = dict(PATH=os.defpath, LANG="C.UTF-8", HOME=str(base), XDG_RUNTIME_DIR=str(runtime),
                   XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"),
                   XDG_STATE_HOME=str(base / "state"), XDG_DATA_HOME=str(base / "data"),
                   FART_RUNTIME_DIR=str(runtime / "core"), FART_STATE_DIR=str(base / "state/fixture"),
                   FART_CACHE_DIR=str(base / "cache/fixture"), FART_MIRROR="0", FART_HOST="fixture",
                   FART_FIXTURE_LOG=str(base / "actions"), FART_VIEW_ENTRY=str(bundle / "FixtureView.qml"),
                   FART_VIEW_STDOUT=str(base / "view.log"), QT_QPA_PLATFORM="offscreen",
                   QT_QUICK_BACKEND="software", QSG_RENDER_TIMING="1",
                   QT_LOGGING_RULES="qt.scenegraph.time.renderloop=true",
                   DBUS_SESSION_BUS_ADDRESS="unix:path=" + str(base / "no-bus"),
                   DBUS_SYSTEM_BUS_ADDRESS="unix:path=" + str(base / "no-bus"))
        if desktop:
            env = desktop_env(env)
        if cache_home is not None:
            # A persistent XDG_CACHE_HOME keeps Quickshell's QML compile cache warm across runs.
            env["XDG_CACHE_HOME"] = str(cache_home)
        env.update(extra_env or {})
        entry = str(Path(source) / "core/fartd.py")
        command = [sys.executable, "-I", entry]
        if reap_after is not None:
            # Scope the shorter deadline to this one test interpreter.
            command = [sys.executable, "-I", "-c",
                       "import sys, runpy; sys.path.insert(0, sys.argv[1]); "
                       "sys.modules['ssl'] = None; import core.view; "
                       "core.view.REAP_AFTER = float(sys.argv[2]); "
                       "runpy.run_path(sys.argv[3], run_name='__main__')",
                       str(source), str(reap_after), entry]
        process = subprocess.Popen(command, env=env,
                                   stdin=subprocess.DEVNULL, cwd=base)
        stack.callback(stop, process)
        path = Path(env["FART_RUNTIME_DIR"]) / "core.sock"
        for _ in range(200):
            connection = try_connect(path)
            if connection:
                stack.callback(connection.close)
                yield Fixture(process, connection, env)
                return
            if process.poll() is not None:
                break
            time.sleep(0.02)
        raise RuntimeError("private core failed to start")
