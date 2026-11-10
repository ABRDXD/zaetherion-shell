#!/usr/bin/env python3
"""The cutover (M7, docs/CUTOVER.md): point `fart` and the clock's right-click at fart-next, and back.

    cutover.py check                  read-only preflight of this desktop; changes nothing
    cutover.py plan                   print the steps apply and rollback take
    cutover.py apply --root DIR       rehearse on a sandbox: DIR/.local/bin and DIR/TimeDateFace.qml
    cutover.py rollback --root DIR
    cutover.py apply --live           the real switch, run only on the user's instruction (AGENTS.md)
    cutover.py rollback --live

Only the entry points change: ~/.local/bin/fart, a new ~/.local/bin/fart-archive (the archive by an explicit
path), and the clock's hunk in Serpantinum's TimeDateFace.qml. Each side keeps its own state, runtime and cache
directories, so a rollback finds the archive's state exactly as it left it. The archive's hunk is removed and
restored by the archive's own tool (tools/fart_clock.py), the variant by adapters/serpantinum/hook, so each tool
only ever reverses its own hunk. The archive's tree is imported read-only and never edited.

Exit codes: 0 done (or already in the requested state; `check`: nothing blocks), 1 refused or blocked, 2 usage.
"""
from __future__ import annotations

import argparse
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "adapters/serpantinum/hook"))
import clock_hook  # type: ignore  # noqa: E402  (adapters/serpantinum/hook, by path)

HOME = Path.home()
ARCHIVE = HOME / ".local/share/fart/source"
NEXT = HOME / ".local/share/fart/next"
REVIEWED = "m6-design"
ARCHIVE_LAUNCHER = '#!/bin/sh\nexec python3 "$HOME/.local/share/fart/source/tools/fart.py" "$@"\n'
NEXT_LAUNCHER = '#!/bin/sh\nexec python3 "$HOME/.local/share/fart/next/tools/fart_next.py" "$@"\n'

APPLY_STEPS = [
    "check: `fart` is the archive's launcher and the clock carries the archive's hunk (else refuse)",
    "live: stop the archive's panel (`fart stop`, the archive's CLI)",
    "write ~/.local/bin/fart-archive: the archive by an explicit path, for rollback",
    "write ~/.local/bin/fart: fart-next (~/.local/share/fart/next, branch main)",
    "clock: remove the archive's hunk with the archive's tool, then install the variant (`fart toggle --from … --screen …`)",
    "live: reload Serpantinum's QML so the clock takes the new handler",
    "live: stop any fart-next still running from a worktree, then start it from main (`fart start`)",
]
ROLLBACK_STEPS = [
    "check: `fart` is fart-next's launcher and the clock carries the variant (else refuse)",
    "live: stop fart-next (`fart-next stop`)",
    "clock: restore the upstream handler with the variant's tool, then reinstall the archive's hunk with the archive's tool",
    "write ~/.local/bin/fart: the archive's launcher again; remove ~/.local/bin/fart-archive",
    "live: reload Serpantinum's QML",
    "live: start the archive's panel (`fart start`)",
]


class Refused(Exception):
    pass


def archive_clock():
    """The archive's own clock tool (tools/fart_clock.py), loaded read-only."""
    path = ARCHIVE / "tools/fart_clock.py"
    if not path.is_file():
        raise Refused(f"the archive's clock tool is missing: {path}")
    spec = importlib.util.spec_from_file_location("fart_clock_archive", path)
    if spec is None or spec.loader is None:
        raise Refused(f"the archive's clock tool can't be loaded: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def live_clock() -> Path:
    if os.environ.get("SERPANTINUM_DIR"):
        root = Path(os.environ["SERPANTINUM_DIR"])
    else:
        cli = shutil.which("serpantinum")
        if not cli:
            raise Refused("the Serpantinum launcher is missing, so the live clock file can't be found")
        root = Path(cli).resolve().parents[1] / "src"
    return root / "quickshell/bar/faces/timedate/TimeDateFace.qml"


class Target:
    """Where a switch acts: the real desktop (`live`) or a sandbox for rehearsal."""

    def __init__(self, root: Path | None, clock: Path | None, live: bool):
        self.live = live
        home = HOME if live or root is None else root
        self.bin = home / ".local/bin"
        self.fart = self.bin / "fart"
        self.archive = self.bin / "fart-archive"
        self.clock = clock or (live_clock() if live else root / "TimeDateFace.qml")

    def launcher(self) -> str:
        text = self.fart.read_text() if self.fart.is_file() else ""
        return "archive" if text == ARCHIVE_LAUNCHER else "next" if text == NEXT_LAUNCHER else "unknown"

    def hook(self) -> str:
        return clock_hook.state(self.clock.read_text()) if self.clock.is_file() else "missing"


def write_launcher(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=path.parent, prefix=f".{path.name}.", delete=False) as out:
        out.write(text)
        staged = Path(out.name)
    staged.chmod(0o755)
    os.replace(staged, path)


def run(say, argv: list[str], what: str, check: bool = True):
    say(f"  {what}: {' '.join(argv)}")
    done = subprocess.run(argv, capture_output=True, text=True, timeout=60)
    if check and done.returncode != 0:
        raise Refused(f"{what} failed ({done.returncode}): {(done.stderr or done.stdout).strip()[-400:]}")


def reload_host(say):
    shell = live_clock().parents[3] / "Shell.qml"
    run(say, ["qs", "-p", str(shell), "ipc", "call", "main", "forceReload"], "reload Serpantinum", check=False)


def apply(t: Target, say=print) -> str:
    launcher, hook = t.launcher(), t.hook()
    if launcher == "next" and hook == "variant":
        return "unchanged"
    if launcher != "archive" or hook != "archive":
        raise Refused(f"expected the archive's launcher and clock hunk; found launcher {launcher}, clock {hook}. "
                      "Nothing was changed.")
    fart_clock = archive_clock()
    if t.live:
        run(say, ["python3", str(ARCHIVE / "tools/fart.py"), "stop"], "stop the archive")
    write_launcher(t.archive, ARCHIVE_LAUNCHER)
    say(f"  wrote {t.archive}")
    write_launcher(t.fart, NEXT_LAUNCHER)
    say(f"  wrote {t.fart} (fart-next)")
    fart_clock.clock_hook(remove=True, face=t.clock)
    clock_hook.apply(t.clock)
    say(f"  clock: {t.hook()}")
    if t.live:
        reload_host(say)
        # A running core may have been started from a worktree; `start` would only connect to it.
        run(say, [str(t.fart), "stop"], "stop fart-next", check=False)
        run(say, [str(t.fart), "start"], "start fart-next from main")
    return "applied"


def rollback(t: Target, say=print) -> str:
    launcher, hook = t.launcher(), t.hook()
    if launcher == "archive" and hook == "archive":
        return "unchanged"
    if launcher != "next" or hook != "variant":
        raise Refused(f"expected fart-next's launcher and the variant; found launcher {launcher}, clock {hook}. "
                      "Nothing was changed.")
    fart_clock = archive_clock()
    if t.live:
        run(say, ["python3", str(NEXT / "tools/fart_next.py"), "stop"], "stop fart-next", check=False)
    clock_hook.apply(t.clock, remove=True)
    fart_clock.clock_hook(remove=False, face=t.clock)
    say(f"  clock: {t.hook()}")
    write_launcher(t.fart, ARCHIVE_LAUNCHER)
    say(f"  wrote {t.fart} (the archive)")
    if t.archive.is_file() and t.archive.read_text() == ARCHIVE_LAUNCHER:
        t.archive.unlink()
        say(f"  removed {t.archive}")
    if t.live:
        reload_host(say)
        run(say, [str(t.fart), "start"], "start the archive")
    return "rolled back"


def git(path: Path, *args) -> str:
    done = subprocess.run(["git", "-C", str(path), *args], capture_output=True, text=True)
    return done.stdout.strip() if done.returncode == 0 else ""


def check() -> int:
    """Read-only. Each line: ok, wait (expected before the switch, or needs the user) or BLOCK."""
    rows = []
    t = Target(None, None, live=True)
    launcher, hook = t.launcher(), t.hook()
    rows.append(("ok" if launcher in ("archive", "next") else "BLOCK", f"`fart` launcher: {launcher} ({t.fart})"))
    rows.append(("ok" if hook in ("archive", "variant") else "BLOCK", f"clock hunk: {hook} ({t.clock})"))
    rows.append(("ok" if (launcher, hook) in (("archive", "archive"), ("next", "variant")) else "BLOCK",
                 "launcher and clock agree" if (launcher, hook) in (("archive", "archive"), ("next", "variant"))
                 else "launcher and clock disagree: finish or roll back the switch"))
    rows.append(("ok" if (ARCHIVE / "tools/fart.py").is_file() and (ARCHIVE / "tools/fart_clock.py").is_file() else "BLOCK",
                 f"the archive's CLI and clock tool are present ({ARCHIVE})"))
    branch, dirty = git(NEXT, "branch", "--show-current"), git(NEXT, "status", "--porcelain")
    rows.append(("ok" if branch == "main" and not dirty else "BLOCK", f"{NEXT}: branch {branch or '?'}, {'dirty' if dirty else 'clean'}"))
    behind = git(NEXT, "rev-list", "--count", f"main..{REVIEWED}")
    rows.append(("ok" if behind == "0" else "wait", f"main is {behind or '?'} commits behind {REVIEWED} (merging needs the user)"))
    helped = subprocess.run(["python3", str(NEXT / "tools/fart_next.py"), "toggle", "--help"], capture_output=True, text=True)
    rows.append(("ok" if "--from" in helped.stdout and "--screen" in helped.stdout else "BLOCK",
                 "fart-next accepts the variant's call (toggle --from --screen)"))
    state = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local/state")
    rows.append(("ok" if (state / "fart-next").is_dir() else "BLOCK", f"fart-next keeps its own state ({state / 'fart-next'})"))
    rows.append(("ok", f"the archive's state stays where it is ({state / 'fart'}); nothing here writes it"))
    archive_open = subprocess.run(["pgrep", "-f", "fart/[0-9a-f]+/package/shell.qml"], capture_output=True).returncode == 0
    rows.append(("ok", f"the archive's panel is {'running' if archive_open else 'stopped'}"))
    for mark, text in rows:
        print(f"{mark:5}  {text}")
    return 1 if any(mark == "BLOCK" for mark, _ in rows) else 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    parser.add_argument("action", choices=("check", "plan", "apply", "rollback"))
    where = parser.add_mutually_exclusive_group()
    where.add_argument("--root", type=Path, help="a sandbox to rehearse in")
    where.add_argument("--live", action="store_true", help="act on this desktop (only on the user's instruction)")
    parser.add_argument("--clock", type=Path, help="the TimeDateFace.qml to change (default: DIR/TimeDateFace.qml, or the live one)")
    args = parser.parse_args(argv)
    if args.action == "check":
        return check()
    if args.action == "plan":
        print("apply:")
        print("\n".join(f"  {i}. {s}" for i, s in enumerate(APPLY_STEPS, 1)))
        print("rollback:")
        print("\n".join(f"  {i}. {s}" for i, s in enumerate(ROLLBACK_STEPS, 1)))
        return 0
    if not args.root and not args.live:
        parser.error("apply and rollback need --root DIR (a rehearsal) or --live (the real switch)")
    try:
        target = Target(args.root, args.clock, args.live)
        result = (apply if args.action == "apply" else rollback)(target)
    except (Refused, clock_hook.Refused, RuntimeError, OSError) as error:
        print(f"cutover: {error}", file=sys.stderr)
        return 1
    print({"unchanged": "Already in the requested state.", "applied": "Switched to fart-next.",
           "rolled back": "Back on the archive."}[result])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
