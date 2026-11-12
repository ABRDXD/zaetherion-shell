"""DmsAdapter under Quickshell offscreen against the stand-in DMS (docs/DMS_ADAPTER.md §9.5).

Three groups: the contract (properties equal §4's mapping, one toggle per real change, errors change nothing, an
unknown network sends nothing), the leases (the subscription list follows the feeds), and restarts (DMS dying and
returning). The stand-in is a subprocess in a private folder; no real DMS is contacted and nothing is actuated.
Replies to action calls are synthetic, written here with obviously fake values."""
import json
from pathlib import Path
import shutil
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import dmstest  # noqa: E402

FIXTURE = json.loads(dmstest.FIXTURE.read_text())
NETWORK = next(e["result"]["data"] for e in FIXTURE["events"] if e["result"]["service"] == "network")
TOGGLE = "network.wifi.toggle"
SCAN = "network.wifi.scan"
CONNECT = "network.wifi.connect"


def network_event(**changes):
    return {"service": "network", "data": dict(NETWORK, **changes)}


class Base(unittest.TestCase):
    def setUp(self):
        if not shutil.which("qs"):
            self.skipTest("Quickshell is not installed")
        self.tmp = dmstest.private_dir()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.stands = []
        self.harness = None

    def tearDown(self):
        if self.harness:
            self.harness.stop()
        for stand in self.stands:
            stand.stop()

    def stand(self, name="dms-1.sock", script=None):
        stand = dmstest.Stand(self.dir, name, script)
        self.stands.append(stand)
        return stand

    def start(self, script=None, harness="AdapterHarness.qml"):
        stand = self.stand(script=script)
        self.harness = dmstest.Harness(stand.path, self.dir, harness)
        return stand, self.harness

    def ready(self, harness):
        state = harness.wait_for(lambda s: s.get("available"))
        self.assertTrue(state["available"], harness.output()[-1500:])
        return state

    def settle(self, seconds=0.4):
        time.sleep(seconds)

    def wait_methods(self, stand, method, count, timeout=4):
        deadline = time.time() + timeout
        while time.time() < deadline and stand.methods().count(method) < count:
            time.sleep(0.05)
        return stand.methods().count(method)


class Contract(Base):
    def test_properties_equal_the_mapping_of_the_snapshot(self):
        stand, harness = self.start({"replies": {SCAN: {"result": {}}}})
        state = self.ready(harness)
        wired, wireless = NETWORK["ethernetConnected"] is True, NETWORK["wifiConnected"] is True
        kind = "ethernet" if wired else "wifi" if wireless else "none"
        self.assertEqual((state["kind"], state["connected"], state["wifiEnabled"]), (kind, kind != "none", NETWORK["wifiEnabled"]))
        self.assertEqual(state["name"], {"wifi": NETWORK["wifiSSID"], "ethernet": NETWORK["ethernetDevice"], "none": ""}[kind])
        self.assertEqual((state["ipAddress"], state["networks"]), ("", []))        # no lease yet
        harness.ipc("acquire", "details")
        state = harness.wait_for(lambda s: s["ipAddress"] != "")
        self.assertEqual(state["ipAddress"], NETWORK["wifiIP"] if kind == "wifi" else NETWORK["ethernetIP"])
        harness.ipc("acquire", "scan")
        state = harness.wait_for(lambda s: s["networks"] != [])
        listed = [n["ssid"] for n in NETWORK["wifiNetworks"] if n["ssid"] and not n["outOfRange"]]
        self.assertEqual([n["ssid"] for n in state["networks"]], list(dict.fromkeys(listed)))
        harness.ipc("release", "details")
        harness.ipc("release", "scan")
        state = harness.wait_for(lambda s: s["ipAddress"] == "" and s["networks"] == [])
        self.assertEqual((state["ipAddress"], state["networks"]), ("", []))
        self.assertEqual(state["name2"], "dms")

    def test_one_toggle_per_real_change_none_for_a_repeat_and_a_stale_answer_gets_one_more(self):
        off = network_event(wifiEnabled=False)
        stand, harness = self.start({"replies": {TOGGLE: {"result": {"enabled": False}}}, "after": {TOGGLE: [off]}})
        self.ready(harness)
        harness.ipc("wifi", "false")
        state = harness.wait_for(lambda s: not s["wifiEnabled"])
        self.assertFalse(state["wifiEnabled"])
        self.assertEqual(self.wait_methods(stand, TOGGLE, 1), 1)
        harness.ipc("wifi", "false")                                               # a repeat: nothing
        self.settle()
        self.assertEqual(stand.methods().count(TOGGLE), 1)
        harness.ipc("wifi", "true")                                                # the stand-in answers "off" again
        self.assertEqual(self.wait_methods(stand, TOGGLE, 3), 3)                   # one flip, one more, then it gives up
        self.settle(0.6)
        self.assertEqual(stand.methods().count(TOGGLE), 3)
        self.assertFalse(harness.state()["wifiEnabled"])

    def test_a_failed_command_leaves_the_property_as_it_was(self):
        stand, harness = self.start({"replies": {TOGGLE: {"error": "synthetic failure"}, CONNECT: {"error": "synthetic failure"}}})
        self.ready(harness)
        harness.ipc("wifi", "false")
        self.assertEqual(self.wait_methods(stand, TOGGLE, 1), 1)
        self.settle()
        state = harness.state()
        self.assertTrue(state["wifiEnabled"])
        self.assertEqual(state["kind"], "wifi" if NETWORK["wifiConnected"] else state["kind"])
        self.assertIn("dms: network.wifi.toggle failed: synthetic failure", harness.output())
        # and the next click may try again
        harness.ipc("wifi", "false")
        self.assertEqual(self.wait_methods(stand, TOGGLE, 2), 2)

    def test_a_request_that_gets_no_answer_times_out_without_changing_anything(self):
        stand, harness = self.start({"silent": ["x.slow"]})
        before = self.ready(harness)
        harness.ipc("call", "x.slow")
        deadline = time.time() + 5
        while time.time() < deadline and json.loads(harness.ipc("results")) == []:
            time.sleep(0.1)
        results = json.loads(harness.ipc("results"))
        self.assertEqual([(r["method"], r["error"]) for r in results], [("x.slow", "timeout")])
        after = harness.state()
        for key in ("wifiEnabled", "kind", "name", "available"):
            self.assertEqual(after[key], before[key])

    def test_a_saved_network_connects_and_an_unknown_one_sends_nothing(self):
        stand, harness = self.start({"replies": {CONNECT: {"result": {}}}})
        self.ready(harness)
        saved = next(n["ssid"] for n in NETWORK["savedWifiNetworks"] if not n["connected"])
        harness.ipc("connect", saved)
        self.assertEqual(self.wait_methods(stand, CONNECT, 1), 1)
        request = next(r for r in stand.requests() if r.get("method") == CONNECT)
        self.assertEqual(request["params"], {"ssid": saved, "interactive": False})
        harness.ipc("connect", NETWORK["wifiSSID"])                                # already on it: nothing
        harness.ipc("connect", "never-seen-network")                               # unknown: hands over, sends nothing
        self.settle()
        self.assertEqual(stand.methods().count(CONNECT), 1)
        self.assertEqual(harness.state()["unknown"], ["never-seen-network"])

    def test_nothing_is_sent_while_offline(self):
        stand, harness = self.start()
        self.ready(harness)
        harness.ipc("setPath", self.dir.as_posix() + "/no-such.sock")
        state = harness.wait_for(lambda s: not s["available"])
        self.assertEqual((state["phase"] in ("connecting", "down"), state["available"], state["wifiEnabled"], state["connected"],
                          state["kind"], state["name"], state["networks"]), (True, False, False, False, "none", "", []))
        sent = len(stand.requests())
        harness.ipc("wifi", "false")
        harness.ipc("connect", "anything")
        harness.ipc("acquire", "scan")
        self.settle()
        self.assertEqual(len(stand.requests()), sent)
        self.assertEqual(harness.state()["unknown"], [])

    def test_no_socket_path_is_a_named_problem(self):
        stand, harness = self.start()
        self.ready(harness)
        harness.ipc("setPath", "")
        state = harness.wait_for(lambda s: s["problem"] == "no-socket")
        self.assertEqual((state["phase"], state["problem"], state["available"]), ("down", "no-socket", False))

    def with_version(self, api):
        fixture = json.loads(json.dumps(FIXTURE))
        fixture["greeting"]["apiVersion"] = api
        for event in fixture["events"]:                       # DMS repeats the version in its `server` event
            if event["result"]["service"] == "server":
                event["result"]["data"]["apiVersion"] = api
        path = self.dir / f"v{api}.json"
        path.write_text(json.dumps(fixture))
        stand = dmstest.Stand(self.dir, "dms-1.sock", None, path)
        self.stands.append(stand)
        self.harness = dmstest.Harness(stand.path, self.dir)
        return stand, self.harness

    def test_an_old_dms_switches_every_domain_off(self):
        stand, harness = self.with_version(37)
        state = harness.wait_for(lambda s: s["problem"] == "too-old")
        self.assertEqual((state["phase"], state["problem"], state["available"]), ("unsupported", "too-old", False))
        self.settle()
        self.assertEqual(stand.subscriptions(), [])

    def test_a_newer_dms_works_and_is_marked_untested(self):
        stand, harness = self.with_version(39)
        state = self.ready(harness)
        self.assertEqual((state["untested"], state["apiVersion"], state["subscribed"]), (True, 39, ["network"]))


class Composition(Base):
    def test_the_adapter_fills_its_domains_with_the_right_implementations(self):
        stand, harness = self.start()
        self.ready(harness)
        got = json.loads(harness.ipc("domains"))
        time.sleep(0.5)                                                            # deferred domains are created by URL
        got = json.loads(harness.ipc("domains"))
        expected = {"media": "QuickshellMedia", "audio": "QuickshellAudio", "network": "DmsNetwork",
                    "workspaces": "HyprlandWorkspaces", "power": "DmsPower",
                    "tray": "QuickshellTray", "keybinds": "HyprlandKeybinds", "lyrics": "LyricsSource",
                    "clipboard": "CliphistClipboard", "system": "LinuxSystem"}
        for domain, kind in expected.items():
            self.assertTrue(got[domain].startswith(kind), f"{domain}: {got[domain]}")
        self.assertTrue(got["powerAvailable"] and got["trayAvailable"] and got["mediaAvailable"])
        self.assertEqual(got["trayItems"], 0)                                      # no tray host in the offscreen run
        output = harness.output()
        for bad in ("ReferenceError:", "TypeError:", "Cannot assign", "Unable to assign", "is not a type", "Binding loop", "dms: "):
            self.assertNotIn(bad, output, output[-2500:])


class Leases(Base):
    def test_the_list_is_network_alone_with_no_view_lease(self):
        stand, harness = self.start()
        state = self.ready(harness)
        self.assertEqual(state["subscribed"], ["network"])
        self.assertEqual(stand.subscriptions(), [["network"]])
        self.assertNotIn(None, stand.subscriptions())

    def test_details_and_scan_gate_their_properties(self):
        stand, harness = self.start({"replies": {SCAN: {"result": {}}}})
        self.ready(harness)
        self.assertEqual(harness.state()["ipAddress"], "")
        harness.ipc("acquire", "details")
        self.assertNotEqual(harness.wait_for(lambda s: s["ipAddress"] != "")["ipAddress"], "")
        harness.ipc("release", "details")
        self.assertEqual(harness.wait_for(lambda s: s["ipAddress"] == "")["ipAddress"], "")
        self.assertEqual(stand.methods().count(SCAN), 0)                             # details never scans

    def test_one_scan_per_acquire(self):
        stand, harness = self.start({"replies": {SCAN: {"result": {}}}})
        self.ready(harness)
        harness.ipc("acquire", "scan")
        self.assertEqual(self.wait_methods(stand, SCAN, 1), 1)
        harness.ipc("acquire", "scan")                                             # same owner again: no new edge
        self.settle()
        self.assertEqual(stand.methods().count(SCAN), 1)
        harness.ipc("release", "scan")
        self.settle()
        harness.ipc("acquire", "scan")                                             # a new acquire is a new edge
        self.assertEqual(self.wait_methods(stand, SCAN, 2), 2)
        self.settle(0.5)
        self.assertEqual(stand.methods().count(SCAN), 2)

    def test_a_test_feed_grows_the_list_and_shrinks_it_again(self):
        stand, harness = self.start()
        self.ready(harness)
        harness.ipc("extra", "true")
        state = harness.wait_for(lambda s: s["subscribed"] == ["brightness", "network"] and s["extra"] and s["extra"]["hasData"])
        self.assertEqual(state["subscribed"], ["brightness", "network"])
        self.assertTrue(state["extra"]["hasData"])
        harness.ipc("extra", "false")                                              # release by destruction
        state = harness.wait_for(lambda s: s["subscribed"] == ["network"])
        self.assertEqual(state["subscribed"], ["network"])
        self.assertEqual(stand.subscriptions(), [["network"], ["brightness", "network"], ["network"]])

    def test_a_feed_for_a_capability_the_dms_lacks_never_dials(self):
        fixture = json.loads(json.dumps(FIXTURE))
        fixture["greeting"]["capabilities"].remove("brightness")
        for event in fixture["events"]:
            if event["result"]["service"] == "server":
                event["result"]["data"]["capabilities"].remove("brightness")
        path = self.dir / "nobright.json"
        path.write_text(json.dumps(fixture))
        stand = dmstest.Stand(self.dir, "dms-1.sock", None, path)
        self.stands.append(stand)
        self.harness = dmstest.Harness(stand.path, self.dir)
        self.ready(self.harness)
        self.harness.ipc("extra", "true")
        self.settle(0.6)
        state = self.harness.state()
        self.assertEqual((state["subscribed"], state["extra"]["usable"]), (["network"], False))
        self.assertEqual(stand.subscriptions(), [["network"]])

    def test_with_no_feeds_the_event_connection_is_closed(self):
        stand, harness = self.start(harness="LinkHarness.qml")
        state = harness.wait_for(lambda s: s["phase"] == "ready")
        self.assertEqual((state["events"], state["subscribed"]), ("closed", []))
        self.assertEqual(stand.subscriptions(), [])
        harness.ipc("feed", "brightness", "true")
        state = harness.wait_for(lambda s: s["events"] == "open")
        self.assertEqual(state["subscribed"], ["brightness"])
        harness.ipc("want", "brightness", "false")                                 # unwanted: the same as gone
        state = harness.wait_for(lambda s: s["events"] == "closed")
        self.assertEqual((state["events"], state["subscribed"]), ("closed", []))
        harness.ipc("want", "brightness", "true")
        harness.wait_for(lambda s: s["events"] == "open")
        harness.ipc("feed", "brightness", "false")
        state = harness.wait_for(lambda s: s["events"] == "closed")
        self.assertEqual(state["events"], "closed")
        closes = [r for r in stand.requests() if r["event"] == "close"]
        self.assertGreaterEqual(len(closes), 2)
        self.assertEqual(stand.subscriptions(), [["brightness"], ["brightness"]])


class Restart(Base):
    def test_sigkill_goes_offline_with_defaults_and_a_new_path_brings_it_back(self):
        script = {"silent": ["x.slow"], "replies": {SCAN: {"result": {}}}}
        first, harness = self.start(script)
        self.ready(harness)
        harness.ipc("acquire", "scan")
        harness.wait_for(lambda s: s["networks"] != [])
        harness.ipc("call", "x.slow")                                              # in flight when DMS dies
        first.kill()
        state = harness.wait_for(lambda s: not s["available"])
        self.assertEqual((state["available"], state["wifiEnabled"], state["connected"], state["kind"], state["name"], state["networks"]),
                         (False, False, False, "none", "", []))
        results = json.loads(harness.ipc("results"))
        self.assertEqual([(r["method"], r["error"]) for r in results], [("x.slow", "offline")])
        second = self.stand("dms-2.sock", script)
        started = time.time()
        harness.ipc("setPath", second.path)
        state = harness.wait_for(lambda s: s["available"] and s["networks"] != [], timeout=5)
        self.assertTrue(state["available"], harness.output()[-1500:])
        self.assertLess(time.time() - started, 5)
        self.assertEqual(state["subscribed"], ["network"])
        self.assertEqual(second.subscriptions(), [["network"]])
        self.assertEqual(self.wait_methods(second, SCAN, 1), 1)                    # the held scan is issued again
        self.assertEqual(first.methods().count(SCAN), 1)

    def test_a_dms_that_returns_on_the_same_path_is_found_by_the_backoff(self):
        first, harness = self.start({"replies": {SCAN: {"result": {}}}})
        self.ready(harness)
        first.kill()
        state = harness.wait_for(lambda s: not s["available"])
        self.assertEqual(state["phase"] in ("down", "connecting"), True)
        started = time.time()
        again = self.stand("dms-1.sock", {"replies": {SCAN: {"result": {}}}})
        state = harness.wait_for(lambda s: s["available"], timeout=5)
        self.assertTrue(state["available"], harness.output()[-1500:])
        self.assertLess(time.time() - started, 3)
        self.assertEqual(again.subscriptions(), [["network"]])


if __name__ == "__main__":
    unittest.main()
