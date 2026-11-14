"""adapters/dms/DmsNetworkMap.js and DmsToggle.js: docs/DMS_ADAPTER.md §4 and §1, under Node.

Expected values are computed from the recorded fixture, not typed in. Variants are synthetic."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = json.loads((ROOT / "tests/fixtures/dms/s0-v2.1.0.json").read_text())
EVENT = next(e["result"]["data"] for e in FIXTURE["events"] if e["result"]["service"] == "network")
REPLY = FIXTURE["replies"]["network.getState"]["result"]


def run(files, expression):
    body = "\n".join(
        l for f in files for l in (ROOT / "adapters/dms" / f).read_text().splitlines() if not l.startswith(".pragma"))
    script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
    return json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)


def mapped(data, details=False, scan=False):
    return run(["DmsNetworkMap.js"], f"{{kind: kind({json.dumps(data)}), wifiEnabled: wifiEnabled({json.dumps(data)}), "
               f"name: name({json.dumps(data)}), ip: ipAddress({json.dumps(data)}, {json.dumps(details)}), "
               f"networks: networks({json.dumps(data)}, {json.dumps(scan)})}}")


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Fixture(unittest.TestCase):
    def test_the_reply_and_the_event_agree_on_everything_but_scrub_placeholders(self):
        # The scrubber numbers its placeholders per position, so names differ between the two recordings.
        a, b = mapped(REPLY), mapped(EVENT)
        self.assertEqual((a["kind"], a["wifiEnabled"]), (b["kind"], b["wifiEnabled"]))

    def test_values_follow_the_recorded_snapshot(self):
        got = mapped(EVENT, details=True, scan=True)
        wired, wireless = EVENT["ethernetConnected"] is True, EVENT["wifiConnected"] is True
        expected_kind = "ethernet" if wired else "wifi" if wireless else "none"
        self.assertEqual(got["kind"], expected_kind)
        self.assertEqual(got["wifiEnabled"], EVENT["wifiEnabled"] is True)
        self.assertEqual(got["name"], {"ethernet": EVENT["ethernetDevice"], "wifi": EVENT["wifiSSID"], "none": ""}[expected_kind])
        self.assertEqual(got["ip"], {"ethernet": EVENT["ethernetIP"], "wifi": EVENT["wifiIP"], "none": ""}[expected_kind])
        seen, expected = set(), []
        for n in EVENT["wifiNetworks"]:
            if n["ssid"] and not n["outOfRange"] and n["ssid"] not in seen:
                seen.add(n["ssid"])
                expected.append({"id": n["ssid"], "ssid": n["ssid"], "strength": min(1, max(0, n["signal"] / 100)),
                                 "secured": n["secured"], "known": n["saved"], "connected": n["connected"],
                                 "enterprise": n["enterprise"], "hidden": n["hidden"], "autoconnect": n["autoconnect"],
                                 "band": run(["DmsNetworkMap.js"], f"band({n.get('frequency', 0)})")})
        self.assertEqual(got["networks"], expected)
        self.assertGreater(len(expected), 0)

    def test_the_address_and_the_list_wait_for_their_leases(self):
        got = mapped(EVENT)
        self.assertEqual((got["ip"], got["networks"]), ("", []))
        self.assertEqual(mapped(EVENT, details=True)["networks"], [])
        self.assertEqual(mapped(EVENT, scan=True)["ip"], "")

    def test_no_data_reads_as_the_contract_defaults(self):
        got = run(["DmsNetworkMap.js"], "{kind: kind(null), w: wifiEnabled(null), name: name(null), ip: ipAddress(null, true), n: networks(null, true)}")
        self.assertEqual(got, {"kind": "none", "w": False, "name": "", "ip": "", "n": []})


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Kinds(unittest.TestCase):
    def kind(self, **fields):
        base = dict(EVENT, networkStatus="", ethernetConnected=False, wifiConnected=False)
        return mapped(dict(base, **fields))["kind"]

    def test_the_status_and_its_flag_agree(self):
        self.assertEqual(self.kind(networkStatus="ethernet", ethernetConnected=True), "ethernet")
        self.assertEqual(self.kind(networkStatus="wifi", wifiConnected=True), "wifi")

    def test_both_connected_follows_the_status_then_wired_first(self):
        self.assertEqual(self.kind(networkStatus="wifi", wifiConnected=True, ethernetConnected=True), "wifi")
        self.assertEqual(self.kind(networkStatus="ethernet", wifiConnected=True, ethernetConnected=True), "ethernet")
        self.assertEqual(self.kind(networkStatus="", wifiConnected=True, ethernetConnected=True), "ethernet")

    def test_a_flag_without_the_matching_status_still_counts(self):
        self.assertEqual(self.kind(networkStatus="disconnected", wifiConnected=True), "wifi")
        self.assertEqual(self.kind(networkStatus="disconnected", ethernetConnected=True), "ethernet")

    def test_the_status_without_its_flag_is_not_a_connection(self):
        self.assertEqual(self.kind(networkStatus="wifi"), "none")
        self.assertEqual(self.kind(networkStatus="ethernet"), "none")

    def test_text_in_a_field_that_was_empty_decides_nothing(self):
        # The scrubbed fixture holds placeholders where the real values were empty.
        self.assertEqual(self.kind(wifiSSID="<placeholder>", wifiIP="<placeholder>", ethernetIP="<placeholder>",
                                   ethernetDevice="<placeholder>"), "none")
        self.assertEqual(mapped(dict(EVENT, wifiConnected=False, ethernetConnected=False), details=True)["ip"], "")

    def test_only_a_true_flag_counts(self):
        self.assertEqual(self.kind(wifiConnected="true"), "none")
        self.assertFalse(mapped(dict(EVENT, wifiEnabled="yes"))["wifiEnabled"])
        self.assertFalse(mapped(dict(EVENT, wifiEnabled=None))["wifiEnabled"])


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Scanning(unittest.TestCase):
    NETS = [
        {"ssid": "net-a", "signal": 140, "secured": True, "saved": True, "connected": False, "outOfRange": False},
        {"ssid": "net-a", "signal": 10, "secured": False, "saved": False, "connected": False, "outOfRange": False},
        {"ssid": "", "signal": 50, "outOfRange": False},
        {"ssid": "net-far", "signal": 0, "outOfRange": True},
        {"ssid": "net-b", "signal": -5, "secured": False, "saved": False, "connected": True, "outOfRange": False},
        {"signal": 40},
    ]

    def test_filtering_clamping_and_the_first_of_a_repeated_name(self):
        got = mapped(dict(EVENT, wifiNetworks=self.NETS), scan=True)["networks"]
        self.assertEqual([n["id"] for n in got], ["net-a", "net-b"])
        self.assertEqual([n["strength"] for n in got], [1, 0])
        self.assertEqual((got[0]["secured"], got[0]["known"]), (True, True))
        self.assertTrue(got[1]["connected"])

    def test_a_missing_list_is_empty(self):
        data = {k: v for k, v in EVENT.items() if k != "wifiNetworks"}
        self.assertEqual(mapped(data, scan=True)["networks"], [])

    def test_same_content_compares_equal(self):
        got = run(["DmsNetworkMap.js"], f"sameNetworks(networks({json.dumps(EVENT)}, true), networks({json.dumps(EVENT)}, true))")
        self.assertTrue(got)
        self.assertFalse(run(["DmsNetworkMap.js"], "sameNetworks([], [{id: 'x'}])"))


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Connecting(unittest.TestCase):
    def action(self, data, ssid):
        return run(["DmsNetworkMap.js"], f"connectAction({json.dumps(data)}, {json.dumps(ssid)})")

    def test_a_saved_network_connects(self):
        saved = EVENT["savedWifiNetworks"][1]["ssid"]
        self.assertEqual(self.action(dict(EVENT, wifiSSID="<other>"), saved), "connect")

    def test_a_listed_saved_network_connects(self):
        data = dict(EVENT, savedWifiNetworks=[], wifiConnected=False,
                    wifiNetworks=[{"ssid": "net-a", "saved": True}, {"ssid": "net-b", "saved": False}])
        self.assertEqual(self.action(data, "net-a"), "connect")
        self.assertEqual(self.action(data, "net-b"), "unknown")

    def test_the_network_already_joined_does_nothing(self):
        self.assertEqual(self.action(EVENT, EVENT["wifiSSID"]), "none")

    def test_an_unknown_name_or_no_data_hands_over_or_does_nothing(self):
        self.assertEqual(self.action(EVENT, "never-seen"), "unknown")
        self.assertEqual(self.action(None, "x"), "none")
        self.assertEqual(self.action(EVENT, ""), "none")


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Toggle(unittest.TestCase):
    def play(self, steps: str):
        return run(["DmsToggle.js"], "(() => { let st = initial(); const out = []; " + steps + " return out; })()")

    def test_a_change_flips_once(self):
        got = self.play("let r = request(st, false, true); st = r.state; out.push(r.flip); "
                        "r = answered(st, false); st = r.state; out.push(r.flip, current(st, true), st.wanted, st.busy);")
        self.assertEqual(got, [True, False, False, None, False])

    def test_a_repeat_of_the_current_value_flips_nothing(self):
        got = self.play("let r = request(st, true, true); out.push(r.flip, r.state.busy, r.state.wanted);")
        self.assertEqual(got, [False, False, None])

    def test_a_second_click_in_flight_does_not_flip_twice(self):
        got = self.play("let r = request(st, false, true); st = r.state; out.push(r.flip); "
                        "r = request(st, false, true); st = r.state; out.push(r.flip);")
        self.assertEqual(got, [True, False])

    def test_the_newest_request_wins(self):
        got = self.play("let r = request(st, false, true); st = r.state; "
                        "r = request(st, true, true); st = r.state; out.push(r.flip); "     # in flight: nothing yet
                        "r = answered(st, false); st = r.state; out.push(r.flip); "         # answer is off, wanted is on: once more
                        "r = answered(st, true); st = r.state; out.push(r.flip, st.wanted);")
        self.assertEqual(got, [False, True, False, None])

    def test_a_stale_snapshot_gets_one_more_flip_then_gives_up(self):
        got = self.play("let r = request(st, false, true); st = r.state; out.push(r.flip); "
                        "r = answered(st, false === false ? true : false); st = r.state; out.push(r.flip); "   # answer still on
                        "r = answered(st, true); st = r.state; out.push(r.flip, st.busy, st.wanted);")
        self.assertEqual(got, [True, True, False, False, None])

    def test_the_override_holds_until_the_next_snapshot(self):
        got = self.play("let r = request(st, false, true); st = r.state; r = answered(st, false); st = r.state; "
                        "out.push(current(st, true)); "                                     # stale snapshot says on
                        "r = request(st, false, true); out.push(r.flip); "                  # a double click does not flip back
                        "st = snapshot(st); out.push(current(st, false));")
        self.assertEqual(got, [False, False, False])

    def test_a_failure_leaves_the_value_and_clears_the_wish(self):
        got = self.play("let r = request(st, false, true); st = r.state; r = failed(st); st = r.state; "
                        "out.push(r.flip, st.busy, st.wanted, current(st, true));")
        self.assertEqual(got, [False, False, None, True])
        # and the next request may flip again
        again = self.play("let r = request(st, false, true); st = r.state; r = failed(st); st = r.state; r = request(st, false, true); out.push(r.flip);")
        self.assertEqual(again, [True])


if __name__ == "__main__":
    unittest.main()
