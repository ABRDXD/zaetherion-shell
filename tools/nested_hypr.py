#!/usr/bin/env python3
"""Nested Hyprland for tests (Z109).

Starts a second Hyprland inside the running session, parked on the hidden special
workspace `special:ztest` without taking focus, and adds a headless output `ZTEST`
inside it. The headless output renders on its own timer, so screenshots work even
though the nested window is never shown. Nothing in the real session is locked,
bound or reconfigured: the window is placed with exec rules, not a config change.

    nested_hypr.py start            start it, write the state file
    nested_hypr.py run CMD...       run CMD as a client of the nested compositor
    nested_hypr.py shot FILE.png    screenshot the ZTEST output
    nested_hypr.py stop             exit it and remove its runtime folder
    nested_hypr.py selftest         start, lock/crash/restore checks, fake PAM, stop
"""
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIX = ROOT / "tests" / "fixtures" / "nested"
RUN = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
STATE = RUN / "zaetherion" / "nested.json"
OUTPUT = "ZTEST"
LOCK_BG = (0x20, 0x00, 0x30)  # tests/fixtures/nested/lock/shell.qml


def instances():
    d = RUN / "hypr"
    return {p.name for p in d.iterdir()} if d.is_dir() else set()


def sockets():
    return {p.name for p in RUN.glob("wayland-*") if not p.name.endswith(".lock")}


def wait(pred, timeout=10.0, step=0.1):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        v = pred()
        if v:
            return v
        time.sleep(step)
    return None


def state():
    if not STATE.exists():
        sys.exit("nested Hyprland is not running (no state file); run `start` first")
    return json.loads(STATE.read_text())


def env_for(st):
    e = dict(os.environ)
    e.update(WAYLAND_DISPLAY=st["wayland"], HYPRLAND_INSTANCE_SIGNATURE=st["sig"],
             QT_QPA_PLATFORM="wayland")
    e.pop("DISPLAY", None)
    return e


def hypr(sig, *args):
    return subprocess.run(["hyprctl", "-i", sig, *args], capture_output=True, text=True, timeout=10)


def start():
    if STATE.exists():
        st = json.loads(STATE.read_text())
        if (RUN / "hypr" / st["sig"] / ".socket.sock").exists():
            print(f"already running: {st['sig']} on {st['wayland']}")
            return st
        STATE.unlink()
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        sys.exit("not inside a Hyprland session")
    before_i, before_s = instances(), sockets()
    STATE.parent.mkdir(parents=True, exist_ok=True)
    log = STATE.with_suffix(".log")
    cmd = f"Hyprland -c {FIX / 'nested.lua'} > {log} 2>&1"
    rules = '{ workspace = "special:ztest silent", no_initial_focus = true }'
    r = subprocess.run(["hyprctl", "dispatch", f"hl.dsp.exec_cmd({json.dumps(cmd)}, {rules})"],
                       capture_output=True, text=True)
    if r.stdout.strip() != "ok":
        sys.exit(f"dispatch failed: {r.stdout}{r.stderr}")
    sig = wait(lambda: next(iter(instances() - before_i), None))
    sock = wait(lambda: next(iter(sockets() - before_s), None))
    if not sig or not sock or not wait(lambda: (RUN / "hypr" / sig / ".socket.sock").exists()):
        sys.exit(f"nested Hyprland did not come up; see {log}")
    wait(lambda: hypr(sig, "monitors").returncode == 0)
    hypr(sig, "output", "create", "headless", OUTPUT)
    if not wait(lambda: f"Monitor {OUTPUT}" in hypr(sig, "monitors").stdout):
        sys.exit("headless output did not appear")
    st = {"sig": sig, "wayland": sock}
    STATE.write_text(json.dumps(st))
    print(f"started {sig} on {sock}, output {OUTPUT}")
    return st


def stop():
    if not STATE.exists():
        print("not running")
        return
    st = json.loads(STATE.read_text())
    hypr(st["sig"], "dispatch", "hl.dsp.exit()")
    gone = wait(lambda: not (RUN / "hypr" / st["sig"] / ".socket.sock").exists()
                and st["wayland"] not in sockets()
                and subprocess.run(["pgrep", "-f", f"Hyprland -c {FIX / 'nested.lua'}"],
                                   capture_output=True).returncode != 0, timeout=10)
    if not gone:
        sys.exit(f"nested Hyprland {st['sig']} did not exit")
    shutil.rmtree(RUN / "hypr" / st["sig"], ignore_errors=True)
    STATE.unlink()
    print(f"stopped {st['sig']}")


def shot(path):
    st = state()
    subprocess.run(["grim", "-o", OUTPUT, str(path)], env=env_for(st), check=True, timeout=10)
    return path


def centre_rgb(path):
    from PIL import Image
    im = Image.open(path).convert("RGB")
    px = im.getpixel((im.width // 2, im.height // 3))
    vals = px if isinstance(px, tuple) else (px, px, px)
    return tuple(int(v or 0) for v in vals)


def is_lock(path):
    return all(abs(a - b) <= 4 for a, b in zip(centre_rgb(path), LOCK_BG))


def selftest(outdir):
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    real = os.environ["HYPRLAND_INSTANCE_SIGNATURE"]
    st = start()
    env = env_for(st)
    lock_cmd = ["quickshell", "-p", str(FIX / "lock" / "shell.qml")]
    results = []

    def check(name, ok):
        results.append((name, ok))
        print(f"{'PASS' if ok else 'FAIL'} {name}")

    try:
        base = shot(out / "0-base.png")
        check("base screen is not locked", not is_lock(base))
        p = subprocess.Popen(lock_cmd, env={**env, "ZT_UNLOCK_MS": "3000"},
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        check("lock shows", bool(wait(lambda: is_lock(shot(out / "1-locked.png")), 5, 0.3)))
        p.wait(timeout=10)
        check("unlock clears", not is_lock(shot(out / "2-unlocked.png")))

        p = subprocess.Popen(lock_cmd, env={**env, "ZT_UNLOCK_MS": "60000"},
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        wait(lambda: is_lock(shot(out / "3-locked.png")), 5, 0.3)
        p.kill(); p.wait()
        time.sleep(1)
        crashed = shot(out / "4-crashed.png")
        # Hyprland's "lockscreen app died" page: still covered, not the desktop and not our lock.
        check("lock client crash keeps the screen covered", centre_rgb(crashed) != centre_rgb(base)
              and not is_lock(crashed))
        p = subprocess.Popen(lock_cmd, env={**env, "ZT_UNLOCK_MS": "3000"},
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        check("new lock client takes over", bool(wait(lambda: is_lock(shot(out / "5-restored.png")), 5, 0.3)))
        p.wait(timeout=10)
        check("restored lock unlocks", not is_lock(shot(out / "6-unlocked.png")))
    finally:
        stop()

    r = subprocess.run(["quickshell", "-p", str(FIX / "pamcheck" / "shell.qml")],
                       env={**os.environ, "QT_QPA_PLATFORM": "offscreen", "ZT_PAM_DIR": str(FIX / "pam")},
                       capture_output=True, text=True, timeout=15)
    log = r.stdout + r.stderr
    check("fake PAM permit succeeds", "ZT PERMIT 0" in log)
    check("fake PAM deny fails", "ZT DENY " in log and "ZT DENY 0" not in log)

    mons, wss = hypr(real, "monitors").stdout, hypr(real, "workspaces").stdout
    check("real session untouched (no ZTEST output, no ztest workspace left)",
          OUTPUT not in mons and "special:ztest" not in wss)
    failed = [n for n, ok in results if not ok]
    print(f"{len(results) - len(failed)}/{len(results)} passed; screenshots in {out}")
    return 1 if failed else 0


def main(argv):
    if not argv:
        sys.exit(__doc__)
    cmd, rest = argv[0], argv[1:]
    if cmd == "start":
        start()
    elif cmd == "stop":
        stop()
    elif cmd == "shot":
        shot(rest[0] if rest else "nested.png")
    elif cmd == "run":
        sys.exit(subprocess.run(rest, env=env_for(state())).returncode)
    elif cmd == "selftest":
        sys.exit(selftest(rest[0] if rest else RUN / "zaetherion" / "nested-selftest"))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
