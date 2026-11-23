"""S10: Wi-Fi, VPN and Bluetooth through DmsAdapter, offscreen, against the stand-in DMS (docs/NET_BT.md §3, §6).

Each flow is scripted in the stand-in: what DMS answers and which events it pushes after a method. No real DMS is
contacted, and no real radio is touched: the harness's system bus is a path that doesn't exist. Every reply, event,
name, token and secret below is synthetic and obviously fake."""
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
BT = json.loads((ROOT / "tests/fixtures/dms/bluetooth-synthetic.json").read_text())["state"]
SECRET = "fake-secret-7f3a91"          # must never reach the view's output
NEW = "<ssid-new>"
SAVED = NETWORK["savedWifiNetworks"][0]["ssid"]


def net_event(**changes):
    return {"service": "network", "data": dict(NETWORK, **changes)}


def connecting(ssid):
    return net_event(wifiConnected=False, isConnecting=True, connectingSSID=ssid, lastError="")


def joined(ssid):
    return net_event(wifiConnected=True, wifiSSID=ssid, wifiIP="192.0.2.1", isConnecting=False, lastError="")


def bt_event(**device_changes):
    """The synthetic Bluetooth state with some devices changed: {address: {field: value}}; None removes it."""
    devices = []
    for d in BT["devices"]:
        change = device_changes.get(d["address"], {})
        if change is not None:
            devices.append(dict(d, **change))
    return {"service": "bluetooth", "data": dict(BT, devices=devices)}


def credentials(reason="", token="tok-fake-net-1", ssid=NEW):
    return {"service": "network.credentials", "data": {"token": token, "ssid": ssid, "setting": "802-11-wireless-security",
                                                       "fields": ["psk"], "reason": reason}}


def pairing(kind, address="<address-d5>", token="tok-fake-bt-1"):
    return {"service": "bluetooth.pairing", "data": {"token": token, "requestType": kind, "passkey": 123456,
                                                     "deviceName": "Fake Phone", "deviceAddr": address}}


OK = {"result": {"success": True, "message": "fake"}}


class Base(unittest.TestCase):
    fixture_bt = False

    def setUp(self):
        if not shutil.which("qs"):
            self.skipTest("Quickshell is not installed")
        self.tmp = dmstest.private_dir()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.fixture = dmstest.FIXTURE
        if self.fixture_bt:
            data = json.loads(dmstest.FIXTURE.read_text())
            for e in data["events"]:
                if e["result"]["service"] == "bluetooth":
                    e["result"]["data"] = BT
            data["replies"]["bluetooth.getState"] = {"id": 0, "result": BT}
            self.fixture = self.dir / "fixture.json"
            self.fixture.write_text(json.dumps(data))
        self.stands, self.harness = [], None

    def tearDown(self):
        if self.harness:
            self.harness.stop()
        for stand in self.stands:
            stand.stop()

    def stand(self, script=None, name="dms-1.sock"):
        stand = dmstest.Stand(self.dir, name, script, self.fixture)
        self.stands.append(stand)
        return stand

    def start(self, script=None, timeouts=None):
        stand = self.stand(script)
        self.harness = dmstest.Harness(stand.path, self.dir)
        self.harness.wait_for(lambda s: s.get("available"))
        if timeouts:
            self.harness.ipc("timeouts", str(timeouts))
        return stand, self.harness

    def poll(self, function, check, timeout=6.0):
        deadline = time.time() + timeout
        state = json.loads(self.harness.ipc(function))
        while time.time() < deadline and not check(state):
            time.sleep(0.05)
            state = json.loads(self.harness.ipc(function))
        return state

    def net(self, check=lambda s: True, timeout=6.0):
        return self.poll("net", check, timeout)

    def bt(self, check=lambda s: True, timeout=6.0):
        return self.poll("bt", check, timeout)

    def sent(self, stand, method):
        return [r["params"] for r in stand.requests() if r["event"] == "request" and r["method"] == method]

    def settle(self, seconds=0.4):
        time.sleep(seconds)


def phase(state, key="attempt"):
    return (state.get(key) or {}).get("phase")


class Wifi(Base):
    def test_a_new_network_joins_with_its_password_once_and_succeeds_only_with_an_address(self):
        stand, h = self.start({"replies": {"network.wifi.connect": OK},
                               "after": {"network.wifi.connect": [connecting(NEW), joined(NEW)]}})
        h.ipc("join", NEW, SECRET, "false")
        h.ipc("join", NEW, SECRET, "false")                 # the double click
        state = self.net(lambda s: phase(s) == "done")
        self.assertEqual(state["attempt"], {"target": NEW, "action": "join", "phase": "done", "reason": ""})
        self.assertEqual(self.sent(stand, "network.wifi.connect"), [{"ssid": NEW, "interactive": False, "password": SECRET}])

    def test_a_hidden_network_says_so(self):
        stand, h = self.start({"replies": {"network.wifi.connect": OK}})
        h.ipc("join", NEW, SECRET, "true")
        self.settle()
        self.assertEqual(self.sent(stand, "network.wifi.connect")[0].get("hidden"), True)

    def test_a_wrong_password_shows_the_prompt_and_the_answer_goes_back_with_its_token(self):
        stand, h = self.start({"replies": {"network.wifi.connect": OK, "network.credentials.submit": OK},
                               "after": {"network.wifi.connect": [connecting(NEW), credentials("wrong-password")],
                                         "network.credentials.submit": [connecting(NEW), joined(NEW)]}})
        h.ipc("join", NEW, "fake-wrong", "false")
        state = self.net(lambda s: phase(s) == "wrong-secret" and s["prompt"])
        self.assertEqual(phase(state), "wrong-secret")
        self.assertEqual(state["prompt"], {"id": "net-1", "ssid": NEW, "name": NEW, "reason": "wrong-password", "kind": "psk"})
        self.assertEqual(state["prompts"], ["net-1"])
        h.ipc("answer", "net-1", SECRET)
        h.ipc("answer", "net-1", SECRET)                   # a second click finds nothing to answer
        state = self.net(lambda s: phase(s) == "done")
        self.assertEqual((phase(state), state["prompt"]), ("done", None))
        self.assertEqual(self.sent(stand, "network.credentials.submit"),
                         [{"token": "tok-fake-net-1", "secrets": {"psk": SECRET}, "save": True}])

    def test_no_answer_from_dms_is_a_timeout(self):
        stand, h = self.start({"silent": ["network.wifi.connect"]}, timeouts=600)
        h.ipc("join", NEW, SECRET, "false")
        self.assertEqual(phase(self.net(lambda s: phase(s) == "timeout")), "timeout")

    def test_taken_but_never_joined_is_a_timeout_too(self):
        stand, h = self.start({"replies": {"network.wifi.connect": OK}}, timeouts=600)
        h.ipc("join", NEW, SECRET, "false")
        self.assertEqual(phase(self.net(lambda s: phase(s) == "timeout")), "timeout")

    def test_progress_that_stops_with_an_error_is_a_failure_with_dms_reason(self):
        stopped = net_event(wifiConnected=False, isConnecting=False, lastError="fake-no-secrets")
        stand, h = self.start({"replies": {"network.wifi.connect": OK},
                               "after": {"network.wifi.connect": [connecting(NEW), stopped]}})
        h.ipc("join", NEW, SECRET, "false")
        state = self.net(lambda s: phase(s) == "failed")
        self.assertEqual(state["attempt"]["reason"], "fake-no-secrets")

    def test_another_network_while_one_is_joining_is_refused(self):
        stand, h = self.start({"silent": ["network.wifi.connect"]})
        h.ipc("join", NEW, SECRET, "false")
        h.ipc("join", "<ssid-other>", SECRET, "false")
        self.settle()
        self.assertEqual([p["ssid"] for p in self.sent(stand, "network.wifi.connect")], [NEW])

    def test_an_enterprise_network_is_refused_without_sending_anything(self):
        nets = [dict(NETWORK["wifiNetworks"][0], ssid="<ssid-ent>", enterprise=True, saved=False, connected=False)]
        stand, h = self.start({"replies": {"network.wifi.connect": OK},
                               "after": {"network.wifi.scan": [net_event(wifiNetworks=NETWORK["wifiNetworks"] + nets)]}})
        h.ipc("call", "network.wifi.scan")                 # pushes the snapshot with the enterprise network
        self.settle()
        h.ipc("join", "<ssid-ent>", SECRET, "false")
        state = self.net(lambda s: phase(s) == "failed")
        self.assertEqual(state["attempt"]["reason"], "enterprise")
        self.assertEqual(self.sent(stand, "network.wifi.connect"), [])

    def test_forget_and_autoconnect_read_the_state_again_because_dms_sends_no_event(self):
        forgotten = dict(NETWORK, savedWifiNetworks=[n for n in NETWORK["savedWifiNetworks"] if n["ssid"] != SAVED],
                         wifiNetworks=[dict(n, saved=False) if n["ssid"] == SAVED else n for n in NETWORK["wifiNetworks"]])
        stand, h = self.start({"replies": {"network.wifi.forget": OK, "network.getState": {"result": forgotten}}})
        h.ipc("forget", SAVED)
        state = self.net(lambda s: phase(s) == "done")
        self.assertEqual(state["attempt"], {"target": SAVED, "action": "forget", "phase": "done", "reason": ""})
        self.assertEqual(self.sent(stand, "network.wifi.forget"), [{"ssid": SAVED}])
        self.assertIn("network.getState", stand.methods())

    def test_autoconnect_off(self):
        off = dict(NETWORK, savedWifiNetworks=[dict(n, autoconnect=False) for n in NETWORK["savedWifiNetworks"]])
        stand, h = self.start({"replies": {"network.wifi.setAutoconnect": OK, "network.getState": {"result": off}}})
        h.ipc("acquire", "saved")
        self.assertTrue(self.net(lambda s: s["saved"])["saved"][0]["autoconnect"])
        h.ipc("autoconnect", SAVED, "false")
        state = self.net(lambda s: phase(s) == "done" and not s["saved"][0]["autoconnect"])
        self.assertEqual((phase(state), state["saved"][0]["autoconnect"]), ("done", False))
        self.assertEqual(self.sent(stand, "network.wifi.setAutoconnect"), [{"ssid": SAVED, "autoconnect": False}])

    def test_a_prompt_left_unanswered_is_cancelled(self):
        stand, h = self.start({"replies": {"network.wifi.connect": OK, "network.credentials.cancel": OK},
                               "after": {"network.wifi.connect": [credentials()]}}, timeouts=800)
        h.ipc("join", NEW, "", "false")
        state = self.net(lambda s: phase(s) == "cancelled", timeout=8)
        self.assertEqual((phase(state), state["attempt"]["reason"], state["prompt"]), ("cancelled", "prompt-timeout", None))
        self.assertEqual(self.sent(stand, "network.credentials.cancel"), [{"token": "tok-fake-net-1"}])

    def test_cancelling_the_prompt_cancels_the_attempt(self):
        stand, h = self.start({"replies": {"network.wifi.connect": OK, "network.credentials.cancel": OK},
                               "after": {"network.wifi.connect": [credentials()]}})
        h.ipc("join", NEW, "", "false")
        self.net(lambda s: s["prompt"])
        h.ipc("cancelPrompt", "net-1")
        state = self.net(lambda s: phase(s) == "cancelled")
        self.assertEqual(state["attempt"]["reason"], "user-canceled")

    def test_dms_dying_mid_join_is_lost_then_the_next_snapshot_decides(self):
        stand, h = self.start({"silent": ["network.wifi.connect"]})
        h.ipc("join", NEW, SECRET, "false")
        self.settle()
        stand.kill()
        self.assertEqual(phase(self.net(lambda s: phase(s) == "lost")), "lost")
        self.stand(name="dms-1.sock")                       # the same path; the backoff finds it
        state = self.net(lambda s: phase(s) == "failed", timeout=8)
        self.assertEqual(state["attempt"]["reason"], "dms-restarted")
        self.assertEqual(self.sent(self.stands[-1], "network.wifi.connect"), [])     # nothing replayed

    def test_vpn_on_and_off(self):
        profiles = [{"uuid": "<uuid-vpn>", "name": "Fake VPN", "type": "wireguard"}]
        on = net_event(vpnProfiles=profiles, vpnActive=[{"uuid": "<uuid-vpn>", "name": "Fake VPN", "state": "activated"}])
        starting = net_event(vpnProfiles=profiles, vpnActive=[{"uuid": "<uuid-vpn>", "state": "activating"}])
        off = net_event(vpnProfiles=profiles, vpnActive=[])
        stand, h = self.start({"replies": {"network.vpn.connect": OK, "network.vpn.disconnect": OK, "network.getState": {"result": off["data"]}},
                               "after": {"network.vpn.connect": [starting, on], "network.vpn.disconnect": [off],
                                         "test.profiles": [off]}})
        h.ipc("call", "test.profiles")
        self.assertEqual(self.net(lambda s: s["vpns"])["vpns"], [{"id": "<uuid-vpn>", "name": "Fake VPN", "state": "off"}])
        h.ipc("vpn", "<uuid-vpn>", "true")
        state = self.net(lambda s: phase(s, "vpnAttempt") == "done")
        self.assertEqual(state["vpns"][0]["state"], "on")
        h.ipc("dismiss")
        h.ipc("vpn", "<uuid-vpn>", "false")
        state = self.net(lambda s: phase(s, "vpnAttempt") == "done" and s["vpns"][0]["state"] == "off")
        self.assertEqual(state["vpns"][0]["state"], "off")
        self.assertEqual(self.sent(stand, "network.vpn.connect"), [{"uuidOrName": "<uuid-vpn>", "singleActive": False}])
        self.assertEqual(self.sent(stand, "network.vpn.disconnect"), [{"uuidOrName": "<uuid-vpn>"}])

    def test_preference(self):
        stand, h = self.start({"replies": {"network.preference.set": OK}})
        h.ipc("preference", "wifi")
        h.ipc("preference", "nonsense")
        self.settle()
        self.assertEqual(self.sent(stand, "network.preference.set"), [{"preference": "wifi"}])

    def test_after_resume_a_held_scan_runs_again(self):
        sleep = {"service": "loginctl", "data": {"preparingForSleep": True}}
        wake = {"service": "loginctl", "data": {"preparingForSleep": False}}
        stand, h = self.start({"replies": {"network.wifi.scan": OK, "test.sleep": OK, "test.wake": OK},
                               "after": {"test.sleep": [sleep], "test.wake": [wake]}})
        h.ipc("acquire", "scan")
        self.settle()
        h.ipc("call", "test.sleep")
        self.settle()
        h.ipc("call", "test.wake")
        self.settle()
        self.assertEqual(stand.methods().count("network.wifi.scan"), 2)

    def test_the_password_never_reaches_the_output(self):
        stand, h = self.start({"replies": {"network.wifi.connect": {"error": "fake failure"}, "network.credentials.submit": OK},
                               "after": {"network.wifi.connect": [credentials("wrong-password")]}})
        h.ipc("join", NEW, SECRET, "false")
        self.net(lambda s: s["prompt"])
        h.ipc("answer", "net-1", SECRET)
        self.settle()
        self.assertNotIn(SECRET, h.output())
        self.assertNotIn(SECRET, json.dumps(json.loads(h.ipc("net"))))
        # The stand-in's own request log holds it, by design: that is what DMS was sent.
        carrying = {r["method"] for r in stand.requests() if SECRET in json.dumps(r)}
        self.assertEqual(carrying, {"network.wifi.connect", "network.credentials.submit"})


class Bluetooth(Base):
    fixture_bt = True

    def test_devices_come_from_dms_connected_first_then_audio(self):
        stand, h = self.start()
        state = self.bt(lambda s: s["available"])
        self.assertEqual([d["name"] for d in state["devices"]], ["Fake Mouse", "Fake Headset", "Fake Keyboard"])
        self.assertEqual(state["primary"]["name"], "Fake Mouse")
        self.assertEqual([d["battery"] for d in state["devices"]], [-1, -1, -1])     # no BlueZ on the test bus
        self.assertEqual(state["nearby"], [])

    def test_power_sends_the_wanted_value_once(self):
        off = dict(BT, powered=False)
        stand, h = self.start({"replies": {"bluetooth.setPowered": OK, "bluetooth.getState": {"result": off}},
                               "after": {"bluetooth.setPowered": [{"service": "bluetooth", "data": off}]}})
        h.ipc("btPower", "true")                            # already on: nothing
        h.ipc("btPower", "false")
        h.ipc("btPower", "false")
        self.assertFalse(self.bt(lambda s: not s["enabled"])["enabled"])
        h.ipc("btPower", "false")                           # already off: nothing
        self.settle()
        self.assertEqual(self.sent(stand, "bluetooth.setPowered"), [{"powered": False, "adapter": "<path-a1>"}])

    def test_connect_once_and_done_when_dms_says_connected(self):
        stand, h = self.start({"replies": {"bluetooth.connect": OK, "bluetooth.getState": {"result": bt_event(**{"<address-d2>": {"connected": True}})["data"]}},
                               "after": {"bluetooth.connect": [bt_event(**{"<address-d2>": {"connected": True}})]}})
        h.ipc("btDo", "connect", "<address-d2>")
        h.ipc("btDo", "connect", "<address-d2>")
        state = self.bt(lambda s: phase(s["attempts"], "<address-d2>") == "done")
        self.assertEqual(state["attempts"]["<address-d2>"]["phase"], "done")
        self.assertEqual(state["primary"]["name"], "Fake Headset")             # audio first among connected
        self.assertEqual(self.sent(stand, "bluetooth.connect"), [{"device": "<path-d2>"}])

    def test_an_error_from_dms_is_a_failure(self):
        stand, h = self.start({"replies": {"bluetooth.connect": {"error": "fake: page timeout"}}})
        h.ipc("btDo", "connect", "<address-d1>")
        state = self.bt(lambda s: phase(s["attempts"], "<address-d1>") == "failed")
        self.assertEqual(state["attempts"]["<address-d1>"]["reason"], "fake: page timeout")

    def test_pair_with_a_pin(self):
        paired = bt_event(**{"<address-d5>": {"paired": True, "trusted": True}})
        stand, h = self.start({"replies": {"bluetooth.pair": OK, "bluetooth.pairing.submit": OK, "bluetooth.getState": {"result": BT}},
                               "after": {"bluetooth.pair": [pairing("pin")], "bluetooth.pairing.submit": [paired]}})
        h.ipc("btAcquire", "scan")
        self.bt(lambda s: s["nearby"])
        h.ipc("btDo", "pair", "<address-d5>")
        state = self.bt(lambda s: s["pairing"])
        self.assertEqual(state["pairing"], {"id": "bt-1", "kind": "pin", "deviceName": "Fake Phone", "device": "<address-d5>", "passkey": ""})
        h.ipc("btAnswer", "bt-1", "")                       # a PIN is needed: nothing sent
        h.ipc("btAnswer", "bt-1", "0000")
        h.ipc("btAnswer", "bt-1", "0000")
        state = self.bt(lambda s: phase(s["attempts"], "<address-d5>") == "done")
        self.assertEqual(state["attempts"]["<address-d5>"]["phase"], "done")
        self.assertIn("Fake Phone", [d["name"] for d in state["devices"]])
        self.assertEqual(self.sent(stand, "bluetooth.pair"), [{"device": "<path-d5>"}])
        self.assertEqual(self.sent(stand, "bluetooth.pairing.submit"), [{"token": "tok-fake-bt-1", "secrets": {"pin": "0000"}, "accept": True}])
        self.assertNotIn("0000", h.output())

    def test_a_passkey_to_compare_shows_and_saying_no_cancels(self):
        stand, h = self.start({"replies": {"bluetooth.pair": OK, "bluetooth.pairing.cancel": OK},
                               "after": {"bluetooth.pair": [pairing("confirm")]}})
        h.ipc("btDo", "pair", "<address-d5>")
        state = self.bt(lambda s: s["pairing"])
        self.assertEqual((state["pairing"]["kind"], state["pairing"]["passkey"]), ("confirm", "123456"))
        h.ipc("btCancel", "bt-1")
        state = self.bt(lambda s: phase(s["attempts"], "<address-d5>") == "cancelled")
        self.assertEqual(state["pairing"], None)
        self.assertEqual(self.sent(stand, "bluetooth.pairing.cancel"), [{"token": "tok-fake-bt-1"}])

    def test_pairing_that_never_finishes_times_out(self):
        stand, h = self.start({"silent": ["bluetooth.pair"]}, timeouts=600)
        h.ipc("btDo", "pair", "<address-d5>")
        self.assertEqual(phase(self.bt(lambda s: phase(s["attempts"], "<address-d5>") == "timeout")["attempts"], "<address-d5>"), "timeout")

    def test_trust(self):
        trusted = bt_event(**{"<address-d3>": {"trusted": True}})
        stand, h = self.start({"replies": {"bluetooth.trust": OK, "bluetooth.getState": {"result": trusted["data"]}},
                               "after": {"bluetooth.trust": [trusted]}})
        h.ipc("btDo", "trust", "<address-d3>")
        state = self.bt(lambda s: phase(s["attempts"], "<address-d3>") == "done")
        self.assertTrue(next(d for d in state["devices"] if d["id"] == "<address-d3>")["trusted"])
        h.ipc("btDo", "trust", "<address-d3>")              # already trusted: nothing
        self.settle()
        self.assertEqual(self.sent(stand, "bluetooth.trust"), [{"device": "<path-d3>"}])

    def test_forget(self):
        gone = bt_event(**{"<address-d1>": None})
        stand, h = self.start({"replies": {"bluetooth.remove": OK, "bluetooth.getState": {"result": gone["data"]}},
                               "after": {"bluetooth.remove": [gone]}})
        h.ipc("btDo", "forget", "<address-d1>")
        state = self.bt(lambda s: phase(s["attempts"], "<address-d1>") == "done")
        self.assertNotIn("Fake Keyboard", [d["name"] for d in state["devices"]])
        self.assertEqual(self.sent(stand, "bluetooth.remove"), [{"device": "<path-d1>"}])

    def test_the_scan_lease_starts_and_stops_discovery(self):
        stand, h = self.start({"replies": {"bluetooth.startDiscovery": OK, "bluetooth.stopDiscovery": OK}})
        h.ipc("btAcquire", "scan")
        state = self.bt(lambda s: s["nearby"])
        self.assertEqual([d["name"] for d in state["nearby"]], ["Fake Speaker", "Fake Phone"])
        h.ipc("btRelease", "scan")
        self.settle()
        self.assertEqual(stand.methods().count("bluetooth.startDiscovery"), 1)
        self.assertEqual(stand.methods().count("bluetooth.stopDiscovery"), 1)
        self.assertEqual(json.loads(h.ipc("bt"))["nearby"], [])

    def test_dms_dying_mid_pair_is_lost_then_the_next_snapshot_decides(self):
        stand, h = self.start({"silent": ["bluetooth.pair"]})
        h.ipc("btDo", "pair", "<address-d5>")
        self.settle()
        stand.kill()
        self.bt(lambda s: phase(s["attempts"], "<address-d5>") == "lost")
        self.stand(name="dms-1.sock")
        state = self.bt(lambda s: phase(s["attempts"], "<address-d5>") == "failed", timeout=8)
        self.assertEqual(state["attempts"]["<address-d5>"]["reason"], "dms-restarted")


if __name__ == "__main__":
    unittest.main()
