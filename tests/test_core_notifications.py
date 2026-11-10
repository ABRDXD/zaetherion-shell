"""The notification mirror fed with busctl JSON lines written by hand (fake contents only)."""
import json
from pathlib import Path
import tempfile
import unittest

from core_fakes import fakes
from core.errors import OpError
from core.notifications import SERVICE, Mirror

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


class MirrorTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.state = Path(temp.name)
        self.clock, self.scheduler, _, _ = fakes()
        self.commands = []

    def mirror(self, owner=OWNER, bus="bus-a"):
        mirror = Mirror(self.clock, self.scheduler, self.commands.append, self.state)
        mirror.started(owner, bus)
        return mirror

    def send(self, mirror, cookie, nid, **fields):
        mirror.feed(notify(":1.9", cookie, **fields))
        mirror.feed(reply(":1.9", cookie, nid, sender=mirror.owner))

    def test_call_and_return_make_an_item_with_contract_fields(self):
        mirror = self.mirror()
        self.send(mirror, 5, 17, hints={"urgency": {"type": "y", "data": 2}}, actions=["default", "Open"])
        snap = mirror.snapshot()
        self.assertEqual(snap["unread"], 1)
        item = snap["items"][0]
        self.assertEqual(set(item), {"id", "appName", "summary", "body", "time", "urgency", "read", "hasActions"})
        self.assertEqual((item["id"], item["urgency"], item["hasActions"]), ("17", "critical", True))

    def test_unpaired_or_foreign_returns_are_ignored(self):
        mirror = self.mirror()
        mirror.feed(reply(":1.9", 5, 17))
        mirror.feed(notify(":1.9", 6))
        mirror.feed(reply(":1.9", 6, 18, sender=":1.77"))
        self.assertEqual(mirror.snapshot()["items"], [])

    def test_transient_is_skipped_and_fields_are_capped(self):
        mirror = self.mirror()
        self.send(mirror, 1, 1, hints={"transient": {"type": "b", "data": True}})
        self.send(mirror, 2, 2, app="", summary="s" * 900)
        items = mirror.snapshot()["items"]
        self.assertEqual([(i["id"], i["appName"], len(i["summary"])) for i in items], [("2", "System", 512)])

    def test_close_removes_and_owner_change_clears(self):
        mirror = self.mirror()
        self.send(mirror, 1, 1)
        self.send(mirror, 2, 2)
        mirror.feed(closed(1))
        self.assertEqual([i["id"] for i in mirror.snapshot()["items"]], ["2"])
        mirror.feed(owner_changed(":1.50"))
        self.assertEqual(mirror.snapshot()["items"], [])
        self.assertEqual(mirror.owner, ":1.50")

    def test_cap_of_one_hundred_newest_last(self):
        mirror = self.mirror()
        for n in range(120):
            self.send(mirror, n, n)
        ids = [i["id"] for i in mirror.snapshot()["items"]]
        self.assertEqual((len(ids), ids[0], ids[-1]), (100, "20", "119"))

    def test_dismiss_asks_the_host_and_mark_all_read(self):
        mirror = self.mirror()
        self.send(mirror, 1, 7)
        mirror.dismiss("7")
        self.assertEqual(self.commands, [["busctl", "--user", "call", OWNER, "/org/freedesktop/Notifications", SERVICE,
                                          "CloseNotification", "u", "7"]])
        mirror.mark_all_read()
        self.assertEqual(mirror.snapshot()["unread"], 0)

    def test_persists_for_24_hours_and_only_for_the_same_owner(self):
        mirror = self.mirror()
        self.send(mirror, 1, 1)
        mirror.flush()
        self.assertEqual((self.state / "notifications.json").stat().st_mode & 0o777, 0o600)
        self.clock.advance(3600)
        self.assertEqual(len(self.mirror().snapshot()["items"]), 1)
        self.assertEqual(self.mirror(owner=":1.99").snapshot()["items"], [])
        restarted = self.mirror(owner=":1.99")
        self.send(restarted, 1, 1)
        self.clock.advance(24 * 3600 - 1)
        self.assertEqual(len(restarted.snapshot()["items"]), 1)
        self.clock.advance(2)
        self.assertEqual(restarted.snapshot()["items"], [])

    def test_reused_owner_and_id_on_another_bus(self):
        old = self.mirror()
        self.send(old, 1, 7)
        old.flush()
        new = self.mirror(bus="bus-b")
        self.assertEqual(new.snapshot()["items"], [])
        with self.assertRaises(OpError):
            new.dismiss("7")
        self.assertEqual(self.commands, [])
        self.send(new, 1, 7)
        new.flush()
        self.assertEqual([r["id"] for r in self.mirror(bus="bus-b").items], ["7"])

    def test_private_apps_are_shown_but_never_written(self):
        mirror = self.mirror()
        mirror.private_apps(["Signal"])
        self.send(mirror, 1, 1, app="signal", summary="secret")
        self.send(mirror, 2, 2, app="Mail")
        mirror.flush()
        self.assertEqual(len(mirror.snapshot()["items"]), 2)
        saved = (self.state / "notifications.json").read_text()
        self.assertNotIn("secret", saved)
        self.assertEqual([i["id"] for i in json.loads(saved)["items"]], ["2"])
        self.assertEqual(json.loads((self.state / "core.json").read_text())["privateApps"], ["Signal"])

    def test_changing_privacy_purges_disk_and_preserves_private_history(self):
        mirror = self.mirror()
        self.send(mirror, 1, 1, app="Mail")
        mirror.flush()
        self.assertEqual(len(self.mirror().items), 1)
        mirror.private_apps(["MAIL"])
        self.assertEqual(self.mirror().items, [])
        mirror.feed(notify(":1.9", 2, app="mail"))
        mirror.private_apps([])
        mirror.feed(reply(":1.9", 2, 2))
        self.send(mirror, 3, 3, app="Mail")
        mirror.flush()
        self.assertEqual([r["id"] for r in mirror.snapshot()["items"]], ["1", "2", "3"])
        self.assertEqual([r["id"] for r in self.mirror().items], ["3"])

    def test_unavailable_hides_items(self):
        mirror = self.mirror()
        self.send(mirror, 1, 1)
        mirror.stopped()
        self.assertEqual(mirror.snapshot(), {"available": False, "items": [], "unread": 0})


if __name__ == "__main__":
    unittest.main()
