#!/usr/bin/env python3
"""Live check of quiet DMS (tools/dms_quiet.py) in the nested test Hyprland, on a private session bus.

The core supervises a real `dms run` whose UI is the full DMS UI, first as shipped (control: it must
take org.freedesktop.Notifications), then the quiet copy (it must come up, stay up and leave the name
free, so a server of ours takes it and receives a notify-send). The session's own DMS, its bus name and
its notifications are never touched. Needs a live Hyprland session and a running DMS (the UI source).

    dms_quiet_check.py        exit 1 if any check fails
"""
import os
import shutil
import signal
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

NAME = "org.freedesktop.Notifications"
OUR_SERVER = """import QtQuick
import Quickshell
import Quickshell.Services.Notifications

ShellRoot {
    NotificationServer {
        keepOnReload: false
        onNotification: n => console.log("OURS " + n.summary)
    }
}
"""


def owner_comm(env) -> str:
    out = subprocess.run(["busctl", "--user", "status", NAME], env=env, capture_output=True, text=True).stdout
    return next((line.split("=", 1)[1] for line in out.splitlines() if line.startswith("PID=")), "")


def main():
    real_owner = owner_comm(os.environ)
    source = dms_quiet.running_source()
    st = nested_hypr.start()
    (REAL / "zaetherion").mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="dms-quiet-check-", dir=REAL / "zaetherion"))
    bus = notiftest.Bus()
    results, benches = [], []

    def check(name, ok, note=""):
        results.append((name, bool(ok)))
        print(f"{'PASS' if ok else 'FAIL'} {name}{' (' + note + ')' if note else ''}", flush=True)

    def bench_for(ui: Path, label: str) -> Bench:
        (work / label).mkdir()
        bench = Bench(work / label, st)
        bench.env.update(DBUS_SESSION_BUS_ADDRESS=bus.address, FART_RESIDENT_DIR=str(ui), FART_SUPERVISE_FIXTURE="1")
        benches.append(bench)
        return bench

    def stop(bench):
        bench.request("shutdown")
        wait(lambda: bench.exited() and not bench.processes(), 15)

    try:
        stock = bench_for(source, "stock")
        check("stock DMS: core and dms come up", stock.start_core() and stock.up(timeout=20))
        held = wait(lambda: owner_comm(bus.env), 15)
        check("stock DMS takes the notification name (control)", held and int(held) in stock.processes(), held)
        stop(stock)
        check("stock DMS gone, name free", not owner_comm(bus.env))

        quiet = dms_quiet.build(source, work / "quiet-ui")
        check("quiet copy builds and checks clean", not dms_quiet.check(quiet))
        bench = bench_for(quiet, "quiet")
        check("quiet DMS: core and dms come up", bench.start_core() and bench.up(timeout=20))
        first = bench.dms().get("pid")
        time.sleep(8.0)
        check("quiet DMS stays up 8 s, no restart", bench.dms().get("pid") == first and bench.dms().get("state") == "up")
        check("quiet DMS leaves the notification name free", not owner_comm(bus.env), owner_comm(bus.env))
        log = (bench.run / "zaetherion" / "dms.log")
        text = log.read_text(errors="replace") if log.exists() else ""
        bad = [line for line in text.splitlines() if "NotificationService" in line and ("rror" in line or "WARN" in line)]
        check("no DMS log errors from NotificationService", not bad, "; ".join(bad[:2]))

        ours_dir = work / "ours"
        ours_dir.mkdir()
        (ours_dir / "shell.qml").write_text(OUR_SERVER)
        ours = subprocess.Popen(["qs", "-n", "--no-color", "-p", str(ours_dir)], env=dict(nested_hypr.env_for(st), DBUS_SESSION_BUS_ADDRESS=bus.address,
                                                                     DBUS_SYSTEM_BUS_ADDRESS=notiftest.NOWHERE),
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        try:
            taken = wait(lambda: owner_comm(bus.env) == str(ours.pid), 10)
            check("our server takes the name beside quiet DMS", taken)
            if taken:
                bus.send("-a", "quietcheck", "hello from the check")
                time.sleep(1.0)
        finally:
            ours.send_signal(signal.SIGTERM)
            out = ours.communicate(timeout=10)[0]
        check("our server received the notification", "OURS hello from the check" in out)
        check("quiet DMS still up after", bench.dms().get("pid") == first and bench.dms().get("state") == "up")
        stop(bench)
    finally:
        for b in benches:
            for pid in b.processes():
                try:
                    os.kill(pid, signal.SIGKILL)
                except OSError:
                    pass
        bus.stop()
        if nested_hypr.STATE.exists():
            nested_hypr.stop()

    check("the session's own notification server is untouched", owner_comm(os.environ) == real_owner, real_owner)
    failed = [name for name, ok in results if not ok]
    if failed:
        print(f"kept for inspection: {work}")
    else:
        shutil.rmtree(work, ignore_errors=True)
    print(f"{len(results) - len(failed)}/{len(results)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
