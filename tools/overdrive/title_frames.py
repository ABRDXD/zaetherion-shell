#!/usr/bin/env python3
"""Frames of the room title under load (docs/OVERDRIVE.md §35) on the GPU, where the counter windows draw.

Runs tools/cuetest/TitleTest.qml as tools/cuetest.py does (a private bundle, no core, private state), but in a real
Wayland window with the hardware scene graph, so the Stratum `title.counters` loads. The window shows for a few seconds.
Usage: title_frames.py OUT_DIR
"""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
TREE = ('view', 'adapters', 'core', 'tools', 'assets')


def main():
    out = Path(sys.argv[1]).resolve()
    out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='fart-next-title-') as tmp:
        base = Path(tmp)
        bundle = base / 'bundle'
        bundle.mkdir()
        for name in TREE:
            shutil.copytree(ROOT / name, bundle / name, ignore=shutil.ignore_patterns('__pycache__'))
        entry = bundle / 'TitleTest.qml'
        shutil.copy2(ROOT / 'tools/cuetest/TitleTest.qml', entry)
        state = base / 'state/fart-next'
        state.mkdir(parents=True)
        env = dict(os.environ, QT_QPA_PLATFORM='wayland', FART_STATE_DIR=str(state), TITLE_SHOTS=str(out), TITLE_GPU='1',
                   XDG_STATE_HOME=str(base / 'state'), XDG_CONFIG_HOME=str(base / 'config'), XDG_CACHE_HOME=str(base / 'cache'),
                   FART_CACHE_DIR=str(base / 'cache/fart'), FART_CORE_SOCKET=str(base / 'absent.sock'))
        env.pop('QT_QUICK_BACKEND', None)
        result = subprocess.run(['qs', '-n', '--no-color', '-p', str(entry)], env=env, stdin=subprocess.DEVNULL,
                                capture_output=True, text=True, timeout=120)
        output = result.stdout + result.stderr
        print('\n'.join(line for line in output.splitlines() if 'CUE_' in line or 'WARN scene' in line or 'Error' in line))
        return 0 if 'CUE_DONE' in output and 'CUE_FAIL' not in output else 1


if __name__ == '__main__':
    raise SystemExit(main())
