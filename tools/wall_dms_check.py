#!/usr/bin/env python3
"""Live check of the wallpaper and theme commands our DMS adapters run (Z178, Z180), in the nested test Hyprland.

A real `dms run` (the stock UI DMS unpacked, read only) under the core, with private HOME, XDG folders, runtime
folder and session bus, so `dms ipc` can only reach this private DMS. Runs the exact argv from
adapters/dms/DmsWallpaperMap.js and DmsThemeMap.js, then reads back what DMS itself wrote with the same maps.
The session's own DMS files are checked unchanged at the end. Not part of the unit suite.

    [WALL_DMS_UI=<unpacked DMS UI>] wall_dms_check.py [OUT_DIR]     exit 1 if any check fails; OUT_DIR keeps before/after screenshots
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import nested_hypr  # noqa: E402
import notiftest  # noqa: E402
from supervisor_check import REAL, Bench, wait  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
OWNER_FILES = [HOME / ".config/dms/settings.json", HOME / ".local/state/dms/session.json"]


def js(module: str, expression: str):
    body = "\n".join(l for l in (ROOT / "adapters/dms" / module).read_text().splitlines() if not l.startswith(".pragma"))
    out = subprocess.run(["node", "-e", body + f"\nprocess.stdout.write(JSON.stringify({expression}));"],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def stock_ui() -> Path:
    if os.environ.get("WALL_DMS_UI"):  # an unpacked DMS UI to use instead, read only (e.g. the session's quiet copy)
        return Path(os.environ["WALL_DMS_UI"])
    found = sorted(Path("/run/user", str(os.getuid()), "dms-shell").glob("*/DMSShell.qml"), key=lambda p: p.stat().st_mtime)
    if not found:
        raise SystemExit("no unpacked DMS UI under /run/user/<uid>/dms-shell")
    return found[-1].parent


def png(path: Path, rgb):
    from PIL import Image
    Image.new("RGB", (320, 180), rgb).save(path)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if out:
        out.mkdir(parents=True, exist_ok=True)
    owner_before = {p: p.stat().st_mtime_ns for p in OWNER_FILES if p.exists()}
    st = nested_hypr.start()
    (REAL / "zaetherion").mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="wall-dms-", dir=REAL / "zaetherion"))
    bus = notiftest.Bus()
    results = []

    def check(name, ok, note=""):
        results.append(bool(ok))
        print(f"{'PASS' if ok else 'FAIL'} {name}{' (' + str(note) + ')' if note else ''}", flush=True)

    bench = Bench(work, st)
    home = work / "home"
    (home / "data").mkdir(parents=True)
    config = work / "config"
    bench.env.update(DBUS_SESSION_BUS_ADDRESS=bus.address, DBUS_SYSTEM_BUS_ADDRESS=notiftest.NOWHERE,
                     FART_RESIDENT_DIR=str(stock_ui()), HOME=str(home), XDG_DATA_HOME=str(home / "data"))
    for name in [k for k in bench.env if k.startswith("DMS_")]:
        bench.env.pop(name)
    themes = config / "dms/themes"
    themes.mkdir(parents=True)
    for theme in ("amoledBlack", "oxeoDeep"):
        shutil.copytree(HOME / ".config/dms/themes" / theme, themes / theme)
    (config / "dms/settings.json").write_text(json.dumps({"currentThemeName": "custom", "currentThemeCategory": "custom",
                                                          "customThemeFile": str(themes / "amoledBlack/theme.json")}))
    walls = work / "walls"
    walls.mkdir()
    a, b = walls / "a red wall.png", walls / "b-blue.png"
    png(a, (200, 30, 30))
    png(b, (30, 60, 200))
    session = work / "state/dms/session.json"
    settings = config / "dms/settings.json"

    def ipc(argv):
        return subprocess.run(argv, env=bench.env, capture_output=True, text=True, timeout=15)

    def shot(label):
        if out:
            subprocess.run([sys.executable, str(ROOT / "tools/nested_hypr.py"), "shot", str(out / f"{label}.png")],
                           check=True, stdout=subprocess.DEVNULL)

    try:
        check("private core and real DMS come up", bench.start_core() and bench.up(timeout=40))
        time.sleep(4)
        got = ipc(["dms", "ipc", "call", "wallpaper", "get"])
        check("dms ipc reaches only the private DMS", got.returncode == 0 and str(HOME / "Pictures") not in got.stdout,
              got.stdout.strip() or got.stderr.strip()[:120])
        # Wallpaper (Z178): the argv DmsWallpaper.set() runs.
        argv = js("DmsWallpaperMap.js", f"setCommand({json.dumps(str(a))})")
        result = ipc(argv)
        check("wallpaper set accepted", "SUCCESS" in result.stdout, result.stdout.strip()[:120])
        read = wait(lambda: js("DmsWallpaperMap.js", f"fromSession({json.dumps(session.read_text())})")
                    if session.exists() else None, 10)
        check("DMS wrote it; our map reads it back", read and read["current"] == str(a), read)
        ipc(js("DmsWallpaperMap.js", f"setCommand({json.dumps(str(b))})"))
        read = wait(lambda: (lambda r: r if r["current"] == str(b) else None)(
            js("DmsWallpaperMap.js", f"fromSession({json.dumps(session.read_text())})")), 10)
        check("a second set replaces it", read, read)
        # One wallpaper per screen (Z210): DMS refuses `set`, our setCommands use `setFor` on every screen instead.
        monitors = json.loads(subprocess.run(["hyprctl", "--instance", st["sig"], "monitors", "-j"],
                                            capture_output=True, text=True, timeout=15).stdout or "[]")
        screens = [m["name"] for m in monitors]
        check("the nested desktop names its screens", screens, screens)
        result = ipc(["dms", "ipc", "call", "wallpaper", "setFor", screens[0], str(a)] if screens else ["true"])
        check("per-screen mode on", "SUCCESS" in result.stdout, result.stdout.strip()[:120])
        result = ipc(js("DmsWallpaperMap.js", f"setCommand({json.dumps(str(b))})"))
        check("DMS refuses a plain set per screen (the bug)", "Per-monitor" in result.stdout, result.stdout.strip()[:120])
        argvs = js("DmsWallpaperMap.js", f"setCommands({json.dumps(str(b))}, true, {json.dumps(screens)})")
        outs = [ipc(argv).stdout for argv in argvs]
        check("setFor accepted on every screen", argvs and all("SUCCESS" in o for o in outs), outs)
        read = wait(lambda: (lambda r: r if r["current"] == str(b) and r["perScreen"] else None)(
            js("DmsWallpaperMap.js", f"fromSession({json.dumps(session.read_text())}, {json.dumps(screens)})")), 10)
        check("our map reads the screen's own wallpaper back", read, read)
        time.sleep(2)
        shot("1-amoled")
        # Theme (Z180): DmsHostTheme.set() runs these two in order.
        check("starts on amoledBlack", js("DmsThemeMap.js", f"currentFrom({json.dumps(settings.read_text())})") == "amoledBlack")
        for argv in js("DmsThemeMap.js", f"setCommands({json.dumps(str(config))}, 'oxeoDeep')"):
            result = ipc(argv)
            check(f"settings set {argv[5]}", "SETTINGS_SET_SUCCESS" in result.stdout, result.stdout.strip()[:80])
        now = wait(lambda: (lambda c: c if c == "oxeoDeep" else None)(
            js("DmsThemeMap.js", f"currentFrom({json.dumps(settings.read_text())})")), 10)
        check("DMS wrote the theme; our map reads oxeoDeep", now == "oxeoDeep", now)
        label = ipc(["dms", "ipc", "call", "settings", "get", "customThemeFile"]).stdout.strip().strip("\"")
        check("DMS holds the new theme file", label.endswith("oxeoDeep/theme.json"), label)
        time.sleep(3)
        shot("2-oxeo")
        if out and (out / "1-amoled.png").exists():
            from PIL import Image, ImageChops
            diff = ImageChops.difference(Image.open(out / "1-amoled.png").convert("RGB"),
                                         Image.open(out / "2-oxeo.png").convert("RGB")).getbbox()
            check("the nested screen changed after the theme switch", diff is not None, diff)
        check("an id outside the themes folder runs nothing", js("DmsThemeMap.js", "setCommands('/x', '../etc')") == [])
        log = (bench.run / "zaetherion" / "dms.log")
        text = log.read_text() if log.exists() else ""
        errors = [l for l in text.splitlines() if "TypeError" in l or "ReferenceError" in l]
        check("no QML type/reference errors in DMS's log", not errors, errors[:3])
    finally:
        try:
            bench.request("shutdown")
        except OSError:
            pass
        wait(lambda: bench.exited() and not bench.processes(), 20)
        bus.stop()
        shutil.rmtree(work, ignore_errors=True)
    owner_after = {p: p.stat().st_mtime_ns for p in OWNER_FILES if p.exists()}
    check("the session's own DMS settings and session files are untouched", owner_after == owner_before)
    print(f"{sum(results)}/{len(results)} passed")
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
