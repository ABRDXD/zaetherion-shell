#!/usr/bin/env python3
"""Nested-only palette comparison using inert fixtures. Start nested_hypr.py first."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

from PIL import Image, ImageDraw, ImageFont
import nested_hypr

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from core.palette_catalog import STUDIES, catalogue, contrast


def capture(output: Path):
    output.mkdir(parents=True, exist_ok=True)
    entries = catalogue()
    studies = ["amoled:" + name.lower() for name in STUDIES]
    readable = ["dms:amoledBlack", "serpantinum:Mocha", "serpantinum:GitHub Light", "serpantinum:Nord", "dms:oxeoDeep"]
    with tempfile.TemporaryDirectory(prefix="palette-capture-") as directory:
        base = Path(directory)
        for name in ("home", "config", "state", "cache", "data", "run", "bundle"):
            (base / name).mkdir(mode=0o700)
        for name in ("core", "view", "adapters", "assets", "tools"):
            (base / "bundle" / name).symlink_to(ROOT / name, target_is_directory=True)
        (base / "bundle/shell.qml").write_text((ROOT / "tests/fixtures/palette/Shell.qml").read_text())
        (base / "catalogue.json").write_text(json.dumps(entries))
        env = {k: v for k, v in nested_hypr.env_for(nested_hypr.state()).items()
               if not k.startswith(("FART_", "DMS_", "MALLOC_", "QT_QUICK", "QSG_"))}
        env.update(HOME=str(base / "home"), XDG_CONFIG_HOME=str(base / "config"), XDG_STATE_HOME=str(base / "state"),
            XDG_CACHE_HOME=str(base / "cache"), XDG_DATA_HOME=str(base / "data"), FART_STATE_DIR=str(base / "state"),
            FART_CACHE_DIR=str(base / "cache"), FART_CORE_SOCKET="", PALETTE_FIXTURE_CATALOG=str(base / "catalogue.json"),
            MALLOC_CONF="thp:never,narenas:4,dirty_decay_ms:3000", PIPEWIRE_RUNTIME_DIR=str(base / "run"),
            DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent/palette-fixture", DBUS_SYSTEM_BUS_ADDRESS="unix:path=/nonexistent/palette-fixture")
        panels, cards, ratios = [], [], {}
        for key in studies + [k for k in readable if k in entries]:
            name = entries[key]["name"]
            with (base / "view.log").open("w") as log:
                process = subprocess.Popen(["qs", "-n", "--no-color", "-p", str(base / "bundle/shell.qml")],
                    env=env, stdout=log, stderr=subprocess.STDOUT)
            def ipc(*args):
                return subprocess.check_output(["qs", "ipc", "--pid", str(process.pid), "call", "palette-fixture", *args],
                    env=env, text=True, stderr=subprocess.STDOUT).strip()
            def shot(label):
                path = base / (label + ".png")
                subprocess.run([sys.executable, str(ROOT / "tools/nested_hypr.py"), "shot", str(path)], check=True,
                               stdout=subprocess.DEVNULL)
                return Image.open(path).convert("RGB")
            try:
                time.sleep(1)
                ipc("select", key)
                time.sleep(.25)
                rest = shot("rest") if key in studies else None
                if key in studies:
                    ipc("notice"); time.sleep(.65); notice = shot("notice")
                ipc("panel", "true"); time.sleep(1.5)
                assert ipc("preferences") == "true"
                time.sleep(.6)
                state = json.loads(ipc("state")); assert state["palette"] == key and state["open"]
                panel = shot("panel")
                # The standard nested fixture output is 1920x1080; preserve native pixels in the comparison.
                panel = panel.crop((288, 0, 1632, 860))
                if key in studies:
                    cards.append((name, entries[key]["colors"]["accent"], rest.crop((860, 0, 1060, 70)),
                                  notice.crop((550, 0, 1370, 160)), panel))
                else:
                    panels.append((name, panel))
                    c = entries[key]["colors"]
                    ratios[name] = {role: round(min(contrast(c[role], c[bg]) for bg in ("background", "surface")), 3)
                                    for role in ("text", "textMuted", "textFaint", "accent")}
                print("Captured", name, flush=True)
            finally:
                process.send_signal(signal.SIGTERM)
                try: process.wait(5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
            log = (base / "view.log").read_text()
            assert not any(error in log for error in ("ReferenceError", "TypeError", "Binding loop", "Unable to assign")), log
        font = ImageFont.truetype("DejaVuSans.ttf", 24)
        small = ImageFont.truetype("DejaVuSans.ttf", 18)
        width, height = 1384, 1110
        board = Image.new("RGB", (width * 2, 90 + height * 5), "#171717")
        draw = ImageDraw.Draw(board)
        draw.text((24, 20), "ZÆTHERION · AMOLED studies · owner selection pending · nested fixtures", font=font, fill="white")
        for index, (name, accent, rest, notice, panel) in enumerate(cards):
            x, y = index % 2 * width, 90 + index // 2 * height
            draw.text((x + 20, y), name.upper() + "  " + accent, font=font, fill=accent)
            draw.text((x + 20, y + 38), "REST", font=small, fill="#aaaaaa")
            draw.text((x + 300, y + 38), "NOTIFICATION", font=small, fill="#aaaaaa")
            board.paste(rest, (x + 20, y + 65)); board.paste(notice, (x + 300, y + 65))
            board.paste(panel, (x + 20, y + 230))
        board.save(output / "amoled-studies.png")
        board = Image.new("RGB", (width * 2, 90 + 920 * 3), "#171717")
        draw = ImageDraw.Draw(board)
        draw.text((24, 20), "Five installed palettes · readable text · nested fixtures", font=font, fill="white")
        for index, (name, panel) in enumerate(panels):
            x, y = index % 2 * width, 90 + index // 2 * 920
            draw.text((x + 20, y), name, font=font, fill="white"); board.paste(panel, (x + 20, y + 40))
        board.save(output / "readability.png")
        (output / "readability.json").write_text(json.dumps(ratios, indent=2) + "\n")


if __name__ == "__main__":
    capture(Path(sys.argv[1]))
