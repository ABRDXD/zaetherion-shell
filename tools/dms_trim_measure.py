#!/usr/bin/env python3
"""What each always-on part of quiet DMS's hidden UI costs, in the nested test Hyprland (measurement only).

Copies the quiet copy the session runs (tools/dms_quiet.py, read only), then makes one copy per variant with one part
taken out of DMSShell.qml (or one setting changed), and runs each under a private core with a real `dms run`:
private HOME, XDG folders, runtime folder and session bus, and no system bus (no NetworkManager, BlueZ, polkit or
logind, so nothing real is touched; absolute numbers are therefore a little below the live session's). The owner's
DMS settings are copied in read only, so the parts that load are the ones the owner's settings load. The owner's
own DMS settings are checked unchanged at the end.

A copy with a part removed is not meant to run: ids that other parts use may now log errors. It answers "what does
this part cost", nothing else. Not part of the unit suite.

    dms_trim_measure.py [--quiet DIR] [--rounds N] [--settle S] [--only a,b] OUT.txt
    dms_trim_measure.py --check OUT.txt     # the copy with every trim (dms_quiet.TRIMS) against the untrimmed one:
                                            # same IPC calls (menus only: no audio, brightness, lock or power), logs
"""
import argparse
import json
import os
import shutil
import signal
import statistics
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dms_quiet  # noqa: E402
import nested_hypr  # noqa: E402
import notiftest  # noqa: E402
from supervisor_check import REAL, Bench, wait  # noqa: E402

HOME = Path.home()
SETTINGS, SESSION = HOME / ".config/dms/settings.json", HOME / ".local/state/dms/session.json"
# The live DMS rewrites session.json by itself (e.g. lastPlayerIdentity), so that file is checked for traces of the
# private runs, not for its time; settings.json must not change at all. Each run also asserts private folders.
SHELL, CORE = Path("DMSShell.qml"), Path("ShellCore.qml")

# name: (what it is, [(file, opening line, text the block must contain or None)], settings changes)
VARIANTS = {
    "quiet": ("the quiet copy as it runs live (baseline)", [], {}),
    "desktop": ("desktop widget layer, editor and right-click menu", [
        (SHELL, "DesktopWidgetLayer {}", None), (SHELL, "DesktopWidgetEditor {}", None),
        (SHELL, "DesktopContextMenu {", None)], {}),
    "lock": ("the lock screen (stays: Z94; measured for scale)", [(SHELL, "Lock {", None)], {}),
    "popups": ("notification popups, per screen (ours shows them)", [(SHELL, "Variants {", "NotificationPopupManager")], {}),
    "mux": ("terminal multiplexer modal", [(SHELL, "MuxModal {", None)], {}),
    "clipboard": ("clipboard history modal (stays: quick paste; measured for scale)",
                  [(SHELL, "ClipboardHistoryModal {", None)], {}),
    "notifmodal": ("notification centre modal (ours is the inbox)", [(SHELL, "NotificationModal {", None)], {}),
    "colorpicker": ("colour picker modal", [(SHELL, "ColorPickerModal {", None)], {}),
    "notepad": ("notepad slide-out, per screen", [(SHELL, "Variants {", "notepadSlideoutVariants")], {}),
    "toast": ("toasts, per screen", [(SHELL, "Variants {", "delegate: Toast")], {}),
    "osd": ("on-screen displays (volume, brightness ...), per screen", [(SHELL, "Loader {", "osdSurfacesLoader")], {}),
    "bridge": ("ZÆTHERION's launcher bridge (stays: Z197; measured for scale)",
               [(SHELL, "ZaetherionLauncherBridge {}", None)], {}),
    "bar": ("the hidden bar, as a setting: the first bar config disabled", [], {"bar0.enabled": False}),
    # The same per-screen parts kept but given no screens: ids and required properties stay valid (notepad's
    # Variants is a required property of DMSShellIPC, so removing it also breaks the IPC object).
    "popups0": ("notification popups on no screen", [(SHELL, "model: root.notificationPopupScreens", "model: []")], {}),
    "notepad0": ("notepad slide-out on no screen", [(SHELL, 'model: SettingsData.getFilteredScreens("notepad")', "model: []")], {}),
    "toast0": ("toasts on no screen", [(SHELL, 'model: SettingsData.getFilteredScreens("toast")', "model: []")], {}),
    "osd0": ("on-screen displays never loaded", [(SHELL, "active: root.osdSurfacesLoaded", "active: false")], {}),
    # What the core could do instead of hiding the bar (Z159): turn it off once DMS is up, as dms_bar sets `visible`.
    "bar-later": ("the bar made, then turned off after the settle (DMS reloads settings.json); settles again",
                  [], {"bar0.enabled.later": False}),
}
# Everything a trim could take, together: not lock, clipboard or bridge.
SMALL = ("desktop", "popups0", "mux", "notifmodal", "colorpicker", "notepad0", "toast0", "osd0")
TRIMMABLE = (*SMALL, "bar")
GROUPS = {"small": SMALL, "trimmable": TRIMMABLE}
# Opened in --check: what ZÆTHERION's keybinds and the island reach in DMS that a trim could break, menus only.
IPC = [["spotlight", "toggle"], ["spotlight", "toggle"], ["clipboard", "toggle"], ["clipboard", "toggle"],
       ["control-center", "toggle"], ["control-center", "toggle"], ["powermenu", "toggle"], ["powermenu", "toggle"],
       ["settings", "toggle"], ["settings", "toggle"], ["dash", "toggle", "overview"], ["dash", "toggle", "overview"]]


def drop(text: str, opening: str, contains: str | None) -> str:
    """The text without the one top-level (4-space) block that opens with `opening` and contains `contains`."""
    hits, start = [], 0
    while (i := text.find("\n    " + opening, start)) >= 0:
        begin = i + 1
        end = dms_quiet.block_end(text, begin)
        if contains is None or contains in text[begin:end]:
            hits.append((begin, end))
        start = end
    if len(hits) != 1:
        raise ValueError(f"expected one block '{opening}' containing {contains!r}, found {len(hits)}")
    begin, end = hits[0]
    return text[:begin] + f"    // dms_trim_measure: removed '{opening.rstrip(' {}')}'" + text[end:]


def replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise ValueError(f"expected '{old}' once, found {text.count(old)}")
    return text.replace(old, new)


def variant_copy(quiet: Path, out: Path, drops) -> Path:
    """A hard-linked copy (cheap); a changed file is unlinked first, so the baseline's inode is never written.
    Each change is (file, opening, contains) to drop a block, or (file, old, new) with `new` not None and `old` a
    line fragment (not an opening ending in "{" or "{}") to replace text."""
    shutil.copytree(quiet, out, symlinks=True, copy_function=os.link)
    for path, opening, contains in drops:
        source = (out / path).read_text()
        if opening.endswith(("{", "{}")):
            text = drop(source, opening, contains)
        else:
            text = replace_once(source, opening, contains)
        (out / path).unlink()
        (out / path).write_text(text)
    return out


def owner_settings(config: Path, state: Path, changes: dict):
    (config / "dms").mkdir(parents=True, exist_ok=True)
    src = HOME / ".config/dms"
    for name in ("settings.json", "plugin_settings.json", "clsettings.json", "plugins.lock.json"):
        if (src / name).is_file():
            shutil.copyfile(src / name, config / "dms" / name)
    for name in ("plugins", "themes"):
        if (src / name).is_dir():
            shutil.copytree(src / name, config / "dms" / name, symlinks=True)
    settings = json.loads((config / "dms/settings.json").read_text())
    if "bar0.enabled" in changes:
        settings["barConfigs"][0]["enabled"] = changes["bar0.enabled"]
    (config / "dms/settings.json").write_text(json.dumps(settings, indent=2))
    (state / "dms").mkdir(parents=True, exist_ok=True)
    if (HOME / ".local/state/dms/session.json").is_file():
        shutil.copyfile(HOME / ".local/state/dms/session.json", state / "dms/session.json")


def kib(pid: int) -> dict:
    out = {}
    for line in Path(f"/proc/{pid}/smaps_rollup").read_text().splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].rstrip(":") in ("Rss", "Pss", "Private_Dirty", "Pss_Anon", "Pss_File"):
            out[parts[0].rstrip(":")] = int(parts[1])
    return out


def run_variant(work: Path, st: dict, bus, ui: Path, changes: dict, settle: float, samples: int, keep: Path,
                ipc: list | None = None):
    work.mkdir()
    bench = Bench(work, st)
    home = work / "home"
    (home / "data").mkdir(parents=True)
    owner_settings(work / "config", work / "state", changes)
    bench.env.update(DBUS_SESSION_BUS_ADDRESS=bus.address, DBUS_SYSTEM_BUS_ADDRESS=notiftest.NOWHERE,
                     FART_RESIDENT_DIR=str(ui), HOME=str(home), XDG_DATA_HOME=str(home / "data"))
    for name in [k for k in bench.env if k.startswith("DMS_")]:
        bench.env.pop(name)
    try:
        if not (bench.start_core() and bench.up(timeout=40)):
            return None, "did not come up"
        qs = bench.named("qs")[0]
        time.sleep(settle)
        if "bar0.enabled.later" in changes:
            path = work / "config/dms/settings.json"
            settings = json.loads(path.read_text())
            settings["barConfigs"][0]["enabled"] = changes["bar0.enabled.later"]
            path.with_name(".s").write_text(json.dumps(settings, indent=2))
            os.replace(path.with_name(".s"), path)
            time.sleep(settle)
            if bench.named("qs") != [qs]:
                return None, "qs restarted after the change"
        answers = []
        for call in ipc or []:
            r = subprocess.run(["dms", "ipc", "call", *call], env=bench.env, capture_output=True, text=True, timeout=15)
            answers.append((" ".join(call), r.returncode, (r.stdout + r.stderr).strip()[:100]))
            time.sleep(1.5)
        if ipc and bench.named("qs") != [qs]:
            return None, "qs restarted during the IPC calls"
        rows = []
        for _ in range(samples):
            rows.append(kib(qs))
            time.sleep(2)
        log = bench.run / "zaetherion" / "dms.log"
        text = log.read_text(errors="replace") if log.exists() else ""
        keep.write_text(text)  # beside OUT, never committed: a DMS log can name local paths
        here = [l for l in Path(f"/proc/{qs}/environ").read_bytes().split(b"\0") if l.startswith((b"HOME=", b"XDG_STATE_HOME=", b"XDG_CONFIG_HOME="))]
        if any(str(work).encode() not in l for l in here):
            raise SystemExit(f"the nested DMS is not on private folders: {here}")
        errors = sum(1 for line in text.splitlines() if " ERROR" in line or "ReferenceError" in line or "TypeError" in line)
        row = {k: statistics.median(r[k] for r in rows) for k in rows[0]}
        if ipc is not None:  # Quickshell's own log: QML errors reach it, not dms.log
            qs_log = subprocess.run(["qs", "log", "--pid", str(qs)], env=bench.env, capture_output=True, text=True,
                                    timeout=30).stdout
            keep.with_suffix(".qs.log").write_text(qs_log)
            row["answers"] = answers
            row["log"] = text + "\n" + qs_log
        return row, f"{errors} error lines"
    finally:
        try:
            bench.request("shutdown")
            wait(lambda: bench.exited() and not bench.processes(), 15)
        except OSError:
            pass
        for pid in bench.processes():
            try:
                os.kill(pid, signal.SIGKILL)
            except OSError:
                pass
        shutil.rmtree(work, ignore_errors=True)  # a run folder holds a copy of the owner's plugins; tmpfs


def main():
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    parser.add_argument("out", type=Path)
    parser.add_argument("--rounds", type=int, default=2)
    parser.add_argument("--settle", type=float, default=30.0)
    parser.add_argument("--samples", type=int, default=5)
    parser.add_argument("--only", default="")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--quiet", type=Path, default=dms_quiet.default_out(), help="the quiet copy to start from")
    args = parser.parse_args()
    if args.check:
        return check(args)
    names = [n for n in args.only.split(",") if n] or [*VARIANTS, "trimmable"]
    logs = args.out.with_suffix(".logs")
    logs.mkdir(parents=True, exist_ok=True)
    settings_before = SETTINGS.stat().st_mtime_ns if SETTINGS.exists() else None
    source = args.quiet
    if dms_quiet.check(source):
        raise SystemExit(f"{source} is not a quiet copy: " + "; ".join(dms_quiet.check(source)))
    st = nested_hypr.start()
    (REAL / "zaetherion").mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="dms-trim-", dir=REAL / "zaetherion"))  # short: the core's socket lives here
    copies_dir = Path(tempfile.mkdtemp(prefix="dms-trim-ui-"))  # the UI copies (48 MiB, hard-linked per variant)
    bus = notiftest.Bus()
    results = {n: [] for n in names}
    notes = {}
    try:
        quiet = copies_dir / "quiet-ui"
        shutil.copytree(source, quiet, symlinks=True)
        copies = {}
        for name in names:
            if name in GROUPS:
                drops = [d for n in GROUPS[name] for d in VARIANTS[n][1]]
                changes = {k: v for n in GROUPS[name] for k, v in VARIANTS[n][2].items()}
            else:
                drops, changes = VARIANTS[name][1], VARIANTS[name][2]
            copies[name] = (variant_copy(quiet, copies_dir / f"ui-{name}", drops) if drops else quiet, changes)
        for r in range(args.rounds):
            for name in names:
                ui, changes = copies[name]
                row, note = run_variant(work / f"run-{name}-{r}", st, bus, ui, changes, args.settle, args.samples,
                                        logs / f"{name}-{r}.log")
                print(f"round {r} {name}: {row and round(row['Pss'] / 1024, 1)} MiB PSS ({note})", flush=True)
                if row:
                    results[name].append(row)
                notes[name] = note
    finally:
        shutil.rmtree(copies_dir, ignore_errors=True)
        bus.stop()
        if nested_hypr.STATE.exists():
            nested_hypr.stop()
    traces = ("dms-trim", str(REAL / "zaetherion"), "ZTEST")
    session = SESSION.read_text(errors="replace") if SESSION.exists() else ""
    settings_text = SETTINGS.read_text(errors="replace") if SETTINGS.exists() else ""
    settings_same = (SETTINGS.stat().st_mtime_ns if SETTINGS.exists() else None) == settings_before
    owner_ok = not any(t in session or t in settings_text for t in traces)

    base = statistics.median(r["Pss"] for r in results.get("quiet", [])) if results.get("quiet") else None
    lines = [f"# quiet DMS hidden UI, cost per part (tools/dms_trim_measure.py, {time.strftime('%Y-%m-%d %H:%M')})",
             f"# DMS UI revision {dms_quiet.revision(source)}; nested Hyprland, one headless output; owner's DMS settings,",
             "# no system bus; settle %.0f s, %d samples 2 s apart per run, median over %d rounds. MiB of the qs process."
             % (args.settle, args.samples, args.rounds),
             "# saved = baseline PSS minus this variant's PSS (positive: removing it saves memory).", "",
             f"{'variant':<12} {'RSS':>7} {'PSS':>7} {'PrivDirty':>9} {'PssAnon':>8} {'PssFile':>8} {'saved':>7}  rounds  log   what"]
    for name in names:
        rows = results[name]
        if not rows:
            lines.append(f"{name:<12} (no data: {notes.get(name)})")
            continue
        med = {k: statistics.median(r[k] for r in rows) / 1024 for k in rows[0]}
        spread = (max(r["Pss"] for r in rows) - min(r["Pss"] for r in rows)) / 1024
        saved = f"{base / 1024 - med['Pss']:7.1f}" if base else "      ?"
        what = "together: " + ", ".join(GROUPS[name]) if name in GROUPS else VARIANTS[name][0]
        lines.append(f"{name:<12} {med['Rss']:7.1f} {med['Pss']:7.1f} {med['Private_Dirty']:9.1f} {med['Pss_Anon']:8.1f} "
                     f"{med['Pss_File']:8.1f} {saved}  {len(rows)} ±{spread:.1f}  {notes.get(name, '')}  {what}")
    lines += ["", f"# no trace of the runs in the owner's DMS files: {'yes' if owner_ok else 'NO'}; settings.json "
              + ("unchanged" if settings_same else "changed during the runs (the live DMS saves it too, e.g. a refresh"
                 " rate on charger in/out; the private runs had their own HOME and no system bus)")]
    args.out.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    if owner_ok:
        shutil.rmtree(work, ignore_errors=True)
    else:
        print(f"kept for inspection: {work}")
    return 0 if owner_ok else 1


def warnings(log: str, work: Path) -> set[str]:
    """The log's warning and error lines, with each run's private folder and numbers made comparable."""
    import re
    out = set()
    for line in log.splitlines():
        if any(w in line for w in ("WARN", "ERROR", "Error", "rror:", " warn", "not initialized", "is not defined")):
            line = re.sub(r"\x1b\[[0-9;]*m", "", line)  # colours
            line = re.sub(r"0x[0-9a-fA-F]+", "ADDR", line)  # object addresses differ per run
            line = re.sub(r"/run/user/\d+/zaetherion/dms-trim-[^/ ]+/run-[^/ ]+", "<run>", line)
            out.add(re.sub(r"\d+", "N", line).strip())
    return out


def check(args) -> int:
    source = args.quiet
    st = nested_hypr.start()
    (REAL / "zaetherion").mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="dms-trim-", dir=REAL / "zaetherion"))
    copies = Path(tempfile.mkdtemp(prefix="dms-trim-ui-"))
    bus = notiftest.Bus()
    logs = args.out.with_suffix(".logs")
    logs.mkdir(parents=True, exist_ok=True)
    rows = {}
    try:
        plain = copies / "plain"
        shutil.copytree(source, plain, symlinks=True)
        dms_quiet.set_trims(plain, [])
        trimmed = variant_copy(plain, copies / "trimmed", [])
        (trimmed / SHELL).unlink()
        (trimmed / SHELL).write_text((plain / SHELL).read_text())
        dms_quiet.set_trims(trimmed, list(dms_quiet.TRIMS))
        # The control: notepad removed outright breaks DMSShellIPC's required property, so its run must log errors
        # the plain one doesn't; if it doesn't, this check can't see QML errors and proves nothing.
        control = variant_copy(plain, copies / "control", VARIANTS["notepad"][1])
        for name, ui in (("plain", plain), ("trimmed", trimmed), ("control", control)):
            row, note = run_variant(work / f"run-{name}", st, bus, ui, {}, args.settle, args.samples,
                                    logs / f"check-{name}.log", IPC)
            rows[name] = (row, note)
            print(f"{name}: {row and round(row['Pss'] / 1024, 1)} MiB PSS ({note})", flush=True)
    finally:
        shutil.rmtree(copies, ignore_errors=True)
        bus.stop()
        if nested_hypr.STATE.exists():
            nested_hypr.stop()
    lines = [f"# dms_trim_measure.py --check, {time.strftime('%Y-%m-%d %H:%M')}: trims {', '.join(dms_quiet.TRIMS)}", ""]
    ok = all(r for r, _ in rows.values())
    if ok:
        (a, _), (b, _), (c, _) = rows["plain"], rows["trimmed"], rows["control"]
        seen = sorted(warnings(c["log"], work) - warnings(a["log"], work))
        ok &= bool(seen)
        lines.append(f"control (notepad removed outright) logs {len(seen)} new warnings: "
                     + ("the check sees QML errors" if seen else "NONE, so this check is blind"))
        lines += [f"  {w[:220]}" for w in seen[:3]]
        lines.append(f"PSS MiB: plain {a['Pss'] / 1024:.1f}, trimmed {b['Pss'] / 1024:.1f}")
        for (call, rc_a, out_a), (_, rc_b, out_b) in zip(a["answers"], b["answers"]):
            same = rc_a == rc_b and out_a == out_b
            ok &= same
            lines.append(f"{'SAME' if same else 'DIFF'} ipc {call}: plain rc={rc_a} {out_a!r} | trimmed rc={rc_b} {out_b!r}")
        new = sorted(warnings(b["log"], work) - warnings(a["log"], work))
        ok &= not new
        lines.append(f"warnings only the trimmed copy logs: {len(new)}")
        lines += [f"  {w[:220]}" for w in new]
    else:
        lines.append("a run failed: " + "; ".join(f"{n}: {note}" for n, (_, note) in rows.items()))
    lines.append(f"result: {'PASS' if ok else 'FAIL'}")
    args.out.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    shutil.rmtree(work, ignore_errors=True)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
