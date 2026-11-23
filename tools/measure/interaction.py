"""Read-only Hyprland interaction proxy. Retain no event payloads or positions."""
import json
from pathlib import Path
import select
import socket
import threading

EVENTS = {b"activewindow", b"activewindowv2", b"workspace", b"workspacev2",
          b"focusedmon", b"focusedmonv2", b"activespecial", b"activespecialv2"}
# A run that maps its own window moves focus itself: it ignores these and relies on the rest and the cursor.
FOCUS = frozenset({b"activewindow", b"activewindowv2"})


def cursor(directory):
    with socket.socket(socket.AF_UNIX) as request:
        request.settimeout(.5)
        request.connect(str(directory / ".socket.sock"))
        request.sendall(b"j/cursorpos")
        with request.makefile("rb") as response:
            data = json.loads(response.read(1024))
        return int(data["x"]), int(data["y"])


class Interaction:
    def __init__(self, env, ignore=frozenset()):
        self.events = EVENTS - set(ignore)
        self.directory = None
        if env.get("XDG_RUNTIME_DIR") and env.get("HYPRLAND_INSTANCE_SIGNATURE"):
            self.directory = Path(env["XDG_RUNTIME_DIR"]) / "hypr" / env["HYPRLAND_INSTANCE_SIGNATURE"]
        self.status = "unknown"
        self.stop = threading.Event()
        self.ready = threading.Event()
        self.thread = None

    def __enter__(self):
        if self.directory:
            self.thread = threading.Thread(target=self.watch)
            self.thread.start()
            self.ready.wait()
        return self

    def __exit__(self, *_):
        if self.thread:
            self.stop.set()
            self.thread.join()

    def watch(self):
        try:
            with socket.socket(socket.AF_UNIX) as events:
                events.settimeout(.5)
                events.connect(str(self.directory / ".socket2.sock"))
                initial = cursor(self.directory)
                self.status = "quiet"
                self.ready.set()
                partial = b""
                while True:
                    readable = select.select([events], [], [], 0 if self.stop.is_set() else .1)[0]
                    if readable:
                        block = events.recv(65536)
                        if not block:
                            raise EOFError
                        *lines, partial = (partial + block).split(b"\n")
                        if any(line.partition(b">>")[0] in self.events for line in lines):
                            self.status = "interrupted"
                            return
                        if len(partial) > 65536:
                            raise ValueError("oversized event")
                    if cursor(self.directory) != initial:
                        self.status = "interrupted"
                        return
                    if self.stop.is_set() and not readable:
                        break
        except (OSError, EOFError, ValueError, TypeError, KeyError):
            self.status = "unknown"
        finally:
            self.ready.set()
