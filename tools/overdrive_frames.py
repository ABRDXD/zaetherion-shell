#!/usr/bin/env python3
"""Review frames of the Overdrive features the plain shots harness can't reach: GPU, fixture data, private core."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from smoke import prepare, run_view  # noqa: E402
from shots import preset_colors  # noqa: E402

HARNESS = '''import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.shell
import qs.view.strata
import qs.view.ui as Fart
Scope {
    id: root
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    property string out: %(out)s
    property var plan: []
    property int cursor: -1
    function find(item, pred) {
        if (pred(item)) return item;
        for (const c of item.children) { const r = find(c, pred); if (r) return r; }
        return null;
    }
    function field() { return find(dashboard, i => i.flight !== undefined && i.ft !== undefined); }
    function orbit() { return dashboard.orbit; }
    Component.onCompleted: {
        fixture.palette.colors = %(colors)s;
        Host.adapter = fixture;
        Fart.Design.source = fixture.palette;
        ViewState.ambientEnabled = true;
        const day = Array.from({ length: 24 }, (_, h) => h === 10 ? 1 : h %% 3 === 0 ? 0.6 : 0.15);
        plan = [
            [1500, () => {
                core.journeyData = { pairs: [{ a: "tasks", b: "timers", weight: 12 }, { a: "media", b: "devices", weight: 4 }], favourite: "tasks",
                                     trend: { media: 1, devices: -1, timers: 0.6 }, seconds: { tasks: 1000, media: 120 }, visits: { tasks: 9 }, hours: { tasks: day },
                                     hour: 10, resonance: ["media", "tasks", "timers"] };
                Motion.overdrive = true; Motion.settleDrive(); dashboard.ignition.settle();
            }],
            [1200, () => dashboard.toggleOrbit()],
            [3200, "orbit-laws"],
            [100, () => orbit().laws.hold("tasks")],
            [700, "orbit-ephemeris"],
            [100, () => { orbit().laws.letGo(); orbit().laws.transitTile = 2; orbit().laws.transitText = "03 × 05  T+1:23"; orbit().chordPair = ["timers", "tasks"]; }],
            [800, "orbit-chord"],
            [100, () => { orbit().chordPair = []; orbit().laws.transitTile = -1; dashboard.toggleOrbit(); }],
            [2200, () => { dashboard.navigate("tasks"); dashboard.orbitTransfer.settle(); }],
            [1200, "room-tasks"],
            [100, () => { dashboard.navigate("media"); dashboard.orbitTransfer.animation.stop(); const f = field(); console.log("FLIGHT", JSON.stringify(f.flight)); dashboard.orbitTransfer.value = f.flight.a * 0.3; }],
            [900, "lens-early"],
            [100, () => { const f = field(); dashboard.orbitTransfer.value = f.flight.a * 0.55; }],
            [900, "lens-mid"],
            [100, () => { const f = field(); dashboard.orbitTransfer.value = f.flight.b + (1 - f.flight.b) * 0.08; }],
            [500, "flight-aberration"],
            [100, () => { const f = field(); dashboard.orbitTransfer.value = f.flight.b + (1 - f.flight.b) * 0.62; }],
            [500, "flight-cut"],
            [100, () => { dashboard.orbitTransfer.settle(); dashboard.navigate("home"); dashboard.orbitTransfer.settle(); }],
            [900, () => { dashboard.commandLine.hint = { candidates: [{ name: "alpha" }, { name: "beta" }, { name: "gamma" }] }; dashboard.focusCommandLine(); }],
            [900, "ballistic"],
            [100, () => { dashboard.commandLine.hint = null; wallpaper.visible = true; }],
            [800, "stress"],
            [300, () => { console.log("FART_DONE"); Qt.quit(); }]
        ];
        next();
    }
    function shot(name) {
        frame.grabToImage(result => {
            console.log("FART_SHOT", name, result.saveToFile(out + "/" + name + ".png"));
            next();
        });
    }
    function next() {
        cursor++;
        if (cursor >= plan.length) return;
        tick.interval = plan[cursor][0];
        tick.restart();
    }
    Timer {
        id: tick
        repeat: false
        onTriggered: {
            const step = root.plan[root.cursor][1];
            if (typeof step === "string") { root.shot(step); return; }
            step();
            root.next();
        }
    }
    FloatingWindow {
        implicitWidth: %(width)d; implicitHeight: %(height)d; visible: true
        color: "#40464d"
        Item {
            id: frame
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: Fart.Design.background; opacity: Fart.Design.panelOpacity }
            Shell { id: dashboard; anchors.fill: parent; host: fixture; shell: context; core: core }
            // The wallpaper tier, on its own: a neutral desktop with a panel-sized hole in the middle.
            Rectangle {
                id: wallpaper
                visible: false
                anchors.fill: parent
                color: "#20242b"
                StressField {
                    anchors.fill: parent
                    panelRect: Qt.rect(parent.width * 0.2, parent.height * 0.14, parent.width * 0.6, parent.height * 0.62)
                    turnValue: 3
                }
            }
        }
    }
}
'''

out = Path(sys.argv[1]).resolve()
out.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='fart-next-frames-') as tmp:
    base = Path(tmp)
    text = HARNESS % {'out': json.dumps(str(out)), 'colors': json.dumps(preset_colors('Mocha')), 'width': 1360, 'height': 860}
    env, state, view_log = prepare(base, text)
    env.pop('QT_QUICK_BACKEND', None)
    env['QT_QPA_PLATFORM'] = 'wayland'
    env['WAYLAND_DISPLAY'] = os.environ.get('WAYLAND_DISPLAY', 'wayland-1')
    core = subprocess.Popen([sys.executable, '-I', str(ROOT / 'core/fartd.py')], env=env,
                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        exited = run_view(Path(env['FART_RUNTIME_DIR']) / 'core.sock', timeout=45)
    finally:
        core.terminate()
        core.wait(5)
    output = view_log.read_text() if view_log.exists() else ''
print('exited', exited)
for line in output.splitlines():
    if any(s in line for s in ('FART_SHOT', 'FART_DONE', 'FLIGHT', 'TypeError', 'ReferenceError', 'Binding loop', 'Error:', 'qsb', 'Failed', 'shader')):
        print(line[:300])
