"""BusctlSource against a private session bus with a fake notification server; never the desktop's bus."""
import asyncio
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from core_fakes import fakes
from core.notifications import BusctlSource, Mirror
from core.track import Track

SERVER = '''
import dbus, dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = dbus.service.BusName("org.freedesktop.Notifications", bus)
class Server(dbus.service.Object):
    @dbus.service.method("org.freedesktop.Notifications", in_signature="susssasa{sv}i", out_signature="u")
    def Notify(self, app, replaces, icon, summary, body, actions, hints, timeout):
        return 42
    @dbus.service.method("org.freedesktop.Notifications", in_signature="u")
    def CloseNotification(self, nid):
        self.NotificationClosed(nid, 3)
    @dbus.service.signal("org.freedesktop.Notifications", signature="uu")
    def NotificationClosed(self, nid, reason):
        pass
Server(bus, "/org/freedesktop/Notifications")
print("ready", flush=True)
GLib.MainLoop().run()
'''

# A fake MPRIS player: already on the bus before the monitor starts, then it changes track on "next".
PLAYER = '''
import dbus, dbus.service, sys
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = dbus.service.BusName("org.mpris.MediaPlayer2.fixture.instance7", bus)
class Player(dbus.service.Object):
    @dbus.service.signal("org.freedesktop.DBus.Properties", signature="sa{sv}as")
    def PropertiesChanged(self, iface, changed, invalidated):
        pass
player = Player(bus, "/org/mpris/MediaPlayer2")
def next_track(source, condition):
    title = sys.stdin.readline().strip()
    md = dbus.Dictionary({"mpris:trackid": dbus.ObjectPath("/t/" + str(len(title))), "xesam:title": title,
                          "xesam:artist": dbus.Array(["Ana", "Bo"], signature="s")}, signature="sv")
    player.PropertiesChanged("org.mpris.MediaPlayer2.Player",
                             dbus.Dictionary({"Metadata": md, "PlaybackStatus": "Playing"}, signature="sv"),
                             dbus.Array([], signature="s"))
    return True
GLib.io_add_watch(sys.stdin, GLib.IO_IN, next_track)
print("ready", flush=True)
GLib.MainLoop().run()
'''


def have_dbus_python():
    return subprocess.run([sys.executable, "-c", "import dbus, gi"], capture_output=True).returncode == 0


@unittest.skipUnless(shutil.which("dbus-daemon") and shutil.which("busctl") and shutil.which("gdbus") and have_dbus_python(),
                     "needs dbus-daemon, busctl, gdbus and dbus-python")
class BusctlTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        base = Path(self.temp.name)
        daemon = subprocess.run(["dbus-daemon", "--session", "--fork", "--print-address=1", "--print-pid=1"],
                                capture_output=True, text=True, check=True)
        address, pid = daemon.stdout.split()
        self.addCleanup(os.kill, int(pid), 15)
        self.env_backup = os.environ.get("DBUS_SESSION_BUS_ADDRESS")
        os.environ["DBUS_SESSION_BUS_ADDRESS"] = address
        self.addCleanup(self.restore_env)
        (base / "server.py").write_text(SERVER)
        self.server = subprocess.Popen([sys.executable, "-I", str(base / "server.py")], stdout=subprocess.PIPE, text=True)
        self.addCleanup(self.server.kill)
        self.assertEqual(self.server.stdout.readline().strip(), "ready")
        self.clock, self.scheduler, _, host = fakes()
        self.commands = []
        self.mirror = Mirror(self.clock, self.scheduler, self.run_command, base)
        self.track = Track(self.clock)
        self.source = BusctlSource(self.mirror, self.track)
        (base / "player.py").write_text(PLAYER)
        self.player = subprocess.Popen([sys.executable, "-I", str(base / "player.py")], stdin=subprocess.PIPE,
                                       stdout=subprocess.PIPE, text=True)
        self.addCleanup(self.player.kill)
        self.assertEqual(self.player.stdout.readline().strip(), "ready")

    def restore_env(self):
        if self.env_backup is None:
            os.environ.pop("DBUS_SESSION_BUS_ADDRESS", None)
        else:
            os.environ["DBUS_SESSION_BUS_ADDRESS"] = self.env_backup

    def run_command(self, argv):
        self.commands.append(argv)
        subprocess.run(argv, capture_output=True, timeout=5)

    async def wait(self, condition):
        for _ in range(100):
            if condition():
                return True
            await asyncio.sleep(0.05)
        return False

    async def asyncTearDown(self):
        await self.source.stop()
        self.temp.cleanup()

    async def test_mirrors_a_notification_and_its_dismissal(self):
        self.source.start()
        self.assertTrue(await self.wait(lambda: self.mirror.available))
        await asyncio.sleep(0.2)  # let busctl install its matches
        await asyncio.to_thread(subprocess.run, [
            "gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path",
            "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "Fixture", "0", "",
            "summary", "body", "[]", '{"urgency": <byte 1>, "image-data": <(1,1,4,true,8,4,[byte 1,2,3,4])>}', "5000"],
            capture_output=True, timeout=5)
        self.assertTrue(await self.wait(lambda: self.mirror.snapshot()["items"]))
        item = self.mirror.snapshot()["items"][0]
        self.assertEqual((item["id"], item["appName"], item["summary"]), ("42", "Fixture", "summary"))
        await asyncio.to_thread(self.mirror.dismiss, "42")
        self.assertTrue(await self.wait(lambda: not self.mirror.snapshot()["items"]))

    async def test_a_running_players_track_change_reaches_the_track_watch(self):
        self.source.start()
        self.assertTrue(await self.wait(lambda: self.mirror.available))
        await asyncio.sleep(0.2)
        self.assertEqual([p.name for p in self.track.players.values()], ["fixture"])  # found at start
        self.player.stdin.write("Song A\n")
        self.player.stdin.flush()
        self.assertTrue(await self.wait(lambda: self.track.current is not None))
        snap = self.track.snapshot()
        self.assertEqual((snap["player"], snap["artist"], snap["title"]), ("fixture", "Ana, Bo", "Song A"))


if __name__ == "__main__":
    unittest.main()
