"""Render two magnified, isolated island title slots from a shared fixture timeline."""
import os
from pathlib import Path
import subprocess
import tempfile
from PIL import Image

HERE = Path(__file__).resolve().parent
ENV = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
           QT_FORCE_STDERR_LOGGING="1")


def shot(path, *args):
    subprocess.run(["qml6", str(HERE / "LyricStudy.qml"), "--", *args, "--out", str(path)],
                   check=True, timeout=10, env=ENV)
    with Image.open(path) as image:
        return image.convert("RGB")


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as work:
        temp = Path(work) / "sample.png"
        frames = [shot(temp, "--at", str(ms)) for ms in range(1000, 1201, 20)]
        frames[0].save(HERE / "title-slots.webp", save_all=True, append_images=frames[1:],
                       loop=0, duration=[1000]+[20]*9+[1150], lossless=True)
        assert shot(temp, "--reduced", "--at", "1000").tobytes() == frames[-1].tobytes()
        rest = shot(HERE / "fallback.png", "--no-lyrics")
        assert shot(temp, "--released").tobytes() == rest.tobytes()
