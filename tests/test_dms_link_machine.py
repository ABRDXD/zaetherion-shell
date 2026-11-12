"""adapters/dms/DmsLinkMachine.js: the DMS link as a pure machine (docs/DMS_ADAPTER.md §2).

One test per table row (L1..L10, R1..R5, S1..S11) and one per invariant, run under Node. Nothing here touches
a socket or a real DMS; every payload is synthetic."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "adapters/dms/DmsLinkMachine.js"

# A small driver over the machine: `go(event, at)` steps it and returns the effects.
PRELUDE = r"""
let now = 1000;
let s = initial("test");
const all = [];
function go(event, at) {
  if (at !== undefined) now = at;
  const r = step(s, event, now);
  s = r.state;
  all.push(...r.effects);
  return r.effects;
}
const kinds = fx => fx.map(e => e.type);
const of = (fx, type) => fx.filter(e => e.type === type);
const GREETING = {apiVersion: 38, capabilities: ["network", "brightness", "bluetooth"]};
function toGreeting(path = "/run/dms-1.sock") { go({type: "path", path}); go({type: "requestUp"}); }
function toReady(greeting = GREETING, path) { toGreeting(path); return go({type: "line", msg: greeting}); }
function feed(key, service, capability, wanted = true) { return go({type: "feed", key, service, capability, wanted}); }
function toOpen(services = [["net", "network", "network"]]) {
  toReady();
  for (const [key, service, capability] of services) feed(key, service, capability);
  go({type: "settle"});
  go({type: "eventsUp"});
}
const snap = (service, data) => ({type: "eventLine", msg: {id: 1, result: {service, data}}});
const call = (token, method = "network.getState", timeoutMs) => go({type: "call", token, method, params: {}, timeoutMs});
"""


@unittest.skipUnless(shutil.which("node"), "needs Node")
class MachineTests(unittest.TestCase):
    def js(self, body: str):
        source = "\n".join(l for l in SOURCE.read_text().splitlines() if not l.startswith(".pragma"))
        script = source + PRELUDE + "\n" + body
        done = subprocess.run(["node", "-e", script], capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stderr)
        return json.loads(done.stdout)

    # ---- L: the request connection ----------------------------------------------------------------------

    def test_L1_new_path_dials_and_clears_the_old_connection(self):
        out = self.js("""
          toOpen();
          go(snap("network", {wifiEnabled: true}));
          const pending = call("tok");
          const fx = go({type: "path", path: "/run/dms-2.sock"});
          process.stdout.write(JSON.stringify({kinds: kinds(fx), s, fx}));""")
        kinds = out["kinds"]
        self.assertEqual(kinds[0], "closeRequest")
        self.assertIn("closeEvents", kinds)
        self.assertEqual(kinds[-2:] if "timer" in kinds else kinds[-1:], ["openRequest"] if "timer" not in kinds else ["openRequest", "timer"])
        reply = [e for e in out["fx"] if e["type"] == "reply"][0]
        self.assertEqual((reply["token"], reply["error"]), ("tok", "offline"))
        self.assertIn({"type": "state", "service": "network", "data": None}, out["fx"])
        s = out["s"]
        self.assertEqual((s["phase"], s["attempt"], s["path"], s["capabilities"], s["cache"], s["ev"]),
                         ("connecting", 0, "/run/dms-2.sock", [], {}, "closing"))

    def test_L1_the_same_path_again_does_nothing(self):
        out = self.js("""
          toReady();
          const fx = go({type: "path", path: "/run/dms-1.sock"});
          process.stdout.write(JSON.stringify({fx, phase: s.phase}));""")
        self.assertEqual((out["fx"], out["phase"]), ([], "ready"))

    def test_L2_empty_path_goes_down_with_no_socket_and_no_timer(self):
        out = self.js("""
          toReady();
          const fx = go({type: "path", path: ""});
          process.stdout.write(JSON.stringify({kinds: kinds(fx), s}));""")
        self.assertEqual(out["kinds"][0], "closeRequest")
        s = out["s"]
        self.assertEqual((s["phase"], s["problem"], s["path"], s["timerAt"], s["retryAt"]), ("down", "no-socket", "", None, None))

    def test_L2_before_any_path_only_names_the_problem(self):
        out = self.js("""
          const fx = go({type: "path", path: ""});
          process.stdout.write(JSON.stringify({fx, s}));""")
        self.assertEqual(out["fx"], [])
        self.assertEqual((out["s"]["phase"], out["s"]["problem"]), ("down", "no-socket"))

    def test_L3_request_up_waits_for_the_greeting_for_three_seconds(self):
        out = self.js("""
          go({type: "path", path: "/run/dms-1.sock"});
          const fx = go({type: "requestUp"}, 1500);
          process.stdout.write(JSON.stringify({fx, s}));""")
        self.assertEqual((out["s"]["phase"], out["s"]["greetingAt"]), ("greeting", 4500))
        self.assertEqual(out["fx"], [{"type": "timer", "at": 4500}])

    def test_L4_failed_connect_goes_down_and_backs_off(self):
        out = self.js("""
          go({type: "path", path: "/run/dms-1.sock"});
          const fx = go({type: "requestDown"}, 2000);
          const a = {phase: s.phase, problem: s.problem, retryAt: s.retryAt, attempt: s.attempt};
          go({type: "tick"}, 2100);
          go({type: "requestDown"}, 2100);
          const b = {retryAt: s.retryAt, attempt: s.attempt};
          process.stdout.write(JSON.stringify({a, b, fx}));""")
        self.assertEqual(out["a"], {"phase": "down", "problem": "offline", "retryAt": 2100, "attempt": 1})
        self.assertEqual(out["b"], {"retryAt": 2300, "attempt": 2})
        self.assertEqual(out["fx"], [{"type": "timer", "at": 2100}])

    def test_L4_backoff_steps_to_two_seconds_and_stays(self):
        out = self.js("process.stdout.write(JSON.stringify([0,1,2,3,4,5,6,50].map(backoff)));")
        self.assertEqual(out, [100, 200, 400, 800, 1600, 2000, 2000, 2000])

    def test_L5_tick_at_the_retry_time_dials_again(self):
        out = self.js("""
          go({type: "path", path: "/run/dms-1.sock"});
          go({type: "requestDown"}, 2000);
          const early = go({type: "tick"}, 2050);
          const fx = go({type: "tick"}, 2100);
          process.stdout.write(JSON.stringify({early, fx, phase: s.phase}));""")
        self.assertEqual([e["type"] for e in out["early"]], ["timer"])    # not yet: re-armed, nothing else
        self.assertEqual([e["type"] for e in out["fx"]], ["openRequest", "timer"])
        self.assertEqual(out["fx"][0]["path"], "/run/dms-1.sock")
        self.assertEqual(out["phase"], "connecting")

    def test_L6_old_dms_is_unsupported_and_the_socket_stays_open(self):
        out = self.js("""
          toGreeting();
          const fx = go({type: "line", msg: {apiVersion: 37, capabilities: ["network"]}});
          process.stdout.write(JSON.stringify({fx, s}));""")
        self.assertEqual((out["s"]["phase"], out["s"]["problem"], out["s"]["greetingAt"]), ("unsupported", "too-old", None))
        self.assertNotIn("closeRequest", [e["type"] for e in out["fx"]])
        self.assertNotIn("settleSoon", [e["type"] for e in out["fx"]])

    def test_L7_a_checked_or_newer_dms_is_ready(self):
        out = self.js("""
          toGreeting();
          const fx = go({type: "line", msg: GREETING});
          const a = {phase: s.phase, untested: s.untested, attempt: s.attempt, caps: s.capabilities, kinds: kinds(fx)};
          go({type: "path", path: "/run/dms-2.sock"});
          go({type: "requestUp"});
          go({type: "line", msg: {apiVersion: 39, capabilities: []}});
          process.stdout.write(JSON.stringify({a, newer: {phase: s.phase, untested: s.untested}}));""")
        self.assertEqual(out["a"]["phase"], "ready")
        self.assertFalse(out["a"]["untested"])
        self.assertEqual(out["a"]["caps"], ["network", "brightness", "bluetooth"])
        self.assertIn("settleSoon", out["a"]["kinds"])
        self.assertEqual(out["newer"], {"phase": "ready", "untested": True})

    def test_L7_resets_the_attempt_counter(self):
        out = self.js("""
          go({type: "path", path: "/run/dms-1.sock"});
          go({type: "requestDown"}, 2000); go({type: "tick"}, 2100);
          go({type: "requestUp"}); go({type: "line", msg: GREETING});
          process.stdout.write(JSON.stringify(s.attempt));""")
        self.assertEqual(out, 0)

    def test_L8_a_first_line_that_is_not_a_greeting_is_a_protocol_problem(self):
        for line in ('{id: 1, result: {}}', '{apiVersion: "38"}', "null", '"hello"'):
            out = self.js(f"""
              toGreeting();
              const fx = go({{type: "line", msg: {line}}});
              process.stdout.write(JSON.stringify({{phase: s.phase, problem: s.problem}}));""")
            self.assertEqual(out, {"phase": "unsupported", "problem": "protocol"}, line)

    def test_L9_no_greeting_in_time_closes_and_retries(self):
        out = self.js("""
          go({type: "path", path: "/run/dms-1.sock"});
          go({type: "requestUp"}, 2000);
          const early = go({type: "tick"}, 4999);
          const fx = go({type: "tick"}, 5000);
          process.stdout.write(JSON.stringify({early: kinds(early), kinds: kinds(fx), s}));""")
        self.assertEqual(out["early"], ["timer"])
        self.assertEqual(out["kinds"], ["closeRequest", "timer"])
        s = out["s"]
        self.assertEqual((s["phase"], s["problem"], s["retryAt"], s["attempt"]), ("down", "offline", 5100, 1))

    def test_L10_losing_the_request_socket_clears_everything_in_every_live_phase(self):
        setups = {"greeting": "toGreeting();", "ready": "toReady();", "unsupported": "toGreeting(); go({type:'line', msg:{apiVersion: 1}});"}
        for phase, setup in setups.items():
            out = self.js(f"""
              {setup}
              const fx = go({{type: "requestDown"}}, 3000);
              process.stdout.write(JSON.stringify({{kinds: kinds(fx), s}}));""")
            s = out["s"]
            self.assertEqual((s["phase"], s["problem"], s["capabilities"], s["cache"]), ("down", "offline", [], {}), phase)
            self.assertEqual(s["retryAt"], 3100, phase)
            self.assertIn("closeRequest", out["kinds"], phase)

    def test_L10_fails_the_pending_requests_and_gives_feeds_null(self):
        out = self.js("""
          toOpen();
          go(snap("network", {wifiEnabled: true}));
          call("a"); call("b");
          const fx = go({type: "requestDown"}, 3000);
          process.stdout.write(JSON.stringify({fx, ev: s.ev}));""")
        replies = [(e["token"], e["error"]) for e in out["fx"] if e["type"] == "reply"]
        self.assertEqual(replies, [("a", "offline"), ("b", "offline")])
        self.assertIn({"type": "closeEvents"}, out["fx"])
        self.assertIn({"type": "state", "service": "network", "data": None}, out["fx"])
        self.assertEqual(out["ev"], "closing")

    # ---- R: requests ------------------------------------------------------------------------------------

    def test_R1_a_call_in_ready_gets_an_id_a_deadline_and_a_timer(self):
        out = self.js("""
          toReady();
          const a = call("one", "network.getState", undefined);
          const b = go({type: "call", token: "two", method: "m", params: {x: 1}, timeoutMs: 500}, 1200);
          process.stdout.write(JSON.stringify({a, b, pending: s.pending}));""")
        self.assertEqual(out["a"], [{"type": "sendRequest", "id": 1, "method": "network.getState", "params": {}},
                                    {"type": "timer", "at": 11000}])
        self.assertEqual(out["b"], [{"type": "sendRequest", "id": 2, "method": "m", "params": {"x": 1}}, {"type": "timer", "at": 1700}])
        self.assertEqual(out["pending"]["2"]["deadline"], 1700)

    def test_R1_ids_restart_at_one_on_each_connection(self):
        out = self.js("""
          toReady(); call("a"); call("b");
          go({type: "path", path: "/run/dms-2.sock"}); go({type: "requestUp"}); go({type: "line", msg: GREETING});
          const fx = call("c");
          process.stdout.write(JSON.stringify(of(fx, "sendRequest")[0].id));""")
        self.assertEqual(out, 1)

    def test_R2_a_call_while_not_ready_fails_at_once_and_sends_nothing(self):
        for setup in ("", "go({type:'path', path:'/run/x.sock'});", "toGreeting();", "toGreeting(); go({type:'line', msg:{apiVersion: 1}});"):
            out = self.js(f"""
              {setup}
              const fx = call("tok");
              process.stdout.write(JSON.stringify(fx));""")
            self.assertEqual(out, [{"type": "reply", "token": "tok", "result": None, "error": "offline"}], setup)

    def test_R3_a_reply_with_a_pending_id_answers_the_caller_once(self):
        out = self.js("""
          toReady();
          call("ok"); call("bad");
          const a = go({type: "line", msg: {id: 1, result: {enabled: true}}});
          const b = go({type: "line", msg: {id: 2, error: "no such thing"}});
          const again = go({type: "line", msg: {id: 1, result: {}}});
          process.stdout.write(JSON.stringify({a, b, again, pending: s.pending}));""")
        self.assertEqual(out["a"][0], {"type": "reply", "token": "ok", "result": {"enabled": True}, "error": ""})
        self.assertEqual(out["b"][0], {"type": "reply", "token": "bad", "result": None, "error": "no such thing"})
        self.assertEqual(out["again"], [])
        self.assertEqual(out["pending"], {})

    def test_R4_a_reply_with_an_unknown_id_is_ignored(self):
        out = self.js("""
          toReady(); call("a");
          const fx = go({type: "line", msg: {id: 99, result: {}}});
          const stray = go({type: "line", msg: {service: "x"}});
          process.stdout.write(JSON.stringify({fx, stray, pending: Object.keys(s.pending)}));""")
        self.assertEqual((out["fx"], out["stray"], out["pending"]), ([], [], ["1"]))

    def test_R5_a_missed_deadline_answers_timeout_and_a_late_reply_is_ignored(self):
        out = self.js("""
          toReady();
          call("slow", "m", 500); call("fast", "m", 5000);
          const fx = go({type: "tick"}, 1500);
          const late = go({type: "line", msg: {id: 1, result: {}}});
          process.stdout.write(JSON.stringify({fx, late, pending: Object.keys(s.pending)}));""")
        self.assertEqual(out["fx"][0], {"type": "reply", "token": "slow", "result": None, "error": "timeout"})
        self.assertEqual(out["fx"][1], {"type": "timer", "at": 6000})
        self.assertEqual((out["late"], out["pending"]), ([], ["2"]))

    # ---- S: the event connection ------------------------------------------------------------------------

    def test_S1_feeds_register_and_unregister_and_ask_for_a_settle(self):
        out = self.js("""
          const a = feed("net", "network", "network");
          const b = go({type: "unfeed", key: "net"});
          process.stdout.write(JSON.stringify({a, b, feeds: s.feeds}));""")
        self.assertEqual(out["a"], [{"type": "settleSoon"}])
        self.assertEqual(out["b"], [{"type": "settleSoon"}])
        self.assertEqual(out["feeds"], {})

    def test_S2_settle_with_wanted_feeds_opens_the_event_connection(self):
        out = self.js("""
          toReady(); feed("net", "network", "network");
          const fx = go({type: "settle"});
          process.stdout.write(JSON.stringify({fx, ev: s.ev}));""")
        self.assertEqual(out["fx"], [{"type": "openEvents", "path": "/run/dms-1.sock"}])
        self.assertEqual(out["ev"], "opening")

    def test_S2_no_feeds_or_unwanted_or_missing_capability_means_no_event_connection(self):
        for setup in ("", "feed('a','network','network',false);", "feed('a','gamma','gamma');", "feed('a','network','network'); go({type:'path', path:''});"):
            out = self.js(f"""
              toReady(); {setup}
              const fx = go({{type: "settle"}});
              process.stdout.write(JSON.stringify({{kinds: kinds(fx), ev: s.ev}}));""")
            self.assertNotIn("openEvents", out["kinds"], setup)

    def test_S3_events_up_subscribes_with_the_service_list(self):
        out = self.js("""
          toReady(); feed("n", "network", "network"); feed("b", "brightness", "brightness"); feed("n2", "network", "network");
          go({type: "settle"});
          const fx = go({type: "eventsUp"});
          process.stdout.write(JSON.stringify({fx, s}));""")
        self.assertEqual(out["fx"], [{"type": "sendEvents", "msg": {
            "id": 1, "method": "subscribe", "params": {"clientId": "test", "services": ["brightness", "network"]}}}])
        self.assertEqual((out["s"]["ev"], out["s"]["subscribed"]), ("open", ["brightness", "network"]))

    def test_S3_if_the_feeds_left_while_dialling_nothing_is_subscribed(self):
        out = self.js("""
          toReady(); feed("n", "network", "network"); go({type: "settle"});
          go({type: "unfeed", key: "n"});
          const fx = go({type: "eventsUp"});
          process.stdout.write(JSON.stringify({fx, ev: s.ev}));""")
        self.assertEqual(out["fx"], [{"type": "closeEvents"}])
        self.assertEqual(out["ev"], "closing")

    def test_S4_a_changed_list_closes_the_connection_and_drops_what_left(self):
        out = self.js("""
          toOpen([["n", "network", "network"], ["b", "brightness", "brightness"]]);
          go(snap("network", {a: 1})); go(snap("brightness", {b: 2}));
          go({type: "unfeed", key: "b"});
          const fx = go({type: "settle"});
          process.stdout.write(JSON.stringify({fx, ev: s.ev, cache: s.cache}));""")
        self.assertEqual(out["fx"], [{"type": "state", "service": "brightness", "data": None}, {"type": "closeEvents"}])
        self.assertEqual((out["ev"], out["cache"]), ("closing", {"network": {"a": 1}}))

    def test_S4_a_longer_list_also_redials(self):
        out = self.js("""
          toOpen();
          feed("b", "brightness", "brightness");
          const fx = go({type: "settle"});
          process.stdout.write(JSON.stringify({kinds: kinds(fx), ev: s.ev}));""")
        self.assertEqual((out["kinds"], out["ev"]), (["closeEvents"], "closing"))

    def test_S5_after_close_a_nonempty_list_dials_again_and_an_empty_one_does_not(self):
        out = self.js("""
          toOpen(); feed("b", "brightness", "brightness"); go({type: "settle"});
          const again = go({type: "eventsDown"});
          const a = {kinds: kinds(again), ev: s.ev};
          go({type: "eventsUp"});
          go({type: "unfeed", key: "b"}); go({type: "unfeed", key: "net"});
          go({type: "settle"});
          const none = go({type: "eventsDown"});
          process.stdout.write(JSON.stringify({a, none, ev: s.ev}));""")
        self.assertEqual(out["a"], {"kinds": ["openEvents"], "ev": "opening"})
        self.assertEqual((out["none"], out["ev"]), ([], "closed"))

    def test_S6_the_same_list_does_nothing(self):
        out = self.js("""
          toOpen();
          feed("again", "network", "network");
          const fx = go({type: "settle"});
          process.stdout.write(JSON.stringify({fx, ev: s.ev}));""")
        self.assertEqual((out["fx"], out["ev"]), ([], "open"))

    def test_S7_an_unasked_drop_retries_with_backoff_and_keeps_the_last_snapshots(self):
        out = self.js("""
          toOpen(); go(snap("network", {a: 1}));
          const fx = go({type: "eventsDown"}, 2000);
          const a = {fx, ev: s.ev, retryAt: s.evRetryAt, cache: s.cache};
          const early = go({type: "tick"}, 2050);
          const retry = go({type: "tick"}, 2100);
          go({type: "eventsDown"}, 2100);
          process.stdout.write(JSON.stringify({a, early: kinds(early), retry: kinds(retry), next: s.evRetryAt}));""")
        self.assertEqual(out["a"]["ev"], "closed")
        self.assertEqual(out["a"]["retryAt"], 2100)
        self.assertEqual(out["a"]["cache"], {"network": {"a": 1}})
        self.assertEqual(out["a"]["fx"], [{"type": "timer", "at": 2100}])
        self.assertEqual(out["early"], ["timer"])
        self.assertEqual(out["retry"], ["openEvents", "timer"])
        self.assertEqual(out["next"], 2300)

    def test_S7_a_failed_dial_is_the_same_drop(self):
        out = self.js("""
          toReady(); feed("n", "network", "network"); go({type: "settle"});
          go({type: "eventsDown"}, 2000);
          process.stdout.write(JSON.stringify({ev: s.ev, retryAt: s.evRetryAt}));""")
        self.assertEqual(out, {"ev": "closed", "retryAt": 2100})

    def test_S8_a_server_event_updates_the_version_and_capabilities(self):
        out = self.js("""
          toOpen();
          const fx = go(snap("server", {apiVersion: 38, cliVersion: "v0.0.0-test", capabilities: ["network", "gamma"]}));
          const a = {fx, caps: s.capabilities, cli: s.cliVersion, phase: s.phase};
          go(snap("server", {apiVersion: 41, cliVersion: "v9.9.9-test", capabilities: ["network"]}));
          const b = {phase: s.phase, untested: s.untested};
          go(snap("server", {apiVersion: 12, capabilities: ["network"]}));
          process.stdout.write(JSON.stringify({a, b, c: {phase: s.phase, problem: s.problem}}));""")
        self.assertEqual(out["a"]["caps"], ["network", "gamma"])
        self.assertEqual((out["a"]["cli"], out["a"]["phase"]), ("v0.0.0-test", "ready"))
        self.assertIn({"type": "settleSoon"}, out["a"]["fx"])
        self.assertEqual(out["b"], {"phase": "ready", "untested": True})
        self.assertEqual(out["c"], {"phase": "unsupported", "problem": "too-old"})

    def test_S8_a_capability_that_appears_later_makes_a_waiting_feed_dial(self):
        out = self.js("""
          toOpen(); feed("g", "gamma", "gamma");
          const a = go({type: "settle"});             // gamma is not offered yet: the list is unchanged
          go(snap("server", {apiVersion: 38, capabilities: ["network", "gamma"]}));
          const b = go({type: "settle"});
          process.stdout.write(JSON.stringify({a: kinds(a), b: kinds(b)}));""")
        self.assertEqual((out["a"], out["b"]), ([], ["closeEvents"]))

    def test_S9_a_changed_snapshot_is_cached_and_passed_on_and_a_repeat_is_not(self):
        out = self.js("""
          toOpen();
          const a = go(snap("network", {wifiEnabled: true, list: [1, 2]}));
          const same = go(snap("network", {wifiEnabled: true, list: [1, 2]}));
          const changed = go(snap("network", {wifiEnabled: false, list: [1, 2]}));
          process.stdout.write(JSON.stringify({a, same, changed, cache: s.cache}));""")
        self.assertEqual(out["a"], [{"type": "state", "service": "network", "data": {"wifiEnabled": True, "list": [1, 2]}}])
        self.assertEqual(out["same"], [])
        self.assertEqual(out["changed"][0]["data"]["wifiEnabled"], False)
        self.assertEqual(out["cache"], {"network": {"wifiEnabled": False, "list": [1, 2]}})

    def test_S10_error_events_and_unsubscribed_services_are_logged_and_ignored(self):
        out = self.js("""
          toOpen();
          const a = go({type: "eventLine", msg: {id: 1, error: "subscribe failed"}});
          const b = go(snap("clipboard", {history: []}));
          const c = go({type: "eventLine", msg: {nonsense: true}});
          process.stdout.write(JSON.stringify({a: kinds(a), b: kinds(b), c: kinds(c), ev: s.ev, cache: s.cache}));""")
        self.assertEqual((out["a"], out["b"], out["c"]), (["log"], ["log"], ["log"]))
        self.assertEqual((out["ev"], out["cache"]), ("open", {}))

    def test_S10_the_greeting_DMS_sends_on_the_event_connection_is_ignored_quietly(self):
        out = self.js("""
          toOpen();
          const fx = go({type: "eventLine", msg: {apiVersion: 38, capabilities: ["network"]}});
          process.stdout.write(JSON.stringify({fx, caps: s.capabilities}));""")
        self.assertEqual(out["fx"], [])
        self.assertEqual(out["caps"], ["network", "brightness", "bluetooth"])

    def test_S11_a_settle_while_dialling_or_closing_is_only_noted(self):
        out = self.js("""
          toReady(); feed("n", "network", "network"); go({type: "settle"});            // opening
          feed("b", "brightness", "brightness");
          const opening = go({type: "settle"});
          go({type: "eventsUp"});                                                       // subscribes: network, brightness
          feed("g", "gamma", "gamma"); go({type: "settle"});                           // wait: gamma absent, no change
          go({type: "unfeed", key: "b"});
          const redial = go({type: "settle"});                                         // closing
          feed("n3", "network", "network");
          const closing = go({type: "settle"});
          process.stdout.write(JSON.stringify({opening, redial: kinds(redial), closing, ev: s.ev}));""")
        self.assertEqual(out["opening"], [])
        self.assertEqual((out["redial"], out["closing"], out["ev"]), (["closeEvents"], [], "closing"))

    # ---- invariants -------------------------------------------------------------------------------------

    def test_a_subscribe_never_goes_out_without_services(self):
        out = self.js("""
          toReady(); feed("n", "network", "network"); go({type: "settle"});
          go({type: "eventsUp"});
          go({type: "unfeed", key: "n"}); go({type: "settle"}); go({type: "eventsDown"});
          feed("x", "network", "network", false); go({type: "settle"});
          feed("y", "gamma", "gamma"); go({type: "settle"});
          go({type: "path", path: "/run/dms-2.sock"}); go({type: "requestUp"}); go({type: "line", msg: GREETING});
          go({type: "settle"});
          const subs = all.filter(e => e.type === "sendEvents");
          process.stdout.write(JSON.stringify(subs.map(e => e.msg.params.services)));""")
        self.assertEqual(out, [["network"]])

    def test_at_most_one_event_connection_is_open_or_opening(self):
        out = self.js("""
          toReady();
          let open = 0, worst = 0;
          const track = fx => { for (const e of fx) { if (e.type === "openEvents") open++; if (e.type === "closeEvents") open--; worst = Math.max(worst, open); } };
          const run = ev => track(go(ev));
          run({type: "feed", key: "n", service: "network", capability: "network", wanted: true});
          run({type: "settle"}); run({type: "eventsUp"});
          run({type: "feed", key: "b", service: "brightness", capability: "brightness", wanted: true});
          run({type: "settle"}); run({type: "settle"}); run({type: "eventsDown"}); run({type: "eventsUp"});
          run({type: "unfeed", key: "b"}); run({type: "settle"}); run({type: "eventsDown"}); run({type: "eventsUp"});
          run({type: "eventsDown"}, 5000); run({type: "tick"}, 9000); run({type: "eventsUp"});
          process.stdout.write(JSON.stringify(worst));""")
        self.assertEqual(out, 1)

    def test_every_pending_request_is_answered_exactly_once(self):
        out = self.js("""
          toReady();
          call("a"); call("b", "m", 100); call("c"); call("d");
          go({type: "line", msg: {id: 1, result: 1}});
          go({type: "tick"}, 1200);
          go({type: "line", msg: {id: 2, result: 2}});          // late: after its timeout
          go({type: "line", msg: {id: 3, error: "x"}});
          go({type: "requestDown"}, 1300);
          go({type: "line", msg: {id: 4, result: 4}});          // after the drop
          const counts = {};
          for (const e of all.filter(e => e.type === "reply")) counts[e.token] = (counts[e.token] || 0) + 1;
          process.stdout.write(JSON.stringify({counts, pending: s.pending}));""")
        self.assertEqual(out["counts"], {"a": 1, "b": 1, "c": 1, "d": 1})
        self.assertEqual(out["pending"], {})

    def test_no_timer_runs_in_ready_with_nothing_pending(self):
        out = self.js("""
          toReady();
          const idle = {at: s.timerAt};
          call("a");
          const busy = s.timerAt;
          go({type: "line", msg: {id: 1, result: {}}});
          toOpen();
          const stateAfter = s.timerAt;
          process.stdout.write(JSON.stringify({idle, busy, after: stateAfter, last: all.filter(e => e.type === "timer").pop()}));""")
        self.assertEqual(out["idle"], {"at": None})
        self.assertEqual(out["busy"], 11000)
        self.assertIsNone(out["after"])
        self.assertEqual(out["last"], {"type": "timer", "at": None})

    def test_the_machine_is_pure(self):
        out = self.js("""
          toOpen();
          call("a");
          const before = JSON.stringify(s);
          const copy = JSON.parse(before);
          const r1 = step(copy, snap("network", {x: 1}), 2000);
          const r2 = step(copy, snap("network", {x: 1}), 2000);
          process.stdout.write(JSON.stringify({untouched: JSON.stringify(copy) === before, same: JSON.stringify(r1) === JSON.stringify(r2)}));""")
        self.assertEqual(out, {"untouched": True, "same": True})

    def test_the_two_version_constants(self):
        out = self.js("process.stdout.write(JSON.stringify([minApi(), checkedApi()]));")
        self.assertEqual(out, [38, 38])


if __name__ == "__main__":
    unittest.main()
