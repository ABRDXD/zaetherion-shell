"""Side column settings (owner's pick B, 22 November 2026; Z223): Bluetooth, the secret prompt and Reload lyrics,
driven offscreen against the contract's recording domains. Every action reaches the same domain call as before."""
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
import QtQuick.Controls
import Quickshell
import qs.view.contract
import qs.view.shell
import qs.view.ui as Fart
Scope {
    id: harness
    function say(name, value) { console.log("SIDE " + JSON.stringify([name, value])); }
    function find(item, test) {
        if (!item) return null;
        if (test(item)) return item;
        const kids = [].concat(Array.from(item.children ?? []), item.contentItem && item.contentItem !== item ? [item.contentItem] : []);
        for (const k of kids) { const hit = find(k, test); if (hit) return hit; }
        return null;
    }
    function action(root, label) { return find(root, i => i.label === label && typeof i.click === "function" && i.visible); }
    function calls(domain) { return domain.calls.map(c => c.method + (c.args.length ? ":" + c.args.join(",") : "")); }
    BluetoothDomain {
        id: bt
        recordCalls: true; available: true; enabled: true; discovering: true
        devices: [{ id: "d1", name: "Sample headphones", connected: true, paired: true, trusted: true, audio: true, battery: 0.72 },
                  { id: "d2", name: "Desk mouse", connected: false, paired: true, trusted: false, audio: false, battery: -1 }]
        nearby: [{ id: "n1", name: "Pocket speaker", connected: false, paired: false, trusted: false, audio: true, battery: -1 }]
    }
    MediaDomain { id: media; recordCalls: true; available: true }
    LyricsDomain { id: lyrics; recordCalls: true; available: true; status: "none"; trackKey: "A - Song"; currentKey: "A - Song" }
    FloatingWindow {
        implicitWidth: WIDTH; implicitHeight: 900; visible: true
        Column {
            width: parent.width
            BluetoothSettings { id: page; width: parent.width; height: 640; bluetooth: bt; active: true; scanning: true }
            LyricsReload { id: reload; width: parent.width; media: media; lyrics: lyrics; active: false }
        }
    }
    Timer {
        interval: 400; running: true
        onTriggered: {
            // Layout: every row's lead action starts in one column; narrow panels put actions under the reading.
            const leads = ["Disconnect", "Connect", "Pair"].map(l => action(page, l)).filter(Boolean);
            harness.say("columns", leads.map(a => Math.round(a.mapToItem(page, 0, 0).x)));
            const side = find(page, i => typeof i.narrow === "boolean" && typeof i.actionWidth === "number" && i.visible && i.width > 0);
            harness.say("narrow", side.narrow);
            // Actions reach the domain.
            action(page, "Disconnect").click();
            action(page, "Connect").click();
            action(page, "✓  Trusted").click();
            action(page, "Trust").click();
            const forget = action(page, "Forget…");
            forget.click();
            harness.say("armed", [forget.armed, calls(bt).includes("forget:d1")]);
            forget.click();
            action(page, "Pair").click();
            action(page, "●  On").click();
            action(page, "Stop scanning").click();
            harness.say("bt", [calls(bt), page.scanning]);
            // BlueZ asks for a PIN: the field, Pair and Cancel; the code goes once and is cleared.
            bt.calls = [];
            bt.pairing = { id: "p1", kind: "pin", deviceName: "Pocket speaker", device: "n1", passkey: "" };
            Qt.callLater(() => {
                const prompt = find(page, i => typeof i.submit === "function" && typeof i.shown === "boolean" && i.visible);
                const field = find(prompt, i => i.objectName === "secretField");
                const pair = action(prompt, "Pair");
                harness.say("pin", [!!field, pair ? pair.enabled : null, find(page, i => i.text === "Enter the PIN") !== null]);
                field.text = "4321";
                pair.click();
                harness.say("pin sent", [calls(bt), field.text]);
                field.text = "99";
                action(prompt, "Cancel").click();
                harness.say("pin cancelled", [calls(bt), field.text]);
                // Lyrics: opening asks nothing; Reload holds the lease and asks fresh; closing lets go.
                harness.say("lyrics idle", [reload.state(), lyrics.holds("lyrics"), calls(lyrics)]);
                media.active = { id: "p", title: "Song", artist: "A" };
                harness.say("lyrics shown", [reload.state(), action(reload, "Reload lyrics").enabled]);
                reload.active = true;
                harness.say("lyrics open", lyrics.holds("lyrics"));
                action(reload, "Reload lyrics").click();
                Qt.callLater(() => {
                    harness.say("lyrics asked", [lyrics.holds("lyrics"), calls(lyrics)]);
                    reload.active = false;
                    harness.say("lyrics closed", lyrics.holds("lyrics"));
                    lyrics.currentKey = "B - Other";
                    harness.say("lyrics stale", reload.state());
                    media.active = null;
                    harness.say("lyrics none", [reload.state(), action(reload, "Reload lyrics").enabled]);
                    harness.say("done", true);
                    Qt.quit();
                });
            });
        }
    }
}
'''


def run_harness(width):
    from smoke import prepare
    with tempfile.TemporaryDirectory() as tmp:
        env, _, _ = prepare(Path(tmp), HARNESS.replace("WIDTH", str(width)))
        run = subprocess.run(["qs", "-n", "--no-color", "-p", str(Path(tmp) / "bundle/Harness.qml")], env=env,
                             capture_output=True, text=True, timeout=60)
    output = run.stdout + run.stderr
    return output, [json.loads(line.split("SIDE ", 1)[1]) for line in output.splitlines() if "SIDE [" in line]


@unittest.skipUnless(shutil.which("qs"), "needs Quickshell")
class SideColumn(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output, cls.said = run_harness(720)
        cls.narrow_output, cls.narrow_said = run_harness(420)

    def heard(self, name, said=None):
        for key, value in said if said is not None else self.said:
            if key == name:
                return value
        self.fail(f"the harness never said {name!r}:\n{self.output[-3000:]}")

    def test_the_run_finished_without_qml_errors(self):
        for output in (self.output, self.narrow_output):
            self.assertIn('SIDE ["done",true]', output)
            for problem in ("ReferenceError", "TypeError", "Cannot assign", "is not a type"):
                self.assertNotIn(problem, output)

    def test_lead_actions_share_one_right_column(self):
        columns = self.heard("columns")
        self.assertEqual(len(columns), 3)
        self.assertEqual(len(set(columns)), 1, columns)
        self.assertGreater(columns[0], 720 / 2)
        self.assertFalse(self.heard("narrow"))

    def test_a_narrow_panel_puts_the_actions_under_the_reading(self):
        self.assertTrue(self.heard("narrow", self.narrow_said))
        self.assertTrue(all(x < 420 / 4 for x in self.heard("columns", self.narrow_said)))

    def test_every_bluetooth_action_reaches_the_same_domain_call(self):
        calls, scanning = self.heard("bt")
        self.assertEqual(calls, ["disconnect:d1", "connect:d2", "trust:d1,false", "trust:d2,true", "forget:d1", "pair:n1",
                                 "setEnabled:false"])
        self.assertFalse(scanning)

    def test_forget_asks_twice(self):
        self.assertEqual(self.heard("armed"), [True, False])

    def test_the_pin_goes_once_is_cleared_and_cancel_clears_too(self):
        self.assertEqual(self.heard("pin"), [True, False, True])  # Pair is off until something is typed
        self.assertEqual(self.heard("pin sent"), [["answerPairing:p1,"], ""])
        self.assertEqual(self.heard("pin cancelled"), [["answerPairing:p1,", "cancelPairing:p1"], ""])

    def test_reload_lyrics_asks_only_when_pressed_and_lets_go_on_close(self):
        self.assertEqual(self.heard("lyrics idle"), ["Nothing playing", False, []])
        self.assertEqual(self.heard("lyrics shown"), ["No lyrics found", True])
        self.assertFalse(self.heard("lyrics open"), "opening Settings holds no lease")
        self.assertEqual(self.heard("lyrics asked"), [True, ["reload"]])
        self.assertFalse(self.heard("lyrics closed"))
        self.assertEqual(self.heard("lyrics stale"), "Not looked up yet")  # a result for another track isn't shown
        self.assertEqual(self.heard("lyrics none"), ["Nothing playing", False])


if __name__ == "__main__":
    unittest.main()
