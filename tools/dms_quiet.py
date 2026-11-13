#!/usr/bin/env python3
"""Build DMS's own UI without its notification server ("quiet DMS"), so ours can hold the bus name.

DMS has no switch for its notification server: `Services/NotificationService.qml` declares one
`NotificationServer`, and Quickshell claims `org.freedesktop.Notifications` when that object is made.
This tool copies the UI that the installed DMS runs and removes that one object; nothing else
in it references the object (checked: its id is unused), so DMS's notification centre stays empty and
its popups never fire while the rest of DMS (bar, control centre, lock, OSDs) is unchanged.

The copy is generated on this machine and never checked in (DMS is MIT; see NOTICE). Point the
supervisor at it with FART_RESIDENT_DIR, which reaches `dms run` as DMS_SHELL_DIR (docs/SUPERVISOR.md §5).

    tools/dms_quiet.py build [--source DIR] [--out DIR]   # default source: the running DMS's UI
    tools/dms_quiet.py check DIR                           # exit 0 if DIR is a quiet copy
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

SERVICE = Path("Services/NotificationService.qml")
MARKER = ".zaetherion-quiet"
OPENING = re.compile(r"^(?P<indent>[ \t]*)NotificationServer\s*\{", re.M)


def block_end(text: str, start: int) -> int:
    """Index just past the `}` that closes the `{` at or after `start`. Skips strings, template
    literals and comments, so braces inside them don't count."""
    i = text.index("{", start)
    depth = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c in "\"'`":
            i += 1
            while i < n and text[i] != c:
                i += 2 if text[i] == "\\" else 1
        elif text.startswith("//", i):
            i = text.find("\n", i)
            if i < 0:
                break
        elif text.startswith("/*", i):
            i = text.index("*/", i) + 1
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError("NotificationServer block is not closed")


def quiet(text: str) -> str:
    """The service's text without its NotificationServer object. Refuses anything but exactly one."""
    found = list(OPENING.finditer(text))
    if len(found) != 1:
        raise ValueError(f"expected one NotificationServer in {SERVICE}, found {len(found)}")
    match = found[0]
    end = block_end(text, match.start())
    ident = re.search(r"\bid:\s*(\w+)", text[match.start():end])
    if ident and re.search(rf"\b{ident.group(1)}\.", text[:match.start()] + text[end:]):
        raise ValueError(f"the server's id `{ident.group(1)}` is used elsewhere; removing it would break DMS")
    note = (f"{match.group('indent')}// NotificationServer removed by ZÆTHERION tools/dms_quiet.py:"
            " our server holds org.freedesktop.Notifications.")
    return text[:match.start()] + note + text[end:]


def running_source() -> Path:
    """The UI folder the running DMS's Quickshell was started with (`qs -p <dir>`)."""
    out = subprocess.run(["pgrep", "-a", "-x", "qs"], capture_output=True, text=True).stdout
    for line in out.splitlines():
        parts = line.split()
        if "-p" in parts:
            path = Path(parts[parts.index("-p") + 1])
            if (path / SERVICE).is_file() and (path / "DMSShell.qml").is_file() and not (path / MARKER).exists():
                return path
    raise SystemExit("dms_quiet: no running stock DMS UI found (a quiet copy can't be the source); pass --source")


def revision(source: Path) -> str:
    rev = source / ".dankrev"
    return rev.read_text().strip() if rev.is_file() else "unknown"


def build(source: Path, out: Path) -> Path:
    if (source / MARKER).exists() or source.resolve() == out.resolve():
        raise SystemExit(f"dms_quiet: {source} is a quiet copy; build from DMS's stock UI")
    text = (source / SERVICE).read_text()
    patched = quiet(text)  # before any copying: a DMS we don't understand leaves nothing behind
    if out.exists():
        if not (out / MARKER).is_file():
            raise SystemExit(f"dms_quiet: {out} exists and is not a quiet copy; not touching it")
        shutil.rmtree(out)
    shutil.copytree(source, out, symlinks=True)
    for path in [out, *out.rglob("*")]:  # DMS extracts read-only
        if not path.is_symlink():
            path.chmod(path.stat().st_mode | 0o200)
    (out / SERVICE).write_text(patched)
    (out / MARKER).write_text(revision(source) + "\n")
    return out


def check(directory: Path) -> list[str]:
    problems = []
    if not (directory / MARKER).is_file():
        problems.append("not made by dms_quiet (no marker)")
    service = directory / SERVICE
    if not service.is_file():
        problems.append(f"no {SERVICE}")
    elif OPENING.search(service.read_text()):
        problems.append("still declares a NotificationServer")
    for path in directory.rglob("*.qml"):
        if path != service and OPENING.search(path.read_text(errors="replace")):
            problems.append(f"{path.relative_to(directory)} declares a NotificationServer")
    return problems


def default_out() -> Path:
    state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    return state / "zaetherion" / "dms-quiet"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    b = sub.add_parser("build")
    b.add_argument("--source", type=Path)
    b.add_argument("--out", type=Path)
    c = sub.add_parser("check")
    c.add_argument("directory", type=Path)
    args = parser.parse_args(argv)
    if args.command == "build":
        source = args.source or running_source()
        out = build(source, args.out or default_out())
        print(f"quiet DMS UI (revision {revision(source)}): {out}")
        return 0
    problems = check(args.directory)
    for problem in problems:
        print("dms_quiet:", problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
