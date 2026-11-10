#!/usr/bin/env python3
"""The heavy layer and the Medium on the real Overlay and a private core, on the AMD chip. Run it inside tools/hidden_desktop.sh so it shows nothing on the real screen."""
import json, os, shutil, subprocess, sys, tempfile, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT)); sys.path.insert(0, str(ROOT / 'tools'))
from tools.fart_next import try_connect
from tools.smoke import TREE

def layers():
    out = json.loads(subprocess.check_output(['hyprctl', 'layers', '-j']))
    found = []
    for mon, data in out.items():
        for level, items in data['levels'].items():
            for it in items:
                if it['namespace'].startswith('fart-'):
                    found.append((mon, 'level ' + level, it['namespace'], it['x'], it['y'], it['w'], it['h'], it['pid']))
    return found

with tempfile.TemporaryDirectory(prefix='fart-desk-') as tmp:
    base = Path(tmp); bundle = base / 'bundle'; bundle.mkdir()
    for name in TREE:
        p = ROOT / name
        if p.is_dir(): shutil.copytree(p, bundle / name, ignore=shutil.ignore_patterns('__pycache__'))
        else: shutil.copy2(p, bundle / name)
    shutil.copy2(ROOT / 'shell-fixture.qml', bundle / 'shell.qml')
    run = base / 'run'; run.mkdir(mode=0o700)
    runtime = os.environ['XDG_RUNTIME_DIR']
    env = dict(PATH=os.environ['PATH'], LANG='C.UTF-8', HOME=str(base), XDG_RUNTIME_DIR=str(run), XDG_CONFIG_HOME=str(base/'config'), XDG_CACHE_HOME=str(base/'cache'),
               XDG_STATE_HOME=str(base/'state'), XDG_DATA_HOME=str(base/'data'), FART_RUNTIME_DIR=str(run/'core'), FART_STATE_DIR=str(base/'state/fixture'), FART_CACHE_DIR=str(base/'cache/fixture'),
               FART_MIRROR='0', FART_HEAVY_CARD='integrated', FART_HEAVY='1', QML_XHR_ALLOW_FILE_READ='1', FART_HOST='fixture', FART_FIXTURE_LOG=str(base/'actions'), FART_VIEW_ENTRY=str(bundle/'shell.qml'), FART_VIEW_STDOUT=str(base/'view.log'),
               QT_QPA_PLATFORM='wayland', WAYLAND_DISPLAY=os.path.join(runtime, os.environ['WAYLAND_DISPLAY']),
               DBUS_SESSION_BUS_ADDRESS='unix:path='+str(base/'no-bus'), DBUS_SYSTEM_BUS_ADDRESS='unix:path='+str(base/'no-bus'))
    core = subprocess.Popen([sys.executable, '-I', str(ROOT/'core/fartd.py')], env=env, stdin=subprocess.DEVNULL, cwd=base)
    bad = []
    try:
        path = run/'core/core.sock'; conn = None
        for _ in range(250):
            conn = try_connect(path)
            if conn: break
            time.sleep(0.02)
        r = conn.request
        def heavy():
            return subprocess.run(['pgrep', '-fc', str(bundle/'shell-heavy.qml')], capture_output=True, text=True).stdout.strip()
        def ticks():
            pid = subprocess.run(['pgrep', '-f', str(bundle/'shell-heavy.qml')], capture_output=True, text=True).stdout.split()
            try: return sum(int(x) for x in Path(f'/proc/{pid[0]}/stat').read_text().rsplit(')', 1)[1].split()[11:13]) if pid else 0
            except OSError: return 0
        def step(name, wait):
            t0 = ticks(); time.sleep(wait); drew = ticks() - t0
            st = r('status'); v = st.get('view', {})
            print(f"[{name}] view={v.get('state')} open={v.get('open')} page={v.get('page')} overdrive={st['overdrive'].get('effective')} guards={st['overdrive'].get('suspended')} heavy_procs={heavy()} heavy_ticks={drew}", flush=True)
        r('view.open', page='home'); step('open silent', 2.5)
        r('overdrive.request', mode='sticky'); step('overdrive on', 5.0)
        for room in ('media', 'performance', 'workspaces', 'devices', 'tasks', 'timers', 'clipboard', 'notifications', 'codex', 'home'):
            r('view.open', page=room); step(room, 2.2)
        r('overdrive.release'); step('released', 3.5)
        if heavy() not in ('0', ''): bad.append('heavy process survived the release')
        r('view.close'); step('closed', 1.5)
        # A heavy process whose panel died before it linked must give up by itself (10 November: one drew on the card for hours).
        lone = subprocess.Popen(['qs', '-n', '--no-color', '-p', str(bundle/'shell-heavy.qml')], env=dict(env, FART_HEAVY_SOCKET=str(run/'nobody.sock')),
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            lone.wait(20); print(f"[unlinked] exited by itself, code {lone.returncode}", flush=True)
        except subprocess.TimeoutExpired:
            lone.kill(); bad.append('an unlinked heavy process did not exit')
    finally:
        core.terminate(); core.wait(8)
    log = (base/'view.log').read_text() if (base/'view.log').exists() else ''
keep = [l[:300] for l in log.splitlines() if any(s in l for s in ('TypeError','ReferenceError','Binding loop','Error:','qsb','failed','Failed','Unable to assign','Cannot')) and '.face' not in l]
print('--- log lines', len(log.splitlines()), 'errors', len(keep)); print('\n'.join(keep[:40])); print('BAD', bad)
sys.exit(1 if bad or keep else 0)
