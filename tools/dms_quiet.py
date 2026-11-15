#!/usr/bin/env python3
"""Build DMS's own UI without its notification server ("quiet DMS"), so ours can hold the bus name; it also leaves
NetworkManager's password prompts and BlueZ's pairing prompts to FART (Z191).

DMS has no switch for its notification server: `Services/NotificationService.qml` declares one
`NotificationServer`, and Quickshell claims `org.freedesktop.Notifications` when that object is made.
This tool copies the UI that the installed DMS runs and removes that one object; nothing else
in it references the object (checked: its id is unused), so DMS's notification centre stays empty and
its popups never fire while the rest of DMS (bar, control centre, lock, OSDs) is unchanged.

The copy is generated on this machine and never checked in (DMS is MIT; see NOTICE). Point the
supervisor at it with FART_RESIDENT_DIR, which reaches `dms run` as DMS_SHELL_DIR (docs/SUPERVISOR.md §5).

    tools/dms_quiet.py build [--source DIR] [--out DIR]   # default source: the running DMS's UI
    tools/dms_quiet.py check DIR                           # exit 0 if DIR is a quiet copy
    tools/dms_quiet.py fits DIR                            # exit 0 if DIR was made for the installed `dms`
    tools/dms_quiet.py bridge [DIR]                        # add the launcher bridge to an existing copy (Z197)

The copy also carries ZÆTHERION's launcher bridge (adapters/dms/bridge, Z197): DMS's own launcher engine, served to
the star chart over a private socket. `bridge` adds it to a copy made before it, without rebuilding.

`dms version` names no UI revision, and the UI is extracted only when DMS runs, so at login (before DMS) an upgrade
can't be seen by revision. `build` therefore also records the installed `dms` program (path, size, mtime);
`fits` compares it, so tools/session-start turns ours on only for the DMS the copy was made from.
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
BAR = Path("Modules/DBar/DBarBody.qml")
# DMS reserves an island-style bar's strip even while the bar is hidden (`visible` is checked only for ordinary
# bars), so with ours on top the windows sat ~34 px lower than needed (owner, 13 November 2026). A hidden bar reserves
# nothing; a shown one is unchanged.
BAR_FROM = "readonly property real surfaceExclusiveZone: isIsland ? ((islandFree || "
BAR_TO = "readonly property real surfaceExclusiveZone: isIsland ? (!(barConfig?.visible ?? true) ? -1 : (islandFree || "
# DMS's own password and pairing windows (docs/NET_BT.md §1, Z191). DMS's backend is NetworkManager's secret agent and
# BlueZ's pairing agent, and broadcasts each prompt to every subscriber; DMS's UI would open its own window beside
# FART's and cancel our token. Each handler gets an early return, so the prompt is left to FART; the rest of DMS's
# Wi-Fi and Bluetooth UI is unchanged.
PROMPTS = (
    (Path("DMSShell.qml"), "function onCredentialsNeeded(token, ssid, setting, fields, hints, reason, connType, connName, vpnService, fieldsInfo) {"),
    (Path("Modules/ControlCenter/Details/BluetoothDetail.qml"), "function onBluetoothPairingRequest(data) {"),
)
PROMPT_NOTE = "return; // ZÆTHERION tools/dms_quiet.py: FART answers this prompt (docs/NET_BT.md, Z191)"
# The launcher bridge (Z197): one file beside DMS's launcher and one instance at the end of DMSShell.qml.
# A template (.qml.in): it imports DMS's modules, so it is QML only once installed inside DMS.
BRIDGE_SOURCE = Path(__file__).resolve().parents[1] / "adapters/dms/bridge/ZaetherionLauncherBridge.qml.in"
BRIDGE = Path("Modals/DLauncherV2/ZaetherionLauncherBridge.qml")
SHELL = Path("DMSShell.qml")
BRIDGE_LINE = "    ZaetherionLauncherBridge {} // ZÆTHERION tools/dms_quiet.py: DMS's launcher engine for the star chart (Z197)"
MARKER = ".zaetherion-quiet"
PROGRAM = ".zaetherion-dms"
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


def hidden_bar_reserves_nothing(text: str) -> str:
    """DBarBody.qml with the hidden-island-bar reservation removed. Refuses a file it doesn't recognise."""
    if text.count(BAR_FROM) != 1:
        raise ValueError(f"{BAR}: the island bar's exclusive zone is not the expression this patch knows")
    return text.replace(BAR_FROM, BAR_TO)


def prompt_left_to_fart(text: str, path: Path, opening: str) -> str:
    """The file with one prompt handler returning at once. Refuses a file without exactly one such handler."""
    lines = text.split("\n")
    found = [i for i, line in enumerate(lines) if line.strip() == opening]
    if len(found) != 1:
        raise ValueError(f"{path}: expected one '{opening}', found {len(found)}")
    i = found[0]
    indent = lines[i][: len(lines[i]) - len(lines[i].lstrip())]
    lines.insert(i + 1, indent + "    " + PROMPT_NOTE)
    return "\n".join(lines)


def with_bridge(text: str) -> str:
    """DMSShell.qml with one bridge instance before the root's closing brace. Idempotent; refuses an unknown shape."""
    if BRIDGE_LINE in text:
        return text
    if "import qs.Modals.DLauncherV2" not in text:
        raise ValueError(f"{SHELL}: does not import DMS's launcher (qs.Modals.DLauncherV2)")
    body = text.rstrip()
    if not body.endswith("}"):
        raise ValueError(f"{SHELL}: does not end with the root object's closing brace")
    return body[:-1].rstrip() + "\n\n" + BRIDGE_LINE + "\n}\n"


def add_bridge(directory: Path) -> Path:
    """Puts the launcher bridge into a quiet copy (only one this tool made)."""
    if not (directory / MARKER).is_file():
        raise SystemExit(f"dms_quiet: {directory} is not a quiet copy; not touching it")
    shell = with_bridge((directory / SHELL).read_text())  # before writing anything
    (directory / BRIDGE).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(BRIDGE_SOURCE, directory / BRIDGE)
    (directory / SHELL).write_text(shell)
    return directory


def bridge_problems(directory: Path) -> list[str]:
    """Why a copy lacks the launcher bridge; a warning, not part of check() (the star chart falls back without it)."""
    problems = []
    if not (directory / BRIDGE).is_file():
        problems.append("no launcher bridge (run `tools/dms_quiet.py bridge`)")
    elif (directory / BRIDGE).read_text() != BRIDGE_SOURCE.read_text():
        problems.append("the launcher bridge is older than ZÆTHERION's (run `tools/dms_quiet.py bridge`)")
    if not (directory / SHELL).is_file() or BRIDGE_LINE not in (directory / SHELL).read_text():
        problems.append("DMSShell.qml makes no launcher bridge (run `tools/dms_quiet.py bridge`)")
    return problems


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


def program_stamp(program: str | None = None) -> str:
    """The installed `dms` program as path, size and mtime; "" when there is none."""
    found = program or shutil.which("dms")
    if not found:
        return ""
    path = Path(found).resolve()
    st = path.stat()
    return f"{path} {st.st_size} {st.st_mtime_ns}"


def fits(directory: Path, program: str | None = None) -> list[str]:
    """Why the quiet copy in `directory` shouldn't run with the installed DMS; [] when it should."""
    problems = check(directory)
    stamp = directory / PROGRAM
    now = program_stamp(program)
    if not now:
        problems.append("no dms program installed")
    elif not stamp.is_file():
        problems.append("the copy records no dms program; rebuild it with the stock UI running")
    elif stamp.read_text().strip() != now:
        problems.append("dms changed since the copy was made (an upgrade?); rebuild it with the stock UI running")
    return problems


def build(source: Path, out: Path) -> Path:
    if (source / MARKER).exists() or source.resolve() == out.resolve():
        raise SystemExit(f"dms_quiet: {source} is a quiet copy; build from DMS's stock UI")
    text = (source / SERVICE).read_text()
    patched = quiet(text)  # before any copying: a DMS we don't understand leaves nothing behind
    bar = hidden_bar_reserves_nothing((source / BAR).read_text())
    prompts = {path: prompt_left_to_fart((source / path).read_text(), path, opening) for path, opening in PROMPTS}
    prompts[SHELL] = with_bridge(prompts.get(SHELL, (source / SHELL).read_text()))
    if out.exists():
        if not (out / MARKER).is_file():
            raise SystemExit(f"dms_quiet: {out} exists and is not a quiet copy; not touching it")
        shutil.rmtree(out)
    shutil.copytree(source, out, symlinks=True)
    for path in [out, *out.rglob("*")]:  # DMS extracts read-only
        if not path.is_symlink():
            path.chmod(path.stat().st_mode | 0o200)
    (out / SERVICE).write_text(patched)
    (out / BAR).write_text(bar)
    for path, text in prompts.items():
        (out / path).write_text(text)
    (out / BRIDGE).parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(BRIDGE_SOURCE, out / BRIDGE)
    (out / MARKER).write_text(revision(source) + "\n")
    (out / PROGRAM).write_text(program_stamp() + "\n")
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
    bar = directory / BAR
    if not bar.is_file() or BAR_TO not in bar.read_text():
        problems.append("a hidden island bar still reserves its strip")
    for path in directory.rglob("*.qml"):
        if path != service and OPENING.search(path.read_text(errors="replace")):
            problems.append(f"{path.relative_to(directory)} declares a NotificationServer")
    return problems


def prompt_problems(directory: Path) -> list[str]:
    """Which of DMS's own prompt windows a copy still opens (Z191). Not part of check(): a copy made before Z191 still
    runs our notification server at login; DMS's window then shows beside FART's until the copy is rebuilt."""
    return [f"{path} still opens DMS's own window" for path, _ in PROMPTS
            if not (directory / path).is_file() or PROMPT_NOTE not in (directory / path).read_text()]


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
    f = sub.add_parser("fits")
    f.add_argument("directory", type=Path)
    g = sub.add_parser("bridge")
    g.add_argument("directory", type=Path, nargs="?")
    args = parser.parse_args(argv)
    if args.command == "build":
        source = args.source or running_source()
        out = build(source, args.out or default_out())
        print(f"quiet DMS UI (revision {revision(source)}): {out}")
        return 0
    if args.command == "bridge":
        out = add_bridge(args.directory or default_out())
        print(f"launcher bridge added: {out / BRIDGE}")
        return 0
    problems = check(args.directory) if args.command == "check" else fits(args.directory)
    for problem in problems:
        print("dms_quiet:", problem, file=sys.stderr)
    for warning in prompt_problems(args.directory):
        print("dms_quiet: warning:", warning, "(rebuild the copy to leave it to FART)", file=sys.stderr)
    for warning in bridge_problems(args.directory):
        print("dms_quiet: warning:", warning, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
