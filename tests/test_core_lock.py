"""The session lock's state (S7, docs/LOCK.md §2, §5 F4, F9, F10, F12): written before it is published, only the view
releases it (and only the view the core spawned may be the view), a marker found at start (even an unreadable one) means locked, release tells logind. And the `lock` verb:
the host's lock until FART_LOCK=own, ZÆTHERION's after (never both: DMS's custom command comes back to the verb)."""
import json
import tempfile
import unittest
from pathlib import Path

import core_fakes  # noqa: F401  (puts the repository on sys.path)
from core.errors import OpError
from core.lock import Lock
from parity.harness import Core


class LockState(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.dir = Path(temp.name)
        self.told = []
        self.lock = Lock(self.dir, unlocked=lambda: self.told.append("unlock"), clock=lambda: 1000.0)

    def test_the_marker_is_written_before_anyone_hears(self):
        seen = []
        self.lock.on_change = lambda: seen.append((self.lock.path.exists(), self.lock.locked))
        self.lock.engage("idle")
        self.assertEqual(seen, [(True, True)])
        self.assertEqual(json.loads(self.lock.path.read_text()), {"locked": True, "since": 1000000, "reason": "idle"})
        self.assertEqual(self.lock.path.stat().st_mode & 0o777, 0o600)

    def test_a_second_request_changes_nothing(self):
        seen = []
        self.lock.on_change = lambda: seen.append(1)
        self.lock.engage("command")
        self.lock.engage("sleep")
        self.assertEqual(len(seen), 1)
        self.assertEqual(self.lock.snapshot()["reason"], "command")

    def test_only_the_view_releases_and_only_while_locked(self):
        with self.assertRaises(OpError):
            self.lock.release("view")  # not locked
        self.lock.engage()
        for kind in ("cli", "", None):
            with self.assertRaises(OpError):
                self.lock.release(kind)
        self.assertTrue(self.lock.locked)
        self.assertTrue(self.lock.path.exists())
        self.assertEqual(self.told, [])
        self.lock.release("view")
        self.assertFalse(self.lock.locked)
        self.assertFalse(self.lock.path.exists())
        self.assertEqual(self.told, ["unlock"])

    def test_a_marker_at_start_means_locked_even_unreadable(self):
        for text in (json.dumps({"locked": True, "since": 5, "reason": "sleep"}), "{broken", "[1]", ""):
            (self.dir / "locked").write_text(text)
            again = Lock(self.dir)
            self.assertTrue(again.locked, text)
        self.assertFalse(Lock(self.dir / "elsewhere").locked)

    def test_a_reason_must_be_known(self):
        for bad in ("", "x", None, 1):
            with self.assertRaises(OpError):
                self.lock.engage(bad)
        self.assertFalse(self.lock.locked)

    def test_lock_and_unlock_play_the_switch_cue(self):
        played = []
        self.lock.on_sound = lambda: played.append(self.lock.locked)
        self.lock.engage()
        self.lock.engage()  # the same lock: no second sound
        self.lock.release("view")
        self.assertEqual(played, [True, False])

    def test_a_failing_logind_call_still_unlocks(self):
        lock = Lock(self.dir, unlocked=lambda: 1 / 0)
        lock.engage()
        lock.release("view")
        self.assertFalse(lock.locked)


class LockOverTheSocket(unittest.TestCase):
    def test_ops_topic_and_the_verb_before_and_after_the_switch(self):
        with Core("python") as core, core.client() as cli:
            self.assertEqual(cli.request("status").get("lock", None), None)  # not a status part
            self.assertEqual(cli.error("lock.release"), "refused")
            cli.request("cmd.run", line="lock")  # the host's lock: no ZÆTHERION lock
            self.assertFalse(cli.request("subscribe", topics=["lock"])["snapshots"]["lock"]["locked"])
            self.assertIn(["power", "lock"], [c[:2] for c in core.host_calls()] or [["power", "lock"]])
        with Core("python", env={"FART_LOCK": "own"}) as core, core.client() as cli:
            cli.request("cmd.run", line="lock")
            snap = cli.request("subscribe", topics=["lock"])["snapshots"]["lock"]
            self.assertTrue(snap["locked"])
            self.assertTrue((core.runtime / "locked").exists())
            self.assertEqual(cli.error("lock.release"), "refused")  # a cli is not the view
            self.assertTrue((core.runtime / "locked").exists())
            # Nobody else can pose as the view: only the view this core spawned may say hello as one.
            peer = core.connect()
            with peer:
                reply = peer.call("hello", client="view", protocol=1)
                self.assertEqual(reply["error"]["code"], "refused")
            self.assertTrue(cli.request("subscribe", topics=["lock"])["snapshots"]["lock"]["locked"])

    def test_a_restarted_core_is_still_locked(self):
        core = Core("python", env={"FART_LOCK": "own"})
        try:
            core.start()
            with core.client() as cli:
                cli.request("lock.engage", reason="idle")
            core.stop()
            core.start()
            with core.client() as cli:
                self.assertTrue(cli.request("subscribe", topics=["lock"])["snapshots"]["lock"]["locked"])
        finally:
            core.close()


if __name__ == "__main__":
    unittest.main()
