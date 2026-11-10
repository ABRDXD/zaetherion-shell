"""Static checks on the view tree: module imports resolve and no legacy or host-owning code returns."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
QML = sorted(p for p in ROOT.rglob("*.qml") if ".git" not in p.parts)


class LayoutTests(unittest.TestCase):
    def test_qs_imports_resolve_to_directories(self):
        for qml in QML:
            for module in re.findall(r"^import qs\.([\w.]+)", qml.read_text(), re.M):
                self.assertTrue((ROOT / module.replace(".", "/")).is_dir(), f"{qml}: qs.{module}")

    def test_no_relative_directory_imports(self):
        # Directory imports go through qs.* so files can move without path arithmetic.
        for qml in QML:
            self.assertIsNone(re.search(r'^import "[^"]*"\s*$', qml.read_text(), re.M), str(qml))

    def test_room_loader_targets_exist(self):
        shell = ROOT / "view/shell/Shell.qml"
        for target in re.findall(r'"(\.\./rooms/\w+\.qml)"', shell.read_text()):
            self.assertTrue((shell.parent / target).is_file(), target)

    def test_shell_paths_exist(self):
        for qml in QML:
            for path in re.findall(r'shellPath\("([^"]+)"\)', qml.read_text()):
                self.assertTrue((ROOT / path).exists(), f"{qml}: {path}")

    def test_font_sizes_come_from_the_type_scale(self):
        # MONTAGE.md §2: no pixelSize literal; a computed fit is marked "// scale:" on its line.
        for qml in QML:
            if qml.name == "MaterialSymbol.qml":
                continue
            for number, line in enumerate(qml.read_text().splitlines(), 1):
                match = re.search(r"pixelSize:\s*([^;}]+)", line)
                if not match or "// scale:" in line:
                    continue
                where = f"{qml.relative_to(ROOT)}:{number}: {line.strip()}"
                self.assertIsNone(re.search(r"(?<![\w.])\d", match.group(1)), where)
                self.assertIsNone(re.search(r"Design\.(heading|subheading)\b", match.group(1)), where)

    def test_index_rooms_take_their_title_from_the_band(self):
        # MONTAGE.md §4 (Q3): the selected index band is the room's title; index rooms have no FHeading.
        # The page map's entries only: the archive and profile overlays load by `source:` and keep theirs.
        shell = (ROOT / "view/shell/Shell.qml").read_text()
        targets = re.findall(r'^\s*(?!source\b)\w+:\s*"\.\./rooms/(\w+\.qml)"', shell, re.M)
        self.assertEqual(len(targets), 10, targets)
        for target in targets:
            self.assertNotIn("FHeading", (ROOT / "view/rooms" / target).read_text(), target)

    def test_view_cannot_claim_host_services_or_reach_the_archive(self):
        forbidden = ("NotificationServer {", "ConflictKiller", "GlobalShortcut {", "host/Shell.qml",
                     "serpantinumd", "FART_SOURCE", "fart/source", "end4-pC", "illogical-impulse")
        for qml in QML:
            data = qml.read_text()
            for symbol in forbidden:
                self.assertNotIn(symbol, data, str(qml))
        self.assertFalse(any(p.is_symlink() for p in ROOT.rglob("*") if ".git" not in p.parts))
