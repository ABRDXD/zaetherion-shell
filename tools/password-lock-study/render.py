"""Capture the fixture states and compare standard and reduced rejection motion."""
from pathlib import Path
import os
import subprocess
import tempfile

from PIL import Image

HERE = Path(__file__).resolve().parent
ENV = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")


def capture(form, output, *args):
    subprocess.run(["qml6", str(HERE / "LockStudy.qml"), "--", "--" + form,
                    *args, "--out", str(output)], check=True, env=ENV, timeout=10)
    with Image.open(output) as image:
        assert image.size == (1280, 720)
        return image.convert("RGB")


def render(form, tmp):
    entry = capture(form, HERE / f"{form}.png")
    failed = capture(form, HERE / f"{form}-failed.png", "--at", "400")
    reduced = capture(form, tmp, "--reduced", "--at", "0")
    assert reduced.tobytes() == failed.tobytes()
    assert capture(form, tmp, "--reduced", "--at", "120").tobytes() == reduced.tobytes()
    assert capture(form, tmp, "--at", "30").crop((400, 385, 850, 450)).tobytes() != reduced.crop((400, 385, 850, 450)).tobytes()
    frames = [entry]
    times = list(range(0, 321, 20))
    for ms in times:
        frames.append(capture(form, tmp, "--at", str(ms)))
    frames[0].save(HERE / f"{form}-motion.webp", save_all=True, append_images=frames[1:],
                   duration=[1050] + [20] * (len(times) - 1) + [1350], lossless=True, loop=0)
    entry.save(HERE / f"{form}-reduced.webp", save_all=True, append_images=[reduced],
               duration=[1050, 1670], lossless=True, loop=0)
    held = capture(form, tmp, "--hold", "0.65")
    assert held.crop((960, 610, 1279, 719)).tobytes() != entry.crop((960, 610, 1279, 719)).tobytes()


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as directory:
        for form in ("angular", "fluid"):
            render(form, Path(directory) / "sample.png")
