#!/usr/bin/env python3
"""Build the owner's palette-following plates into a wallpaper folder (Z213).

Each plate's face is the file the picker shows (`<folder>/<stem>.png`); its layers go to `<folder>/.typeset/<stem>/`
(ink.png, signal.png, plate.json), where the core finds them. Glyph plates are rendered from their scene; any other
listed image has its one accent lifted out (extract.py) and keeps its own file as the face.

    build.py [folder]        (default ~/Pictures/Wallpapers)
"""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
GLYPH = {"zg-01-torii": "torii", "zg-02-city": "city", "zg-03-dusk": "dusk"}
EXTRACTED = ["aether-null-result.png"]


def main():
    folder = Path(sys.argv[1] if len(sys.argv) > 1 else "~/Pictures/Wallpapers").expanduser()
    for stem, scene in GLYPH.items():
        subprocess.run([sys.executable, str(HERE / "glyph.py"), str(HERE / "scenes" / f"{scene}.json"),
                        str(folder / f"{stem}.png"), "--layers", str(folder / ".typeset" / stem)], check=True)
        print("glyph", stem)
    for name in EXTRACTED:
        path = folder / name
        if path.is_file():
            subprocess.run([sys.executable, str(HERE / "extract.py"), str(path), str(folder / ".typeset" / path.stem), "--notch"], check=True)
            print("extracted", path.stem)


if __name__ == "__main__":
    main()
