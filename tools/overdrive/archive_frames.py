#!/usr/bin/env python3
"""Review frames of the field archive on its worn tape (docs/OVERDRIVE.md §17) and of the field book (§16), on the GPU.

The real Shell runs against the fixture adapter in a real window (the only way to get shaders here), with the engine lit
directly, as tools/overdrive_frames.py does, so the core's guards (a woken dGPU) don't hold it back. The view's state is
private and seeded: every note unlocked, a few notes worn, a field book with readings, a changed wall, a scale correction
and a survey error. Usage: archive_frames.py OUT_DIR
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

WEAR = {"FIELD NOTE / 000": 1400, "FIELD NOTE / 001": 900, "FIELD NOTE / 002": 300, "SURVEY RECORD / Ø-01": 700}
BOOK = {"version": 1, "seed": 12345, "day": "2026-11-09", "stations": 14, "total": 212, "scale": 101, "scaleDay": "2026-11-09",
        "readings": [{"room": "tasks", "kind": "TAB", "w": 1.27, "h": 0.28, "unit": "M"},
                     {"room": "devices", "kind": "SLIDER", "w": 4.56, "h": 0.2, "unit": "M"},
                     {"room": "home", "kind": "ROW", "w": 3.95, "h": 0.36, "unit": "M"}],
        "walls": {"home": {"first": 9.84, "last": 14.4, "changes": 2}},
        "errors": [{"station": 81, "e": 4.73, "n": -1.92, "day": "2026-11-07"}], "widths": [1.27, 4.56, 3.95]}

HARNESS = '''import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues
import qs.view.shell
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
    function archive() { return find(dashboard, i => i.spans !== undefined && i.wearOf !== undefined); }
    function notes() { return find(archive(), i => i.contentY !== undefined && i.flick !== undefined); }
    Component.onCompleted: {
        fixture.palette.colors = %(colors)s;
        Host.adapter = fixture;
        Fart.Design.source = fixture.palette;
        plan = [
            [1500, () => {
                ViewState.loreEnabled = true;
                ViewState.visited = ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications"];
                ViewState.surveyDays = Array.from({ length: 10 }, (_, i) => "2026-11-" + String(i + 1).padStart(2, "0"));
                ViewState.tapeWear = %(wear)s;
                ViewState.tapeSeconds = 4521;
                ViewState.fieldBook = %(book)s;
                Motion.overdrive = true; Motion.settleDrive(); dashboard.ignition.settle();
            }],
            [400, () => { dashboard.archiveOpen = true; }],
            [1600, "archive-tape-1"],
            [650, "archive-tape-2"],
            [100, () => { const n = notes(); n.contentY = Math.max(0, n.contentHeight - n.height); }],
            [1200, "archive-fieldbook-tape"],
            [100, () => { Motion.overdrive = false; Motion.settleDrive(); }],
            [900, "archive-fieldbook-silent"],
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
        implicitWidth: 1360; implicitHeight: 860; visible: true
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
    with tempfile.TemporaryDirectory(prefix='fart-next-archive-') as tmp:
        base = Path(tmp)
        text = HARNESS % {'out': json.dumps(str(out)), 'colors': json.dumps(preset_colors('Mocha')),
                          'wear': json.dumps(WEAR, ensure_ascii=False), 'book': json.dumps(BOOK)}
        env, state, view_log = prepare(base, text)
        env.pop('QT_QUICK_BACKEND', None)
        env['QT_QPA_PLATFORM'] = 'wayland'
        env['WAYLAND_DISPLAY'] = os.environ.get('WAYLAND_DISPLAY', 'wayland-1')
        core = subprocess.Popen([sys.executable, '-I', str(ROOT / 'core/fartd.py')], env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            run_view(Path(env['FART_RUNTIME_DIR']) / 'core.sock', timeout=45)
        finally:
            core.terminate()
            core.wait(5)
        output = view_log.read_text() if view_log.exists() else ''
    shots = [line for line in output.splitlines() if 'FART_SHOT' in line]
    problems = [line for line in output.splitlines() if any(e in line for e in ('TypeError', 'ReferenceError', 'qsb', 'Failed'))]
    print('\n'.join(shots + problems))
    return 0 if shots and 'FART_DONE' in output else 1


if __name__ == '__main__':
    raise SystemExit(main())
