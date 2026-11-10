"""view/rooms/Attention.js: Inbox's attention band (atlas #33 source eclipse, #34 arrival cadence, #35 silence debt).

Run under Node with the QML `.pragma` line stripped; `now` is passed in. Only sources, counts and times are used."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "view/rooms/Attention.js"
H = 3600 * 1000
NOW = 1_794_200_000_000


def item(app, hours_ago, read=False, urgency="normal"):
    return {"appName": app, "time": NOW - hours_ago * H, "read": read, "urgency": urgency, "summary": "SECRET", "body": "SECRET"}


@unittest.skipUnless(shutil.which("node"), "needs Node")
class AttentionTests(unittest.TestCase):
    def js(self, expression: str):
        body = "\n".join(line for line in SOURCE.read_text().splitlines() if not line.startswith(".pragma"))
        script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
        return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)

    def test_cadence_places_the_last_day_on_a_score(self):
        items = [item("mail", 12), item("chat", 0.5, read=True), item("mail", 30), item("pager", 6, urgency="critical")]
        got = self.js(f"cadence({json.dumps(items)}, {NOW})")
        self.assertEqual([round(t["x"], 3) for t in got], [0.5, 0.75, 0.979])
        self.assertEqual([t["unread"] for t in got], [True, True, False])
        self.assertEqual([t["urgent"] for t in got], [False, True, False])
        self.assertNotIn("SECRET", json.dumps(got))
        # Seconds work as well as milliseconds.
        self.assertEqual(len(self.js(f"cadence([{{appName: 'a', time: {(NOW - H) // 1000}, read: false}}], {NOW})")), 1)

    def test_sources_put_the_longest_ignored_first(self):
        items = [item("chat", 1), item("mail", 20), item("mail", 2), item("chat", 3, read=True), item("news", 5, read=True)]
        got = self.js(f"sources({json.dumps(items)})")
        self.assertEqual([(s["app"], s["unread"]) for s in got], [("mail", 2), ("chat", 1)])
        self.assertNotIn("SECRET", json.dumps(got))

    def test_eclipse_slabs_overlap_and_fit(self):
        got = self.js("eclipse([{app: 'a', unread: 3}, {app: 'b', unread: 1}], 400)")
        self.assertEqual([(round(s["x"], 6), s["w"]) for s in got], [(0, 62), (37.2, 30)])
        many = self.js("eclipse(Array.from({length: 30}, (_, i) => ({app: 'a' + i, unread: 5})), 300)")
        self.assertAlmostEqual(many[-1]["x"] + many[-1]["w"], 300, places=6)
        self.assertEqual(self.js("eclipse([], 300)"), [])

    def test_silence_debt_grows_with_how_long_unread_items_are_left(self):
        self.assertEqual(self.js(f"debt({json.dumps([item('a', 6), item('b', 48), item('c', 12, read=True)])}, {NOW})"), 1.25)
        self.assertEqual(self.js("[overhang(0), overhang(1), overhang(400)]"), [0, 28, 120])


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class InboxBand(unittest.TestCase):
    """The band in the real Inbox (tools/cuetest/InboxTest.qml)."""

    def test_the_band_in_the_room(self):
        import sys
        sys.path.insert(0, str(ROOT / "tools"))
        import cuetest
        output = cuetest.run("InboxTest.qml", timeout=60)
        self.assertIn("CUE_DONE", output, output[-2000:])
        self.assertEqual([line for line in output.splitlines() if "CUE_FAIL" in line], [])
        for name in ("inbox.band", "inbox.read"):
            self.assertIn(f"CUE_PASS {name}", output)
        self.assertIn("CUE_ACTIVE 0 []", output)
        self.assertFalse([e for e in ("ReferenceError:", "TypeError:", "Cannot assign") if e in output], output[-2000:])


if __name__ == "__main__":
    unittest.main()
