"""Render the 1.5 s login, a 3× slower detail of the fold, and the desktop."""
import os
from pathlib import Path
import subprocess
import tempfile

from PIL import Image

HERE = Path(__file__).resolve().parent


def save_loop(filename, frames, durations):
    frames[0].save(HERE / filename, save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, lossless=True)


def main():
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"}
    times = [round(frame * 1000 / 60) for frame in range(91)]
    frames = []
    with tempfile.TemporaryDirectory() as tmp:
        for elapsed in times:
            out = HERE / "desktop.png" if elapsed == 1500 else Path(tmp) / "frame.png"
            subprocess.run(["qml6", str(HERE / "LoginClock.qml"), "--", "--at", str(elapsed),
                            "--out", str(out)], env=env, check=True, timeout=10)
            with Image.open(out) as image:
                frames.append(image.convert("RGB").resize((896, 504), Image.Resampling.LANCZOS))
    durations = [b - a for a, b in zip(times, times[1:])]
    save_loop("login-clock.webp", frames, durations + [1250])
    start = times.index(900)
    save_loop("fold-detail.webp", frames[start:], [3 * ms for ms in durations[start:]] + [850])


if __name__ == "__main__":
    main()
