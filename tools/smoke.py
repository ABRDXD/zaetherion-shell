#!/usr/bin/env python3
"""Load all nine FART rooms against the fixture adapter and a private core, outside the desktop.

Uses Qt's offscreen platform and private config/state. The core runs with the fixture host profile and no
notification mirror. No real host shell, notification daemon, recorder, clipboard history or system action
is started.
"""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
# The harness must sit at a shell root for qs.* imports, so it runs on a private copy.
TREE = ('shell.qml', 'shell-heavy.qml', 'view', 'adapters', 'core', 'tools', 'assets')


def seed_tasks(state: Path, data: dict):
    """Write a synthetic tasks.json into the private state; `due` may be a day offset from today ("+2", "-1")."""
    from datetime import date, timedelta
    tasks = []
    for task in data['tasks']:
        due = task.get('due')
        if isinstance(due, str) and due[:1] in '+-':
            due = (date.today() + timedelta(days=int(due))).isoformat()
        tasks.append({'created': None, 'doneAt': None, 'done': False, 'due': None, **task, 'due': due})
    (state / 'tasks.json').write_text(json.dumps({'version': 1, 'lists': data['lists'], 'tasks': tasks}))


def prepare(base: Path, harness_text: str, theme: dict | None = None, source: Path = ROOT):
    """Copy the shell tree (from `source`, a checkout) under `base`, write the harness and stub commands;
    return (env, state, view_log)."""
    bundle = base / 'bundle'
    bundle.mkdir()
    for name in TREE:
        copy = shutil.copytree if (source / name).is_dir() else shutil.copy2
        copy(source / name, bundle / name, **({'ignore': shutil.ignore_patterns('__pycache__')} if copy is shutil.copytree else {}))
    state = base / 'state/fart-next'
    state.mkdir(parents=True)
    (state / 'todo.json').write_text('[]')
    theme_dir = base / 'config/serpantinum'
    theme_dir.mkdir(parents=True)
    settings = theme_dir / 'settings.json'
    settings.write_text(json.dumps(theme or {'theme': {'colors': {'base': '#123456'}, 'elementOpacity': 62, 'borderRadius': 6}}))
    commands = base / 'bin'
    commands.mkdir()
    for name in ('cliphist', 'serpantinum', 'notify-send', 'pw-play', 'gdbus', 'cava', 'kitty'):
        p = commands / name
        p.write_text('#!/bin/sh\nexit 0\n')
        p.chmod(0o755)
    harness = bundle / 'Harness.qml'
    harness.write_text(harness_text)
    runtime = base / 'run'
    view_log = base / 'view.log'
    # The core spawns the harness as its view, so the harness may say hello as one.
    env = dict(os.environ, FART_STATE_DIR=str(state), FART_RUNTIME_DIR=str(runtime), FART_HOST='fixture',
        FART_MIRROR='0', FART_FIXTURE_LOG=str(base / 'fixture.jsonl'), FART_VIEW_ENTRY=str(harness),
        FART_VIEW_STDOUT=str(view_log), QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software',
        XDG_STATE_HOME=str(base / 'state'), XDG_CONFIG_HOME=str(base / 'config'),
        XDG_CACHE_HOME=str(base / 'cache'), PATH=str(commands) + ':' + os.environ['PATH'],
        FART_CACHE_DIR=str(base / 'cache/fart'), SERPANTINUM_DIR=str(base / 'serpantinum'), PIPEWIRE_RUNTIME_DIR='/nonexistent/fart-fixture',
        HYPRLAND_INSTANCE_SIGNATURE='', WAYLAND_DISPLAY='', DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent/fart-fixture', DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent/fart-fixture')
    return env, state, view_log


SMOKE = '''import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.adapters.fixture
import qs.adapters.serpantinum
import qs.core.client
import qs.view.cues
import qs.view.shell
import qs.view.ui as Fart
Scope {
    CoreClient { id: core }
    FixtureAdapter { id: fixture }
    // Loaded beside the fixture to catch binding errors and check the palette mapping, isolated from real host files.
    SerpantinumAdapter { id: serpantinum; core: core }
    ShellContext { id: context; panelOpen: true; core: core }
    // Motion reduced: the smoke checks loading, not cues (a switch's flight would hold each room past the 150 ms step).
    Component.onCompleted: { Host.adapter = fixture; Fart.Design.source = fixture.palette; Motion.reduced = true; }
    property var pages: ["home", "media", "performance", "workspaces", "devices", "tasks", "timers", "clipboard", "notifications", "codex"]
    property int cursor: -1
    property int waited: 0
    function hostTheme() { return [serpantinum.palette.colors.background, serpantinum.palette.opacity, serpantinum.palette.radius].join(" "); }
    function viewTheme() { return [Fart.Design.background.toString(), Fart.Design.panelOpacity, Fart.Design.radiusPanel].join(" "); }
    FileView {
        id: themeFixture
        path: Quickshell.env("XDG_CONFIG_HOME") + "/serpantinum/settings.json"
    }
    FloatingWindow {
        implicitWidth: 1120; implicitHeight: 760; visible: true
        Shell { id: dashboard; anchors.fill: parent; host: fixture; shell: context; core: core }
    }
    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: {
            // A room that takes longer than a tick is given 3 s, and how long it took is logged: a slow room is a cost to record,
            // not a room that failed to load.
            if (cursor >= 0 && dashboard.loadedPage !== pages[cursor] && waited < 20) {
                waited++;
                return;
            }
            if (waited > 0) console.log("FART_SMOKE_SLOW", pages[cursor], waited * 150);
            waited = 0;
            if (cursor >= 0) console.log("FART_SMOKE", pages[cursor], dashboard.loadedPage);
            if (cursor === 0) {
                console.log("FART_THEME_INITIAL", viewTheme());
                console.log("FART_HOST_THEME_INITIAL", hostTheme());
                fixture.palette.colors = { background: "#654321" };
                fixture.palette.opacity = 0.85;
                fixture.palette.radius = 12;
                themeFixture.setText(JSON.stringify({theme: {colors: {base: "#654321"}, elementOpacity: 85, borderRadius: 12}}));
            }
            if (cursor === 0) console.log("FART_CORE", core.connected, serpantinum.notifications.available);
            // The deferred domains (ADAPTER_CONTRACT §1) are placeholders until loadDeferred(), then the real ones.
            if (cursor === 0 || cursor === 1) {
                const deferred = [serpantinum.audio, serpantinum.audio.equalizer, serpantinum.bluetooth, serpantinum.notifications,
                                  serpantinum.lyrics, serpantinum.clipboard].map(d => /^(Serpantinum|LyricsSource|CliphistClipboard)/.test(String(d)));
                console.log("FART_DEFERRED", cursor === 0 ? "before" : "after", deferred.join(","));
                if (cursor === 0) serpantinum.loadDeferred();
            }
            if (cursor === 1) { core.tasks.add("fixture"); console.log("FART_LEASE media", fixture.media.holds("position"), fixture.media.holds("spectrum")); }
            if (cursor === 2) { core.tasks.setDone(core.tasks.all[0].id, true); console.log("FART_RELEASE media", fixture.media.holds("position"), fixture.media.holds("spectrum")); }
            if (cursor === 3) { console.log("FART_TASK", core.tasks.all[0].done); core.tasks.remove(core.tasks.all[0].id, r => console.log("FART_REMOVED", r.task.text, r.index)); }
            if (cursor === 4) { core.timers.toggle("stopwatch"); console.log("FART_LEASE devices", fixture.audio.holds("mixer"), fixture.power.holds("brightness"), fixture.network.holds("scan")); }
            if (cursor === 5) console.log("FART_RELEASE devices", fixture.audio.holds("mixer"), fixture.power.holds("brightness"));
            if (cursor === 6) {
                console.log("FART_THEME_CHANGED", viewTheme());
                console.log("FART_HOST_THEME_CHANGED", hostTheme());
            }
            if (cursor === 7) core.timers.toggle("stopwatch");
            if (cursor === 8) {
                const sw = core.timersData.stopwatch;
                console.log("FART_STOPWATCH", sw.elapsed > 0, sw.running, core.tasks.all.length);
            }
            cursor++;
            if (cursor >= pages.length) {
                console.log("FART_CALLS", JSON.stringify([fixture.media, fixture.audio, fixture.hostActions, fixture.power].map(d => d.calls.length)));
                console.log("FART_SMOKE_DONE");
                Qt.quit();
                return;
            }
            dashboard.navigate(pages[cursor]);
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='fart-next-smoke-') as tmp:
        base = Path(tmp)
        env, state, view_log = prepare(base, SMOKE)
        runtime = Path(env['FART_RUNTIME_DIR'])
        core = subprocess.Popen([sys.executable, '-I', str(ROOT / 'core/fartd.py')], env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            exited = run_view(runtime / 'core.sock')
        finally:
            core.terminate()
            core.wait(5)
        output = view_log.read_text() if view_log.exists() else ''
        print(output)
        if not exited:
            print('FART_SMOKE: the harness did not finish')
            return 1
        pages = ['home','media','performance','workspaces','devices','tasks','timers','clipboard','notifications','codex']
        ok = 'FART_SMOKE_DONE' in output and all(f'FART_SMOKE {p} {p}' in output for p in pages)
        ok = ok and all(s in output for s in ('FART_THEME_INITIAL #123456 0.62 6', 'FART_THEME_CHANGED #654321 0.85 12',
            'FART_HOST_THEME_INITIAL #123456 0.62 6', 'FART_HOST_THEME_CHANGED #654321 0.85 12',
            # The spectrum is held only while something plays (the visualiser); the fixture's player is paused.
            'FART_LEASE media true false', 'FART_RELEASE media false false',
            'FART_LEASE devices true true false', 'FART_RELEASE devices false false',
            'FART_CORE true false', 'FART_TASK true', 'FART_REMOVED fixture 0', 'FART_STOPWATCH true false 0',
            'FART_CALLS [0,0,0,0]', 'FART_DEFERRED before false,false,false,false,false,false',
            'FART_DEFERRED after true,true,true,true,true,true'))
        # Runtime binding/type errors are failures even if a component nominally loads.
        ok = ok and not any(s in output for s in ('ReferenceError:', 'TypeError:', 'Cannot assign', 'Unable to assign', 'is not a type', 'Failed to load configuration'))
        # fart-next writes only its own state directory, never the archive's.
        ok = ok and json.loads((state / 'todo.json').read_text()) == [] and not (base / 'state/fart').exists()
        ok = ok and json.loads((state / 'tasks.json').read_text())['tasks'] == []
        return 0 if ok else 1

def request(stream, op, **args):
    stream.write(json.dumps({'id': 1, 'op': op, 'args': args}) + '\n')
    stream.flush()
    return json.loads(stream.readline())


def run_view(path: Path, timeout: float = 25) -> bool:
    """Open the harness through the core, then wait (up to `timeout` s) until it quits."""
    for _ in range(200):
        try:
            sock = socket.socket(socket.AF_UNIX)
            sock.connect(str(path))
            break
        except OSError:
            sock.close()
            time.sleep(0.02)
    else:
        raise RuntimeError('the smoke core did not start')
    with sock, sock.makefile('rw') as stream:
        request(stream, 'hello', client='cli', protocol=1)
        if not request(stream, 'view.open', page='home').get('ok'):
            return False
        for _ in range(round(timeout / 0.05)):
            if request(stream, 'status')['result']['view']['state'] == 'absent':
                return True
            time.sleep(0.05)
    return False


if __name__ == '__main__':
    raise SystemExit(main())
