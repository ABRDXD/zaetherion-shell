"""Recolour a typeset plate to an accent with ImageMagick (Z213): copy = ink + accent × signal.

The core calls recolour(); ImageMagick is known only here (like matugen in wallpaper_colors.py). The copy is written
to a temporary name and renamed, so a half-written file is never applied; an existing copy is reused.
"""
from __future__ import annotations

import asyncio
import os
import shutil
from pathlib import Path

from core.typeset import copy_path, lift

TIMEOUT = 30.0


def argv(layers: Path, accent: str, out: Path) -> list[str]:
    # The signal mask's grey levels mapped onto black → accent is accent × mask; added onto the ink.
    # Both layers in colour whatever their files hold (a grey PNG would make the sum grey), and the copy written in colour.
    return ["magick", str(layers / "ink.png"), "-colorspace", "sRGB", "-type", "TrueColor",
            "(", str(layers / "signal.png"), "-colorspace", "sRGB", "-type", "TrueColor", "+level-colors", f"black,{lift(accent)}", ")",
            "-compose", "plus", "-composite", "-type", "TrueColor", str(out)]


async def recolour(layers: Path, accent: str) -> str:
    out = copy_path(layers, accent)
    if out.is_file():
        return str(out)
    if not shutil.which("magick"):
        raise RuntimeError("ImageMagick (magick) is not installed")
    temp = out.with_name(f".{out.stem}.{os.getpid()}.tmp.png")
    proc = await asyncio.create_subprocess_exec(*argv(layers, accent, temp), stdout=asyncio.subprocess.DEVNULL,
                                                stderr=asyncio.subprocess.PIPE)
    try:
        _, err = await asyncio.wait_for(proc.communicate(), TIMEOUT)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.wait()
        temp.unlink(missing_ok=True)
        raise RuntimeError("recolouring took too long")
    if proc.returncode != 0 or not temp.is_file():
        temp.unlink(missing_ok=True)
        raise RuntimeError("recolouring failed: " + err.decode(errors="replace").strip()[:200])
    temp.replace(out)
    return str(out)
