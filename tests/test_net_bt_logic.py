"""S10, Wi-Fi and Bluetooth in FART: the pure parts under Node (docs/NET_BT.md §3, §6).

DmsAttempt.js (one action from click to outcome), DmsSet.js (explicit setters), DmsPrompt.js (the agents' prompts),
and the mappings DmsNetworkMap.js and DmsBluetoothMap.js. Network values are computed from the recorded fixture;
Bluetooth rows come from a labelled synthetic snapshot (the recording has the radio off). Every secret here is fake."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = json.loads((ROOT / "tests/fixtures/dms/s0-v2.1.0.json").read_text())
NETWORK = next(e["result"]["data"] for e in FIXTURE["events"] if e["result"]["service"] == "network")
BT_FILE = ROOT / "tests/fixtures/dms/bluetooth-synthetic.json"
BT = json.loads(BT_FILE.read_text())["state"]
RECORDED_BT = FIXTURE["replies"]["bluetooth.getState"]["result"]
SSID = NETWORK["wifiSSID"]


def run(files, expression):
    body = "\n".join(
        l for f in files for l in (ROOT / "adapters/dms" / f).read_text().splitlines() if not l.startswith(".pragma"))
    script = body + f"\nprocess.stdout.write(JSON.stringify({expression}));"
    out = subprocess.run(["node", "-e", script], capture_output=True, text=True)
    if out.returncode:
        raise AssertionError(out.stderr)
    return json.loads(out.stdout)


def j(value):
    return json.dumps(value)


def attempt(steps):
    """Runs DmsAttempt.js steps in order; each step is a JS expression of `s` (the state). Returns every state."""
    body = "let s = null; const out = [];\n" + "\n".join(f"s = {x}; out.push(s);" for x in steps)
    return run(["DmsAttempt.js"], f"(() => {{ {body} return out; }})()")


OK = {"ok": True, "progress": False, "reason": "", "wrongSecret": False}
GOING = {"ok": False, "progress": True, "reason": "", "wrongSecret": False}
IDLE = {"ok": False, "progress": False, "reason": "", "wrongSecret": False}


def stopped(reason=""):
    return dict(IDLE, reason=reason)


def begin(target="net-a", action="join", now=0, timeout=40000):
    return f"begin(s, {j(target)}, {j(action)}, {now}, {timeout}).state"


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Attempt(unittest.TestCase):
    def phases(self, steps):
        return [s["phase"] if s else None for s in attempt(steps)]

    def test_success_needs_the_snapshot_not_the_reply(self):
        got = self.phases([begin(), "replied(s, '', 10)", f"observe(s, {j(GOING)}, 20)", f"observe(s, {j(OK)}, 30)"])
        self.assertEqual(got, ["working", "working", "working", "done"])

    def test_a_stale_error_before_any_progress_is_not_read(self):
        got = self.phases([begin(), "replied(s, '', 10)", f"observe(s, {j(stopped('bad-credentials'))}, 20)"])
        self.assertEqual(got[-1], "working")

    def test_progress_that_stops_with_bad_credentials_is_a_wrong_password(self):
        got = attempt([begin(), f"observe(s, {j(GOING)}, 5)", f"observe(s, {j(stopped('bad-credentials'))}, 9)"])
        self.assertEqual((got[-1]["phase"], got[-1]["reason"]), ("wrong-secret", "bad-credentials"))

    def test_a_prompt_saying_wrong_password_settles_it_and_a_retry_runs_again_with_a_fresh_deadline(self):
        wrong = dict(IDLE, wrongSecret=True)
        got = attempt([begin(now=0), f"observe(s, {j(wrong)}, 30000)", "retry(s, 35000)", "tick(s, 41000)"])
        self.assertEqual([s["phase"] for s in got], ["working", "wrong-secret", "working", "working"])
        self.assertEqual(got[2]["deadline"], 75000)

    def test_other_stops_are_failures_and_a_cancel_is_cancelled(self):
        self.assertEqual(self.phases([begin(), f"observe(s, {j(GOING)}, 1)", f"observe(s, {j(stopped('no-secrets'))}, 2)"])[-1], "failed")
        self.assertEqual(self.phases([begin(), f"observe(s, {j(GOING)}, 1)", f"observe(s, {j(stopped('user-canceled'))}, 2)"])[-1], "cancelled")
        self.assertEqual(self.phases([begin(), f"observe(s, {j(GOING)}, 1)", f"observe(s, {j(stopped())}, 2)"])[-1], "failed")
        self.assertEqual(self.phases([begin(), "cancel(s, 5)"])[-1], "cancelled")

    def test_every_action_ends_with_a_timeout_at_the_latest(self):
        got = attempt([begin(now=0, timeout=40000), "tick(s, 39999)", "tick(s, 40000)"])
        self.assertEqual([s["phase"] for s in got], ["working", "working", "timeout"])
        self.assertEqual(run(["DmsAttempt.js"], f"nextDeadline({j(attempt([begin(now=7, timeout=100)])[0])})"), 107)

    def test_the_reply_errors(self):
        self.assertEqual(self.phases([begin(), "replied(s, 'timeout', 1)"])[-1], "timeout")
        got = attempt([begin(), "replied(s, 'no such network', 1)"])[-1]
        self.assertEqual((got["phase"], got["reason"]), ("failed", "no such network"))
        self.assertEqual(self.phases([begin(), "replied(s, 'offline', 1)"])[-1], "lost")

    def test_a_double_click_sends_once_and_another_target_is_refused(self):
        got = run(["DmsAttempt.js"], f"""(() => {{
            const a = begin(null, "net-a", "join", 0, 1000);
            const again = begin(a.state, "net-a", "join", 5, 1000);
            const other = begin(a.state, "net-b", "connect", 5, 1000);
            const after = begin(settle(a.state, "done", "", 9), "net-b", "connect", 10, 1000);
            return [a.send, again.send, again.refused, other.send, other.refused, after.send];
        }})()""")
        self.assertEqual(got, [True, False, "", False, "busy", True])

    def test_dms_going_away_then_the_first_snapshot_decides(self):
        self.assertEqual(self.phases([begin(), "linkDown(s)", f"observe(s, {j(OK)}, 3)"]), ["working", "lost", "done"])
        got = attempt([begin(), "linkDown(s)", f"observe(s, {j(IDLE)}, 3)"])[-1]
        self.assertEqual((got["phase"], got["reason"]), ("failed", "dms-restarted"))
        self.assertEqual(self.phases([begin(), "linkDown(s)", f"observe(s, {j(GOING)}, 3)"])[-1], "working")
        got = attempt([begin(now=0, timeout=100), "linkDown(s)", "tick(s, 100)"])[-1]
        self.assertEqual((got["phase"], got["reason"]), ("failed", "offline"))

    def test_time_asleep_does_not_count(self):
        got = attempt([begin(now=0, timeout=40000), "resumed(s, 900000)", "tick(s, 900001)"])
        self.assertEqual((got[-1]["phase"], got[-1]["deadline"]), ("working", 940000))

    def test_a_late_success_after_a_timeout_is_shown_as_it_is(self):
        self.assertEqual(self.phases([begin(now=0, timeout=10), "tick(s, 10)", f"observe(s, {j(OK)}, 20)"])[-1], "done")

    def test_settled_attempts_go_away_after_a_while(self):
        got = self.phases([begin(), f"observe(s, {j(OK)}, 100)", "tick(s, 5099)", "tick(s, 5100)"])
        self.assertEqual(got[-2:], ["done", None])
        got = self.phases([begin(now=0, timeout=10), "tick(s, 10)", "tick(s, 60009)", "tick(s, 60010)"])
        self.assertEqual(got[-2:], ["timeout", None])

    def test_the_view_hides_the_bookkeeping(self):
        got = run(["DmsAttempt.js"], f"view(begin(null, 'net-a', 'join', 0, 10).state)")
        self.assertEqual(got, {"target": "net-a", "action": "join", "phase": "working", "reason": ""})


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Setter(unittest.TestCase):
    def test_one_call_a_repeat_sends_nothing_and_the_newest_wins_after_the_answer(self):
        got = run(["DmsSet.js"], """(() => {
            const a = request(initial(), true, false);
            const same = request(a.state, true, false);
            const flip = request(same.state, false, false);
            const after = answered(flip.state, true);
            const nothing = request(initial(), true, true);
            const settled = answered(request(a.state, true, false).state, true);
            return [a.send, same.send, flip.send, after.send, nothing.send, settled.send, settled.state];
        })()""")
        self.assertEqual(got, [True, None, None, False, None, None, {"sending": None, "queued": None}])


@unittest.skipUnless(shutil.which("node"), "needs Node")
class Prompts(unittest.TestCase):
    def test_a_wifi_password_prompt(self):
        data = {"token": "tok-fake-1", "ssid": "<ssid-x>", "setting": "802-11-wireless-security", "fields": ["psk"],
                "reason": "wrong-password"}
        got = run(["DmsPrompt.js"], f"(() => {{ const p = credential({j(data)}, 5, 1); return [view(p), credentialParams(p, 'fake-secret')]; }})()")
        self.assertEqual(got[0], {"id": "net-1", "ssid": "<ssid-x>", "name": "<ssid-x>", "reason": "wrong-password", "kind": "psk"})
        self.assertEqual(got[1], {"token": "tok-fake-1", "secrets": {"psk": "fake-secret"}, "save": True})

    def test_the_view_never_carries_the_token(self):
        got = run(["DmsPrompt.js"], "[view(credential({token: 'tok-fake-2'}, 0, 1)), view(pairing({token: 'tok-fake-3', requestType: 'pin'}, 0, 2))]")
        self.assertNotIn("tok-fake", json.dumps(got))

    def test_kinds(self):
        cases = [
            ({"token": "t", "fields": ["psk"]}, "psk"),
            ({"token": "t"}, "psk"),
            ({"token": "t", "setting": "802-1x", "fields": ["identity", "password"]}, "unsupported"),
            ({"token": "t", "connType": "vpn", "setting": "vpn", "fields": ["password"]}, "vpn"),
            ({"token": "t", "connType": "vpn", "fieldsInfo": [{"name": "password", "isSecret": True}]}, "vpn"),
            ({"token": "t", "connType": "vpn", "fieldsInfo": [{"name": "user", "isSecret": False}, {"name": "password", "isSecret": True}]}, "unsupported"),
        ]
        got = run(["DmsPrompt.js"], f"{j([c for c, _ in cases])}.map(d => credential(d, 0, 1).kind)")
        self.assertEqual(got, [k for _, k in cases])

    def test_vpn_answers_name_the_secret_field(self):
        got = run(["DmsPrompt.js"], "credentialParams(credential({token: 't', connType: 'vpn', fieldsInfo: [{name: 'password', isSecret: true}]}, 0, 1), 'fake')")
        self.assertEqual(got["secrets"], {"password": "fake"})

    def test_no_token_no_prompt(self):
        self.assertEqual(run(["DmsPrompt.js"], "[credential({}, 0, 1), credential(null, 0, 1), pairing({token: ''}, 0, 1)]"), [None, None, None])

    def test_pairing_kinds_and_answers(self):
        got = run(["DmsPrompt.js"], """['confirm', 'display-passkey', 'authorize', 'pin', 'passkey', 'odd'].map(k => {
            const p = pairing({token: 'tok-fake', requestType: k, passkey: 4242, deviceName: 'Fake Headset'}, 0, 7);
            return [p.kind, p.passkey, pairingParams(p, '0000').secrets];
        })""")
        self.assertEqual(got, [
            ["confirm", "004242", {"decision": "yes"}], ["display-passkey", "004242", {"decision": "yes"}],
            ["authorize", "", {"decision": "yes"}], ["pin", "", {"pin": "0000"}], ["passkey", "", {"passkey": "0000"}],
            ["unsupported", "", {"decision": "yes"}]])

    def test_an_unanswered_prompt_expires_after_90_s(self):
        got = run(["DmsPrompt.js"], "(() => { const p = credential({token: 't'}, 1000, 1); return [expired(p, 90999), expired(p, 91000), deadline(p)]; })()")
        self.assertEqual(got, [False, True, 91000])


@unittest.skipUnless(shutil.which("node"), "needs Node")
class NetworkMapping(unittest.TestCase):
    def test_rows_carry_enterprise_hidden_autoconnect_and_band_from_the_fixture(self):
        got = run(["DmsNetworkMap.js"], f"networks({j(NETWORK)}, true)")
        recorded = {n["ssid"]: n for n in NETWORK["wifiNetworks"]}
        self.assertGreater(len(got), 0)
        for row in got:
            n = recorded[row["id"]]
            f = n.get("frequency", 0)
            self.assertEqual((row["enterprise"], row["hidden"], row["autoconnect"]), (n["enterprise"], n["hidden"], n["autoconnect"]))
            self.assertEqual(row["band"], "" if not f else "2.4" if f < 3000 else "5" if f < 5925 else "6")

    def test_bands(self):
        self.assertEqual(run(["DmsNetworkMap.js"], "[0, 2412, 5180, 5955, undefined].map(band)"), ["", "2.4", "5", "6", ""])

    def test_saved_list_follows_the_fixture_and_its_lease(self):
        got = run(["DmsNetworkMap.js"], f"[saved({j(NETWORK)}, false), saved({j(NETWORK)}, true)]")
        self.assertEqual(got[0], [])
        near = {n["ssid"] for n in NETWORK["wifiNetworks"] if not n["outOfRange"]}
        expected, seen = [], set()
        for n in NETWORK["savedWifiNetworks"]:
            if n["ssid"] and n["ssid"] not in seen:
                seen.add(n["ssid"])
                expected.append({"id": n["ssid"], "ssid": n["ssid"], "autoconnect": n["autoconnect"], "inRange": n["ssid"] in near,
                                 "enterprise": n["enterprise"], "connected": NETWORK["wifiConnected"] and NETWORK["wifiSSID"] == n["ssid"]})
        self.assertEqual(got[1], expected)

    def test_wired_vpn_and_connecting(self):
        got = run(["DmsNetworkMap.js"], f"[wired({j(NETWORK)}), vpn({j(NETWORK)}), connecting({j(NETWORK)})]")
        self.assertEqual(got[0], {"connected": NETWORK["ethernetConnected"],
                                  "name": NETWORK["ethernetDevice"] if NETWORK["ethernetConnected"] else ""})
        self.assertEqual(got[1], [])          # the recording has no VPN profiles
        self.assertEqual(got[2], NETWORK["connectingSSID"] if NETWORK["isConnecting"] else "")
        synthetic = dict(NETWORK, vpnProfiles=[{"uuid": "<uuid-v1>", "name": "Fake VPN", "type": "wireguard"},
                                               {"uuid": "<uuid-v2>", "name": "Other VPN"}],
                         vpnActive=[{"uuid": "<uuid-v1>", "name": "Fake VPN", "state": "activating"}])
        self.assertEqual(run(["DmsNetworkMap.js"], f"vpn({j(synthetic)})"),
                         [{"id": "<uuid-v1>", "name": "Fake VPN", "state": "starting"}, {"id": "<uuid-v2>", "name": "Other VPN", "state": "off"}])

    def test_observations(self):
        def obs(data, target, action, fn="wifiObservation"):
            return run(["DmsNetworkMap.js"], f"{fn}({j(data)}, {j({'target': target, 'action': action})})")
        self.assertTrue(obs(NETWORK, SSID, "join")["ok"])                         # connected with an address
        self.assertFalse(obs(dict(NETWORK, wifiIP=""), SSID, "join")["ok"])       # no address yet
        joining = dict(NETWORK, wifiConnected=False, isConnecting=True, connectingSSID="<other>")
        self.assertEqual((obs(joining, "<other>", "join")["progress"], obs(joining, SSID, "join")["progress"]), (True, False))
        self.assertFalse(obs(NETWORK, SSID, "disconnect")["ok"])
        self.assertTrue(obs(dict(NETWORK, wifiConnected=False), SSID, "disconnect")["ok"])
        saved_ssid = NETWORK["savedWifiNetworks"][0]["ssid"]
        self.assertFalse(obs(NETWORK, saved_ssid, "forget")["ok"])
        self.assertTrue(obs(dict(NETWORK, savedWifiNetworks=[], wifiNetworks=[]), saved_ssid, "forget")["ok"])
        on = NETWORK["savedWifiNetworks"][0]["autoconnect"]
        self.assertTrue(obs(NETWORK, saved_ssid, "autoconnect:" + ("on" if on else "off"))["ok"])
        self.assertFalse(obs(NETWORK, saved_ssid, "autoconnect:" + ("off" if on else "on"))["ok"])
        vpn = dict(NETWORK, vpnProfiles=[{"uuid": "<uuid-v1>", "name": "Fake VPN"}], vpnActive=[{"uuid": "<uuid-v1>", "state": "activated"}],
                   vpnErrorUuid="<uuid-v1>", vpnError="fake error")
        self.assertEqual(obs(vpn, "<uuid-v1>", "vpn:on", "vpnObservation"), {"ok": True, "progress": False, "reason": "fake error", "wrongSecret": False})
        self.assertFalse(obs(vpn, "<uuid-v1>", "vpn:off", "vpnObservation")["ok"])

    def test_connect_action_says_enterprise(self):
        ent = dict(NETWORK, savedWifiNetworks=[], wifiNetworks=[{"ssid": "<ent>", "enterprise": True, "saved": False}])
        self.assertEqual(run(["DmsNetworkMap.js"], f"[connectAction({j(ent)}, '<ent>'), connectAction({j(ent)}, '<new>')]"),
                         ["enterprise", "unknown"])


@unittest.skipUnless(shutil.which("node"), "needs Node")
class BluetoothMapping(unittest.TestCase):
    def test_the_synthetic_fixture_is_labelled_and_scrubbed(self):
        text = BT_FILE.read_text()
        self.assertIn("SYNTHETIC", json.loads(text)["_note"])
        self.assertEqual(re.findall(r"(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}", text), [])
        for d in BT["devices"]:
            self.assertTrue(d["address"].startswith("<") and d["path"].startswith("<"))
            self.assertTrue(d["name"].startswith("Fake ") or d["name"].startswith("<"))

    def test_the_recording_reads_off_with_nothing_in_it(self):
        got = run(["DmsBluetoothMap.js"], f"[enabled({j(RECORDED_BT)}), devices({j(RECORDED_BT)}, null), nearby({j(RECORDED_BT)}, true), adapterPath({j(RECORDED_BT)})]")
        self.assertEqual(got, [RECORDED_BT["powered"], [], [], RECORDED_BT["adapters"][0]["path"]])

    def test_paired_devices_connected_first_then_audio_then_by_name(self):
        got = run(["DmsBluetoothMap.js"], f"devices({j(BT)}, a => a === '<address-d2>' ? 0.8 : -1)")
        self.assertEqual([d["name"] for d in got], ["Fake Mouse", "Fake Headset", "Fake Keyboard"])
        self.assertEqual([d["kind"] for d in got], ["mouse", "headphones", "keyboard"])
        self.assertEqual([d["battery"] for d in got], [-1, 0.8, -1])
        self.assertEqual([d["audio"] for d in got], [False, True, False])
        self.assertEqual([d["trusted"] for d in got], [False, True, True])

    def test_nearby_waits_for_its_lease_skips_nameless_devices_and_puts_audio_first(self):
        got = run(["DmsBluetoothMap.js"], f"[nearby({j(BT)}, false), nearby({j(BT)}, true)]")
        self.assertEqual(got[0], [])
        self.assertEqual([(d["name"], d["kind"]) for d in got[1]], [("Fake Speaker", "speaker"), ("Fake Phone", "smartphone")])
        self.assertAlmostEqual(got[1][1]["strength"], 40 / 60)

    def test_observations(self):
        def ok(target, action):
            return run(["DmsBluetoothMap.js"], f"observation({j(BT)}, {j({'target': target, 'action': action})}).ok")
        self.assertEqual([ok("<address-d3>", "connect"), ok("<address-d2>", "connect"), ok("<address-d2>", "disconnect")], [True, False, True])
        self.assertEqual([ok("<address-d5>", "pair"), ok("<address-d2>", "pair"), ok("<address-d2>", "forget"), ok("<address-gone>", "forget")], [False, True, False, True])
        self.assertEqual([ok("<address-d3>", "trust:on"), ok("<address-d3>", "trust:off")], [False, True])
        self.assertEqual(run(["DmsBluetoothMap.js"], f"pathOf({j(BT)}, '<address-d1>')"), "<path-d1>")


if __name__ == "__main__":
    unittest.main()
