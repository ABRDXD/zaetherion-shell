"""Render the OPEN 8 copy candidates against the picked Angular boot motion."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

from PIL import Image

HERE = Path(__file__).resolve().parent
READINGS = {
    "impression": ("face", "register", "impression", "day"),
    "turnover": ("index", "register", "impression", "turn"),
}


def main():
    words = json.loads((HERE / "lines.json").read_text())
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"}
    with tempfile.TemporaryDirectory() as tmp:
        for name, keys in READINGS.items():
            reading = json.dumps([words[key] for key in keys], ensure_ascii=False)
            frames = []
            for ms in range(0, 1501, 30):
                out = HERE / f"{name}.png" if ms == 900 else Path(tmp) / "frame.png"
                subprocess.run(["qml6", str(HERE / "VoiceStudy.qml"), "--", "--reading", reading,
                                "--at", str(ms), "--out", str(out)], env=env, check=True, timeout=10)
                with Image.open(out) as image:
                    frames.append(image.convert("RGB").resize((784, 441), Image.Resampling.LANCZOS))
            frames[0].save(HERE / f"{name}.webp", save_all=True, append_images=frames[1:],
                           duration=[30] * (len(frames) - 1) + [900], loop=0, lossless=True)


if __name__ == "__main__":
    main()
