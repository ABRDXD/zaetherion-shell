#!/usr/bin/env python3
"""Install or remove FART's clock hook variant in a copy of Serpantinum's TimeDateFace.qml (DAILY_DRIVER §2).

The variant replaces exactly one hunk, the host's upstream clock handler (upstream.qmlpart), with
variant.qmlpart: a right-click runs `fart toggle --from x,y,w,h --screen NAME`, a left-click still opens the
host's calendar. Everything else in the file is kept byte for byte.

    clock_hook.py FILE            install (a no-op when the variant is already there)
    clock_hook.py --remove FILE   restore the upstream handler (a no-op when it is already there)
    clock_hook.py --check FILE    report the state, change nothing

The target file is always explicit: this tool has no default path and never finds the live host file by
itself. It is run on the live file only at the cutover (M7), on the user's instruction. If the archive's
hook (archive.qmlpart, `fart open`) is installed, it refuses: remove that one with the archive's own tool
first, so each tool only ever reverses its own hunk.

Exit codes: 0 done or already in the requested state, 1 refused (the file is not in a known state), 2 usage.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import stat
import sys
import tempfile

HERE = Path(__file__).resolve().parent
UPSTREAM = (HERE / "upstream.qmlpart").read_text()
VARIANT = (HERE / "variant.qmlpart").read_text()
ARCHIVE = (HERE / "archive.qmlpart").read_text()


class Refused(Exception):
    pass


def state(text: str) -> str:
    """upstream | variant | archive | unknown (none, or more than one, of the known hunks)."""
    counts = {name: text.count(hunk) for name, hunk in (("variant", VARIANT), ("archive", ARCHIVE), ("upstream", UPSTREAM))}
    found = [name for name, count in counts.items() if count]
    if len(found) == 1 and counts[found[0]] == 1:
        return found[0]
    return "unknown"


def apply(path: Path, remove: bool = False) -> str:
    """Returns "installed", "removed" or "unchanged"; raises Refused when the file is not in a known state."""
    text = path.read_text()
    current = state(text)
    wanted, before, after = ("upstream", VARIANT, UPSTREAM) if remove else ("variant", UPSTREAM, VARIANT)
    if current == wanted:
        return "unchanged"
    if current == "archive":
        raise Refused(f"{path} has the archive's clock hook (fart open). Remove it with the archive's tool first.")
    if current != ("variant" if remove else "upstream"):
        raise Refused(f"{path}: the clock handler is not the one this hook knows. Review the file; nothing was changed.")
    staged = None
    try:
        with tempfile.NamedTemporaryFile("w", dir=path.parent, prefix=f".{path.name}.", delete=False) as out:
            staged = Path(out.name)
            out.write(text.replace(before, after, 1))
        staged.chmod(stat.S_IMODE(path.stat().st_mode))
        if path.read_text() != text:
            raise Refused(f"{path} changed while the hook was being written; nothing was changed. Retry after reviewing it.")
        os.replace(staged, path)
        staged = None
    finally:
        if staged:
            staged.unlink(missing_ok=True)
    return "removed" if remove else "installed"


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--remove", action="store_true", help="restore the upstream handler")
    mode.add_argument("--check", action="store_true", help="print the state and change nothing")
    parser.add_argument("file", type=Path, help="a TimeDateFace.qml to change; there is no default")
    args = parser.parse_args(argv)
    try:
        if args.check:
            print(state(args.file.read_text()))
            return 0
        result = apply(args.file, args.remove)
    except (Refused, OSError, UnicodeDecodeError) as error:
        print(f"clock_hook: {error}", file=sys.stderr)
        return 1
    print({"installed": "Installed the FART clock hook variant.", "removed": "Restored the upstream clock handler.",
           "unchanged": "Already in the requested state."}[result])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
