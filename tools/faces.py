#!/usr/bin/env python3
"""Render the planet faces (view/faces) against the fixture and a private core, offscreen.

    python3 tools/faces.py OUT_DIR [--preset Mocha] [--tasks tools/shot_tasks.json]

Writes OUT_DIR/faces-<stage>.png: every face in a tile's corner (45 x 28, 75 x 42, 95 x 55), in the
readout (236 x 110, paper and ink) and on a round planet, for each stage: idle timers, then a running countdown with a stopwatch,
then a paused countdown with the recorder on. It also checks the Timers face's stepping: while a
timer runs, the face must step once per shown second (printed as FART_FACE_STEPS). The private
core's timers are started and stopped; nothing on the desktop is touched. For review, not measurement.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from smoke import ROOT, prepare, run_view, seed_tasks  # noqa: E402
from shots import preset_colors  # noqa: E402

HARNESS = '''import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.faces
import qs.view.ui as Fart
Scope {
    id: harness
    CoreClient { id: client }
    FixtureAdapter { id: fixture }
    property string out: %(out)s
    property int stage: 0
    property bool settled: false
    property int startWhole: 0
    readonly property var stages: ["idle", "running", "held"]
    Component.onCompleted: {
        fixture.palette.colors = %(colors)s;
        Fart.Design.source = fixture.palette;
    }
    // A plane of a given size and role with one face on it, as OrbitSystem binds one.
    component Cell: Rectangle {
        id: cell
        property string role: "paper"
        property bool round: false
        property int inset: 0
        property Component face
        color: role === "ink" ? Fart.Design.ink : role === "signal" ? Fart.Design.accent : Fart.Design.surface
        radius: round ? width / 2 : 0
        Loader {
            anchors.fill: parent
            anchors.margins: cell.inset
            sourceComponent: cell.face
            onLoaded: {
                item.tone = Qt.binding(() => cell.role === "paper" ? Fart.Design.ink : Fart.Design.background);
                item.ground = Qt.binding(() => cell.color);
            }
        }
    }
    Component { id: tasksFace; TasksFace { core: client } }
    Component { id: timersFace; TimersFace { core: client } }
    Component { id: devicesFace; DevicesFace { host: fixture } }
    Component { id: clipboardFace; ClipboardFace { host: fixture } }
    Component { id: notificationsFace; NotificationsFace { host: fixture } }
    // Columns: the tile's corner at 1360 x 860 (smallest and largest), at 1920 x 1080, the readout on
    // paper and on ink, and a round planet.
    readonly property var slots: [
        { w: 45, h: 28, role: "paper" }, { w: 75, h: 42, role: "ink" }, { w: 95, h: 55, role: "signal" },
        { w: 236, h: 110, role: "paper" }, { w: 236, h: 110, role: "ink" }, { w: 124, h: 124, role: "paper", round: true, inset: 18 }
    ]
    FloatingWindow {
        id: window
        implicitWidth: 960; implicitHeight: 5 * 132 + 16; visible: true
        color: Fart.Design.background
        Item {
            id: frame
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: Fart.Design.background }
            Column {
                x: 8; y: 8
                spacing: 8
                Repeater {
                    model: [tasksFace, timersFace, devicesFace, clipboardFace, notificationsFace]
                    Row {
                        id: faceRow
                        required property var modelData
                        spacing: 12
                        height: 124
                        Repeater {
                            model: harness.slots
                            Cell {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                width: modelData.w; height: modelData.h
                                role: modelData.role
                                round: modelData.round ?? false
                                inset: modelData.inset ?? 0
                                face: faceRow.modelData
                            }
                        }
                    }
                }
            }
        }
    }
    // A probe face that counts its own steps while a countdown runs.
    TimersFace { id: probe; core: client; visible: false; property int steps: 0; onWholeChanged: steps++ }
    Timer {
        id: tick
        interval: 3300; running: client.connected; repeat: false
        onTriggered: harness.advance()
    }
    function shoot(then) {
        frame.grabToImage(result => {
            console.log("FART_SHOT", stages[stage], result.saveToFile(out + "/faces-" + stages[stage] + ".png"));
            then();
        });
    }
    function advance() {
        if (stage === 0) {
            shoot(() => {
                stage = 1;
                client.timers.startCountdown(95);
                client.timers.toggle("stopwatch");
                tick.interval = 1000;
                tick.restart();
            });
        } else if (stage === 1 && !settled) {
            // The snapshots have arrived: count the face's steps from here.
            settled = true;
            probe.steps = 0;
            startWhole = probe.whole;
            tick.interval = 3100;
            tick.restart();
        } else if (stage === 1) {
            console.log("FART_FACE_STEPS", probe.steps, startWhole - probe.whole);
            shoot(() => {
                stage = 2;
                client.timers.toggle("countdown");
                fixture.hostActions.recording = { available: true, active: true, startedAt: Date.now() / 1000 - 70 };
                tick.interval = 900;
                tick.restart();
            });
        } else {
            console.log("FART_FACE_RUNNING", probe.running, probe.shown.note);
            shoot(() => {
                client.timers.reset("countdown");
                client.timers.reset("stopwatch");
                console.log("FART_SHOTS_DONE");
                Qt.quit();
            });
        }
    }
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('out', type=Path)
    parser.add_argument('--preset', default='Mocha')
    parser.add_argument('--tasks', type=Path, default=ROOT / 'tools/shot_tasks.json')
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='fart-next-faces-') as tmp:
        base = Path(tmp)
        text = HARNESS % {'out': json.dumps(str(out)), 'colors': json.dumps(preset_colors(args.preset))}
        env, state, view_log = prepare(base, text)
        seed_tasks(state, json.loads(args.tasks.read_text()))
        core = subprocess.Popen([sys.executable, '-I', str(ROOT / 'core/fartd.py')], env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            exited = run_view(Path(env['FART_RUNTIME_DIR']) / 'core.sock', timeout=40)
        finally:
            core.terminate()
            core.wait(5)
        output = view_log.read_text() if view_log.exists() else ''
    lines = output.splitlines()
    errors = [line for line in lines if any(s in line for s in ('ReferenceError', 'TypeError', 'ERROR', 'Cannot assign'))]
    for line in lines:
        if line in errors or 'FART_FACE' in line:
            print(line)
    if not any('FART_SHOT ' in line for line in lines):
        print(output[-4000:])
    saved = [line for line in lines if 'FART_SHOT ' in line and line.endswith('true')]
    steps = next((line.split() for line in lines if 'FART_FACE_STEPS' in line), None)
    # 3.1 s of a running countdown steps 3 or 4 times, once per shown second (never at 5 Hz), and every
    # step is exactly one second of the display.
    stepped = steps is not None and 3 <= int(steps[-2]) <= 4 and steps[-2] == steps[-1]
    print(f'{len(saved)}/3 stages saved to {out}; stepping {"ok" if stepped else "FAILED"} ({steps and ' '.join(steps[-2:])})')
    return 0 if exited and len(saved) == 3 and stepped and not errors else 1


if __name__ == '__main__':
    raise SystemExit(main())
