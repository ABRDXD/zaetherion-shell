"""Check Serpantinum's current recorder before invoking its toggle-only CLI."""
import os
from pathlib import Path
import sys


def recording(directory: Path):
    try:
        pid = int((directory / "rec_pid").read_text())
        if pid <= 0:
            return None
        command = (Path("/proc") / str(pid) / "exe").readlink().name
    except FileNotFoundError:
        return 0
    except (OSError, ValueError):
        return None
    if command not in ("gpu-screen-recorder", "wf-recorder"):
        return None  # An unrelated process may have inherited this stale PID.
    try:
        return max(1, int((directory / "rec_start_epoch").read_text()))
    except (OSError, ValueError):
        return 1


def main(action):
    cache = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    active = recording(cache / "serpantinum/recording")
    if action == "status":
        print(active or 0)
    elif active is not None and ((action in ("start", "capture") and not active) or (action == "stop" and active)):
        args = ["serpantinum", "screenshot"]
        if action != "capture":
            args.append("--record")
        os.execvp(args[0], args)


if __name__ == "__main__":
    main(sys.argv[1])
