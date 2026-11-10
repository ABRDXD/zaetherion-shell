"""The committed qmldir files match what Quickshell would synthesize (tools/make_qmldirs.py)."""
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import make_qmldirs  # noqa: E402


class QmldirTests(unittest.TestCase):
    def test_the_tree_is_up_to_date(self):
        self.assertEqual(make_qmldirs.problems(), [], "run python3 tools/make_qmldirs.py")

    def test_lines_follow_quickshells_rules(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "shell.qml").write_text("import QtQuick\nItem {}\n")
            mod = root / "view" / "ui"
            mod.mkdir(parents=True)
            (mod / "Feedback.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject {}\n")
            (mod / "FButton.qml").write_text("//@ pragma Internal\nimport QtQuick\nItem {\n    // pragma Singleton\n}\n")
            (mod / "Alpha.qml").write_text("import QtQuick\nItem {}\n")
            (mod / "helper.qml").write_text("import QtQuick\nItem {}\n")
            self.assertEqual(make_qmldirs.write(root), [mod / "qmldir"])
            self.assertEqual((mod / "qmldir").read_text().splitlines()[1:], [
                "module qs.view.ui", "Alpha 1.0 Alpha.qml", "internal FButton 1.0 FButton.qml",
                "singleton Feedback 1.0 Feedback.qml"])
            self.assertFalse((root / "qmldir").exists())
            self.assertEqual(make_qmldirs.problems(root), [])
            for name in ("Alpha.qml", "Feedback.qml", "FButton.qml", "helper.qml"):
                (mod / name).unlink()
            self.assertEqual(make_qmldirs.problems(root), ["view/ui/qmldir: no .qml left"])
            make_qmldirs.write(root)
            self.assertFalse((mod / "qmldir").exists())


if __name__ == "__main__":
    unittest.main()
