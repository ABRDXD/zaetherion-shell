#!/usr/bin/env python3
"""Operate fart-next, the FART-native successor run beside the archive until cutover, through its core."""
from __future__ import annotations

import json
import os
import socket
import sys

PROTOCOL = 1
EXIT_CORE, EXIT_USAGE, EXIT_UNREACHABLE = 1, 2, 3


def key_edge(edge: str) -> int | None:
    """`fart-next key down|up`, the Super+` bind's two edges, sent before the rest of the CLI is imported:
    those imports take about 60 ms, which every press would otherwise wait before `view.open` (COLDSTART.md).
    Returns the exit code, or None to fall through to the full CLI, which starts the core on a press."""
    xdg = os.environ.get("XDG_RUNTIME_DIR")
    base = os.environ.get("FART_RUNTIME_DIR") or (xdg and xdg + "/zaetherion")
    if not base:
        return None  # the full CLI reports the missing session
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(20)
    try:
        sock.connect(base + "/core.sock")
    except (FileNotFoundError, ConnectionRefusedError):
        sock.close()
        return 0 if edge == "up" else None  # a release with no core has nothing to end
    with sock, sock.makefile("rb") as replies:
        for number, op, args in ((1, "hello", {"client": "cli", "protocol": PROTOCOL}), (2, "key." + edge, {})):
            sock.sendall(json.dumps({"id": number, "op": op, "args": args}).encode() + b"\n")
            while True:
                line = replies.readline()
                if not line:
                    print("zaetherion: the core closed the connection", file=sys.stderr)
                    return EXIT_UNREACHABLE
                message = json.loads(line)
                if message.get("id") == number:
                    break
            if not message.get("ok"):
                error = message.get("error") or {}
                print(f"zaetherion: {error.get('message', 'unknown error')} ({error.get('code', 'internal')})", file=sys.stderr)
                return EXIT_CORE
    return 0


if __name__ == "__main__" and sys.argv[1:] in (["key", "down"], ["key", "up"]):
    try:
        code = key_edge(sys.argv[2])
    except OSError as error:
        print(f"zaetherion: {error}", file=sys.stderr)
        code = EXIT_UNREACHABLE
    if code is not None:
        raise SystemExit(code)

import argparse  # noqa: E402 (below the key fast path, which needs none of these)
import fcntl  # noqa: E402
from pathlib import Path  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import time  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))  # -I leaves the repository off sys.path; only the stdlib-only line helpers are used
from core.verbs.lines import clock, overdrive_line, session_line, timers_line  # noqa: E402
ENTRY = ROOT / "shell.qml"
PAGES = ("home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex")
ALIASES = {"inbox": "notifications", "clips": "clipboard"}
STATE_FILES = ("todo.json", "preferences.json", "timers.json", "settings.json")


def xdg(name: str, fallback: str) -> Path:
    return Path(os.environ.get("XDG_" + name + "_HOME") or Path.home() / fallback)


def seed_file(path: Path, content: bytes):
    # Publish complete files atomically; an existing destination always wins.
    with tempfile.NamedTemporaryFile(dir=path.parent) as temp:
        temp.write(content)
        temp.flush()
        os.chmod(temp.name, 0o600)
        try:
            os.link(temp.name, path)
        except FileExistsError:
            pass


def seed_state(dest: Path, archive: Path):
    """Copy the archive's state once, so the two views never write the same files."""
    dest.mkdir(parents=True, exist_ok=True, mode=0o700)
    for name in STATE_FILES:
        source = archive / name
        if (dest / name).exists() or not source.is_file():
            continue
        try:
            value = json.loads(source.read_text())
        except ValueError as error:
            raise ValueError(f"Cannot seed from {source}: invalid JSON. Original file preserved.") from error
        if name == "settings.json":
            profile = value.get("profile", {}) if isinstance(value, dict) else {}
            avatar = Path(profile.get("avatarPicture") or "")
            if avatar.parent == archive and avatar.is_file():
                own = dest / avatar.name
                seed_file(own, avatar.read_bytes())
                profile["avatarPicture"] = str(own)
        seed_file(dest / name, json.dumps(value).encode())


class CoreError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


class Unreachable(RuntimeError):
    pass


def runtime() -> Path:
    if os.environ.get("FART_RUNTIME_DIR"):
        path = Path(os.environ["FART_RUNTIME_DIR"])
    elif os.environ.get("XDG_RUNTIME_DIR"):
        path = Path(os.environ["XDG_RUNTIME_DIR"]) / "zaetherion"
    else:
        raise Unreachable("Run zaetherion from the desktop session (XDG_RUNTIME_DIR is unset).")
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    return path


class Connection:
    def __init__(self, sock: socket.socket):
        self.sock = sock
        self.file = sock.makefile("rb")
        self.next_id = 0

    def request(self, op: str, **args):
        self.next_id += 1
        self.sock.sendall(json.dumps({"id": self.next_id, "op": op, "args": args}).encode() + b"\n")
        while True:
            line = self.file.readline()
            if not line:
                raise Unreachable("the core closed the connection")
            message = json.loads(line)
            if message.get("id") == self.next_id:
                if message.get("ok"):
                    return message.get("result")
                error = message.get("error") or {}
                raise CoreError(error.get("code", "internal"), error.get("message", "unknown error"))

    def close(self):
        self.file.close()
        self.sock.close()


def try_connect(path: Path, timeout: float = 20) -> Connection | None:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        sock.connect(str(path))
    except (FileNotFoundError, ConnectionRefusedError):
        sock.close()
        return None
    connection = Connection(sock)
    connection.request("hello", client="cli", protocol=PROTOCOL)
    return connection


def start_core(path: Path) -> Connection:
    """Start the core detached (until the systemd socket unit is approved) and wait for its socket."""
    with (path.parent / "launch.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        connection = try_connect(path)
        if connection:
            return connection
        state = xdg("STATE", ".local/state")
        seed_state(state / "zaetherion", state / "fart")
        env = dict(os.environ, FART_STATE_DIR=str(state / "zaetherion"),
                   FART_CACHE_DIR=str(xdg("CACHE", ".cache") / "zaetherion"), FART_RUNTIME_DIR=str(path.parent),
                   FART_HOST=os.environ.get("FART_HOST") or "serpantinum")
        log = (path.parent / "core.log").open("ab")
        subprocess.Popen([sys.executable, "-I", str(ROOT / "core/fartd.py")], env=env, cwd="/", start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=log)
        log.close()
        for _ in range(80):
            connection = try_connect(path)
            if connection:
                return connection
            time.sleep(0.025)
    raise Unreachable(f"the core did not start; see {path.parent / 'core.log'}")


def connect(start: bool) -> Connection | None:
    path = runtime() / "core.sock"
    connection = try_connect(path)
    if connection or not start:
        return connection
    return start_core(path)


# Parsing

def rect(text: str) -> dict:
    parts = text.split(",")
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("--from takes x,y,width,height")
    try:
        values = [float(p) for p in parts]
    except ValueError:
        raise argparse.ArgumentTypeError("--from takes four numbers: x,y,width,height") from None
    if values[2] <= 0 or values[3] <= 0:
        raise argparse.ArgumentTypeError("--from needs a positive width and height")
    return dict(zip(("x", "y", "width", "height"), values))


def screen(text: str) -> str:
    # An empty name (the hook's fallback when the bar has no screen) means "the focused screen".
    if len(text) > 64 or not text.isprintable():
        raise argparse.ArgumentTypeError("--screen takes an output name, such as eDP-1")
    return text


def placement(args) -> dict:
    """The clock rect and screen of open and toggle, as view.open/view.toggle arguments."""
    extra = {}
    if getattr(args, "rect", None):
        extra["from"] = args.rect
    if getattr(args, "screen", None):
        extra["screen"] = args.screen
    return extra


# Output

def view_line(view: dict) -> str:
    if view["state"] != "ready":
        return view["state"]
    if view["open"]:
        return f"open on {view['page']} (pid {view['pid']})"
    closed = (time.time() * 1000 - view["closedSince"]) / 1000 if view["closedSince"] else 0
    return f"closed {clock(closed)} (pid {view['pid']})"


def status_text(status: dict, timers: dict) -> str:
    core, tasks, inbox = status["core"], status["tasks"], status["notifications"]
    return "\n".join([
        f"Source: {ROOT}",
        f"Core: pid {core['pid']}, {core['rssKiB'] / 1024:.1f} MiB RSS, up {clock(core['uptime'])}, host {core['host']}",
        f"View: {view_line(status['view'])}",
        f"Timers: {timers_line(timers)}",
        f"Tasks: {tasks['open']} open, {tasks['done']} done in {tasks['lists']} list{'s' if tasks['lists'] != 1 else ''}",
        f"Inbox: {'listening' if inbox['available'] else 'not listening'}, {inbox['count']} ({inbox['unread']} unread)",
        f"Overdrive: {overdrive_line(status['overdrive'], time.time())}",
        f"Session: {session_line(status['session'], time.time())}",
    ])


def snapshot(connection: Connection, topic: str) -> dict:
    data = connection.request("subscribe", topics=[topic])["snapshots"][topic]
    connection.request("unsubscribe", topics=[topic])
    return data


def stop_core():
    connection = connect(start=False)
    if connection:
        try:
            connection.request("shutdown")
        except (Unreachable, OSError):
            pass
        connection.close()
        path = runtime() / "core.sock"
        for _ in range(240):
            if not path.exists():
                break
            time.sleep(0.025)
    stop_legacy_view()


def stop_legacy_view():
    """A view started by the M0/M1 launcher (qs -d) is not the core's child."""
    try:
        listed = subprocess.run(["qs", "list", "-a", "-j"], capture_output=True, text=True, check=True, timeout=4)
        if any(i.get("config_path") == str(ENTRY) for i in json.loads(listed.stdout)):
            subprocess.run(["qs", "-p", str(ENTRY), "kill"], capture_output=True, timeout=5, check=False)
    except (OSError, ValueError, subprocess.SubprocessError):
        pass


def report():
    # Read-only: this repository has no upstream to merge. Changes arrive as reviewed Git commits.
    git = ["git", "-C", str(ROOT)]
    print(f"zaetherion source: {ROOT}")
    subprocess.run([*git, "status", "--short", "--branch"], check=False)
    subprocess.run([*git, "log", "--oneline", "-5"], check=False)
    print("No upstream merge applies. Pull reviewed commits into this repository, then run fart-next restart.")


BUILTINS = ("open", "page", "close", "toggle", "status", "start", "stop", "restart", "update", "key")


class VerbFailed(Exception):
    def __init__(self, result: dict):
        super().__init__(result.get("line") or result.get("code") or "failed")
        self.result = result


def verb(words: list[str]):
    """Any other word is a command-line verb, parsed by the core's registry (docs/M5-COMMAND.md)."""
    connection = connect(start=True)
    result = connection.request("cmd.run", line=" ".join(words))
    if not result.get("ok"):
        raise VerbFailed(result)
    return result


def parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__, epilog="Any other word is a command-line verb, "
                                     "for example fart-next vol 40. fart-next ? lists them.")
    parser.add_argument("--json", action="store_true", help="print the core's raw result")
    sub = parser.add_subparsers(dest="action", required=True)
    for name in ("open", "toggle"):
        placed = sub.add_parser(name)
        placed.add_argument("--from", dest="rect", type=rect, help="clock rect x,y,width,height")
        placed.add_argument("--screen", type=screen, help="the clock's output name; the panel opens there")
    sub.add_parser("page").add_argument("room", choices=(*PAGES, *ALIASES))
    sub.add_parser("key", help="the Super+` edges (DAILY_DRIVER §4.6); the bind is not installed").add_argument(
        "edge", choices=("down", "up"))
    for name in ("close", "status", "start", "stop", "restart", "update"):
        sub.add_parser(name)
    return parser


def run(args):
    action = args.action
    if action == "update":
        return report()
    if action == "stop":
        return stop_core()
    if action == "restart":
        stop_core()
        args.action, args.rect, args.screen = "open", None, None
        return run(args)
    if action == "key":
        # Thin on both edges: the hold length is their difference, so each pays the same start-up.
        connection = connect(start=args.edge == "down")
        if not connection:
            return None  # a release with no core has nothing to end
        return connection.request("key." + args.edge)
    if action == "status":
        connection = connect(start=False)
        if not connection:
            return {"core": "stopped", "source": str(ROOT)} if args.json else f"Source: {ROOT}\nCore: stopped"
        status = connection.request("status")
        return status if args.json else status_text(status, snapshot(connection, "timers"))
    if action == "close":
        connection = connect(start=False)
        if connection:
            connection.request("view.close")
        return None
    connection = connect(start=True)
    if action == "start":
        return None
    if action == "open":
        return connection.request("view.open", page="home", **placement(args))
    if action == "page":
        return connection.request("view.open", page=ALIASES.get(args.room, args.room))
    if action == "toggle":
        return connection.request("view.toggle", **placement(args))
    raise ValueError(action)


def split_verb(argv: list[str]) -> tuple[bool, list[str] | None]:
    """(--json, verb words), or (_, None) when argparse handles the line."""
    options = 0
    while options < len(argv) and argv[options] == "--json":
        options += 1
    rest = argv[options:]
    if not rest or rest[0] in BUILTINS or rest[0].startswith("-"):
        return options > 0, None
    return options > 0, rest


def main() -> int:
    as_json, words = split_verb(sys.argv[1:])
    if words is not None:
        try:
            result = verb(words)
        except VerbFailed as failed:
            if as_json:
                print(json.dumps(failed.result, indent=2))
            else:
                print(f"zaetherion: {failed}", file=sys.stderr)
            return EXIT_USAGE if failed.result.get("code") in ("usage", "ambiguous") else EXIT_CORE
        except CoreError as error:
            print(f"zaetherion: {error} ({error.code})", file=sys.stderr)
            return EXIT_CORE
        except (Unreachable, OSError) as error:
            print(f"zaetherion: {error}", file=sys.stderr)
            return EXIT_UNREACHABLE
        print(json.dumps(result, indent=2) if as_json else result["line"])
        return 0
    args = parser().parse_args()
    try:
        result = run(args)
    except ValueError as error:
        print(f"zaetherion: {error}", file=sys.stderr)
        return EXIT_USAGE
    except CoreError as error:
        print(f"zaetherion: {error} ({error.code})", file=sys.stderr)
        return EXIT_CORE
    except (Unreachable, OSError) as error:
        print(f"zaetherion: {error}", file=sys.stderr)
        return EXIT_UNREACHABLE
    if isinstance(result, str):
        print(result)
    elif result is not None and args.json:
        print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
