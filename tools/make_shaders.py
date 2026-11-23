#!/usr/bin/env python3
"""Compile the view's GLSL shaders (view/**/shaders/*.vert, *.frag) to Qt's .qsb, beside each source.

Run after editing a shader; the .qsb files are derived and committed (NOTICE). `--check` compiles to a
temporary directory and fails if a committed .qsb is missing or stale.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
QSB = shutil.which("qsb") or "/usr/lib/qt6/bin/qsb"


def sources():
    return sorted(p for p in (ROOT / "view").rglob("shaders/*") if p.suffix in (".vert", ".frag"))


def compile_to(source: Path, out: Path):
    subprocess.run([QSB, "--qt6", "-o", str(out), str(source)], check=True, capture_output=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale = []
    with tempfile.TemporaryDirectory() as tmp:
        for source in sources():
            target = source.with_name(source.name + ".qsb")
            if args.check:
                fresh = Path(tmp) / target.name
                compile_to(source, fresh)
                if not target.exists() or target.read_bytes() != fresh.read_bytes():
                    stale.append(target.relative_to(ROOT))
            else:
                compile_to(source, target)
                print(target.relative_to(ROOT))
    if stale:
        print("stale or missing:", *stale, sep="\n  ")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
