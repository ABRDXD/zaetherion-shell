#!/usr/bin/env python3
"""The session lock, for real, in a private nested Hyprland (docs/LOCK.md §5). A Python core with the fixture host and
FART_LOCK=own spawns the view itself (as in the session, so it may say hello as the view and respawns it if it dies);
the view is a harness with the real LockHost, Quickshell's WlSessionLock and the fake PAM of tests/fixtures/nested/pam
(zt-deny refuses, zt-permit accepts). No system PAM file, no real password, nothing in the owner's session.

    tools/lock_nested_check.py        run every check, print PASS/FAIL lines, exit 1 on a failure

Engage covers the screen; F1 a refusal keeps it and counts; F2 the right password unlocks, logind is told, the
marker goes; F10 a second lock is the same lock; F3 the view killed while locked: the screen stays covered and the
respawned view re-locks; F11 an output added while locked stays covered; F7 the core gone at unlock: still locked,
and it says so; F4 a restarted core still says locked, then the password unlocks.
"""
from __future__ import annotations

import json
import os
import signal
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests"))
import nested_hypr  # noqa: E402
from parity.harness import Core  # noqa: E402
from smoke import prepare  # noqa: E402

PAM = ROOT / "tests/fixtures/nested/pam"

# The view the core spawns. CONTROL holds "watch" or "unlock": with "unlock" it tries a wrong then the right password
# once the compositor has locked.
HARNESS = '''import QtQuick
import Quickshell
import Quickshell.Io
import qs.adapters.common
import qs.core.client
import qs.view.lock
Scope {
    id: h
    CoreClient { id: client }
    PamLockAuth { id: auth; configDirectory: "PAMDIR"; service: "zt-deny" }
    LockHost { id: lock; core: client; auth: auth }
    property string mode: "watch"
    property int phase: 0
    FileView { id: control; path: "CONTROL"; watchChanges: true; printErrors: false
               onLoaded: h.mode = text().trim(); onFileChanged: reload() }
    Timer {
        interval: 250; running: true; repeat: true
        onTriggered: {
            console.log("STATE " + JSON.stringify({ pid: Quickshell.processId ?? 0, secure: lock.secure, locked: lock.locked,
                attempts: lock.attempts, notice: lock.notice, connected: client.connected, screens: Quickshell.screens.length,
                phase: h.phase, mode: h.mode }));
            if (h.mode !== "unlock") { h.phase = 0; auth.service = "zt-deny"; return; }
            if (h.phase === 0 && lock.secure) { h.phase = 1; lock.submit("wrong"); }
            else if (h.phase === 1 && lock.attempts >= 1 && !auth.busy) { h.phase = 2; auth.service = "zt-permit"; lock.submit("right"); }
        }
    }
}
'''


class Check:
    def __init__(self):
        self.failed = 0

    def __call__(self, ok: bool, name: str, detail: object = ""):
        print(("PASS " if ok else "FAIL ") + name + (f"  ({detail})" if detail and not ok else ""))
        self.failed += 0 if ok else 1


class ViewLog:
    """STATE lines from the view the core spawned (FART_VIEW_STDOUT), read as they come."""

    def __init__(self, path: Path):
        self.path, self.offset, self.last = path, 0, None

    def wait(self, until, timeout: float):
        deadline = time.monotonic() + timeout
        seen = []
        while time.monotonic() < deadline:
            if self.path.exists():
                with open(self.path, "rb") as f:
                    f.seek(self.offset)
                    chunk = f.read()
                cut = chunk.rfind(b"\n") + 1
                self.offset += cut
                for line in chunk[:cut].decode(errors="replace").splitlines():
                    if "STATE " in line:
                        self.last = json.loads(line.split("STATE ", 1)[1])
                        seen.append(self.last)
                        if until(self.last):
                            return self.last, seen, True
                    elif "TypeError" in line or "ReferenceError" in line or "Failed to load" in line:
                        print("  view: " + line.strip())
            time.sleep(0.1)
        return self.last, seen, False


def main() -> int:
    check = Check()
    work = Path(tempfile.mkdtemp(prefix="zt-lock-"))
    nested_hypr.STATE = work / "nested.json"
    nested = nested_hypr.start()
    control = work / "control"
    control.write_text("watch\n")
    env, _, view_log = prepare(work, HARNESS.replace("PAMDIR", str(PAM)).replace("CONTROL", str(control)))
    view = {k: v for k, v in env.items() if k in ("FART_VIEW_ENTRY", "FART_VIEW_STDOUT", "PATH", "XDG_CONFIG_HOME",
                                                    "XDG_CACHE_HOME", "SERPANTINUM_DIR", "QML_IMPORT_PATH",
                                                    "QML2_IMPORT_PATH", "QS_CONFIG_PATH")}
    # The private core gives the view its own XDG_RUNTIME_DIR, so the nested socket is named by its full path.
    display = str(Path(os.environ["XDG_RUNTIME_DIR"]) / nested["wayland"])
    view.update(FART_LOCK="own", FART_RESIDENT_VIEW="1", WAYLAND_DISPLAY=display,
                HYPRLAND_INSTANCE_SIGNATURE=nested["sig"], QT_QPA_PLATFORM="wayland")
    core = Core("python", env=view)
    log = ViewLog(view_log)
    try:
        core.start()
        s, _, ok = log.wait(lambda s: s["connected"], 20)
        check(ok, "the core spawned the view and it connected as the view", s)
        if not ok:
            print("  view log: " + (view_log.read_text()[-1500:] if view_log.exists() else "none"))
            print("  core log: " + ((core.runtime / "core.log").read_text()[-800:] if (core.runtime / "core.log").exists() else "none"))
            return 1
        with core.client() as cli:
            # Engage, F1, F2
            cli.request("lock.engage", reason="command")
            s, _, ok = log.wait(lambda s: s["secure"], 10)
            check(ok, "engage: the compositor reports the session locked", s)
            control.write_text("unlock\n")
            s, seen, ok = log.wait(lambda s: s["phase"] == 2 and not s["locked"] and not s["secure"], 15)
            check(any(x["attempts"] >= 1 and x["secure"] for x in seen), "F1: a refused password keeps it locked and counts", seen[-3:])
            check(ok, "F2: the right password unlocks", s)
            check(["loginctl", "unlock-session"] in core.host_calls(), "F2: logind is told", core.host_calls()[-3:])
            check(not (core.runtime / "locked").exists(), "F2: the marker is gone")
            control.write_text("watch\n")
            log.wait(lambda s: s["mode"] == "watch", 5)

            # F10
            first = cli.request("lock.engage", reason="idle")
            again = cli.request("lock.engage", reason="sleep")
            check(first["reason"] == "idle" and again == first, "F10: a second lock is the same lock", again)

            # F3: the view dies while locked; the core respawns it and it re-locks from the core's state
            s, _, ok = log.wait(lambda s: s["secure"], 10)
            check(ok, "F3: locked before the kill", s)
            old = s["pid"] if s else 0
            if old:
                os.kill(old, signal.SIGKILL)
            started = time.monotonic()
            s, _, ok = log.wait(lambda s: s["pid"] != old and s["secure"], 20)
            check(ok, "F3: the respawned view re-locks (allow_session_lock_restore)", f"{time.monotonic() - started:.1f}s {s}")

            # F11: an output added while locked
            nested_hypr.hypr(nested["sig"], "output", "create", "headless", "ZTEST2")
            s, _, ok = log.wait(lambda s: s["screens"] >= 3 and s["secure"], 10)
            check(ok, "F11: still locked with an output added", s)

        # F7: the core gone at unlock (killed; the view lives on in its own session)
        core.process.kill()
        core.process.wait(5)
        log.wait(lambda s: not s["connected"], 10)
        control.write_text("unlock\n")
        s, _, ok = log.wait(lambda s: s["phase"] == 2 and s["notice"] != "", 15)
        check(ok and bool(s and s["secure"] and s["locked"]), "F7: the core gone: still locked, and it says so", s)
        control.write_text("watch\n")
        log.wait(lambda s: s["mode"] == "watch", 5)

        # F4: a restarted core reads the marker; its view (the old one goes) re-locks; then the password unlocks
        stale = s["pid"] if s else 0
        try:
            (core.runtime / "core.sock").unlink()
        except FileNotFoundError:
            pass
        core.start()
        if stale:
            try:
                os.kill(stale, signal.SIGKILL)
            except ProcessLookupError:
                pass
        s, _, ok = log.wait(lambda s: s["pid"] != stale and s["connected"] and s["locked"] and s["secure"], 25)
        check(ok, "F4: a restarted core still says locked", s)
        control.write_text("unlock\n")
        s, _, ok = log.wait(lambda s: s["phase"] == 2 and not s["secure"], 20)
        check(ok, "F4: then the password unlocks", s)
    finally:
        try:
            core.close()
        finally:
            nested_hypr.stop()
    print("ALL PASS" if not check.failed else f"{check.failed} FAILED")
    return 1 if check.failed else 0


if __name__ == "__main__":
    sys.exit(main())
