#!/usr/bin/env python3
"""One bounded, read-only GPU sample. Prefer an AMD display adapter."""
import json
from pathlib import Path
import subprocess


def number(path):
    try:
        return float(path.read_text().strip())
    except (OSError, ValueError):
        return None


def sample(sys_root=Path('/sys')):
    drm = sys_root / 'class/drm'
    cards = [c for c in sorted(drm.glob('card[0-9]*')) if c.name[4:].isdigit()]
    cards.sort(key=lambda c: number(c / 'device/boot_vga') != 1)
    for card in cards:
        device = card / 'device'
        busy = number(device / 'gpu_busy_percent')
        if busy is None or not 0 <= busy <= 100:
            continue
        temperature = None
        for hwmon in device.glob('hwmon/hwmon*'):
            raw = number(hwmon / 'temp1_input')
            if raw is not None:
                temperature = raw / 1000
                break
        return dict(available=True, source='AMD · ' + card.name, gpu=busy / 100,
                    temperature=temperature, vramUsed=number(device / 'mem_info_vram_used'),
                    vramTotal=number(device / 'mem_info_vram_total'))
    try:
        result = subprocess.run(['nvidia-smi', '--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total',
                                 '--format=csv,noheader,nounits'], capture_output=True, text=True, timeout=2, check=True)
        busy, temp, used, total = [float(v) for v in result.stdout.splitlines()[0].split(',')]
        if not 0 <= busy <= 100:
            raise ValueError('invalid utilization')
        return dict(available=True, source='NVIDIA', gpu=busy / 100, temperature=temp,
                    vramUsed=used * 1048576, vramTotal=total * 1048576)
    except (OSError, ValueError, IndexError, subprocess.SubprocessError):
        return dict(available=False, error='No readable GPU utilization sensor')


if __name__ == '__main__':
    print(json.dumps(sample()))
