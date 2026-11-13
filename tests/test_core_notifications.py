"""The Inbox, fed by the mirror (busctl JSON lines written by hand) and by our own server's operations. Fake
contents only."""
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest

from core_fakes import fakes
from core.errors import OpError
from core.notification_mirror import SERVICE, Mirror
from core.notifications import CONTRACT_FIELDS, KEEP, TTL, Inbox

OWNER = ":1.40"


def notify(sender, cookie, app="Mail", summary="Hello", hints=None, actions=()):
    return {"type": "method_call", "cookie": cookie, "sender": sender, "destination": SERVICE, "member": "Notify",
            "payload": {"type": "susssasa{sv}i", "data": [app, 0, "", summary, "body", list(actions), hints or {}, 5000]}}


def reply(destination, cookie, nid, sender=OWNER):
    return {"type": "method_return", "cookie": 99, "reply_cookie": cookie, "sender": sender, "destination": destination,
            "member": None, "payload": {"type": "u", "data": [nid]}}


def closed(nid, sender=OWNER):
    return {"type": "signal", "sender": sender, "member": "NotificationClosed", "payload": {"type": "uu", "data": [nid, 2]}}


def owner_changed(new):
    return {"type": "signal", "sender": "org.freedesktop.DBus", "member": "NameOwnerChanged",
            "payload": {"type": "sss", "data": [SERVICE, OWNER, new]}}


class InboxCase(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.state = Path(temp.name)
        self.clock, self.scheduler, _, _ = fakes()
        self.commands = []

    def mirror(self, owner=OWNER, bus="bus-a"):
        """A fresh core: the Inbox reloaded from disk, with the mirror listening."""
        self.inbox = Inbox(self.clock, self.scheduler, self.state)
        mirror = Mirror(self.inbox, self.commands.append)
        mirror.started(owner, bus)
        return mirror

    def on_disk(self):
        return json.loads((self.state / "notifications.json").read_text())["items"]

    def send(self, mirror, cookie, nid, **fields):
        mirror.feed(notify(":1.9", cookie, **fields))
        mirror.feed(reply(":1.9", cookie, nid, sender=mirror.owner))


class MirrorTests(InboxCase):
    def test_call_and_return_make_an_item_with_contract_fields(self):
        mirror = self.mirror()
        self.send(mirror, 5, 17, hints={"urgency": {"type": "y", "data": 2}}, actions=["default", "Open"])
        snap = self.inbox.snapshot()
        self.assertEqual(snap["unread"], 1)
        item = snap["items"][0]
        self.assertEqual(set(item), set(CONTRACT_FIELDS))
        self.assertEqual((item["id"], item["urgency"], item["actions"], item["hasActions"], item["live"]),
                         ("17", "critical", [{"id": "default", "label": "Open"}], True, False))

    def test_unpaired_or_foreign_returns_are_ignored(self):
        mirror = self.mirror()
        mirror.feed(reply(":1.9", 5, 17))
        mirror.feed(notify(":1.9", 6))
        mirror.feed(reply(":1.9", 6, 18, sender=":1.77"))
        self.assertEqual(self.inbox.snapshot()["items"], [])

    def test_transient_is_skipped_and_fields_are_capped(self):
        mirror = self.mirror()
        self.send(mirror, 1, 1, hints={"transient": {"type": "b", "data": True}})
        self.send(mirror, 2, 2, app="", summary="s" * 900)
        items = self.inbox.snapshot()["items"]
        self.assertEqual([(i["id"], i["appName"], len(i["summary"])) for i in items], [("2", "System", 512)])

    def test_close_removes_and_owner_change_clears(self):
        mirror = self.mirror()
        self.send(mirror, 1, 1)
        self.send(mirror, 2, 2)
        mirror.feed(closed(1))
        self.assertEqual([i["id"] for i in self.inbox.snapshot()["items"]], ["2"])
        mirror.feed(owner_changed(":1.50"))
        self.assertEqual(self.inbox.snapshot()["items"], [])
        self.assertEqual(mirror.owner, ":1.50")

    def test_cap_of_one_hundred_newest_last(self):
        mirror = self.mirror()
        for n in range(120):
            self.send(mirror, n, n)
        ids = [i["id"] for i in self.inbox.snapshot()["items"]]
        self.assertEqual((len(ids), ids[0], ids[-1]), (100, "20", "119"))

    def test_dismiss_asks_the_host_and_mark_all_read(self):
        mirror = self.mirror()
        self.send(mirror, 1, 7)
        self.inbox.dismiss("7")
        self.assertEqual(self.commands, [["busctl", "--user", "call", OWNER, "/org/freedesktop/Notifications", SERVICE,
                                          "CloseNotification", "u", "7"]])
        self.inbox.mark_all_read()
        self.assertEqual(self.inbox.snapshot()["unread"], 0)

    def test_persists_for_24_hours_and_only_for_the_same_owner(self):
        mirror = self.mirror()
        self.send(mirror, 1, 1)
        self.inbox.flush()
        self.assertEqual((self.state / "notifications.json").stat().st_mode & 0o777, 0o600)
        self.clock.advance(3600)
        self.mirror()
        self.assertEqual(len(self.inbox.snapshot()["items"]), 1)
        self.mirror(owner=":1.99")
        self.assertEqual(self.inbox.snapshot()["items"], [])
        restarted = self.mirror(owner=":1.99")
        self.send(restarted, 1, 1)
        self.clock.advance(24 * 3600 - 1)
        self.assertEqual(len(self.inbox.snapshot()["items"]), 1)
        self.clock.advance(2)
        self.assertEqual(self.inbox.snapshot()["items"], [])

    def test_reused_owner_and_id_on_another_bus(self):
        old = self.mirror()
        self.send(old, 1, 7)
        self.inbox.flush()
        new = self.mirror(bus="bus-b")
        self.assertEqual(self.inbox.snapshot()["items"], [])
        with self.assertRaises(OpError):
            self.inbox.dismiss("7")
        self.assertEqual(self.commands, [])
        self.send(new, 1, 7)
        self.inbox.flush()
        self.mirror(bus="bus-b")
        self.assertEqual([r["id"] for r in self.inbox.items], ["7"])

    def test_private_apps_are_shown_but_never_written(self):
        mirror = self.mirror()
        self.inbox.private_apps(["Signal"])
        self.send(mirror, 1, 1, app="signal", summary="secret")
        self.send(mirror, 2, 2, app="Mail")
        self.inbox.flush()
        self.assertEqual(len(self.inbox.snapshot()["items"]), 2)
        saved = (self.state / "notifications.json").read_text()
        self.assertNotIn("secret", saved)
        self.assertEqual([i["id"] for i in json.loads(saved)["items"]], ["2"])
        self.assertEqual(json.loads((self.state / "core.json").read_text())["privateApps"], ["Signal"])

    def test_changing_privacy_purges_disk_and_preserves_private_history(self):
        mirror = self.mirror()
        inbox = self.inbox
        self.send(mirror, 1, 1, app="Mail")
        inbox.flush()
        self.assertEqual(len(self.on_disk()), 1)
        inbox.private_apps(["MAIL"])
        self.assertEqual(self.on_disk(), [])
        mirror.feed(notify(":1.9", 2, app="mail"))
        inbox.private_apps([])
        mirror.feed(reply(":1.9", 2, 2))
        self.send(mirror, 3, 3, app="Mail")
        inbox.flush()
        self.assertEqual([r["id"] for r in inbox.snapshot()["items"]], ["1", "2", "3"])
        self.assertEqual([r["id"] for r in self.on_disk()], ["3"])

    def test_unavailable_hides_items(self):
        mirror = self.mirror()
        self.send(mirror, 1, 1)
        mirror.stopped()
        self.assertEqual(self.inbox.snapshot(),
                         {"available": False, "source": "mirror", "dnd": False, "items": [], "unread": 0})

    def test_urgency_low_normal_critical(self):
        mirror = self.mirror()
        for nid, level in enumerate((0, 1, 2, 9)):
            self.send(mirror, nid, nid, hints={"urgency": {"type": "y", "data": level}})
        self.assertEqual([i["urgency"] for i in self.inbox.snapshot()["items"]], ["low", "normal", "critical", "normal"])


class ServerTests(InboxCase):
    """Our own server in the view reports to the Inbox; `view` stands for its client connection."""

    def setUp(self):
        super().setUp()
        self.view = SimpleNamespace(pid=4242)
        self.mirror()
        self.inbox.serve(self.view)
        self.inbox.name_holder(self.view.pid)

    def ingest(self, id="s1-1", **fields):
        return self.inbox.ingest(self.view, id=id, **{"appName": "Mail", "summary": "Hello", **fields})

    def ids(self):
        return [i["id"] for i in self.inbox.snapshot()["items"]]

    def test_serving_replaces_the_mirror_and_keeps_stored_items(self):
        mirror = Mirror(self.inbox, self.commands.append)
        self.ingest()
        self.send(mirror, 1, 1)  # the monitor also sees calls to our own server
        snap = self.inbox.snapshot()
        self.assertEqual((snap["source"], self.ids()), ("server", ["s1-1"]))
        self.inbox.flush()
        self.mirror(owner=":1.99", bus="bus-b")
        self.assertEqual((self.inbox.snapshot()["source"], self.ids()), ("mirror", ["s1-1"]))

    def test_while_another_program_holds_the_name_the_mirror_goes_on(self):
        mirror = self.mirror()
        self.inbox.serve(self.view)
        self.inbox.name_holder(77)
        self.send(mirror, 1, 1)
        self.assertEqual((self.inbox.snapshot()["source"], self.ids()), ("mirror", ["1"]))

    def test_taking_the_name_drops_mirrored_items_and_doubles(self):
        mirror = self.mirror()
        self.inbox.serve(self.view)
        self.send(mirror, 1, 1)
        mirror.feed(owner_changed(":1.50"))
        self.assertEqual((self.ids(), self.inbox.snapshot()["source"]), ([], "mirror"))
        self.ingest("s1-1")
        self.send(mirror, 2, 1)  # seen by the monitor before the holder is known
        self.assertEqual(self.ids(), ["s1-1", "1"])
        self.inbox.name_holder(self.view.pid)
        self.assertEqual((self.ids(), self.inbox.snapshot()["source"]), (["s1-1"], "server"))

    def test_item_carries_actions_reply_images_and_timeout(self):
        self.ingest(urgency="low", actions=[{"id": "default", "label": "Open"}, {"id": "x", "label": "Y" * 500}],
                    reply="Reply", icon="mail-unread", image="/fixture/picture.png", timeout=3000)
        item = self.inbox.snapshot()["items"][0]
        self.assertEqual(set(item), set(CONTRACT_FIELDS))
        self.assertEqual((item["urgency"], item["reply"], item["icon"], item["image"], item["timeout"], item["live"]),
                         ("low", "Reply", "mail-unread", "/fixture/picture.png", 3000, True))
        self.assertEqual((item["actions"][0], len(item["actions"][1]["label"])), ({"id": "default", "label": "Open"}, 128))

    def test_bad_fields_fall_back(self):
        self.ingest(urgency="loud", actions="open", timeout=-5, body=7)
        item = self.inbox.snapshot()["items"][0]
        self.assertEqual((item["urgency"], item["actions"], item["hasActions"], item["timeout"], item["body"]),
                         ("normal", [], False, -1, ""))
        for bad in (None, "", 7, "x" * 65, "../s1-1", "s1 1"):
            with self.assertRaises(OpError):
                self.inbox.ingest(self.view, id=bad)

    def test_replace_id_updates_in_place_as_unread_and_newest(self):
        self.ingest("s1-1")
        self.ingest("s1-2")
        self.inbox.mark_all_read()
        self.clock.advance(5)
        self.ingest("s1-1", summary="Changed")
        items = self.inbox.snapshot()["items"]
        self.assertEqual([(i["id"], i["summary"], i["read"]) for i in items],
                         [("s1-2", "Hello", True), ("s1-1", "Changed", False)])
        self.assertGreater(items[1]["time"], items[0]["time"])

    def test_closed_and_dismiss_remove_without_a_host_call(self):
        self.ingest("s1-1")
        self.ingest("s1-2")
        self.inbox.closed(self.view, "s1-1")
        self.inbox.dismiss("s1-2")
        self.assertEqual((self.ids(), self.commands), ([], []))
        with self.assertRaises(OpError):
            self.inbox.dismiss("s1-2")

    def test_only_the_server_may_report(self):
        stranger = SimpleNamespace(pid=self.view.pid)
        for call in (lambda: self.inbox.ingest(stranger, id="s1-1"), lambda: self.inbox.closed(stranger, "s1-1"),
                     lambda: self.inbox.image(stranger, "s1-1")):
            with self.assertRaises(OpError) as raised:
                call()
            self.assertEqual(raised.exception.code, "not-serving")

    def test_a_lost_server_leaves_items_readable_but_not_live(self):
        self.ingest("s1-1", actions=[{"id": "default", "label": "Open"}])
        self.ingest("s1-2", transient=True)
        self.inbox.disconnected(SimpleNamespace(pid=self.view.pid))
        self.assertEqual(len(self.ids()), 2)
        self.inbox.disconnected(self.view)
        snap = self.inbox.snapshot()
        self.assertEqual((snap["source"], [(i["id"], i["live"]) for i in snap["items"]]), ("mirror", [("s1-1", False)]))

    def test_a_returning_server_names_what_it_still_holds(self):
        self.ingest("s1-1")
        self.ingest("s1-2")
        self.inbox.disconnected(self.view)
        self.inbox.serve(self.view, ids=["s1-2", "s1-9"])
        self.assertEqual([(i["id"], i["live"]) for i in self.inbox.snapshot()["items"]], [("s1-1", False), ("s1-2", True)])
        with self.assertRaises(OpError):
            self.inbox.serve(self.view, ids="s1-2")

    def test_kept_for_24_hours_across_a_restart_and_capped(self):
        for n in range(KEEP + 5):
            self.ingest(f"s1-{n}")
        self.inbox.flush()
        self.clock.advance(TTL - 1)
        self.mirror()
        self.assertEqual((len(self.ids()), self.ids()[0], self.inbox.items[0]["live"]), (KEEP, "s1-5", False))
        self.clock.advance(2)
        self.assertEqual(self.inbox.items, [])

    def test_transient_and_private_items_are_never_written(self):
        self.inbox.private_apps(["Signal"])
        self.assertEqual(self.ingest("s1-1", appName="signal", summary="secret")["imagePath"], "")
        self.assertEqual(self.ingest("s1-2", transient=True, summary="passing")["imagePath"], "")
        self.ingest("s1-3")
        self.inbox.flush()
        saved = (self.state / "notifications.json").read_text()
        self.assertEqual([i["id"] for i in json.loads(saved)["items"]], ["s1-3"])
        self.assertNotIn("secret", saved)
        self.assertNotIn("passing", saved)
        self.assertEqual(len(self.ids()), 3)

    def picture(self, id):
        path = Path(self.ingest(id)["imagePath"])
        path.write_bytes(b"fixture")
        self.inbox.image(self.view, id)
        return path

    def test_a_kept_image_lives_and_dies_with_its_item(self):
        path = self.picture("s1-1")
        self.assertEqual((path.parent, path.parent.stat().st_mode & 0o777), (self.state / "notification-images", 0o700))
        self.assertEqual(self.inbox.snapshot()["items"][0]["image"], str(path))
        self.inbox.flush()
        self.mirror()
        self.assertTrue(path.exists())  # a restart keeps it
        self.inbox.dismiss("s1-1")
        self.assertFalse(path.exists())

    def test_images_go_on_expiry_clear_and_privacy(self):
        expiring = self.picture("s1-1")
        self.clock.advance(TTL + 1)
        self.assertFalse(expiring.exists())
        cleared = self.picture("s1-2")
        self.inbox.clear()
        self.assertFalse(cleared.exists())
        hidden = self.picture("s1-3")
        self.inbox.private_apps(["Mail"])
        self.assertFalse(hidden.exists())
        self.assertEqual(self.inbox.snapshot()["items"][0]["image"], "")

    def test_an_image_is_refused_for_an_unwritten_or_missing_item(self):
        self.ingest("s1-1", transient=True)
        with self.assertRaises(OpError):
            self.inbox.image(self.view, "s1-1")
        self.ingest("s1-2")
        with self.assertRaises(OpError):
            self.inbox.image(self.view, "s1-2")  # nothing was written
        with self.assertRaises(OpError):
            self.inbox.image(self.view, "s1-404")

    def test_a_stray_file_in_the_image_folder_is_swept(self):
        path = self.picture("s1-1")
        stray = path.with_name("stray.png")
        stray.write_bytes(b"fixture")
        self.mirror()
        self.assertEqual((path.exists(), stray.exists()), (True, False))

    def test_what_is_heard(self):
        heard = []
        self.inbox.on_sound = heard.append
        self.ingest("s1-1", urgency="low")
        self.ingest("s1-2")
        self.ingest("s1-2", summary="Replaced")          # a replace-id is not a new arrival
        self.ingest("s1-3", silent=True)                 # the sender plays its own
        self.ingest("s1-4", urgency="critical")
        self.assertEqual(heard, ["normal", "critical"])
        self.inbox.set_dnd(True)
        self.ingest("s1-5")
        self.ingest("s1-6", urgency="critical")
        self.assertEqual(heard, ["normal", "critical", "critical"])
        self.send(Mirror(self.inbox, self.commands.append), 1, 1)   # the host's own server sounds for itself
        self.assertEqual(len(heard), 3)

    def test_do_not_disturb_is_kept_and_published(self):
        changes = []
        self.inbox.on_change = lambda: changes.append(self.inbox.dnd)
        self.assertEqual(self.inbox.set_dnd(True), {"dnd": True})
        self.inbox.set_dnd(True)
        self.assertEqual(changes, [True])
        self.mirror()
        self.assertEqual((self.inbox.snapshot()["dnd"], self.inbox.summary()["dnd"]), (True, True))
        with self.assertRaises(OpError):
            self.inbox.set_dnd("yes")
        self.inbox.private_apps(["Signal"])
        self.assertTrue(json.loads((self.state / "core.json").read_text())["dnd"])


if __name__ == "__main__":
    unittest.main()
