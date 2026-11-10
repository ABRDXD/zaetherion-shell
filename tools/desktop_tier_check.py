#!/usr/bin/env python3
"""Exercise Overlay's desktop tier for real: private core, fixture adapter, the real layer surfaces, a few seconds."""
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
               FART_MIRROR='0', FART_HOST='fixture', FART_FIXTURE_LOG=str(base/'actions'), FART_VIEW_ENTRY=str(bundle/'shell.qml'), FART_VIEW_STDOUT=str(base/'view.log'),
               QT_QPA_PLATFORM='wayland', WAYLAND_DISPLAY=os.path.join(runtime, os.environ['WAYLAND_DISPLAY']),
               DBUS_SESSION_BUS_ADDRESS='unix:path='+str(base/'no-bus'), DBUS_SYSTEM_BUS_ADDRESS='unix:path='+str(base/'no-bus'))
    core = subprocess.Popen([sys.executable, '-I', str(ROOT/'core/fartd.py')], env=env, stdin=subprocess.DEVNULL, cwd=base)
    try:
        path = run/'core/core.sock'; conn = None
        for _ in range(250):
            conn = try_connect(path)
            if conn: break
            time.sleep(0.02)
        r = conn.request
        def step(name, wait):
            time.sleep(wait)
            st = r('status'); v = st.get('view', {})
            print(f"[{name}] view={v.get('state')} open={v.get('open')} overdrive={st['overdrive'].get('effective')} layers={layers()}", flush=True)
        r('view.open', page='home'); step('open silent', 2.5)
        r('overdrive.request', mode='sticky'); step('overdrive on', 3.0)
        r('view.open', page='media'); step('room moved', 1.8)
        r('view.close'); step('closed, residue', 2.2)
        step('residue gone', 15.0)
        r('view.open', page='home'); step('reopened', 2.0)
        r('overdrive.release'); step('released', 3.0)
        r('view.close'); step('closed silent', 1.5)
    finally:
        core.terminate(); core.wait(8)
    log = (base/'view.log').read_text() if (base/'view.log').exists() else ''
keep = [l[:280] for l in log.splitlines() if any(s in l for s in ('TypeError','ReferenceError','Binding loop','Error:','file://','qsb','failed','Failed')) and '.face' not in l]
print('--- log lines', len(log.splitlines()), 'errors', len(keep)); print('\n'.join(keep[:30]))
