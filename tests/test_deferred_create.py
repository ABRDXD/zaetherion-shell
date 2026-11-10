"""DeferredCreate (the Serpantinum adapter's deferred domains): a domain that fails at construction
leaves the placeholder in place instead of publishing null over it (Astra's coldstart review)."""
import os
import re
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

ENTRY = """import QtQuick
import Quickshell
import "DeferredCreate.js" as DeferredCreate

ShellRoot {
    id: root
    property var domain: "placeholder"
    property int pending: 3
    function step(name, url, properties) {
        DeferredCreate.create(root, Qt.resolvedUrl(url), properties, object => {
            root.domain = object;
            console.log("DEFERRED_SET", name, object === null ? "null" : object.label);
        }, "deferred-test:");
        // Every case here finishes synchronously (local files): report the domain after each.
        console.log("DEFERRED_AFTER", name, root.domain === null ? "null" : typeof root.domain === "string" ? root.domain : root.domain.label);
    }
    Component.onCompleted: {
        try {
            step("missing-required", "NeedsValue.qml", {});
            step("broken-file", "Broken.qml", {});
            step("good", "NeedsValue.qml", { value: 2 });
        } finally {
            Qt.callLater(Qt.quit);
        }
    }
}
"""
NEEDS_VALUE = """import QtQuick
QtObject {
    required property int value
    readonly property string label: "real " + value
}
"""


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class DeferredCreateTests(unittest.TestCase):
    def test_a_failed_construction_keeps_the_placeholder(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            shutil.copy2(ROOT / "adapters/serpantinum/DeferredCreate.js", base / "DeferredCreate.js")
            (base / "NeedsValue.qml").write_text(NEEDS_VALUE)
            (base / "Broken.qml").write_text("import QtQuick\nQtObject { this is not qml }\n")
            entry = base / "DeferredTest.qml"
            entry.write_text(ENTRY)
            env = dict(PATH=os.defpath, HOME=tmp, XDG_RUNTIME_DIR=tmp, XDG_CONFIG_HOME=str(base / "config"),
                       XDG_CACHE_HOME=str(base / "cache"), XDG_STATE_HOME=str(base / "state"),
                       QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software",
                       DBUS_SESSION_BUS_ADDRESS=f"unix:path={base}/no-bus")
            out = subprocess.run(["qs", "-n", "-p", str(entry)], env=env, cwd=base, capture_output=True,
                                 text=True, timeout=20).stdout
            out = re.sub(r"\x1b\[[0-9;]*m", "", out)
            lines = re.findall(r"qml: (DEFERRED_.*)", out)
            self.assertEqual(lines, ["DEFERRED_AFTER missing-required placeholder",
                                     "DEFERRED_AFTER broken-file placeholder",
                                     "DEFERRED_SET good real 2", "DEFERRED_AFTER good real 2"], out)
            self.assertIn("could not be created; keeping the placeholder", out)


if __name__ == "__main__":
    unittest.main()
