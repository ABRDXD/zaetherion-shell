"""The lock screen (S7, docs/LOCK.md §5 F8, F12, F13), offscreen with a stand-in host: Astra's face loads with the
field holding the keyboard; the face is given the mask length, never the text; Enter hands the text to the host and
clears it; a refusal counts and shakes; a face that cannot load leaves a plain card that still asks; no property of
the face ever holds the secret. The real PAM and session lock run in the nested check (tools/lock_nested_check.py)."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

HARNESS = '''import QtQuick
import Quickshell
import qs.view.lock
Scope {
    id: harness
    function say(name, value) { console.log("LOCKS " + JSON.stringify([name, value])); }
    function props(item) {
        const out = [];
        for (const k in item) { try { const v = item[k]; if (typeof v === "string") out.push(v); } catch (e) {} }
        return out;
    }
    QtObject {
        id: host
        property url faceSource: Qt.resolvedUrl("view/lock/PasswordLockFace.qml")
        property int maskLength: 0
        property int attempts: 0
        property real rejectionMs: -1
        property string notice: ""
        property real holdProgress: 0
        property string wallpaper: ""
        property var track: ({ title: "Low Moon", artist: "Vesper Field", playing: true })
        property real batteryFraction: 0.76
        property var submitted: []
        function typing(n) { maskLength = n; }
        function submit(s) { submitted = submitted.concat([s.length]); attempts += 1; rejectionMs = 320; }
        function media(a) {}
        function holdStart() {}
        function holdEnd() {}
    }
    QtObject {
        id: broken
        property url faceSource: Qt.resolvedUrl("view/lock/Nope.qml")
        property int maskLength: 3
        property int attempts: 1
        property real rejectionMs: 320
        property string notice: ""
        property real holdProgress: 0
        property string wallpaper: ""
        property var track: null
        property real batteryFraction: -1
        function typing(n) {}
        function submit(s) {}
        function media(a) {}
        function holdStart() {}
        function holdEnd() {}
    }
    FloatingWindow {
        implicitWidth: 1280; implicitHeight: 720; visible: true
        LockScreen { id: screen; anchors.fill: parent; lock: host }
    }
    FloatingWindow {
        implicitWidth: 640; implicitHeight: 360; visible: true
        LockScreen { id: plain; anchors.fill: parent; lock: broken }
    }
    property int step: 0
    Timer {
        interval: 300; running: true; repeat: true
        onTriggered: {
            switch (harness.step++) {
            case 0: break;
            case 1:
                harness.say("faceLoaded", screen.faceLoaded);
                screen.field.forceActiveFocus();
                harness.say("fieldFocus", screen.focus && screen.field.focus);  // active focus needs the active window: nested check
                screen.field.text = "hunter2-secret";
                break;
            case 2: {
                const face = screen.children.find(c => c.objectName === "lockFace").item;
                harness.say("maskLength", face.maskLength);
                harness.say("secretInFace", harness.props(face).some(v => v.indexOf("hunter2") >= 0));
                screen.field.accepted();
                break;
            }
            case 3: {
                const face = screen.children.find(c => c.objectName === "lockFace").item;
                harness.say("afterEnter", [screen.field.text, host.submitted, face.attempts, face.rejectionMs, face.maskLength]);
                harness.say("plainCard", [plain.faceLoaded, plain.children.find(c => c.objectName === "plainCard").visible]);
                if (Quickshell.env("LOCK_SHOT")) screen.grabToImage(r => r.saveToFile(Quickshell.env("LOCK_SHOT")));
                break;
            }
            case 4:
                harness.say("done", true);
                Qt.quit();
            }
        }
    }
}
'''


def run_harness(shot=None):
    from smoke import prepare
    with tempfile.TemporaryDirectory() as tmp:
        env, _, _ = prepare(Path(tmp), HARNESS)
        if shot:
            env["LOCK_SHOT"] = shot
        run = subprocess.run(["qs", "-n", "--no-color", "-p", str(Path(tmp) / "bundle/Harness.qml")], env=env,
                             capture_output=True, text=True, timeout=90)
    output = run.stdout + run.stderr
    return output, {k: v for k, v in (json.loads(line.split("LOCKS ", 1)[1]) for line in output.splitlines() if "LOCKS [" in line)}


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class LockScreenRun(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import os
        cls.output, cls.said = run_harness(os.environ.get("LOCK_SHOT"))

    def heard(self, name):
        if name not in self.said:
            self.fail(f"the harness never said {name!r}:\n{self.output[-3000:]}")
        return self.said[name]

    def test_the_face_loads_and_the_field_has_the_keyboard(self):
        self.assertTrue(self.heard("faceLoaded"))
        self.assertTrue(self.heard("fieldFocus"))

    def test_the_face_gets_the_length_never_the_secret(self):
        self.assertEqual(self.heard("maskLength"), len("hunter2-secret"))
        self.assertFalse(self.heard("secretInFace"))
        self.assertNotIn("hunter2", self.output)

    def test_enter_hands_it_over_and_a_refusal_shows(self):
        self.assertEqual(self.heard("afterEnter"), ["", [14], 1, 320, 0])

    def test_a_face_that_cannot_load_leaves_a_plain_card(self):
        self.assertEqual(self.heard("plainCard"), [False, True])

    def test_ran_clean(self):
        self.assertTrue(self.heard("done"))
        for problem in ("ReferenceError", "TypeError", "Cannot assign", "is not a type", "Unable to assign"):
            self.assertNotIn(problem, self.output)


if __name__ == "__main__":
    unittest.main()
