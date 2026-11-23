"""Render the combined fixture and its one-login loop with Qt 6 offscreen."""
import os
from pathlib import Path
import subprocess
import tempfile

from PIL import Image

HERE = Path(__file__).resolve().parent


def main():
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"}
    frames = []
    with tempfile.TemporaryDirectory() as tmp:
        for elapsed in range(0, 1501, 30):
            out = HERE / "desktop.png" if elapsed == 1500 else Path(tmp) / "frame.png"
            subprocess.run(["qml6", str(HERE / "LoginClock.qml"), "--", "--at", str(elapsed),
                            "--out", str(out)], env=env, check=True, timeout=10)
            with Image.open(out) as image:
                frames.append(image.convert("RGB").resize((896, 504), Image.Resampling.LANCZOS))
    frames[0].save(HERE / "login-clock.webp", save_all=True, append_images=frames[1:],
                   duration=[30] * (len(frames) - 1) + [1250], loop=0, lossless=True)


if __name__ == "__main__":
    main()
