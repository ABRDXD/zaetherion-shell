"""A palette made from a wallpaper image with matugen's dry run (Z179): no files written, no templates run.

The core calls colors_for(); matugen and its JSON shape are known only here (like palette_sources.py).
"""
from __future__ import annotations

import asyncio
import json
import re
import shutil

HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
# Material 3 dark roles → FART's palette roles (docs/fart/ADAPTER_CONTRACT.md, palette).
MATERIAL_ROLES = dict(background="background", surface="surface_container_low", surfaceRaised="surface_container_high",
                      text="on_surface", textMuted="on_surface_variant", textFaint="outline", line="outline_variant",
                      accent="primary", warm="tertiary", danger="error", success="secondary", highlight="primary_container")
TIMEOUT = 10.0


def argv(path: str) -> list[str]:
    # A fixed source colour: with several candidates matugen otherwise waits for a terminal choice.
    return ["matugen", "image", path, "--dry-run", "--json", "hex", "-m", "dark", "-t", "scheme-tonal-spot",
            "--source-color-index", "0"]


def roles(output: dict) -> dict:
    """matugen 4.x JSON → {role: "#rrggbb"}; roles it lacks are left out (normalize() fills them)."""
    colors = output.get("colors") if isinstance(output, dict) else None
    if not isinstance(colors, dict):
        return {}
    result = {}
    for role, key in MATERIAL_ROLES.items():
        value = colors.get(key)
        value = value.get("dark", value.get("default")) if isinstance(value, dict) else None
        value = value.get("color") if isinstance(value, dict) else value
        if isinstance(value, str) and HEX.fullmatch(value):
            result[role] = value.lower()
    return result


async def colors_for(path: str) -> dict:
    """Roles for an image, or raises RuntimeError with a short reason."""
    if not shutil.which("matugen"):
        raise RuntimeError("matugen is not installed")
    process = await asyncio.create_subprocess_exec(*argv(path), stdin=asyncio.subprocess.DEVNULL,
                                                   stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        out, _ = await asyncio.wait_for(process.communicate(), TIMEOUT)
    except asyncio.TimeoutError:
        process.kill()
        await process.wait()
        raise RuntimeError("matugen took too long") from None
    if process.returncode != 0:
        raise RuntimeError("matugen could not read this image")
    try:
        result = roles(json.loads(out))
    except ValueError:
        result = {}
    if "background" not in result or "accent" not in result:
        raise RuntimeError("matugen gave no usable colours")
    return result
