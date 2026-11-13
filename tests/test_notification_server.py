"""S4's pass condition: a `notify-send` matrix against our own notification server (docs/MILESTONES.md).

Quickshell runs offscreen with DmsNotifications on a private session bus, reporting to a private core. Senders are
`notify-send` and `gdbus` on that bus; every text is synthetic. The desktop's bus and notifications are not touched.
"""
import json
from pathlib import Path
import subprocess
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tests"))
import dmstest  # noqa: E402
import notiftest  # noqa: E402
from test_core_busctl import SERVER as FOREIGN_SERVER, have_dbus_python  # noqa: E402

# One opaque red pixel as the image-data hint (width, height, rowstride, alpha, bits, channels, bytes).
PIXEL = '{"image-data": <(1,1,4,true,8,4,[byte 255,0,0,255])>}'


@unittest.skipIf(notiftest.missing(), "needs " + ", ".join(notiftest.missing()))
class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = dmstest.private_dir()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.bus = notiftest.Bus()
        self.addCleanup(self.bus.stop)
        self.view = notiftest.View(self.dir)
        self.addCleanup(self.view.stop)
        self.core = None

    def start_core(self):
        self.core = notiftest.Core(self.dir, self.bus, self.view)
        self.addCleanup(self.core.stop)
        return self.view.attach(self.core)

    def serving(self):
        """Wait until the view's server holds the name and is the Inbox's source."""
        view = self.view if self.core else self.start_core()
        state = view.wait_for(lambda s: s["source"] == "server" and s["available"], timeout=10)
        self.assertEqual((state["source"], state["available"]), ("server", True), view.output()[-1500:] + self.core.log()[-1500:])
        return view

    def items(self, count, check=lambda items: True):
        """Wait until the Inbox shows `count` items that satisfy `check`."""
        state = self.view.wait_for(lambda s: len(s["items"]) == count and check(s["items"]))
        self.assertEqual(len(state["items"]), count, state)
        self.assertTrue(check(state["items"]), state)
        return state["items"]

    def played(self):
        """The cues the core asked the (fixture) host to play, in order."""
        log = self.dir / "fixture.jsonl"
        lines = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
        return [line[1] for line in lines if isinstance(line, list) and line[:1] == ["play"]]

    def background(self, process):
        """A sender or monitor left running: stopped and reaped with the test."""
        def end():
            process.kill()
            process.communicate()
        self.addCleanup(end)
        return process

    def notify(self, summary, app="Fixture", replaces=0, icon="", actions="[]", hints="{}", timeout=-1):
        """A raw Notify call, for what notify-send cannot say. Returns the bus id."""
        out = self.bus.call("Notify", app, str(replaces), icon, summary, "Synthetic body", actions, hints, "--", str(timeout))
        return int(out.strip("(),").split()[-1])


class MatrixTests(Base):
    def test_urgencies_and_their_showing_time(self):
        self.serving()
        for urgency in ("low", "normal", "critical"):
            self.bus.send("-u", urgency, "-a", "Fixture", urgency, "Synthetic body")
        items = self.items(3)
        self.assertEqual([(i["summary"], i["urgency"], i["timeout"]) for i in items],
                         [("low", "low", 5000), ("normal", "normal", 5000), ("critical", "critical", 0)])
        self.assertEqual({(i["appName"], i["body"], i["read"], i["live"]) for i in items},
                         {("Fixture", "Synthetic body", False, True)})
        self.assertEqual(self.played(), ["notify.normal", "notify.critical"])   # low is silent

    def test_sound_is_left_to_a_sender_that_plays_its_own_and_to_do_not_disturb(self):
        view = self.serving()
        self.bus.send("-h", "boolean:suppress-sound:true", "own sound", "Synthetic body")
        view.ipc("dnd", "true")
        self.assertTrue(view.wait_for(lambda s: s["dnd"])["dnd"])
        self.bus.send("quiet", "Synthetic body")
        self.bus.send("-u", "critical", "loud", "Synthetic body")
        self.items(3)
        # Switching do-not-disturb has its own cue (dnd.on); of the three notifications only the critical one sounds.
        self.assertEqual(self.played(), ["dnd.on", "notify.critical"])

    def test_expiry_the_senders_time_is_kept_and_a_transient_leaves_when_it_ends(self):
        self.serving()
        self.bus.send("-t", "1500", "kept", "Synthetic body")
        self.assertEqual(self.items(1)[0]["timeout"], 1500)
        self.bus.send("-e", "-t", "400", "passing", "Synthetic body")
        self.items(2)
        self.assertEqual([i["summary"] for i in self.items(1)], ["kept"])

    def test_actions_reach_the_sender(self):
        view = self.serving()
        sender = self.background(self.bus.send("-A", "open=Open", "-A", "later=Later", "with actions", "Synthetic body", wait=False))
        item = self.items(1)[0]
        self.assertEqual((item["actions"], item["hasActions"]),
                         ([{"id": "open", "label": "Open"}, {"id": "later", "label": "Later"}], True))
        view.ipc("invoke", item["id"], "later", "")
        self.assertEqual(sender.communicate(timeout=5)[0].strip(), "later")
        self.items(0)   # answering closes it

    def test_inline_reply_reaches_the_sender(self):
        view = self.serving()
        monitor = self.background(subprocess.Popen(["gdbus", "monitor", "--session", "--dest", notiftest.SERVICE],
                                                   env=self.bus.env, stdout=subprocess.PIPE, text=True))
        time.sleep(0.3)
        # Quickshell shows the reply action's label as the field's placeholder.
        self.notify("with reply", actions='["inline-reply", "Say something"]')
        item = self.items(1)[0]
        self.assertEqual((item["reply"], item["actions"]), ("Say something", []))
        view.ipc("invoke", item["id"], "", "Synthetic answer")
        self.items(0)
        monitor.terminate()
        seen = monitor.communicate(timeout=5)[0]
        self.assertIn("NotificationReplied", seen)
        self.assertIn("Synthetic answer", seen)

    def test_images_a_file_an_icon_name_and_raw_pixels(self):
        self.serving()
        picture = self.dir / "picture.png"
        picture.write_bytes(b"not read here")
        self.bus.send("-h", f"string:image-path:{picture}", "file", "Synthetic body")
        self.bus.send("-i", "dialog-information", "icon", "Synthetic body")
        self.notify("pixels", hints=PIXEL)
        file, icon, pixels = self.items(3)
        self.assertEqual((file["image"], icon["icon"], icon["image"]), (f"file://{picture}", "dialog-information", ""))
        self.assertTrue(pixels["image"].startswith("image://qsimage/"), pixels)   # shown from the view until saved

    def test_raw_pixels_are_kept_once_drawn_and_outlive_the_view(self):
        view = self.serving()
        self.notify("pixels", hints=PIXEL)
        item = self.items(1)[0]
        view.ipc("keepImage", item["id"])
        kept = self.items(1, lambda items: items[0]["image"].startswith("file://"))[0]["image"]
        path = Path(kept.removeprefix("file://"))
        self.assertEqual((path.parent, path.read_bytes()[:4]), (self.dir / "cs/notification-images", b"\x89PNG"))
        gone = view.process.pid
        view.kill()
        view.attach(self.core, after=gone)
        self.assertEqual(self.items(1)[0]["image"], kept)
        view.ipc("dismiss", item["id"])
        self.items(0)
        self.assertFalse(path.exists())

    def test_a_private_apps_pixels_are_not_kept(self):
        view = self.serving()
        self.core.request("notif.privateApps", apps=["Fixture"])
        self.notify("pixels", hints=PIXEL)
        item = self.items(1)[0]
        view.ipc("keepImage", item["id"])
        time.sleep(0.5)
        self.assertTrue(self.view.state()["items"][0]["image"].startswith("image://qsimage/"))
        self.assertFalse((self.dir / "cs/notification-images").exists())

    def test_replace_id_updates_the_same_item(self):
        self.serving()
        first = self.bus.send("-p", "before", "Synthetic body")
        self.bus.send("other", "Synthetic body")
        before = self.items(2)[0]
        self.bus.send("-r", first, "-u", "critical", "after", "Synthetic body")
        items = self.items(2, lambda items: items[-1]["summary"] == "after")
        self.assertEqual([(i["summary"], i["urgency"]) for i in items], [("other", "normal"), ("after", "critical")])
        self.assertEqual(items[-1]["id"], before["id"])

    def test_closing_from_either_side(self):
        view = self.serving()
        closed_by_sender = self.notify("retracted")
        self.bus.send("dismissed here", "Synthetic body")
        ours = self.items(2)[1]
        self.bus.call("CloseNotification", str(closed_by_sender))
        self.assertEqual([i["summary"] for i in self.items(1)], ["dismissed here"])
        view.ipc("dismiss", ours["id"])
        self.items(0)

    def test_do_not_disturb_keeps_the_inbox_and_turns_away_what_only_passes(self):
        view = self.serving()
        view.ipc("dnd", "true")
        self.assertTrue(view.wait_for(lambda s: s["dnd"])["dnd"])
        self.bus.send("-e", "passing", "Synthetic body")
        self.bus.send("-e", "-u", "critical", "-t", "5000", "urgent passing", "Synthetic body")
        self.bus.send("kept", "Synthetic body")
        self.assertEqual([i["summary"] for i in self.items(2)], ["urgent passing", "kept"])
        self.assertEqual(self.view.state()["unread"], 2)
        view.ipc("markAllRead")
        self.assertEqual(view.wait_for(lambda s: s["unread"] == 0)["unread"], 0)


class LifetimeTests(Base):
    def test_items_outlive_the_view_but_not_their_actions(self):
        view = self.serving()
        self.background(self.bus.send("-A", "open=Open", "survivor", "Synthetic body", wait=False))
        old = self.items(1)[0]
        self.assertTrue(old["live"])
        gone = view.process.pid
        view.kill()
        view.attach(self.core, after=gone)   # the core restarts its resident view
        self.serving()
        kept = self.items(1)[0]
        self.assertEqual((kept["id"], kept["summary"], kept["live"]), (old["id"], "survivor", False))
        self.bus.send("newcomer", "Synthetic body")
        items = self.items(2)
        self.assertEqual(len({i["id"] for i in items}), 2)   # the new server's ids do not collide with the old
        view.ipc("dismiss", kept["id"])                      # no live notification: the Inbox drops it itself
        self.assertEqual([i["summary"] for i in self.items(1)], ["newcomer"])

    def test_items_outlive_the_core(self):
        self.serving()
        self.bus.send("survivor", "Synthetic body")
        old = self.items(1)[0]
        self.core.stop()
        self.start_core()
        self.serving()
        self.assertEqual([(i["id"], i["summary"], i["live"]) for i in self.items(1)], [(old["id"], "survivor", False)])

    @unittest.skipUnless(have_dbus_python(), "needs dbus-python")
    def test_waits_behind_another_server_then_takes_over(self):
        (self.dir / "foreign.py").write_text(FOREIGN_SERVER)
        foreign = self.background(subprocess.Popen([sys.executable, "-I", str(self.dir / "foreign.py")], env=self.bus.env,
                                                   stdout=subprocess.PIPE, text=True))
        self.assertEqual(foreign.stdout.readline().strip(), "ready")
        view = self.start_core()
        state = view.wait_for(lambda s: s["available"])
        self.assertEqual((state["available"], state["source"]), (True, "mirror"))
        time.sleep(0.3)   # let busctl install its matches
        self.notify("to the other server")   # the stand-in answers Notify only, which notify-send finds too little
        mirrored = self.items(1)[0]
        self.assertEqual((mirrored["id"], mirrored["live"]), ("42", False))
        foreign.kill()
        state = view.wait_for(lambda s: s["source"] == "server", timeout=10)
        self.assertEqual((state["source"], state["items"]), ("server", []))   # the other server's items went with it
        self.bus.send("to ours", "Synthetic body")
        self.assertEqual([(i["summary"], i["live"]) for i in self.items(1)], [("to ours", True)])


if __name__ == "__main__":
    unittest.main()
