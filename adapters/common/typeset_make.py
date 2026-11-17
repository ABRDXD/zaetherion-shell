"""Typeset any picture into a plate (Z215): runs tools/typeset/glyph.py --auto, which writes the face and its layers.

The core calls make(); the generator (Pillow, the house fonts) is known only here. It runs as its own process, so a
slow or failing picture never blocks the core; one at a time (the core refuses a second).
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

TOOL = Path(__file__).resolve().parents[2] / "tools" / "typeset" / "glyph.py"
TIMEOUT = 180.0


def argv(source: str, face: Path, layers: Path) -> list[str]:
    return [sys.executable, str(TOOL), "--auto", source, str(face), "--layers", str(layers)]


async def make(source: str, face: Path, layers: Path) -> str:
    proc = await asyncio.create_subprocess_exec(*argv(source, face, layers), stdout=asyncio.subprocess.DEVNULL,
                                                stderr=asyncio.subprocess.PIPE)
    try:
        _, err = await asyncio.wait_for(proc.communicate(), TIMEOUT)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.wait()
        raise RuntimeError("typesetting took too long")
    if proc.returncode != 0 or not face.is_file():
        lines = [l for l in err.decode(errors="replace").strip().splitlines() if l.strip()]
        raise RuntimeError("typesetting failed" + (": " + lines[-1][:200] if lines else ""))
    return str(face)
