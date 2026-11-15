"""Z202: quick paste on DMS's own clipboard history, through DmsAdapter, offscreen, against the stand-in DMS.

Nothing real is contacted; every entry below is synthetic and obviously fake. The history is read only under the
"history" lease (docs/DMS_ADAPTER.md §8): no subscription, no call and nothing held without it."""
import base64
import json
import shutil
import sys
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import dmstest  # noqa: E402

HISTORY = [
    {"id": 41, "preview": "fake words one", "isImage": False, "pinned": False, "timestamp": "2026-11-15T10:00:00Z"},
    {"id": 42, "preview": "[[ fake image ]]", "isImage": True, "pinned": False, "timestamp": "2026-11-15T11:00:00Z", "mimeType": "image/png"},
    {"id": 43, "preview": "fake words two", "isImage": False, "pinned": True, "timestamp": "2026-11-15T12:00:00Z"},
]
TEXT = "fäke full text ✓"
PNG = base64.b64encode(b"\x89PNG fake bytes").decode()
OK = {"result": {"success": True}}


def event(history):
    return {"service": "clipboard", "data": {"enabled": True, "history": history}}


@unittest.skipUnless(shutil.which("qs"), "Quickshell is not installed")
class DmsClipboard(unittest.TestCase):
    def setUp(self):
        self.tmp = dmstest.private_dir()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.stand = self.harness = None

    def tearDown(self):
        if self.harness:
            self.harness.stop()
        if self.stand:
            self.stand.stop()

    def start(self, replies=None, after=None):
        script = {"replies": {"clipboard.getHistory": {"result": HISTORY}, "clipboard.pasteSupported": {"result": {"supported": True}},
                              **(replies or {})}, "after": after or {}}
        self.stand = dmstest.Stand(self.dir, "dms-1.sock", script)
        self.harness = dmstest.Harness(self.stand.path, self.dir)
        self.harness.wait_for(lambda s: s.get("phase") == "ready")
        return self.stand, self.harness

    def clips(self, check=lambda s: True, timeout=6.0):
        deadline = time.time() + timeout
        state = json.loads(self.harness.ipc("clips"))
        while time.time() < deadline and not check(state):
            time.sleep(0.05)
            state = json.loads(self.harness.ipc("clips"))
        return state

    def sent(self, method):
        return [r["params"] for r in self.stand.requests() if r["event"] == "request" and r["method"] == method]

    def clipboard_requests(self):
        return [r["method"] for r in self.stand.requests()
                if r["event"] == "request" and r["method"].startswith("clipboard.") and r["method"] != "clipboard.pasteSupported"]

    def test_nothing_is_read_or_subscribed_without_the_lease(self):
        stand, h = self.start()
        h.ipc("domains")                                       # the clipboard is made, unleased
        state = self.clips(lambda s: s["kind"] == "DmsClipboard")
        time.sleep(0.5)
        self.assertEqual((state["kind"], state["entries"], state["loaded"], state["pinsKept"]), ("DmsClipboard", [], False, True))
        self.assertEqual(self.clipboard_requests(), [])
        self.assertFalse(any("clipboard" in (s or []) for s in stand.subscriptions()))

    def test_the_lease_reads_the_history_newest_first_and_releasing_drops_it(self):
        stand, h = self.start()
        h.ipc("clipAcquire")
        state = self.clips(lambda s: s["loaded"])
        self.assertEqual([e["id"] for e in state["entries"]], ["43", "42", "41"])
        self.assertEqual(state["entries"][0], {"id": "43", "text": "fake words two", "isImage": False, "pinned": True})
        self.assertTrue(any("clipboard" in (s or []) for s in stand.subscriptions()))
        h.ipc("clipRelease")
        state = self.clips(lambda s: not s["loaded"])
        self.assertEqual((state["entries"], state["thumbnails"]), ([], {}))
        time.sleep(0.5)
        self.assertNotIn("clipboard", stand.subscriptions()[-1] or [])
        h.ipc("clipDo", "copy", "43")                          # unleased: names nothing
        time.sleep(0.3)
        self.assertEqual(self.sent("clipboard.copyEntry"), [])

    def test_a_pushed_history_replaces_the_list(self):
        stand, h = self.start(replies={"clipboard.copyEntry": OK}, after={"clipboard.copyEntry": [event(HISTORY[:1])]})
        h.ipc("clipAcquire")
        self.clips(lambda s: len(s["entries"]) == 3)
        h.ipc("clipDo", "copy", "41")
        state = self.clips(lambda s: len(s["entries"]) == 1)
        self.assertEqual([e["id"] for e in state["entries"]], ["41"])

    def test_copy_paste_remove_and_pins_name_dmss_own_ids(self):
        stand, h = self.start(replies={m: OK for m in ("clipboard.copyEntry", "clipboard.sendPaste", "clipboard.deleteEntry",
                                                        "clipboard.pinEntry", "clipboard.unpinEntry")})
        h.ipc("clipAcquire")
        self.clips(lambda s: s["loaded"])
        h.ipc("clipDo", "copy", "41")
        h.ipc("clipDo", "paste", "43")
        h.ipc("clipDo", "remove", "42")
        h.ipc("clipDo", "pin", "41")
        h.ipc("clipDo", "unpin", "43")
        h.ipc("clipDo", "copy", "999")                         # not on show: nothing sent
        deadline = time.time() + 4
        while time.time() < deadline and not self.sent("clipboard.sendPaste"):
            time.sleep(0.05)
        self.assertEqual(self.sent("clipboard.copyEntry"), [{"id": 41}, {"id": 43}])
        self.assertEqual(self.sent("clipboard.sendPaste"), [{"shift": False}])     # 200 ms after the copy; no terminal here
        self.assertEqual(self.sent("clipboard.deleteEntry"), [{"id": 42}])
        self.assertEqual((self.sent("clipboard.pinEntry"), self.sent("clipboard.unpinEntry")), ([{"id": 41}], [{"id": 43}]))

    def test_without_paste_support_paste_only_copies(self):
        stand, h = self.start(replies={"clipboard.pasteSupported": {"result": {"supported": False}}, "clipboard.copyEntry": OK})
        h.ipc("clipAcquire")
        self.clips(lambda s: s["loaded"])
        h.ipc("clipDo", "paste", "43")
        time.sleep(0.8)
        self.assertEqual((self.sent("clipboard.copyEntry"), self.sent("clipboard.sendPaste")), ([{"id": 43}], []))

    def test_full_text_and_a_picture_come_from_the_entry(self):
        stand, h = self.start(replies={"clipboard.getEntry": {"result": {"id": 42, "data": PNG, "mimeType": "image/png"}}})
        h.ipc("clipAcquire")
        self.clips(lambda s: s["loaded"])
        h.ipc("clipDo", "thumb", "42")
        state = self.clips(lambda s: "42" in s["thumbnails"])
        self.assertEqual(state["thumbnails"]["42"], "data:image/png;base64," + PNG)
        self.stand.stop()
        self.harness.stop()

    def test_text_is_decoded_as_utf8(self):
        data = base64.b64encode(TEXT.encode()).decode()
        stand, h = self.start(replies={"clipboard.getEntry": {"result": {"id": 41, "data": data}}})
        h.ipc("clipAcquire")
        self.clips(lambda s: s["loaded"])
        h.ipc("clipDo", "fetch", "41")
        self.assertEqual(self.clips(lambda s: "41" in s["fetched"])["fetched"]["41"], TEXT)


    def test_the_settings_are_read_only_under_their_lease_and_written_one_key_at_a_time(self):
        config = {"disabled": False, "maxHistory": 1000, "maxEntrySize": 5242880, "autoClearDays": 0, "maxPinned": 25,
                  "clearAtStartup": False, "extra": "ignored"}
        stand, h = self.start(replies={"clipboard.getConfig": {"result": config}, "clipboard.setConfig": OK,
                                       "clipboard.clearHistory": OK})
        h.ipc("domains")
        time.sleep(0.4)
        h.ipc("clipDo", "set:maxHistory", "500")              # unleased: nothing sent
        self.assertEqual((self.sent("clipboard.getConfig"), self.sent("clipboard.setConfig")), ([], []))
        h.ipc("configAcquire")
        state = self.clips(lambda s: s["config"] is not None)
        self.assertEqual(state["config"], {k: v for k, v in config.items() if k != "extra"})
        h.ipc("clipDo", "set:maxHistory", "500")
        h.ipc("clipDo", "set:bogus", "1")                     # not a DMS setting: nothing sent
        h.ipc("clipDo", "clear", "")
        deadline = time.time() + 3
        while time.time() < deadline and len(self.sent("clipboard.getConfig")) < 2:
            time.sleep(0.05)
        self.assertEqual(self.sent("clipboard.setConfig"), [{"maxHistory": 500}])
        self.assertEqual(len(self.sent("clipboard.clearHistory")), 1)
        self.assertGreaterEqual(len(self.sent("clipboard.getConfig")), 2)   # read again after the write
        h.ipc("configRelease")
        self.assertIsNone(self.clips(lambda s: s["config"] is None)["config"])

if __name__ == "__main__":
    unittest.main()
