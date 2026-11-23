#!/usr/bin/env python3
"""Run a cue harness from tools/cuetest/ under Quickshell offscreen and print its output (docs/CUES.md §10).

The harness sits at the root of a private copy so qs.* imports resolve. No core, host shell or
system action is started; state, config and cache are private.
"""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TREE = ('view', 'adapters', 'core', 'tools', 'assets')


# ViewTest walks every room at timeScale 10 with the 1000 ms orbit transfer (about 300 s), so the limit is 420 s.
def run(harness: str, timeout: float = 420) -> str:
    with tempfile.TemporaryDirectory(prefix='fart-next-cues-') as tmp:
        base = Path(tmp)
        bundle = base / 'bundle'
        bundle.mkdir()
        for name in TREE:
            shutil.copytree(ROOT / name, bundle / name, ignore=shutil.ignore_patterns('__pycache__'))
        entry = bundle / harness
        shutil.copy2(ROOT / 'tools/cuetest' / harness, entry)
        state = base / 'state/fart-next'
        state.mkdir(parents=True)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software', FART_STATE_DIR=str(state),
                   XDG_STATE_HOME=str(base / 'state'), XDG_CONFIG_HOME=str(base / 'config'), XDG_CACHE_HOME=str(base / 'cache'),
                   FART_CACHE_DIR=str(base / 'cache/fart'), FART_CORE_SOCKET=str(base / 'absent.sock'),
                   HYPRLAND_INSTANCE_SIGNATURE='', WAYLAND_DISPLAY='', PIPEWIRE_RUNTIME_DIR='/nonexistent/fart-fixture',
                   DBUS_SYSTEM_BUS_ADDRESS='unix:path=/nonexistent/fart-fixture', DBUS_SESSION_BUS_ADDRESS='unix:path=/nonexistent/fart-fixture')
        result = subprocess.run(['qs', '-n', '--no-color', '-p', str(entry)], env=env, stdin=subprocess.DEVNULL,
                                capture_output=True, text=True, timeout=timeout)
        return result.stdout + result.stderr


if __name__ == '__main__':
    output = run(sys.argv[1] if len(sys.argv) > 1 else 'CueTest.qml')
    print(output)
    raise SystemExit(0 if 'CUE_DONE' in output and 'CUE_FAIL' not in output else 1)
