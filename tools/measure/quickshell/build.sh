#!/bin/sh
# The disk-cache experiment's scratch Quickshell (docs/COLDSTART.md, "Disk-cache experiment").
# Usage: build.sh SCRATCH QUICKSHELL_GIT
# Clones QUICKSHELL_GIT (a URL or a local mirror) at the revision the installed qs reports into
# SCRATCH/src/qs, then builds it twice with the AUR package's CMake flags. Nothing is installed:
#   SCRATCH/bin/qs-control  unpatched (controls for build differences against /usr/bin/qs)
#   SCRATCH/bin/qs-patched  with 1434-file-urls.patch (an incremental rebuild)
set -eu
S=$(realpath "$1"); ORIGIN=$2
REV=4f508be500dea6e5732cc3d50382a0048b17e7b1
PATCH=$(dirname "$(realpath "$0")")/1434-file-urls.patch
case "$S" in "$HOME"/.local/share/fart/*) echo "use a scratch directory, not a FART tree" >&2; exit 2;; esac
[ -d "$S/src/qs" ] || git clone -q "$ORIGIN" "$S/src/qs"
git -C "$S/src/qs" checkout -q "$REV"
git -C "$S/src/qs" checkout -q -- .
mkdir -p "$S/bin"
cmake -S "$S/src/qs" -B "$S/build-qs" -GNinja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX="$S/never-installed" \
  -DDISTRIBUTOR="scratch ($REV, disk-cache experiment)" \
  -DDISTRIBUTOR_DEBUGINFO_AVAILABLE=NO \
  -DINSTALL_QML_PREFIX=lib/qt6/qml
cmake --build "$S/build-qs"
cp "$S/build-qs/src/quickshell" "$S/bin/qs-control"
git -C "$S/src/qs" apply "$PATCH"
cmake --build "$S/build-qs"
cp "$S/build-qs/src/quickshell" "$S/bin/qs-patched"
"$S/bin/qs-patched" --version
