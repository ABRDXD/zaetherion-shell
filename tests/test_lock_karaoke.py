"""Karaoke on the lock (owner, 24 Nov): the current line between the one before and after, the stack travelling to a
new line, word-timed lines filling word by word in the accent; the visualiser's bars span their strip."""
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
import qs.view.ui
import qs.view.lock
Scope {
    id: h
    function say(n, v) { console.log("KAR " + JSON.stringify([n, v])); }
    QtObject { id: clock; property real pos: 15.0; function now() { return pos; } }
    FloatingWindow { implicitWidth: 1000; implicitHeight: 400; visible: true
        LockLyrics { id: lyr; width: 900; height: implicitHeight; clock: clock; index: 1
            lines: [{ time: 10, text: "before", words: [] },
                    { time: 14, text: "now thank you", words: [{time:14,text:"now"},{time:14.6,text:"thank"},{time:15.4,text:"you"}] },
                    { time: 18, text: "after", words: [] }] }
        LockBars { id: bars; y: 220; width: 1000; height: 80; levels: [0.2, 0.9, 0.5, 0.1] } }
    property int step: 0
    Timer { interval: 300; running: true; repeat: true; onTriggered: {
        switch (h.step++) {
        case 0: break;
        case 1: {
            lyr.sung = 15.0;
            const html = lyr.filled(lyr.lines[1]);
            h.say("fill", [html.split("<font").length - 1, (html.match(new RegExp(Qt.alpha(Design.accent, 1).toString(), "g")) || []).length]);
            h.say("bars", [bars.count, Math.round(bars.span) <= 1000, Math.round(bars.span) > 900]);
            lyr.index = 2;
            break;
        }
        case 2: h.say("travelling", lyr.scroll > 1 && lyr.scroll <= 2); break;
        case 4: h.say("arrived", lyr.scroll); h.say("done", true); Qt.quit();
        }
    } }
}
'''


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class Karaoke(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from smoke import prepare
        with tempfile.TemporaryDirectory() as tmp:
            env, _, _ = prepare(Path(tmp), HARNESS)
            run = subprocess.run(["qs", "-n", "--no-color", "-p", str(Path(tmp) / "bundle/Harness.qml")], env=env,
                                 capture_output=True, text=True, timeout=60)
        cls.output = run.stdout + run.stderr
        cls.said = {k: v for k, v in (json.loads(l.split("KAR ", 1)[1]) for l in cls.output.splitlines() if "KAR [" in l)}

    def test_sung_words_fill_in_the_accent(self):
        self.assertEqual(self.said.get("fill"), [3, 2], self.output[-1500:])  # "now" and "thank" sung, "you" not yet

    def test_the_stack_travels_to_the_new_line(self):
        self.assertTrue(self.said.get("travelling"), self.output[-1500:])
        self.assertEqual(self.said.get("arrived"), 2)

    def test_the_bars_span_their_strip(self):
        self.assertEqual(self.said.get("bars"), [91, True, True])  # floor((1000 + 4) / (7 + 4))

    def test_ran_clean(self):
        self.assertTrue(self.said.get("done"))
        for problem in ("ReferenceError", "TypeError", "Unable to assign"):
            self.assertNotIn(problem, self.output)


if __name__ == "__main__":
    unittest.main()
