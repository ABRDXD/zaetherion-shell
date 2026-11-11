#!/usr/bin/env python3
"""Live check of the core supervising `dms run` (docs/SUPERVISOR.md), in the nested test Hyprland.

Runs the real core (FART_SUPERVISE=dms) and a real DMS with an empty test UI, all in private
XDG folders, so the session's own DMS, its dms.path and its keybinds are never touched
(docs/F1_RECON.md §Shared state). Needs a live Hyprland session; not part of the unit suite.

    supervisor_check.py        run every check; exit 1 if any fails
"""
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import nested_hypr  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
REAL = nested_hypr.RUN
EMPTY_UI = "import Quickshell\n\nShellRoot {}\n"  # enough for `dms run` to start a Quickshell child


def wait(pred, timeout=10.0, step=0.05):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = pred()
        if value:
            return value
        time.sleep(step)
    return None


class Bench:
    def __init__(self, base: Path, st: dict):
        self.base, self.run, self.ui = base, base / "run", base / "resident"
        for name in ("run", "config", "cache", "state", "resident"):
            (base / name).mkdir()
        (self.ui / "shell.qml").write_text(EMPTY_UI)
        os.chmod(self.run, 0o700)
        (self.run / "hypr").symlink_to(REAL / "hypr")
        self.env = dict(
            os.environ, XDG_RUNTIME_DIR=str(self.run), XDG_CONFIG_HOME=str(base / "config"),
            XDG_CACHE_HOME=str(base / "cache"), XDG_STATE_HOME=str(base / "state"),
            WAYLAND_DISPLAY=str(REAL / st["wayland"]), HYPRLAND_INSTANCE_SIGNATURE=st["sig"], QT_QPA_PLATFORM="wayland",
            FART_RUNTIME_DIR=str(self.run / "zaetherion"), FART_STATE_DIR=str(base / "state" / "zaetherion"),
            FART_HOST="fixture", FART_MIRROR="0", FART_SUPERVISE="dms", FART_RESIDENT_DIR=str(self.ui))
        for name in ("DISPLAY", "FART_LOG", "DMS_SHELL_DIR", "DMS_LOG_FILE"):
            self.env.pop(name, None)
        self.sock = self.run / "zaetherion" / "core.sock"
        self.core = None

    def exited(self):
        return self.core is not None and self.core.poll() is not None

    def start_core(self):
        self.core = subprocess.Popen([sys.executable, "-I", str(ROOT / "core" / "fartd.py")], env=self.env, cwd="/",
                                     start_new_session=True, stdin=subprocess.DEVNULL,
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return wait(self.sock.exists)

    def request(self, op, **args):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(5)
            s.connect(str(self.sock))
            stream, reply = s.makefile("rwb"), {}
            for number, (name, arguments) in enumerate((("hello", {"client": "cli", "protocol": 1}), (op, args))):
                stream.write(json.dumps({"id": number, "op": name, "args": arguments}).encode() + b"\n")
                stream.flush()
                reply = json.loads(stream.readline())
            return reply.get("result")

    def dms(self):
        try:
            return self.request("status")["supervisor"]["children"]["dms"]
        except (OSError, ValueError, KeyError, TypeError):
            return {}

    def processes(self):
        """Everything started under the private runtime folder: {pid: (name, parent, command line)}."""
        found, marker = {}, f"XDG_RUNTIME_DIR={self.run}".encode()
        for entry in os.scandir("/proc"):
            if not entry.name.isdigit() or int(entry.name) == os.getpid():
                continue
            try:
                if marker not in Path(entry.path, "environ").read_bytes().split(b"\0"):
                    continue
                stat = Path(entry.path, "stat").read_text()
                fields = stat.rsplit(")", 1)[1].split()
                if fields[0] == "Z":
                    continue
                command = Path(entry.path, "cmdline").read_bytes().replace(b"\0", b" ").decode(errors="replace").strip()
                found[int(entry.name)] = (stat[stat.index("(") + 1:stat.rindex(")")], int(fields[1]), command)
            except OSError:
                continue
        return found

    def named(self, name):
        return sorted(pid for pid, (comm, _, _) in self.processes().items() if comm == name)

    def up(self, owned=True, other_than=None, timeout=10.0):
        def ready():
            state = self.dms()
            good = state.get("state") == "up" and state.get("owned") is owned and state.get("pid") != other_than
            return state if good and len(self.named("dms")) == 1 and len(self.named("qs")) == 1 else None
        return wait(ready, timeout)

    def log(self):
        try:
            return (self.run / "zaetherion" / "core.log").read_text()
        except OSError:
            return ""


def main():
    real_path = REAL / "dms.path"
    real_before = (real_path.read_text() if real_path.exists() else None,
                   sorted(p.name for p in REAL.glob("dms-*.pid")))
    st = nested_hypr.start()
    (REAL / "zaetherion").mkdir(exist_ok=True)
    bench = Bench(Path(tempfile.mkdtemp(prefix="supervisor-check-", dir=REAL / "zaetherion")), st)
    results = []

    def check(name, ok, note=""):
        results.append((name, bool(ok)))
        print(f"{'PASS' if ok else 'FAIL'} {name}{' (' + note + ')' if note else ''}", flush=True)

    try:
        # 1. Start
        check("core starts", bench.start_core())
        first = bench.up()
        check("start: fartd -> dms -> UI, one of each", first)
        first = first or {}
        qs = bench.processes().get((bench.named("qs") or [0])[0], ("", 0, ""))
        check("the UI is the test resident, child of the supervised dms", qs[1] == first.get("pid") and str(bench.ui) in qs[2])
        check("dms.path in the private folder points at the test resident",
              (bench.run / "dms.path").exists() and (bench.run / "dms.path").read_text().strip() == str(bench.ui))

        # 2. UI crash: DMS exits too (137); restarted after 0.25 s
        t = time.monotonic()
        os.kill(bench.named("qs")[0], signal.SIGKILL)
        second = bench.up(other_than=first.get("pid")) or {}
        took = time.monotonic() - t
        last = second.get("last") or {}
        check("UI crash: named, restarted within 5 s", last.get("what") == "resident" and last.get("signal") == "SIGKILL"
              and took <= 5, f"{took:.2f} s, {last.get('what')} {last.get('signal')}")

        # 3. DMS crash by KILL: the UI is orphaned and must be swept before the restart
        orphan = bench.named("qs")[0]
        os.kill(second["pid"], signal.SIGKILL)
        third = bench.up(other_than=second.get("pid")) or {}
        last = third.get("last") or {}
        check("DMS crash: named, orphan UI swept, one pair again",
              last.get("what") == "dms" and last.get("signal") == "SIGKILL" and orphan not in bench.processes(),
              f"{last.get('what')} {last.get('signal')}")

        # 4. Owner restart: `dms restart` sends SIGUSR1; DMS exits 0 and a detached new dms takes over
        t = time.monotonic()
        os.kill(third["pid"], signal.SIGUSR1)
        fourth = bench.up(owned=False, other_than=third.get("pid")) or {}
        took = time.monotonic() - t
        last = fourth.get("last") or {}
        qs = bench.processes().get((bench.named("qs") or [0])[0], ("", 0, ""))
        check("owner restart: the new dms is adopted within 1.5 s, not called a crash",
              fourth.get("owned") is False and last.get("what") == "stopped" and last.get("owned") is False and took <= 1.5,
              f"{took:.2f} s, last {last.get('what')}")
        check("owner restart keeps the resident UI (DMS_SHELL_DIR)", qs[1] == fourth.get("pid") and str(bench.ui) in qs[2])
        time.sleep(4.0)  # past the handover wait: the cancelled retry must not start a second dms
        check("still exactly one dms after the handover wait, and no duplicate reported",
              len(bench.named("dms")) == 1 and bench.dms().get("pid") == fourth.get("pid") and "event=duplicate" not in bench.log())

        # 5. The adopted DMS dies: its tree is swept and the core starts its own again
        orphan = bench.named("qs")[0]
        os.kill(fourth["pid"], signal.SIGKILL)
        fifth = bench.up(other_than=fourth.get("pid")) or {}
        check("adopted DMS killed: orphan swept, the core's own dms is back",
              fifth.get("owned") is True and orphan not in bench.processes())

        # 6. Backoff as designed: 0.25, 1, the 3 s handover wait (cut short by the adoption), then 4
        waits = [line.split("inSeconds=")[1].split()[0] for line in bench.log().splitlines() if "retry inSeconds=" in line]
        check("backoff delays grow and the handover wait applies", waits == ["0.25", "1.0", "3.0", "4.0"], " ".join(waits))

        # 7. Stop by request: the whole tree goes
        bench.request("shutdown")
        gone = wait(lambda: bench.exited() and not bench.processes(), 15)
        check("shutdown leaves no processes", gone, "" if gone else str(bench.processes()))
        check("DMS removed its own dms.path", not (bench.run / "dms.path").exists())

        # 8. Logout: the compositor goes first
        bench.start_core()
        check("second start comes up", bench.up(timeout=15))
        nested_hypr.stop()
        gone = wait(lambda: bench.exited() and not bench.processes(), 20)
        check("compositor exit ends the core and leaves no processes", gone, "" if gone else str(bench.processes()))
    finally:
        for pid in bench.processes():  # only if a check failed
            try:
                os.kill(pid, signal.SIGKILL)
            except OSError:
                pass
        if nested_hypr.STATE.exists():
            nested_hypr.stop()

    real_after = (real_path.read_text() if real_path.exists() else None, sorted(p.name for p in REAL.glob("dms-*.pid")))
    check("the session's own DMS and dms.path are untouched", real_after == real_before)
    print("--- supervisor log")
    for line in bench.log().splitlines():
        if "fart.supervisor" in line or "compositor" in line:
            print("  " + line.split(" ", 2)[2].replace(str(bench.base), "<bench>"))
    failed = [name for name, ok in results if not ok]
    if failed:
        print(f"kept for inspection: {bench.base}")
    else:
        shutil.rmtree(bench.base, ignore_errors=True)
    print(f"{len(results) - len(failed)}/{len(results)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
