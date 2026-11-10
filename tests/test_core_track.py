"""The MPRIS track watch (core/track.py) on messages shaped as busctl monitor --json=short prints them,
and the core's rule for spawning the view for the track satellite. No bus, no player."""
import asyncio
from pathlib import Path
import tempfile
import unittest

import core_fakes
from core.app import Core
from core.guards import SessionGuard
from core.track import Track, player_name

BUS = "org.freedesktop.DBus"


def owner_changed(name, old, new):
    return {"type": "signal", "sender": BUS, "path": "/org/freedesktop/DBus", "interface": BUS,
            "member": "NameOwnerChanged", "payload": {"type": "sss", "data": [name, old, new]}}


def changed(sender, title=None, artist=None, trackid=None, status=None, iface="org.mpris.MediaPlayer2.Player"):
    props = {}
    if title is not None:
        md = {"xesam:title": {"type": "s", "data": title}}
        if artist is not None:
            md["xesam:artist"] = {"type": "as", "data": artist}
        if trackid is not None:
            md["mpris:trackid"] = {"type": "o", "data": trackid}
        props["Metadata"] = {"type": "a{sv}", "data": md}
    if status is not None:
        props["PlaybackStatus"] = {"type": "s", "data": status}
    return {"type": "signal", "sender": sender, "path": "/org/mpris/MediaPlayer2",
            "interface": "org.freedesktop.DBus.Properties", "member": "PropertiesChanged",
            "payload": {"type": "sa{sv}as", "data": [iface, props, []]}}


class Watch(unittest.TestCase):
    def setUp(self):
        self.clock, _, _, _ = core_fakes.fakes()
        self.track = Track(self.clock)
        self.tracks, self.changes = [], 0
        self.track.on_track = lambda: self.tracks.append(self.track.snapshot())
        self.track.on_change = lambda: setattr(self, "changes", self.changes + 1)

    def test_player_names(self):
        self.assertEqual(player_name("org.mpris.MediaPlayer2.chromium.instance1234"), "chromium")
        self.assertEqual(player_name("org.mpris.MediaPlayer2.spotify"), "spotify")

    def test_a_change_is_announced_once(self):
        self.track.started({":1.5": "org.mpris.MediaPlayer2.spotify"})
        self.track.feed(changed(":1.5", "Song A", ["Ana", "Bo"], "/t/1", "Playing"))
        self.assertEqual(self.tracks, [{"player": "spotify", "artist": "Ana, Bo", "title": "Song A",
                                        "at": round(self.clock.real * 1000)}])
        self.track.feed(changed(":1.5", "Song A", ["Ana", "Bo"], "/t/1"))  # art loaded: the same track again
        self.track.feed(changed(":1.5", status="Playing"))
        self.assertEqual(len(self.tracks), 1)
        self.clock.advance(200)
        self.track.feed(changed(":1.5", "Song B", ["Cy"], "/t/2"))
        self.assertEqual([t["title"] for t in self.tracks], ["Song A", "Song B"])
        self.assertEqual(self.changes, 2)

    def test_paused_metadata_waits_for_play(self):
        self.track.feed(owner_changed("org.mpris.MediaPlayer2.firefox.instance_1_9", "", ":1.9"))
        self.track.feed(changed(":1.9", "Video", None, None, "Paused"))
        self.assertEqual(self.tracks, [])
        self.track.feed(changed(":1.9", status="Playing"))
        self.assertEqual([(t["player"], t["title"], t["artist"]) for t in self.tracks], [("firefox", "Video", None)])

    def test_ignored_messages(self):
        self.track.feed(changed(":1.2", "Other", iface="org.mpris.MediaPlayer2"))  # not the Player interface
        self.track.feed(changed(":1.2", "  ", status="Playing"))  # no title
        self.track.feed({"type": "method_call", "member": "PropertiesChanged"})
        self.track.feed(owner_changed("org.freedesktop.Notifications", "", ":1.3"))
        self.assertEqual((self.tracks, self.track.players.keys() - {":1.2"}), ([], set()))
        self.assertEqual(self.track.snapshot(), {"player": None, "artist": None, "title": None, "at": None})

    def test_a_player_that_leaves_is_forgotten(self):
        self.track.feed(owner_changed("org.mpris.MediaPlayer2.mpv", "", ":1.4"))
        self.track.feed(owner_changed("org.mpris.MediaPlayer2.mpv", ":1.4", ""))
        self.assertEqual(self.track.players, {})
        self.track.feed(changed(":1.4", "Late", status="Playing"))  # unknown sender: named by its bus name
        self.assertEqual(self.tracks[-1]["player"], ":1.4")

    def test_long_titles_are_cut(self):
        self.track.feed(changed(":1.6", "x" * 1000, ["y" * 1000], status="Playing"))
        self.assertEqual((len(self.tracks[0]["title"]), len(self.tracks[0]["artist"])), (256, 256))


class Spawn(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.clock, scheduler, _, host = core_fakes.fakes()
        self.spawns = 0

        async def spawn():
            self.spawns += 1
            raise OSError("no view in this test")
        self.core = Core(self.clock, scheduler, host, Path(self.temp.name), spawn=spawn, guard_types=[SessionGuard])
        self.fullscreen = False
        self.core.fullscreen_focused = lambda: self.fullscreen
        self.n = 0

    async def play(self):
        self.n += 1
        self.core.track.feed(changed(":1.5", f"Song {self.n}", status="Playing"))
        for _ in range(5):
            await asyncio.sleep(0)

    async def test_spawns_the_absent_view_unless_quiet(self):
        with self.assertLogs("fart.core", "INFO"):
            await self.play()
        self.assertEqual(self.spawns, 1)
        self.fullscreen = True
        await self.play()
        self.fullscreen = False
        self.core.sessions.start("pyq", 3600)
        await self.play()
        self.core.sessions.end()
        self.core.view.state = "ready"  # alive: the view follows host.media itself
        await self.play()
        self.assertEqual(self.spawns, 1)
        self.assertEqual(self.core.track.snapshot()["title"], "Song 4")  # the topic still follows


if __name__ == "__main__":
    unittest.main()
