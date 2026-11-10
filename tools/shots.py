#!/usr/bin/env python3
"""Screenshot every room against the fixture adapter, offscreen, in a Serpantinum preset's palette.

    python3 tools/shots.py OUT_DIR [--preset Mocha] [--pages home,media,map] [--size 860x760] [--tasks tools/shot_tasks.json] [--window]

Writes OUT_DIR/<page>.png (1360 x 860, the panel's size, unless --size); the page "orbit" is the orbit and "fly:ROOM@T" a held frame of a switch. The palette comes from a host preset file, read only, mapped
through the same roles as adapters/serpantinum/SerpantinumPalette.qml. Nothing is actuated; the
fixture has sample data only. For visual review, never for measurement. --tasks seeds the private core's
tasks.json from a synthetic file whose `due` values may be day offsets ("+2", "-1") from today.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
from smoke import ROOT, prepare, run_view, seed_tasks  # noqa: E402

PRESETS = Path.home() / '.local/share/serpantinum/src/assets/themes'
ROLES = {'background': 'base', 'surface': 'surface0', 'surfaceRaised': 'surface1', 'text': 'text',
         'textMuted': 'overlay2', 'textFaint': 'subtext1', 'line': 'overlay0', 'accent': 'blue', 'warm': 'yellow',
         'danger': 'red', 'success': 'green', 'highlight': 'mauve'}
PAGES = ['home', 'media', 'performance', 'workspaces', 'devices', 'tasks', 'timers', 'clipboard', 'notifications', 'codex']

HARNESS = '''import QtQuick
import Quickshell
import qs.adapters.fixture
import qs.core.client
import qs.view.cues as Cues
import qs.view.shell
import qs.view.ui as Fart
Scope {
    CoreClient { id: core }
%(overdrive)s    FixtureAdapter { id: fixture }
    ShellContext { id: context; panelOpen: true; core: core }
    property var pages: %(pages)s
    property string out: %(out)s
    property int cursor: -1
    Component.onCompleted: {
        fixture.palette.colors = %(colors)s;
        Host.adapter = fixture;
        Fart.Design.source = fixture.palette;
    }
    FloatingWindow {
        implicitWidth: %(width)d; implicitHeight: %(height)d; visible: true
        color: "#40464d" // a neutral stand-in for the wallpaper behind the translucent panel
        Item {
            id: frame
            anchors.fill: parent
            Rectangle { anchors.fill: parent; color: Fart.Design.background; opacity: Fart.Design.panelOpacity }
            Shell { id: dashboard; anchors.fill: parent; host: fixture; shell: context; core: core }
        }
    }
    Timer {
        id: tick
        interval: 700; running: true; repeat: false
        onTriggered: {
            if (cursor >= 0) {
                const name = pages[cursor];
                frame.grabToImage(result => {
                    console.log("FART_SHOT", name, result.saveToFile(out + "/" + name + ".png"));
                    next();
                });
                return;
            }
            next();
        }
    }
    function next() {
        cursor++;
        if (cursor >= pages.length) {
            console.log("FART_SHOTS_DONE");
            Qt.quit();
            return;
        }
        // "orbit" opens the orbit over the room shot before it (that room is the current one).
        if (pages[cursor] === "orbit") dashboard.toggleOrbit();
        // "js:CODE" runs CODE with `dashboard` in scope before the shot (review set-ups); "|" stands for a
        // comma, since pages are comma-separated.
        else if (pages[cursor].startsWith("js:")) (new Function("dashboard", pages[cursor].slice(3).replace(/\\|/g, ",")))(dashboard);
        // "fly:ROOM@T" switches to ROOM and holds the orbit camera at T (0–1) of the flight, for review frames.
        else if (pages[cursor].startsWith("fly:")) {
            const [room, at] = pages[cursor].slice(4).split("@");
            dashboard.navigate(room);
            dashboard.orbitTransfer.animation.stop();
            dashboard.orbitTransfer.value = Number(at);
        } else {
            // A plain room lands at once, so a following "fly:" frame starts from rest.
            dashboard.navigate(pages[cursor]);
            dashboard.orbitTransfer.settle();
        }
        tick.restart();
    }
}
'''

# --overdrive: the lease on the private core, and the engine bound to it as the Overlay binds it.
OVERDRIVE = '''    Binding { target: Cues.Motion; property: "overdrive"; value: core.overdriveData?.effective === "active" }
    Connections {
        target: core
        function onConnectedChanged() { if (core.connected) core.request("overdrive.request", { mode: "sticky" }); }
    }
'''


def preset_colors(name: str) -> dict:
    data = json.loads((PRESETS / f'{name}.json').read_text())
    colors = data.get('colors', data)
    return {role: colors[key] for role, key in ROLES.items() if key in colors}


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('out', type=Path)
    parser.add_argument('--preset', default='Mocha')
    parser.add_argument('--pages', default=','.join(PAGES))
    parser.add_argument('--size', default='1360x860', help='window WIDTHxHEIGHT, for the narrow layouts')
    parser.add_argument('--gl', action='store_true', help='render with OpenGL instead of the software renderer, which '
                        'mishandles clips under sheared transforms and ignores ShapePath.fillItem')
    parser.add_argument('--window', action='store_true', help='render in a real window on this Wayland session (shown for '
                        'the run): the only way to get GPU shaders, which offscreen Qt cannot run')
    parser.add_argument('--overdrive', action='store_true', help='light Overdrive: a sticky lease on the private core, '
                        'bound to the view as the Overlay binds it (strata that need a GPU still need --window)')
    parser.add_argument('--log', action='store_true', help="print the view's whole log (warnings, console.log)")
    parser.add_argument('--tasks', type=Path, help='a synthetic tasks file to seed the private core with')
    parser.add_argument('--preferences', type=Path, help="a preferences.json for the view's private state (lore, visited rooms, survey days)")
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    pages = [p for p in args.pages.split(',') if p]
    width, height = (int(n) for n in args.size.lower().split('x'))
    with tempfile.TemporaryDirectory(prefix='fart-next-shots-') as tmp:
        base = Path(tmp)
        text = HARNESS % {'pages': json.dumps(pages), 'out': json.dumps(str(out)),
                          'colors': json.dumps(preset_colors(args.preset)), 'width': width, 'height': height,
                          'overdrive': OVERDRIVE if args.overdrive else ''}
        env, state, view_log = prepare(base, text)
        if args.tasks:
            seed_tasks(state, json.loads(args.tasks.read_text()))
        if args.preferences:
            (state / 'preferences.json').write_text(args.preferences.read_text())
        if args.gl:
            env.pop('QT_QUICK_BACKEND', None)
            env['QSG_RHI_BACKEND'] = 'opengl'
        if args.window:
            env.pop('QT_QUICK_BACKEND', None)
            env['QT_QPA_PLATFORM'] = 'wayland'
            env['WAYLAND_DISPLAY'] = os.environ.get('WAYLAND_DISPLAY', 'wayland-1')
        core = subprocess.Popen([sys.executable, '-I', str(ROOT / 'core/fartd.py')], env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            exited = run_view(Path(env['FART_RUNTIME_DIR']) / 'core.sock')
        finally:
            core.terminate()
            core.wait(5)
        output = view_log.read_text() if view_log.exists() else ''
    saved = [line.split()[-2] for line in output.splitlines() if 'FART_SHOT ' in line and line.endswith('true')]
    errors = [line for line in output.splitlines() if any(s in line for s in ('ReferenceError', 'TypeError'))]
    for line in output.splitlines() if args.log else errors:
        print(line)
    print(f'{len(saved)}/{len(pages)} rooms saved to {out}')
    return 0 if exited and len(saved) == len(pages) else 1


if __name__ == '__main__':
    raise SystemExit(main())
