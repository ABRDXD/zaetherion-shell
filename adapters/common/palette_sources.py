"""Optional installed palette files, read-only; no host commands or settings writes."""
import json
import os
from pathlib import Path
import re

HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
SERP_ROLES = dict(background="base", surface="surface0", surfaceRaised="surface1", text="text",
                  textMuted="overlay2", textFaint="subtext1", line="overlay0", accent="blue", warm="yellow",
                  danger="red", success="green", highlight="mauve")
DMS_ROLES = dict(background="background", surface="surface", surfaceRaised="surfaceContainerHigh", text="surfaceText",
                 textMuted="secondary", textFaint="info", line="outline", accent="primary", warm="warning",
                 danger="error", success="primary", highlight="primary")


def read(path: Path) -> dict:
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def dms_dark(data: dict) -> dict:
    """Resolve the declared dark flavour/accent, including DMS's multi-variant themes."""
    colors = dict(data.get("dark") or {})
    variants = data.get("variants") or {}
    defaults = variants.get("defaults", {}).get("dark", {})
    flavor = defaults.get("flavor")
    for item in variants.get("flavors", []):
        if item.get("id") == flavor:
            colors.update(item.get("dark") or {})
    for item in variants.get("accents", []):
        if item.get("id") == defaults.get("accent"):
            colors.update(item.get(flavor) or item.get("dark") or {})
    return colors


def installed_palettes(serpantinum=None, dms=None, matugen=None):
    home = Path.home()
    serpantinum = serpantinum if serpantinum is not None else Path(os.environ.get(
        "SERPANTINUM_DIR", home / ".local/share/serpantinum/src")) / "assets/themes"
    dms = dms if dms is not None else Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")) / "dms/themes"
    matugen = matugen if matugen is not None else Path(os.environ.get("XDG_STATE_HOME", home / ".local/state")) / "serpantinum/qs_matugen_colors.json"
    entries = []

    def add(key, name, source, colors):
        entries.append(dict(id=key, name=name, source=source, colors=colors))

    for path in sorted(serpantinum.glob("*.json")):
        data = read(path)
        generated = read(matugen) if data.get("isMatugen") is True else data
        colors = generated.get("colors", generated)
        if not isinstance(colors, dict) or not HEX.fullmatch(str(colors.get("base", ""))):
            continue
        add("serpantinum:" + path.stem, str(data.get("name") or path.stem), "Serpantinum",
            {role: colors.get(key) for role, key in SERP_ROLES.items()})
    for path in sorted(dms.glob("*/theme.json")):
        data = read(path)
        try:
            colors = dms_dark(data)
        except (AttributeError, TypeError, ValueError):
            continue
        if not HEX.fullmatch(str(colors.get("background", ""))):
            continue
        add("dms:" + path.parent.name, str(data.get("name") or path.parent.name), "DMS",
            {role: colors.get(key) for role, key in DMS_ROLES.items()})
    return entries
