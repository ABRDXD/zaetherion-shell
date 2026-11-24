#!/usr/bin/env python3
"""Switch the session's locker between DMS's and ZÆTHERION's (docs/LOCK.md §6). Run with the owner present.

    tools/lock_switch.py status    what DMS's custom lock command is and whether the core runs FART_LOCK=own
    tools/lock_switch.py on        DMS's custom lock command becomes `<repo>/zaetherion lock` (refused unless the
                                   running core has FART_LOCK=own: otherwise `zaetherion lock` would ask DMS, which
                                   would run `zaetherion lock` again)
    tools/lock_switch.py off       DMS's own lock again, at once (the command is removed)
    tools/lock_switch.py is-on     exit 0 when DMS's command is ZÆTHERION's lock (tools/session-start reads it at login)

Order on:  `tools/live-restart FART_LOCK=own`, then `tools/lock_switch.py on`.
Order off: `tools/lock_switch.py off`, then `tools/live-restart FART_LOCK=`.
DMS's settings.json is written the way DMS writes it (2-space JSON, atomic replace); the first change keeps a copy
beside it (settings.json.pre-lock-switch). Only `customPowerActionLock` is touched.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KEY = "customPowerActionLock"
COMMAND = f"{ROOT}/zaetherion lock"


def settings_path() -> Path:
    config = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(config) / "dms" / "settings.json"


def core_lock_own() -> bool | None:
    """FART_LOCK of the running core (None: no core running from this checkout)."""
    found = subprocess.run(["pgrep", "-u", str(os.getuid()), "-f", f"^/usr/bin/python3 -I {ROOT}/core/fartd.py$"],
                           capture_output=True, text=True).stdout.split()
    if not found:
        return None
    try:
        environ = Path(f"/proc/{found[0]}/environ").read_bytes().split(b"\0")
    except OSError:
        return None
    return b"FART_LOCK=own" in environ


def write(path: Path, value: str | None) -> bool:
    """True when the file changed. `None` removes the key (DMS's default: its own lock)."""
    settings = json.loads(path.read_text())
    if not isinstance(settings, dict):
        raise SystemExit(f"{path}: not a settings object; left alone")
    if settings.get(KEY) == value or (value is None and KEY not in settings):
        return False
    backup = path.with_name(path.name + ".pre-lock-switch")
    if not backup.exists():
        shutil.copy2(path, backup)
    if value is None:
        settings.pop(KEY, None)
    else:
        settings[KEY] = value
    temp = path.with_name(f".{path.name}.zaetherion")
    temp.write_text(json.dumps(settings, indent=2, ensure_ascii=False))
    os.chmod(temp, path.stat().st_mode & 0o777)
    os.replace(temp, path)
    return True


def main(argv: list[str]) -> int:
    action = argv[1] if len(argv) == 2 else ""
    path = settings_path()
    if action == "status":
        current = json.loads(path.read_text()).get(KEY) if path.exists() else None
        print(f"DMS {KEY}: {current!r}")
        print(f"core FART_LOCK=own: {core_lock_own()}")
        return 0
    if action == "is-on":
        try:
            current = json.loads(path.read_text()).get(KEY)
        except (OSError, ValueError, AttributeError):
            return 1
        return 0 if isinstance(current, str) and current.endswith("/zaetherion lock") else 1
    if action == "on":
        if core_lock_own() is not True:
            print("refused: the running core does not have FART_LOCK=own (run `tools/live-restart FART_LOCK=own` first)")
            return 1
        print("changed" if write(path, COMMAND) else "already on", f"({KEY} = {COMMAND!r})")
        return 0
    if action == "off":
        print("changed" if write(path, None) else "already off", f"({KEY} removed: DMS's own lock)")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
