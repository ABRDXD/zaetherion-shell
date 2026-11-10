"""Atomic, private JSON state files."""
from __future__ import annotations

import json
import os
from pathlib import Path


def read_json(path: Path, default=None):
    """The parsed file, or default when it is missing. Invalid JSON raises ValueError."""
    try:
        text = path.read_text()
    except FileNotFoundError:
        return default
    try:
        return json.loads(text)
    except ValueError as error:
        raise ValueError(f"{path}: invalid JSON") from error


def _temp(path: Path, value) -> str:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    # Not tempfile: it pulls in shutil and the compression and crypto libraries (several MiB of RSS).
    name = str(path.with_name(f".{path.name}.{os.getpid()}.{os.urandom(4).hex()}.tmp"))
    fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC, 0o600)
    with os.fdopen(fd, "w") as out:
        json.dump(value, out, separators=(",", ":"))
        out.flush()
        os.fsync(out.fileno())
    return name


def write_json(path: Path, value):
    name = _temp(path, value)
    os.replace(name, path)


def publish_new(path: Path, value) -> bool:
    """Write only if path does not exist yet; an existing file always wins."""
    name = _temp(path, value)
    try:
        os.link(name, path)
        return True
    except FileExistsError:
        return False
    finally:
        os.unlink(name)


def append_line(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd = os.open(path, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
    with os.fdopen(fd, "a") as out:
        out.write(json.dumps(value, separators=(",", ":")) + "\n")
