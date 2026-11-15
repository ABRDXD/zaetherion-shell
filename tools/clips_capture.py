#!/usr/bin/env python3
"""Offscreen captures of the island's quick paste and rests, for the owner's review (S3). Made-up clips only.

    python3 tools/clips_capture.py REPO OUT_DIR        (MOCK_SCENES=name,name to pick scenes)
"""
import os, subprocess, sys, tempfile
from pathlib import Path
REPO = Path(sys.argv[1]); OUT = Path(sys.argv[2]); OUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(REPO / "tools"))
from smoke import prepare
from PIL import Image, ImageDraw

HARNESS = (Path(__file__).resolve().parent.parent / "tests/fixtures/clips/Harness.qml").read_text()
with tempfile.TemporaryDirectory(prefix="zt-mock-") as tmp:
    base = Path(tmp)
    for i, (a, b) in enumerate([((70, 90, 140), (200, 120, 90)), ((30, 120, 100), (230, 220, 160))]):
        im = Image.new("RGB", (320, 180)); d = ImageDraw.Draw(im)
        for x in range(320):
            t = x / 319; d.line([(x, 0), (x, 179)], fill=tuple(int(a[k] + (b[k] - a[k]) * t) for k in range(3)))
        d.rectangle([40, 40, 150, 140], outline=(255, 255, 255), width=3); d.ellipse([190, 60, 260, 130], fill=(20, 20, 30))
        im.save(base / f"thumb{i}.png")
    env, _, _ = prepare(base, HARNESS.replace("@THUMBS@", str(base)), source=REPO)
    env = {k: v for k, v in env.items() if not k.startswith("DMS_")}
    runtime = base / "runtime"; runtime.mkdir(mode=0o700)
    env.update(XDG_RUNTIME_DIR=str(runtime), MOCK_OUT=str(OUT), MOCK_SCENES=os.environ.get("MOCK_SCENES", ""))
    r = subprocess.run(["qs", "--no-color", "-p", env["FART_VIEW_ENTRY"]], env=env, stdin=subprocess.DEVNULL,
                       capture_output=True, text=True, timeout=60)
    out = r.stdout + r.stderr
    print("\n".join(line for line in out.splitlines() if "MOCK" in line or "rror" in line))
