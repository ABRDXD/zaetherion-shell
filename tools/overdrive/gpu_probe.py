#!/usr/bin/env python3
"""Per-room GPU time a frame and view CPU in Overdrive, out of sight (docs/OVERDRIVE.md §9, the 10 November pass).

Run inside tools/hidden_desktop.sh. The fixture view renders on the AMD chip through Mesa (as in daily use; the hidden
KWin would otherwise hand it the NVIDIA card) with Qt's RHI timestamps, so each frame's GPU time is read from the
render loop's log. `--off a,b` switches those strata off by name in a temporary copy of the checkout (Stratum.qml is
patched in the copy only), to find what a room's cost is made of. The hidden desktop runs at 60 Hz, so the numbers are
indicative: compare variants in alternating runs, since the chip moves between clock states from run to run.

    tools/hidden_desktop.sh python3 tools/overdrive/gpu_probe.py --rooms devices,tasks [--off sheet.sundial] [--seconds 6]
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import statistics
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.measure.fixture import private_core  # noqa: E402

GPU = re.compile(r"last retrieved GPU frame time was (\d+(?:\.\d+)?) ms")
FRAME = re.compile(r"frame rendered in")
OFF_PATCH = ('active: wanted &&',
             'active: ("," + (Quickshell.env("FART_STRATA_OFF") || "") + ",").indexOf("," + name + ",") < 0 && wanted &&')


def copy_with_off_switch(source, into):
    shutil.copytree(source, into, ignore=shutil.ignore_patterns(".git", "__pycache__"))
    stratum = into / "view/strata/Stratum.qml"
    text = stratum.read_text()
    if OFF_PATCH[0] not in text:
        raise SystemExit("Stratum.qml changed: update OFF_PATCH")
    stratum.write_text(text.replace("import QtQuick\n", "import QtQuick\nimport Quickshell\n", 1).replace(*OFF_PATCH))


def cpu_ticks(pid):
    fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
    return int(fields[11]) + int(fields[12])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--rooms", default="devices,tasks,media,performance,home")
    parser.add_argument("--off", default="", help="strata names to switch off, comma-separated")
    parser.add_argument("--seconds", type=float, default=6)
    parser.add_argument("--source", type=Path, default=ROOT)
    args = parser.parse_args()
    if "WAYLAND_DISPLAY" not in os.environ:
        raise SystemExit("run inside tools/hidden_desktop.sh")
    extra = dict(FART_MOTION="serpantinum", FART_FRAME_PROBE="0", QSG_RHI_PROFILE="1", FART_KEEP_SHELL="1",
                 FART_REDUCED="0", FART_AMBIENT="1", FART_FIXTURE_PLAYING="0", FART_IDLE_MS="",
                 FART_STRATA_OFF=args.off, DRI_PRIME="pci-0000_06_00_0",
                 __EGL_VENDOR_LIBRARY_FILENAMES="/usr/share/glvnd/egl_vendor.d/50_mesa.json")
    with tempfile.TemporaryDirectory(prefix="fart-gpu-probe-") as tmp:
        source = Path(tmp) / "src"
        copy_with_off_switch(args.source.resolve(), source)
        with private_core(source=source, desktop=True, extra_env=extra) as f:
            f.request("view.open", page="home")
            pid = f.wait_state(True, "home")["pid"]
            time.sleep(1.5)
            f.request("overdrive.request", mode="sticky")
            time.sleep(3)
            for room in [r for r in args.rooms.split(",") if r]:
                f.request("view.open", page=room)
                f.wait_state(True, room)
                time.sleep(3)
                before = len(f.log.read_text().splitlines())
                c0, t0 = cpu_ticks(pid), time.time()
                time.sleep(args.seconds)
                cpu = (cpu_ticks(pid) - c0) / os.sysconf("SC_CLK_TCK") / (time.time() - t0) * 100
                lines = f.log.read_text().splitlines()[before:]
                gpu = sorted(float(m[1]) for line in lines if (m := GPU.search(line)))
                frames = sum(bool(FRAME.search(line)) for line in lines)
                p90 = gpu[int(0.9 * (len(gpu) - 1))] if gpu else 0
                print(f"{room:14s} fps {frames / args.seconds:6.1f}  gpu ms median {statistics.median(gpu) if gpu else 0:.2f}"
                      f" p90 {p90:.2f}  view cpu {cpu:.1f} %", flush=True)
            f.request("overdrive.release")
            f.request("view.close")


if __name__ == "__main__":
    raise SystemExit(main())
