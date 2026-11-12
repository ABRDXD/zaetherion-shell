#!/usr/bin/env python3
"""Load all FART rooms with DMS's network domain in place of the fixture's, against the stand-in DMS.

Reuses `prepare` and `run_view` from smoke.py. The shell runs offscreen with private config and state;
DMS_SOCKET points at tools/dms_replay.py in a short private folder. A real DMS is never contacted and nothing is
actuated. Expects: no binding errors, `details` held on Devices and released after, DMS's network values showing
in the rooms' domain, and no request in the stand-in's log that changes anything.

    python3 tools/dms_smoke.py
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import dmstest  # noqa: E402
from smoke import prepare, run_view  # noqa: E402

# Methods that only read. Anything else in the stand-in's log is an action the smoke must not make.
READ_ONLY = {"subscribe"}

SMOKE = '''import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.adapters.dms
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.shell
import qs.view.ui as Fart
Scope {
    CoreClient { id: core }
    DmsAdapter { id: dms; core: core; role: "smoke" }
    FixtureAdapter { id: fixture; network: dms.network }
    ShellContext { id: context; panelOpen: true; core: core }
    Component.onCompleted: { Host.adapter = fixture; Fart.Design.source = fixture.palette; Motion.reduced = true; }
    property var pages: ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"]
    property int cursor: -1
    property int waited: 0
    FloatingWindow {
        implicitWidth: 1120; implicitHeight: 760; visible: true
        Shell { id: dashboard; anchors.fill: parent; host: fixture; shell: context; core: core }
    }
    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: {
            if (cursor >= 0 && dashboard.loadedPage !== pages[cursor] && waited < 20) { waited++; return; }
            waited = 0;
            if (cursor >= 0) console.log("FART_SMOKE", pages[cursor], dashboard.loadedPage);
            if (cursor === 0) console.log("DMS_NETWORK", dms.network.available, dms.network.kind, dms.network.holds("details"));
            if (cursor === 4) console.log("DMS_LEASE devices", dms.network.holds("details"), dms.network.holds("scan"), dms.network.ipAddress !== "");
            if (cursor === 5) console.log("DMS_RELEASE devices", dms.network.holds("details"), dms.network.holds("scan"), dms.network.ipAddress !== "");
            cursor++;
            if (cursor >= pages.length) {
                console.log("DMS_SMOKE_DONE");
                Qt.quit();
                return;
            }
            dashboard.navigate(pages[cursor]);
        }
    }
}
'''


def main():
    with dmstest.private_dir() as tmp:
        base = Path(tmp)
        stand = dmstest.Stand(base, "dms-smoke.sock")
        work = base / "w"
        work.mkdir()
        env, state, view_log = prepare(work, SMOKE)
        env["DMS_SOCKET"] = stand.path
        runtime = Path(env["FART_RUNTIME_DIR"])
        core = subprocess.Popen([sys.executable, "-I", str(ROOT / "core/fartd.py")], env=env, stdin=subprocess.DEVNULL,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            exited = run_view(runtime / "core.sock", timeout=40)
        finally:
            core.terminate()
            core.wait(5)
            stand.stop()
        output = view_log.read_text() if view_log.exists() else ""
        print(output)
        if not exited:
            print("DMS_SMOKE: the harness did not finish")
            return 1
        pages = ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"]
        ok = "DMS_SMOKE_DONE" in output and all(f"FART_SMOKE {p} {p}" in output for p in pages)
        ok = ok and "DMS_LEASE devices true false true" in output and "DMS_RELEASE devices false false false" in output
        ok = ok and not any(s in output for s in ("ReferenceError:", "TypeError:", "Cannot assign", "Unable to assign", "is not a type",
                                                  "Failed to load configuration", "Binding loop"))
        actions = [m for m in stand.methods() if m not in READ_ONLY]
        if actions:
            print("DMS_SMOKE: the stand-in saw requests:", actions)
        ok = ok and not actions
        subscriptions = stand.subscriptions()
        if subscriptions and subscriptions != [["network"]]:
            print("DMS_SMOKE: unexpected subscriptions", subscriptions)
            ok = False
        return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
