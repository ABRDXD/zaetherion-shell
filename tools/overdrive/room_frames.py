#!/usr/bin/env python3
"""Frames of B's rooms in Overdrive inside the real Shell, on the GPU, with a private core (docs/OVERDRIVE.md §35–46).

The real Shell runs against the fixture adapter and a private core, in a real window with the engine lit directly, as
tools/overdrive_frames.py does. The core's lease isn't taken (its guards hold it on battery), so the strata that pull
from the core are fed samples shaped like this machine's here, as the cuetests do. Run it through
tools/hidden_desktop.sh so nothing shows on the user's screen:
    tools/hidden_desktop.sh python3 tools/overdrive/room_frames.py OUT_DIR
Frames: Home; Performance under CPU, MEM, DISK, GPU and SWAP; Devices; Tasks.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
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
    function go(page) { dashboard.navigate(page); dashboard.orbitTransfer.settle(); }
    function item(pred) { return find(dashboard, pred); }
    function feed() {
        const plates = item(i => i.loads !== undefined && i.scarps !== undefined);
        if (plates) for (let k = 0; k < 8; k++) plates.take({ running: true, cores: [0.2, 0.1, 0.9, 0.15, 0.1, 0.3, 0.1, 0.12, 0.05, 0.1, 0.6, 0.1], runnable: 9, blocked: 0, ctxt: 30000, voluntary: 9000, involuntary: 2500 });
        const spectro = item(i => i.tracks !== undefined && i.sparks !== undefined);
        if (spectro) {
            const b = (id, name, cpu, rss, age) => ({ id: id, name: name, cpu: cpu, rss: rss, age: age, born: false });
            for (let k = 0; k < 4; k++)
                spectro.sample = { running: true, forks: 4, bodies: [b("1", "quickshell", 12 + k, 600, 3000), b("2", "pipewire", k %% 2 ? 0 : 2, 40, 2e5), b("3", "firefox", 30, 1800, 9000),
                                   b("4", "fartd", 1, 60, 3000), b("5", "Hyprland", 4, 300, 2e5), b("6", "cc1plus", 180, 500, 4 + k), b("7", "kworker", k %% 2 ? 1 : 0, 0, 5e5)] };
        }
        const tide = item(i => i.state !== undefined && i.speed !== undefined && i.take !== undefined);
        if (tide) { for (let k = 0; k < 5; k++) tide.take({ running: true, read: 30e6, written: 2e6, busy: 0.55 }, 1); for (let k = 0; k < 4; k++) tide.take({ running: true, read: 2e5, written: 9e6, busy: 0.12 }, 1); }
        const rec = item(i => i.trace !== undefined && i.main !== undefined && i.take !== undefined);
        if (rec) for (let k = 0; k < 60; k++) rec.take({ running: true, gpus: [{ card: "card0", vendor: "NVIDIA", awake: false },
            { card: "card1", vendor: "AMD", awake: true, busy: 0.25 + 0.2 * Math.sin(k / 5) + (k > 40 ? 0.4 : 0), levels: [800, 1100, 2700], level: k > 40 ? 2 : k %% 15 < 5 ? 1 : 0, vram: 420e6, total: 536870912 }] });
        const silt = item(i => i.flying !== undefined && i.bands !== undefined && i.take !== undefined);
        if (silt) for (let k = 0; k < 200; k++) silt.take({ running: true, in: k %% 40 === 0 ? 300 : 0, out: 900, used: 340e6 + k * 3e6, total: 4294967296 });
        const buses = item(i => i.columns !== undefined && i.memory !== undefined && i.take !== undefined);
        if (buses) buses.take({ running: true, controllers: [{ pci: "0000:06:00.3", hubs: [{ bus: 1, speed: 480, ports: 5 }, { bus: 2, speed: 10000, ports: 2 }] },
            { pci: "0000:06:00.4", hubs: [{ bus: 3, speed: 480, ports: 1 }, { bus: 4, speed: 10000, ports: 1 }] },
            { pci: "0000:08:00.3", hubs: [{ bus: 5, speed: 480, ports: 1 }, { bus: 6, speed: 10000, ports: 1 }] },
            { pci: "0000:08:00.4", hubs: [{ bus: 7, speed: 480, ports: 1 }, { bus: 8, speed: 10000, ports: 1 }] }],
            devices: [{ path: "1-1", parent: "usb1", port: 1, kind: "INPUT", speed: 12, product: "2.4G Wireless", ports: 0 },
                      { path: "1-3", parent: "usb1", port: 3, kind: "VIDEO", speed: 480, product: "HD Camera", ports: 0 },
                      { path: "1-4", parent: "usb1", port: 4, kind: "RADIO", speed: 12, product: "Bluetooth Radio", ports: 0 },
                      { path: "7-1", parent: "usb7", port: 1, kind: "NETWORK", speed: 480, product: "Phone", ports: 0 }] }, Date.now());
    }
    // The live title's tree walk, timed: 20 rescans of the shown room (it runs every 1.5 s in Overdrive).
    function timeTitle(page) {
        const t = item(i => i.rescan !== undefined && i.loads !== undefined && i.pressureEntry !== undefined);
        if (!t) { console.log("TITLE_SCAN", page, "absent"); return; }
        const t0 = Date.now();
        for (let k = 0; k < 20; k++) t.rescan();
        console.log("TITLE_SCAN", page, ((Date.now() - t0) / 20).toFixed(2), "ms");
    }
    function reading(key) {
        const room = find(dashboard, i => i.readings !== undefined && i.reading !== undefined);
        const halo = room ? find(room, i => i.currentIndex !== undefined && i.count !== undefined && i.model !== undefined) : null;
        if (halo) halo.currentIndex = room.readings.findIndex(r => r.key === key);
    }
    Component.onCompleted: {
        fixture.palette.colors = %(colors)s;
        Host.adapter = fixture;
        Fart.Design.source = fixture.palette;
        const today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        const d = new Date(); d.setDate(d.getDate() - 1);
        const yesterday = Qt.formatDate(d, "yyyy-MM-dd");
        plan = [
            [1500, () => { Motion.overdrive = true; Motion.settleDrive(); dashboard.ignition.settle(); }],
            [600, () => go("home")],
            [3500, "b-home"],
            [100, () => go("performance")],
            [3000, () => feed()],
            [500, "b-perf-cpu"],
            [100, () => reading("memory")],
            [2500, () => feed()],
            [500, "b-perf-mem"],
            [100, () => reading("disk")],
            [2500, () => feed()],
            [500, "b-perf-disk"],
            [100, () => reading("gpu")],
            [3500, () => feed()],
            [500, "b-perf-gpu"],
            [100, () => reading("swap")],
            [2500, () => feed()],
            [500, "b-perf-swap"],
            [100, () => go("devices")],
            [3500, () => feed()],
            [500, "b-devices"],
            [100, () => go("tasks")],
            [3000, "b-tasks"],
            [100, () => timeTitle("tasks")],
            [100, () => go("codex")],
            [2500, () => timeTitle("codex")],
            [100, () => go("notifications")],
            [2500, () => timeTitle("notifications")],
            [100, () => go("media")],
            [2500, () => timeTitle("media")],
            [100, () => go("home")],
            [2500, () => timeTitle("home")],
            [100, () => go("performance")],
            [2500, () => timeTitle("performance")],
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
        }
    }
}
'''


def main():
    out = Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='fart-next-b-frames-') as tmp:
        base = Path(tmp)
        text = HARNESS % {'out': json.dumps(str(out)), 'colors': json.dumps(preset_colors('Mocha')), 'width': 1360, 'height': 860}
        env, state, view_log = prepare(base, text)
        env.pop('QT_QUICK_BACKEND', None)
        env['QT_QPA_PLATFORM'] = 'wayland'
        env['WAYLAND_DISPLAY'] = os.environ.get('WAYLAND_DISPLAY', 'wayland-1')
        core = subprocess.Popen([sys.executable, '-I', str(ROOT / 'core/fartd.py')], env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            exited = run_view(Path(env['FART_RUNTIME_DIR']) / 'core.sock', timeout=60)
        finally:
            core.terminate()
            core.wait(5)
        output = view_log.read_text() if view_log.exists() else ''
    print('exited', exited)
    for line in output.splitlines():
        if any(s in line for s in ('FART_SHOT', 'FART_DONE', 'TITLE_SCAN', 'TypeError', 'ReferenceError', 'Binding loop', 'Error:', 'qsb', 'Failed', 'shader')):
            print(line[:300])


if __name__ == '__main__':
    main()
