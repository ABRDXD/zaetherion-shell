#!/usr/bin/env python3
"""Key capture when the launcher opens (Z139: key press → typing accepted ≤ 100 ms, no lost keys).

Runs in a private nested Hyprland (tools/nested_hypr.py, with its own state file so another check's nested
session is never reused or stopped) with a private core (FART_HOST=fixture, FART_RESIDENT_VIEW=1) and a view
made from shell.qml with the fixture adapter in place of Serpantinum's. Never a real DMS, bus or PipeWire.

A plain Quickshell window holds focus first and logs every key it gets, as the app the owner is typing in.
Each trial is one wtype burst: a sentinel key (to that window, the time reference T0), Super+` pressed, held --hold ms (60) and
released, then a 12-letter word with a fixed delay before and between its letters. The view prints, with
FART_COLD_PROBE=1, the command arriving (FART_COLD command), the panel window turning active and the command
line's focus (FART_CMDFOCUS) and every change of its text (FART_CMDTEXT).

    A  today's open: SUPER+grave → `<repo>/zaetherion key down` / release → `key up` (a process per edge, the core
       sends view.command open)
    B  prototype: SUPER+grave → hl.dsp.global("zaetherion:launcher"), a GlobalShortcut in the view
       (FART_LAUNCHER_SHORTCUT=1) opens the command line itself
    C  the launcher (S6): SUPER+grave → hl.dsp.global("zaetherion:apps"); the launcher grows inside the island's
       window, which is already mapped, so only its keyboard focus changes (the same markers, from LauncherFace)

Cases: `resident` (view up, panel closed: the owner's case) and `first` (the first open after the view starts;
the core is restarted for every trial).

    launcher_keycheck.py [--trials 10] [--delays 0,5,15,40] [--hold 60] [--paths A,B] [--cases resident,first] [--json FILE] [--keep]

wtype's keymap is its own, so the nested Hyprland resolves binds by symbol (input.resolve_binds_by_sym), or no
bind would match a wtype key. Everything it started is stopped at the end; exit 1 if that fails.
"""
import argparse
import json
import os
import shutil
import signal
import socket
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import nested_hypr  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
REAL = nested_hypr.RUN
TREE = ("shell.qml", "view", "adapters", "core", "tools", "assets")
WORD = "upholstering"  # 12 letters, none repeated, so each one is traced to where it went
SENTINEL = "0"
NOWHERE = "unix:path=/nonexistent/fart-keycheck"
APPID, NAME = "zaetherion", "launcher"
SHORTCUT = {"B": "launcher", "C": "apps"}  # the global shortcut each path binds

HOLDER = """import QtQuick
import Quickshell
// The focused app: logs every key it receives, wall-clock ms.
ShellRoot {
    FloatingWindow {
        title: "keycheck-holder"
        implicitWidth: 480; implicitHeight: 240; visible: true
        TextInput {
            anchors.fill: parent
            focus: true
            onActiveFocusChanged: console.log("HOLDER focus", activeFocus, Date.now())
            Keys.onPressed: event => console.log("HOLDER key", JSON.stringify(event.text), event.key, Date.now())
        }
    }
}
"""


def wait(pred, timeout=10.0, step=0.05):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        value = pred()
        if value:
            return value
        time.sleep(step)
    return None


def harness_text() -> str:
    """shell.qml with the fixture adapter for Serpantinum's: the owner's entry shape (island + panel), inert host."""
    text = (ROOT / "shell.qml").read_text()
    swaps = (("import qs.adapters.serpantinum", "import qs.adapters.fixture"),
             ("SerpantinumAdapter { id: adapter; core: client }", "FixtureAdapter { id: adapter }"))
    for old, new in swaps:
        if old not in text:
            raise SystemExit(f"shell.qml changed shape: {old!r} not found")
        text = text.replace(old, new)
    return text


class Bench:
    def __init__(self, base: Path, st: dict):
        self.base, self.st = base, st
        self.run = base / "run"
        for name in ("run", "config", "cache", "state", "bin", "home"):
            (base / name).mkdir()
        os.chmod(self.run, 0o700)
        (self.run / "hypr").symlink_to(REAL / "hypr")
        bundle = base / "bundle"
        bundle.mkdir()
        for name in TREE:
            src = ROOT / name
            if src.is_dir():
                shutil.copytree(src, bundle / name, ignore=shutil.ignore_patterns("__pycache__"))
            else:
                shutil.copy2(src, bundle / name)
        self.entry = bundle / "KeycheckShell.qml"
        self.entry.write_text(harness_text())
        for name in ("cliphist", "serpantinum", "notify-send", "pw-play", "gdbus", "cava", "kitty", "dms"):
            stub = base / "bin" / name
            stub.write_text("#!/bin/sh\nexit 0\n")
            stub.chmod(0o755)
        (base / "holder").mkdir()
        (base / "holder" / "shell.qml").write_text(HOLDER)
        self.view_log = base / "view.log"
        self.holder_log = base / "holder.log"
        self.sock = self.run / "zaetherion" / "core.sock"
        env = {k: v for k, v in os.environ.items() if not k.startswith(("FART_", "DMS_"))}
        env.pop("DISPLAY", None)
        env.update(XDG_RUNTIME_DIR=str(self.run), XDG_CONFIG_HOME=str(base / "config"), XDG_CACHE_HOME=str(base / "cache"),
                   XDG_STATE_HOME=str(base / "state"), XDG_DATA_HOME=str(base / "home" / "data"),
                   WAYLAND_DISPLAY=str(REAL / st["wayland"]), HYPRLAND_INSTANCE_SIGNATURE=st["sig"], QT_QPA_PLATFORM="wayland",
                   PATH=str(base / "bin") + ":" + os.environ["PATH"], PIPEWIRE_RUNTIME_DIR="/nonexistent/fart-keycheck",
                   DBUS_SESSION_BUS_ADDRESS=NOWHERE, DBUS_SYSTEM_BUS_ADDRESS=NOWHERE)
        self.env = env
        self.core_env = dict(env, FART_RUNTIME_DIR=str(self.run / "zaetherion"), FART_STATE_DIR=str(base / "state" / "zaetherion"),
                             FART_CACHE_DIR=str(base / "cache" / "fart"), FART_HOST="fixture", FART_MIRROR="0",
                             FART_RESIDENT_VIEW="1", FART_VIEW_ENTRY=str(self.entry), FART_VIEW_STDOUT=str(self.view_log),
                             FART_COLD_PROBE="1")
        self.core = self.holder = None

    # Processes

    def start_holder(self):
        self.holder = subprocess.Popen(["qs", "-n", "--no-color", "-p", str(self.base / "holder")], env=self.env, cwd="/",
                                       start_new_session=True, stdin=subprocess.DEVNULL,
                                       stdout=self.holder_log.open("ab"), stderr=subprocess.STDOUT)
        if not wait(lambda: "HOLDER focus true" in self.holder_log.read_text(errors="replace"), 15):
            raise RuntimeError("the focus-holding window did not get focus")

    def start_core(self, shortcut: bool):
        env = dict(self.core_env)
        if shortcut:
            env["FART_LAUNCHER_SHORTCUT"] = "1"
        self.core = subprocess.Popen([sys.executable, "-I", str(ROOT / "core" / "fartd.py")], env=env, cwd="/",
                                     start_new_session=True, stdin=subprocess.DEVNULL,
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if not wait(self.sock.exists, 10):
            raise RuntimeError("the core did not start")
        if not wait(lambda: (self.status() or {}).get("core"), 30, 0.2):
            raise RuntimeError("the view did not come up: " + self.view_log.read_text(errors="replace")[-1500:])
        if shortcut and not wait(lambda: all(f"{APPID}:{name}" in self.hypr("globalshortcuts").stdout
                                             for name in SHORTCUT.values()), 10):
            raise RuntimeError("the view's global shortcut was not registered")

    def stop_core(self):
        if self.core and self.core.poll() is None:
            self.core.terminate()
            try:
                self.core.wait(15)
            except subprocess.TimeoutExpired:
                self.core.kill()
                self.core.wait()
        self.core = None
        wait(lambda: not any("KeycheckShell.qml" in cmd for _, cmd in self.processes().values()), 10)

    def processes(self) -> dict:
        """Everything started under the private runtime folder: {pid: (name, command line)}."""
        found, marker = {}, f"XDG_RUNTIME_DIR={self.run}".encode()
        for entry in os.scandir("/proc"):
            if not entry.name.isdigit() or int(entry.name) == os.getpid():
                continue
            try:
                if marker not in Path(entry.path, "environ").read_bytes().split(b"\0"):
                    continue
                stat = Path(entry.path, "stat").read_text()
                if stat.rsplit(")", 1)[1].split()[0] == "Z":
                    continue
                cmd = Path(entry.path, "cmdline").read_bytes().replace(b"\0", b" ").decode(errors="replace").strip()
                found[int(entry.name)] = (stat[stat.index("(") + 1:stat.rindex(")")], cmd)
            except OSError:
                continue
        return found

    # Talking to things

    def hypr(self, *args):
        return nested_hypr.hypr(self.st["sig"], *args)

    def lua(self, code: str):
        r = self.hypr("eval", code)
        if r.returncode != 0 or "ok" not in r.stdout:
            raise RuntimeError(f"hyprctl eval {code!r}: {r.stdout}{r.stderr}")

    def status(self) -> dict | None:
        r = subprocess.run(["qs", "-p", str(self.entry), "ipc", "call", "fart", "status"], env=self.env,
                           capture_output=True, text=True, timeout=10)
        try:
            return json.loads(r.stdout)
        except ValueError:
            return None

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

    def bind(self, path: str):
        """Super+` as the owner binds it (~/.config/hypr/zaetherion/fart.lua), pointed at this checkout and core."""
        self.lua('hl.unbind("SUPER + grave")')
        if path == "A":
            prefix = f"FART_RUNTIME_DIR={self.run / 'zaetherion'} XDG_RUNTIME_DIR={self.run} {ROOT / 'zaetherion'}"
            self.lua(f'hl.bind("SUPER + grave", hl.dsp.exec_cmd({json.dumps(prefix + " key down")}))')
            self.lua(f'hl.bind("SUPER + grave", hl.dsp.exec_cmd({json.dumps(prefix + " key up")}), {{ release = true }})')
        else:
            self.lua(f'hl.bind("SUPER + grave", hl.dsp.global("{APPID}:{SHORTCUT[path]}"))')

    def close_panel(self):
        """Fold the panel and wait until it is gone from the screen (the holder has the keyboard back)."""
        if self.launcher_open():
            subprocess.run(["qs", "-p", str(self.entry), "ipc", "call", "launcher", "toggle"], env=self.env,
                           capture_output=True, timeout=10)
            if not wait(lambda: not self.launcher_open(), 10, 0.1):
                raise RuntimeError("the launcher did not fold")
        status = self.status() or {}
        if status.get("open"):
            self.request("view.close")
        if not wait(lambda: (s := self.status()) and not s.get("open") and s.get("surfaces", 0) == 0, 10, 0.1):
            raise RuntimeError("the panel did not fold")
        time.sleep(0.3)


    def launcher_open(self) -> bool:
        """The launcher's last word in the view log (FART_LAUNCHER open|closed, probe only)."""
        lines = self.view_log.read_text(errors="replace").splitlines() if self.view_log.exists() else []
        starts = [i for i, line in enumerate(lines) if "FART_COLD created" in line]  # only this view's marks count
        marks = [line.split("FART_LAUNCHER", 1)[1].split()[0] for line in lines[starts[-1] if starts else 0:]
                 if "FART_LAUNCHER " in line]
        return bool(marks) and marks[-1] == "open"


def tail(path: Path, offset: int) -> list[str]:
    with path.open("rb") as f:
        f.seek(offset)
        return f.read().decode(errors="replace").splitlines()


def size(path: Path) -> int:
    return path.stat().st_size if path.exists() else 0


def trial(bench: Bench, delay: int, hold: int = 60) -> dict:
    h0, v0 = size(bench.holder_log), size(bench.view_log)
    argv = ["wtype", "-k", SENTINEL, "-M", "logo", "-P", "grave", *(["-s", str(hold)] if hold else []), "-p", "grave", "-m", "logo",
            *(["-s", str(delay), "-d", str(delay)] if delay else []), WORD]
    subprocess.run(argv, env=bench.env, check=True, timeout=10)
    time.sleep(1.0)
    holder = [line.split() for line in tail(bench.holder_log, h0) if "HOLDER key" in line]
    view = tail(bench.view_log, v0)
    out = {"delay": delay, "ok": True, "note": ""}
    keys = [(json.loads(parts[parts.index("HOLDER") + 2]), int(parts[-1])) for parts in holder]
    t0 = next((ts for ch, ts in keys if ch == SENTINEL), None)
    if t0 is None:
        return dict(out, ok=False, note="sentinel did not reach the holder (focus was elsewhere)")
    after = [ch for ch, ts in keys if ts >= t0][1:]
    out["holder"] = "".join(ch for ch in after if ch in WORD)
    out["holder_other"] = "".join(ch for ch in after if ch not in WORD and ch)  # a '`' here: the bind did not fire

    def first(prefix, *match):
        for line in view:
            parts = line.split()
            if prefix in parts:
                i = parts.index(prefix)
                rest = parts[i + 1:]
                if prefix == "FART_COLD" and rest[:1] == list(match):
                    return int(rest[1]) - t0
                if prefix == "FART_CMDFOCUS" and rest[1:3] == list(match):
                    return int(rest[0]) - t0
        return None

    texts = []
    for line in view:
        if "FART_CMDTEXT" in line:
            parts = line.split("FART_CMDTEXT", 1)[1].split(" ", 2)
            texts.append((int(parts[1]) - t0, json.loads(parts[2])))
    typed = [(ts, text) for ts, text in texts if text]
    out["fart"] = typed[-1][1] if typed else ""
    out["first_char"] = typed[0][0] if typed else None
    out["command"] = first("FART_COLD", "command")
    out["handled"] = first("FART_COLD", "handled")
    out["window"] = first("FART_CMDFOCUS", "window", "true")
    out["input"] = first("FART_CMDFOCUS", "input", "true")
    # Typing is accepted once the keyboard is in the panel window and the line has focus in it.
    # The keyboard came to the panel and left it again while it was open (it went to another surface).
    left = first("FART_CMDFOCUS", "window", "false")
    out["dropped"] = out["window"] is not None and left is not None and left >= out["window"]
    marks = [m for m in (out["window"], out["input"]) if m is not None]
    out["keyboard"] = max(marks) if len(marks) == 2 else None
    out["lost"] = len(WORD) - len(out["holder"]) - len(out["fart"])
    out["misrouted"] = len(out["holder"])
    out["clean"] = out["fart"] == WORD
    out["split_ok"] = out["holder"] + out["fart"] == WORD  # nothing reordered: a prefix to the app, the rest to FART
    return out


def run_case(bench: Bench, path: str, case: str, delays, trials, hold) -> list[dict]:
    results = []
    if case == "resident":
        bench.start_core(shortcut=path in SHORTCUT)
        time.sleep(1.0)
    try:
        for delay in delays:
            for n in range(trials):
                if case == "first":
                    bench.start_core(shortcut=path in SHORTCUT)
                    time.sleep(1.0)  # loaded and idle, as after a login
                else:
                    bench.close_panel()
                r = dict(trial(bench, delay, hold), path=path, case=case, n=n)
                results.append(r)
                print(f"  {path} {case:8} d={delay:2} #{n}: keyboard={r.get('keyboard')} cmd={r.get('command')} "
                      f"fart={r.get('fart', '')!r} app={r.get('holder', '')!r} {r['note']}", flush=True)
                if case == "first":
                    bench.stop_core()
    finally:
        bench.stop_core()
    return results


def stats(values):
    values = [v for v in values if v is not None]
    if not values:
        return "-"
    return f"{statistics.median(values):.0f} / {min(values)} / {max(values)}"


def table(results):
    rows = ["| path | case | delay ms | n | keyboard ms med/min/max | command ms med/min/max | first char in FART ms med | "
            "lost | to app | clean trials | no/dropped focus |", "|---|---|---|---|---|---|---|---|---|---|---|"]
    keys = sorted({(r["path"], r["case"], r["delay"]) for r in results}, key=lambda k: (k[0], k[1] != "resident", k[2]))
    for path, case, delay in keys:
        rs = [r for r in results if (r["path"], r["case"], r["delay"]) == (path, case, delay)]
        good = [r for r in rs if r["ok"]]
        firsts = [r["first_char"] for r in good if r["first_char"] is not None]
        rows.append(f"| {path} | {case} | {delay} | {len(good)}/{len(rs)} | {stats([r['keyboard'] for r in good])} | "
                    f"{stats([r['command'] for r in good])} | {statistics.median(firsts) if firsts else '-'} | "
                    f"{sum(r['lost'] for r in good)} | {sum(r['misrouted'] for r in good)} | "
                    f"{sum(r['clean'] for r in good)}/{len(good)} | {sum(r['keyboard'] is None or r['dropped'] for r in good)} |")
    return "\n".join(rows)


def main():
    ap = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    ap.add_argument("--trials", type=int, default=10)
    ap.add_argument("--delays", default="0,5,15,40")
    ap.add_argument("--paths", default="A,B")
    ap.add_argument("--cases", default="resident,first")
    ap.add_argument("--hold", type=int, default=60, help="ms between the ` press and its release (a tap)")
    ap.add_argument("--json", type=Path)
    ap.add_argument("--keep", action="store_true", help="keep the work folder (logs) after a clean run")
    args = ap.parse_args()
    delays = [int(d) for d in args.delays.split(",")]
    for tool in ("wtype", "qs", "hyprctl", "Hyprland"):
        if not shutil.which(tool):
            sys.exit(f"needs {tool}")
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        sys.exit("needs a running Hyprland session (the nested one is started inside it)")

    (REAL / "zaetherion").mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="launcher-keycheck-", dir=REAL / "zaetherion"))
    # A state file of our own: never reuse, or stop, a nested session another check started.
    nested_hypr.STATE = work / "nested.json"
    results, bench, failed = [], None, False
    try:
        st = nested_hypr.start()
        bench = Bench(work, st)
        bench.lua("hl.config({ input = { resolve_binds_by_sym = true } })")
        bench.start_holder()
        for path in args.paths.split(","):
            bench.bind(path)
            for case in args.cases.split(","):
                print(f"path {path}, {case}", flush=True)
                results += run_case(bench, path, case, delays, args.trials, args.hold)
    except Exception as error:  # noqa: BLE001 (reported, then cleaned up)
        print(f"FAIL {error}", flush=True)
        failed = True
    finally:
        if bench:
            bench.stop_core()
            if bench.holder and bench.holder.poll() is None:
                bench.holder.terminate()
                bench.holder.wait(10)
        if nested_hypr.STATE.exists():
            nested_hypr.stop()
        left = bench.processes() if bench else {}
        for pid in left:
            try:
                os.kill(pid, signal.SIGKILL)
            except OSError:
                pass
        if left:
            print(f"FAIL processes left (killed): {left}")
            failed = True

    if results:
        print()
        print(f"word {WORD!r} ({len(WORD)} letters); ` held {args.hold} ms; ms after the sentinel key that precedes "
              "Super+` in the same burst")
        print(table(results))
        if args.json:
            args.json.write_text(json.dumps(results, indent=1))
    if failed or args.keep:
        print(f"kept for inspection: {work}")
    else:
        shutil.rmtree(work, ignore_errors=True)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
