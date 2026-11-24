"""fartd-cpp, stage 0 (Z226, docs/CPP_CORE.md): what the parity scenarios don't reach on their own.

- The op table (core-cpp/src/op_table.inc) is the Python core's registry as it is now.
- The JSON writer equals Python's on the corpus (core-cpp's json-check).
- Protocol edges, byte for byte against the Python core: argument binding's order and wording, odd ids, repeated
  keys, invalid UTF-8 and surrogates, number forms, repr's quoting in messages, the output limit.
- Its own safety rails: SIGTERM right after start, only the fixture host runs, FART_FIXTURE_EPOCH.

The cross-core and binary checks skip until core-cpp/build has been built
(cmake -S core-cpp -B core-cpp/build -G Ninja && cmake --build core-cpp/build).
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import socket
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]

from parity.harness import Core, CoreGone  # noqa: E402

BUILD = ROOT / "core-cpp/build"
FARTD_CPP = BUILD / "fartd-cpp"
JSON_CHECK = BUILD / "json-check"
built = unittest.skipUnless(FARTD_CPP.is_file() and os.access(FARTD_CPP, os.X_OK), "fartd-cpp not built")

# Sent after hello; every reply must be byte-equal between the cores. Only ops whose reply doesn't depend on a
# port (protocol errors, binding errors, unknown ops, subscribe/unsubscribe on fixed topics).
AFTER_HELLO = [
    # unknown ops, quoted as repr() quotes them
    b'{"id":1,"op":"egg"}', b'{"id":2,"op":"it\'s"}', b'{"id":3,"op":"say \\"hi\\""}', b'{"id":4,"op":"both \' \\""}',
    b'{"id":5,"op":"tab\\there\\nnl\\\\"}', '{"id":6,"op":"naïve"}'.encode(), b'{"id":7,"op":"\\u00a0nbsp"}',
    b'{"id":8,"op":"\\u200bzw"}', b'{"id":9,"op":"\\ud83d\\ude00"}', b'{"id":10,"op":"\\u007f\\u0001\\u0085"}',
    b'{"id":11,"op":""}', b'{"id":12,"op":"\\u00ad\\u2028\\ue000"}',
    # binding: the peer twice, then the first missing, then the first unexpected
    b'{"id":20,"op":"subscribe","args":{"client":1,"topics":[]}}', b'{"id":21,"op":"task.add","args":{"peer":1}}',
    b'{"id":22,"op":"timer.start","args":{}}', b'{"id":23,"op":"timer.start","args":{"bogus":1}}',
    b'{"id":24,"op":"timer.start","args":{"kind":"countdown","zz":1,"bogus":2}}',
    b'{"id":25,"op":"hello","args":{"protocol":1,"client":"cli","pid":1,"x":2}}', b'{"id":26,"op":"hello"}',
    b'{"id":27,"op":"task.update","args":{}}', b'{"id":28,"op":"cmd.history","args":{"limit":1,"x":1}}',
    # subscribe and unsubscribe (Python's TypeError for an unhashable topic is an internal error)
    b'{"id":30,"op":"subscribe","args":{"topics":[[1]]}}', b'{"id":31,"op":"subscribe","args":{"topics":[1]}}',
    b'{"id":32,"op":"subscribe","args":{"topics":["nope",[1]]}}', b'{"id":33,"op":"subscribe","args":{"topics":{}}}',
    b'{"id":34,"op":"subscribe","args":{"topics":["supervisor","supervisor"]}}',
    b'{"id":35,"op":"subscribe","args":{"topics":[]}}', b'{"id":36,"op":"unsubscribe","args":{"topics":[[1]]}}',
    b'{"id":37,"op":"unsubscribe","args":{"topics":[1,"x"]}}', b'{"id":38,"op":"unsubscribe","args":{"topics":null}}',
    # request shapes
    b'{"id":40,"op":"egg","args":null}', b'{"id":41,"op":"egg","args":"x"}', b'{"id":42,"op":"egg","args":[]}',
    b'{"id":43}', b'{"id":44,"op":null}', b'{"id":45,"op":["egg"]}', b'{"id":46,"op":"egg","id":47}',
    b'{"op":"nope","id":48,"op":"egg"}', b' \t{"id" : 49 , "op" : "egg" }\r', b'{"id":50,"op":"egg","args":{"a":1,"a":2}}',
    # ids are echoed whatever their JSON
    b'{"id":NaN,"op":"egg"}', b'{"id":Infinity,"op":"egg"}', b'{"id":-Infinity,"op":"egg"}', b'{"id":-0.0,"op":"egg"}',
    b'{"id":-0,"op":"egg"}', b'{"id":1e16,"op":"egg"}', b'{"id":1E+2,"op":"egg"}', b'{"id":1e400,"op":"egg"}',
    b'{"id":1180591620717411303424,"op":"egg"}', b'{"id":-9223372036854775809,"op":"egg"}', b'{"id":0.1,"op":"egg"}',
    b'{"id":5e-324,"op":"egg"}', b'{"id":123456789012345678,"op":"egg"}', b'{"id":"","op":"egg"}', b'{"id":true,"op":"egg"}',
    b'{"id":false,"op":"egg"}', b'{"id":{"a":[1,{"b":null}],"":[]},"op":"egg"}', '{"id":"naïve 🪐  ","op":"egg"}'.encode(),
    b'{"id":"\\u0000\\u001f\\"\\\\\\/","op":"egg"}', b'{"id":' + b"[" * 60 + b"]" * 60 + b',"op":"egg"}',
    # not JSON (each answered with id null)
    b"\xef\xbb\xbf{}", b'{"id":60,"op":"\xff"}', b'{"id":61,"op":"\xc0\xaf"}', b'{"id":62,"op":"\xed\xa0\x80"}',
    b'{"id":63,"op":"a\x01"}', b'{"id":64,"op":"\\udc00"}', b'{"id":65,"op":"\\ud800\\u0041"}', b'{"id":01,"op":"egg"}',
    b'{"id":1.,"op":"egg"}', b'{"id":-,"op":"egg"}', b'{"id":1,"op":"egg",}', b'{"id":1,"op":"egg"} x', b"",
    b"{'id':1}", b'{"id":1,"op":"egg\\x"}', b'{"id":nan,"op":"egg"}', b'{"id":"\\u12"}',
    # not requests: nothing comes back
    b"[1]", b"5", b'"text"', b"null", b'{"op":"egg"}', b'{"id":null,"op":"egg"}', b'{"op":"hello","args":{}}',
]


def exchange(which: str, lines: list[bytes], hello: bool = True) -> list[bytes]:
    """Every raw line the core sends back for these lines, up to the reply to a final sentinel request."""
    with Core(which) as core:
        peer = core.client() if hello else core.connect()
        with peer:
            return _collect(peer, lines)


def _collect(peer, lines: list[bytes]) -> list[bytes]:
    peer.send_raw(b"".join(line + b"\n" for line in lines) + b'{"id":"end","op":"egg"}\n')
    got = []
    while not got or json.loads(got[-1]).get("id") != "end":
        if len(got) > 4 * len(lines) + 10:
            raise AssertionError("no end reply")
        got.append(peer.read_line())
    return got


def masked_hello(line: bytes) -> dict:
    reply = json.loads(line)
    core = reply.get("result", {}).get("core")
    if isinstance(core, dict):
        core["pid"], core["startedAt"] = "<pid>", "<ms>"
    return reply


class OpTable(unittest.TestCase):
    def test_table_is_current(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/cpp_op_table.py"), "--check"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


@unittest.skipUnless(JSON_CHECK.is_file(), "json-check not built")
class JsonWriter(unittest.TestCase):
    def test_corpus(self):
        result = subprocess.run([str(JSON_CHECK), str(ROOT / "tests/parity/json_corpus.json")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("all equal", result.stdout)


@built
class ProtocolEdges(unittest.TestCase):
    maxDiff = None

    def test_replies_byte_equal(self):
        python, cpp = exchange("python", AFTER_HELLO), exchange(str(FARTD_CPP), AFTER_HELLO)
        for i, (a, b) in enumerate(zip(python, cpp)):
            self.assertEqual(a, b, f"reply {i}")
        self.assertEqual(len(python), len(cpp))

    def test_before_hello(self):
        lines = [b'{"id":1,"op":"egg"}', b'{"id":2,"op":"status"}', b'{"id":3,"op":"hello","args":{"client":"cli"}}',
                 b'{"id":4,"op":"hello","args":{"peer":0,"client":"cli","protocol":1}}',
                 b'{"id":5,"op":"hello","args":{"client":"cli","protocol":"1"}}',
                 b'{"id":6,"op":"hello","args":{"client":["cli"],"protocol":1}}',
                 b'{"id":7,"op":"hello","args":{"client":"view","protocol":1.0}}',
                 b'{"id":8,"op":"hello","args":{"client":"robot","protocol":2}}', b'not json']
        self.assertEqual(exchange("python", lines, hello=False), exchange(str(FARTD_CPP), lines, hello=False))

    def test_hello_accepts_what_python_accepts(self):
        for args in ('{"client":"cli","protocol":1.0}', '{"client":"cli","protocol":true}', '{"protocol":1,"client":"cli","pid":7}'):
            line = b'{"id":1,"op":"hello","args":' + args.encode() + b"}"
            got = {which: [masked_hello(x) for x in exchange(which, [line], hello=False)] for which in ("python", str(FARTD_CPP))}
            self.assertEqual(got["python"], got[str(FARTD_CPP)], args)
            self.assertTrue(got["python"][0]["ok"], args)

    def test_output_limit_drops_only_that_client(self):
        """A client that never reads: past 4 MiB of unsent replies the core lets it go and serves the others.
        Big replies (an unknown op's name comes back in its message) reach the limit in a few dozen requests."""
        def run(which):
            with Core(which) as core:
                greedy = core.client()
                greedy.sock.settimeout(20)
                line = b'{"id":1,"op":"' + b"x" * 100_000 + b'"}\n'
                try:
                    for _ in range(80):  # ~8 MB of replies, never read
                        greedy.send_raw(line)
                except (BrokenPipeError, ConnectionResetError):
                    pass
                log = core.runtime / "core.log"
                deadline = time.monotonic() + 10
                while "over the output limit" not in log.read_text() and time.monotonic() < deadline:
                    time.sleep(0.05)
                other = core.client()
                return other.call("hello", client="cli", protocol=1)["ok"], "over the output limit" in log.read_text()
        for which in ("python", str(FARTD_CPP)):
            self.assertEqual(run(which), (True, True), which)


def tasks_edges(which: str) -> list[str]:
    """Task ops at their edges; replies and tasks.json with random ids aliased and times tagged."""
    import re
    aliases: dict[str, str] = {}

    def norm(text: str) -> str:
        text = re.sub(r'"(created|doneAt)":\d+', r'"\1":<ms>', text)
        return re.sub(r"\b[tl][0-9a-f]{8}\b", lambda m: aliases.setdefault(m.group(), f"{m.group()[0]}#{len(aliases) + 1}"), text)

    out = []
    with Core(which) as core, core.client() as peer:
        def call(op, **args):
            peer.send({"id": len(out), "op": op, "args": args})
            line = peer.read_line().decode()
            out.append(norm(line))
            return json.loads(line)
        a = call("task.add", text="  first \u3000\x1c")["result"]["task"]["id"]
        b = call("task.add", text="é" * 1000, due="2024-02-29")["result"]["task"]["id"]
        call("task.add", text="🪐" * 1001)
        for text in ("", " \u2028 ", 5, None, ["x"]):
            call("task.add", text=text)
        for due in ("2026-02-29", "0000-01-01", "2026-11-25\n", "\u0662\u0660\u0662\u0666-11-25", "2026-11-25T24:00",
                    "9999-12-31T24:00", "2026-11-25T24:01", "2026-11-25T23:60", "2026-11-25t10:00", "2026-1-25", 20261125, ""):
            call("task.add", text="d", due=due)
        for lst in (0, "", [], False, None, [1], "nope", {"a": 1}, 1.5):
            call("task.add", text="l", list=lst)
        for index in (0, True, -1, 1.0, 10 ** 30, -(10 ** 30), "0", None, 1):
            call("task.add", text="i", index=index)
        work = call("list.add", name="  Work ")["result"]["list"]["id"]
        call("list.add", name="x" * 65)
        call("list.rename", id=work, name="Jobs")
        call("list.rename", id="nope", name="Jobs")
        call("task.update", id=a, text="renamed", done=True, due="2026-12-01", list=work)
        call("task.update", id=a, zeta=1, alpha=2, text="x")
        call("task.update", id=a, done=1)
        call("task.update", id=a, done=False, due=None, list=None, text=None)
        call("task.update", id="t00000000")
        call("task.update", id=7)
        call("task.move", id=b, index=0)
        call("task.move", id=b, index=-2)
        call("task.move", id=b, index=None)
        removed = call("task.remove", id=a)["result"]
        call("task.restore", task=removed["task"], index=removed["index"])
        call("task.restore", task=removed["task"])
        call("task.restore", task={"id": "t0000000g", "text": "x"})
        call("task.restore", task={"id": "tabcdef01", "text": "back", "list": "gone", "done": 1, "created": True, "doneAt": 2.5})
        call("task.restore", task={"id": "tabcdef02", "text": "", "due": "bad"})
        call("task.restore", task=[1])
        call("list.remove", id="default")
        call("list.remove", id=work)
        call("list.remove", id=work)
        out.append(json.dumps(peer.request("status")["tasks"]))  # the tasks summary; the rest is other stages'
        out.append(norm(core.state_bytes("tasks.json").decode()))
    return out


@built
class TasksEdges(unittest.TestCase):
    maxDiff = None

    def test_tasks_byte_equal(self):
        """Replies and tasks.json, byte for byte (ids aliased, times tagged), at the validators' edges."""
        python, cpp = tasks_edges("python"), tasks_edges(str(FARTD_CPP))
        for i, (a, b) in enumerate(zip(python, cpp)):
            self.assertEqual(a, b, f"step {i}")
        self.assertEqual(len(python), len(cpp))

    def test_state_files_at_start(self):
        """What a start leaves behind for each kind of file it finds (state_files byte for byte)."""
        seeds = [{"tasks.json": '{"version":1,"lists":[{"id":"x","name":"X"}],"tasks":[],"extra":"\\u00e9"}'},
                 {"tasks.json": '[]'}, {"tasks.json": '{"tasks":[]}'}, {"tasks.json": '{not json\r\n'},
                 {"todo.json": '[{"content":"  milk  "},{"content":"","done":true},{"content":"x","done":1},5]'},
                 {"todo.json": '{bad'}, {"todo.json": '{"a":1}'},
                 {"tasks.json": '{"tasks":"no"}', "todo.json": '[{"content":"y","done":true}]'}]
        import re
        for seed in seeds:
            got = {}
            for which in ("python", str(FARTD_CPP)):
                with Core(which, seed=seed) as core:
                    core.client().close()
                    files = core.state_files()
                got[which] = {k: re.sub(rb"t[0-9a-f]{8}", b"t#", v) for k, v in files.items() if k.startswith(("tasks", "todo"))}
            self.assertEqual(got["python"], got[str(FARTD_CPP)], seed)


SETTINGS_LINES = [
    b'{"id":1,"op":"island.rest","args":{"item":"inbox","mode":"unread"}}', b'{"id":2,"op":"island.rest","args":{"item":"inbox","mode":"unread"}}',
    b'{"id":3,"op":"island.rest","args":{"item":"power","mode":"dot"}}', b'{"id":4,"op":"island.rest","args":{"item":"cpu","mode":"always"}}',
    b'{"id":5,"op":"island.rest","args":{"item":5,"mode":"always"}}', b'{"id":6,"op":"island.rest","args":{"item":"battery","mode":["always"]}}',
    b'{"id":7,"op":"island.rest","args":{"item":"network","mode":null}}', b'{"id":8,"op":"clips.set","args":{"key":"rows","value":4}}',
    b'{"id":9,"op":"clips.set","args":{"key":"rows","value":11}}', b'{"id":10,"op":"clips.set","args":{"key":"rows","value":true}}',
    b'{"id":11,"op":"clips.set","args":{"key":"rows","value":10.0}}', b'{"id":12,"op":"clips.set","args":{"key":7,"value":true}}',
    b'{"id":13,"op":"clips.set","args":{"key":"enterPastes","value":1}}', b'{"id":14,"op":"clips.set","args":{"key":"showImages","value":false}}',
    '{"id":15,"op":"clips.set","args":{"key":"naïve","value":"é"}}'.encode(), b'{"id":16,"op":"clips.set","args":{"key":null,"value":{"a":[1.5]}}}',
]


@built
class SettingsEdges(unittest.TestCase):
    maxDiff = None

    def test_replies_byte_equal(self):
        self.assertEqual(exchange("python", SETTINGS_LINES), exchange(str(FARTD_CPP), SETTINGS_LINES))

    def test_saved_files(self):
        """What each core makes of what it finds, and what it writes after one change."""
        seeds = [{"island.json": '{"noticeMs":2000.0,"form":"fluid","rest":{"inbox":"dot","cpu":"x","power":"matters"},"screen":"' + "s" * 65 + '","zz":1}'},
                 {"island.json": '{"screen":"DP-1","edge":"left"}'}, {"island.json": '{bad'}, {"island.json": '0'},
                 {"clips.json": '{"rows":11,"enterPastes":true,"x":1}'}, {"clips.json": '[1]'}, {"clips.json": '{bad'}]
        for seed in seeds:
            got = {}
            for which in ("python", str(FARTD_CPP)):
                with Core(which, seed=seed) as core, core.client() as peer:
                    snaps = peer.subscribe("island", "clips")["snapshots"]
                    peer.call("island.rest", item="battery", mode="hover")
                    peer.call("clips.set", key="rows", value=9)
                    files = {k: v for k, v in core.state_files().items() if k.startswith(("island", "clips"))}
                got[which] = (json.dumps(snaps), files)
            self.assertEqual(got["python"], got[str(FARTD_CPP)], seed)

    def test_island_file_not_an_object_gives_defaults(self):
        """Both cores start on defaults (Python stopped on saved.items() until 24 Nov)."""
        for text in ("[1]", "5"):
            seed = {"island.json": text}
            answers = [start_or_gone(which, seed, lambda core, peer: core.state_bytes("island.json"))
                       for which in ("python", str(FARTD_CPP))]
            self.assertNotIn("gone", answers, text)
            self.assertEqual(answers[0], answers[1], text)


def timers_edges(which: str, seed: dict | None = None, steps=True) -> list:
    """Timer ops at their edges: normalised replies (times as type tags), then the host calls and timers.json."""
    from parity.normalise import Normaliser
    norm = Normaliser()
    out = []
    with Core(which, seed=seed or {}) as core, core.client() as peer:
        def call(op, **args):
            reply = peer.call(op, **args)
            out.append(norm(reply.get("error") or reply["result"]))
        if steps:
            for seconds in (0, 0.5, 1, 604800, 604800.5, True, "60", None, [60], float("inf"), float("nan"), 10 ** 30, -(10 ** 30), 10 ** 400):
                call("timer.start", kind="countdown", seconds=seconds)
            for kind in ("Countdown", None, 1, ["countdown"], "pomodoro "):
                call("timer.start", kind=kind, seconds=60)
            call("timer.start", kind="pomodoro", focus=90.5)
            call("timer.start", kind="pomodoro", focus=0)
            call("timer.start", kind="pomodoro", seconds=5, focus=None)
            call("timer.start", kind="stopwatch", seconds="ignored", focus=[1])
            call("timer.lap")
            call("timer.toggle", kind="stopwatch")
            call("timer.lap")
            call("timer.reset", kind="countdown")
            call("timer.toggle", kind="countdown")
            call("timer.add", kind="countdown", seconds=604000)
            call("timer.add", kind="countdown", seconds=1000)
            call("timer.add", kind="pomodoro", seconds=1)
            call("timer.add", kind="nope", seconds="x")
            call("timer.add", kind="countdown", seconds=0)
            for config in ({"pomodoro": {"focus": 59.9}}, {"pomodoro": {"focus": 3600.7, "cycles": 12}}, {"pomodoro": {"cycles": True}},
                           {"pomodoro": {"cycles": 10 ** 20}}, {"pomodoro": {"Focus": 60}}, {"pomodoro": {"focus": 600}, "sound": "yes"},
                           {"pomodoro": {}}, {}, {"pomodoro": None, "sound": None}, {"pomodoro": [1]}, {"sound": True}, {"sound": 0},
                           {"pomodoro": {"focus": 1200}, "sound": "no"}):  # refused whole: the focus change stays out
                call("timer.configure", **config)
            call("timer.reset", kind="pomodoro")
            for kind in (None, "countdown", "pomodoro", "stopwatch", "x"):
                call("timer.ack", kind=kind)
            call("timer.toggle", kind="pomodoro")
            call("timer.toggle", kind="pomodoro")
        out.append(norm(peer.request("status")["timers"]))
        time.sleep(0.3)
        out.append(core.host_calls())
        saved = core.state_bytes("timers.json")
        out.append(norm(_tag_late(json.loads(saved))) if saved else None)  # values with times as type tags
        out.append(sorted(k for k in core.state_files() if k.startswith("timers")))
    return out


def _tag_late(value):
    """`late` (seconds past a deadline) depends on timing too; keep only its type."""
    if isinstance(value, dict):
        return {k: (type(v).__name__ if k == "late" else _tag_late(v)) for k, v in value.items()}
    return [_tag_late(v) for v in value] if isinstance(value, list) else value


def timers_seed(**kinds) -> dict:
    """A version-2 timers.json whose running kinds started on another boot, `ago` seconds back."""
    now = time.time()
    state = {"version": 2, "config": {"pomodoro": {"focus": 1500, "break": 300, "longBreak": 900, "cycles": 4}, "sound": True}}
    for kind, (duration, ago) in kinds.items():
        state[kind] = {"duration": duration, "run": {"running": True, "elapsed": 0.0,
                                                     "anchor": {"boot": 1.0, "real": now - ago, "bootId": "another-boot"}}}
    return {"timers.json": state}


@built
class TimersEdges(unittest.TestCase):
    maxDiff = None

    def test_ops_equal(self):
        python, cpp = timers_edges("python"), timers_edges(str(FARTD_CPP))
        for i, (a, b) in enumerate(zip(python, cpp)):
            self.assertEqual(a, b, f"step {i}")
        self.assertEqual(len(python), len(cpp))

    def test_saved_files(self):
        """Odd and old files: version 1 migration, settings.json's v1 lengths, foreign shapes, and deadlines that pass
        while the core was down (late: no sound, the pomodoro pauses; on time: the cue plays)."""
        v1 = {"timer": {"pomodoro": {"cycle": 7, "isBreak": True, "running": False},
                        "stopwatch": {"running": False, "elapsed": 1234, "laps": [100, "x", 250.5, True]},
                        "countdown": {"duration": 90, "running": False}}}
        seeds = [{"timers.json": v1, "settings.json": {"time": {"pomodoro": {"focus": 1800, "breakTime": 0, "cyclesBeforeLongBreak": 3}},
                                                       "sounds": {"pomodoro": True}}},
                 {"timers.json": {"version": 2, "config": {"pomodoro": {"focus": True, "cycles": 2.0, "x": 5}, "sound": 1},
                                  "pomodoro": {"phase": "longBreak", "cycle": "3", "duration": "120", "lengths": {"break": 61.5, "focus": -1}},
                                  "stopwatch": {"laps": "12"}, "countdown": {"duration": 30, "done": {"at": 1}}}},
                 {"timers.json": "{broken"}, {"timers.json": [1, 2]}, {"settings.json": "{broken"},
                 timers_seed(countdown=(300, 3600)), timers_seed(pomodoro=(1500, 7200)), timers_seed(pomodoro=(1500, 1510)),
                 timers_seed(countdown=(60, 30), stopwatch=(0, 5)),
                 # int() takes any size: a cycle past 64 bits loads (v2 keeps it, v1 reduces it)
                 {"timers.json": {"version": 2, "pomodoro": {"phase": "break", "cycle": 10 ** 20}}},
                 {"timers.json": {"version": 2, "pomodoro": {"cycle": "-" + "9" * 30}}},
                 {"timers.json": {"version": 2, "pomodoro": {"cycle": 9223372036854775807}}},
                 {"timers.json": {"timer": {"pomodoro": {"cycle": 10 ** 20 + 3, "isBreak": True}}}},
                 {"timers.json": {"timer": {"pomodoro": {"cycle": "-100000000000000000001", "isBreak": True}}}}]
        for seed in seeds:
            python, cpp = timers_edges("python", seed, steps=False), timers_edges(str(FARTD_CPP), seed, steps=False)
            self.assertEqual(python, cpp, seed)


def sessions_edges(which: str, seed: dict | None = None, steps=True, tz=None) -> list:
    from parity.normalise import Normaliser
    norm = Normaliser()
    out = []
    with Core(which, seed=seed or {}, **({"tz": tz} if tz else {})) as core, core.client() as peer:
        def call(op, **args):
            reply = peer.call(op, **args)
            out.append(norm(reply.get("error") or reply["result"]))
        if steps:
            for preset in ("nap\n", "Nap", "-nap", "n" * 32, "n" * 33, "9to5", "a_b-c", "", 5, None, "nap\nx", "café"):
                call("session.start", preset=preset, seconds=600)
                peer.call("session.end")
            for seconds in (60, 43200, 43200.5, 59.99, float("nan"), 10 ** 30, "600", [600], False, 600.25):
                call("session.start", preset="nap", seconds=seconds)
                call("session.end")
            call("session.start", preset="deep")
            call("session.start", preset="read")
            call("session.end")
            call("session.dismiss")
            call("session.dismiss")
        out.append(norm(peer.request("status")["session"]))
        time.sleep(0.3)
        out.append(core.host_calls())
        for name in ("session.json", "sessions.jsonl"):
            data = core.state_bytes(name)
            try:
                parsed = None if data is None else [json.loads(x) for x in data.splitlines()] if name.endswith("l") else json.loads(data)
            except ValueError:
                parsed = data.decode(errors="replace")  # left as the seed was
            out.append(norm(parsed))
    return out


def _ms(days_ago: float) -> int:
    return round((time.time() - days_ago * 86400) * 1000)


@built
class SessionsEdges(unittest.TestCase):
    maxDiff = None

    def test_ops_equal(self):
        python, cpp = sessions_edges("python"), sessions_edges(str(FARTD_CPP))
        for i, (a, b) in enumerate(zip(python, cpp)):
            self.assertEqual(a, b, f"step {i}")
        self.assertEqual(len(python), len(cpp))

    def test_saved_files(self):
        now = time.time()
        ended = {"session.json": {"active": {"preset": "focus", "anchor": {"boot": 1.0, "real": now - 4000, "bootId": "other"},
                                             "seconds": 3000.0, "dnd": True}, "last": None}}
        running = {"session.json": {"active": {"preset": "nap", "anchor": {"boot": 1.0, "real": now - 60, "bootId": "other"},
                                               "seconds": 600, "dnd": False}, "last": {"preset": "x", "apps": [["a", 1]]}}}
        log = "\n".join(json.dumps(e) for e in (
            {"preset": "a", "start": _ms(0), "seconds": 300}, {"preset": "a", "start": _ms(0) - 1, "seconds": 300.5},
            {"preset": "b", "start": _ms(1), "seconds": 601}, {"preset": "c", "start": _ms(3), "seconds": 1e3},
            {"preset": "d", "start": _ms(2), "seconds": -1}, {"preset": 4, "start": 0, "seconds": 9}, {"start": True, "seconds": 900}))
        seeds = [ended, running, {"session.json": "{bad"}, {"session.json": {"active": [1], "last": 5}},
                 {"session.json": {"active": {}, "last": None}},  # `if self.current:`: no session, not a crash
                 {"sessions.jsonl": log.replace("\n", "\u2028", 1).replace("\n", "\x85", 1) + "\r\nnot json\n"},
                 {"sessions.jsonl": log}]
        for seed in seeds:
            for tz in (None, "Pacific/Kiritimati", "America/St_Johns"):
                python = sessions_edges("python", seed, steps=False, tz=tz)
                cpp = sessions_edges(str(FARTD_CPP), seed, steps=False, tz=tz)
                self.assertEqual(python, cpp, (tz, seed))


COMMAND_EDGES = (
    "t 5", "s", "se", "zzz", "TİM 5", "? tim", "? timers", "? t", "? zzz", "? ?", "help", "? help", "? session", "? \u212aeys",
    "tim \u0662\u0665", "tim 0", "tim 99999999999999999999", "tim " + "9" * 400, "tim 1h", "tim h", "tim 1h30m", "tim 30m15", "tim 5S",
    "tim 10080", "tim 10081", "tim 1h0m0s", "tim 0h0m1s", "focus 0", "focus 1h", "focus 1", "tim focus", "tim focus 25 5",
    "task a @tasks", "task a @TASKS", "task a @default", "task a @nope", "task @x @y z", "task a !x !y", "task a !mon", "task a !mo",
    "task a !TUESDAY", "task a !+0d", "task a !+999w", "task a !+1000d", "task a !2026-11-25t10:00", "task a !2026-11-25T24:00",
    "task a !\u0662\u0660\u0662\u0666-11-25", "task !today", "task @", "task !", "task\u3000spaced\u2003words", "TASK Upper",
    "task a !2026-02-29", "task a !wed", "task a !sun", "task a !tod", "task a !tmr",
    "island", "island FLUID", "island screen AUTO", "island screen DP-1", "island screen " + "x" * 65, "island notice 2",
    "island notice 4", "island rest A", "island rest inbox DOT", "island rest power unread", "island bogus", "island screen",
    "island BOTTOM", "island floating", "island rest", "island notice",
    "session", "session nap", "session focus", "session focus", "session end", "session end", "session nap 30", "session nap 2h",
    "session nap 13h", "session END", "session a b c", "session Read", "session end",
    "sw", "sw", "tim lap", "tim pause", "tim pause", "tim stop", "tim sw x", "tim STOP",
    "x" * 1000, "é" * 1000,
)


def commands_edges(which: str, seed: dict | None = None) -> list:
    from parity.normalise import Normaliser
    norm = Normaliser()
    out = []
    with Core(which, seed=seed or {}, tz="Asia/Kolkata", env={"FART_FIXTURE_EPOCH": "1795464000"}) as core, core.client() as peer:
        def call(op, **args):
            reply = peer.call(op, **args)
            out.append(norm(reply.get("error") or reply["result"]))
        for line in ("tim 25", "tim 25", "task x", "tim 25"):
            call("cmd.run", line=line, record=True)
        for line in COMMAND_EDGES:
            call("cmd.run", line=line)
        call("cmd.run", line="sw", record=True)
        call("cmd.run", line="? tim", record=True)  # ? is never kept
        for bad in ({"line": None}, {"line": "x" * 1001}, {"line": "é" * 1001}, {"line": "tim 5", "fallthrough": None, "record": 1}):
            call("cmd.run", **bad)
        for text in ("T", "s", "zz", "? ", "tim   25", 5, "é" * 1001, "\u212a", "se", "is"):
            call("cmd.complete", text=text)
        for args in ({}, {"prefix": "tim"}, {"limit": 0}, {"limit": True}, {"limit": 2.5}, {"limit": 10 ** 30}, {"limit": "1"},
                     {"prefix": 5}, {"prefix": "", "limit": 2}):
            call("cmd.history", **args)
        out.append(norm(peer.subscribe("tasks", "timers", "session", "island")["snapshots"]))
        out.append(core.state_bytes("history.json"))
    return out


@built
class CommandsEdges(unittest.TestCase):
    maxDiff = None

    def test_lines_equal(self):
        python, cpp = commands_edges("python"), commands_edges(str(FARTD_CPP))
        for i, (a, b) in enumerate(zip(python, cpp)):
            self.assertEqual(a, b, f"step {i}")
        self.assertEqual(len(python), len(cpp))

    def test_history_files(self):
        seeds = [{"history.json": {"version": 1, "lines": ["task a", 5, "tim 1", None, "session end"] + [f"tim {n}" for n in range(150)]}},
                 {"history.json": {"lines": "tim 5"}}, {"history.json": [1]}, {"history.json": "{nope"},
                 {"history.json": {"lines": ["task 1", "task 2", "task 3", "TIM 4", "  ", ""]}}]
        for seed in seeds:
            self.assertEqual(commands_edges("python", seed), commands_edges(str(FARTD_CPP), seed), seed)

    def test_unported_verbs_say_so(self):
        """What isn't here yet answers `unported`, never a fake success."""
        with Core(str(FARTD_CPP)) as core, core.client() as peer:
            for line in ("home", "vol 40", "overdrive 20m", "tim", "task", "clip x", "lock"):
                result = peer.request("cmd.run", line=line)
                self.assertEqual((result["ok"], result["code"]), (False, "unported"), line)
            result = peer.request("cmd.run", line="zzz", fallthrough=True)
            self.assertEqual((result["ok"], result["code"]), (False, "unported"))


def start_or_gone(which: str, seed: dict, probe) -> object:
    """probe(core, peer)'s answer, or "gone" when the core refuses to start on these files."""
    core = Core(which, seed=seed)
    try:
        try:
            core.start()
        except CoreGone:
            return "gone"
        with core.client() as peer:
            return probe(core, peer)
    finally:
        core.close()


@built
class ReviewFixes(unittest.TestCase):
    """The code review of stages 0 and 1 (24 Nov): each case where the C++ core stopped and Python carried on."""
    maxDiff = None

    def test_float_text_as_python_reads_it(self):
        from parity.normalise import Normaliser
        for text in ("_5", "5_", "1__0", "1_0", "nan(123)", "1e1_0", "inf", "-Infinity", " 2.5 ", "0x10", "1_000.5"):
            seed = {"timers.json": {"version": 2, "countdown": {"duration": text}}}
            probe = lambda core, peer: Normaliser()(peer.request("status")["timers"])
            self.assertEqual(start_or_gone("python", seed, probe), start_or_gone(str(FARTD_CPP), seed, probe), text)

    def test_a_failing_deadline_leaves_the_core_serving(self):
        """A countdown ends while the state dir can't be written: logged, and the core keeps answering."""
        for which in ("python", str(FARTD_CPP)):
            with Core(which) as core, core.client() as peer:
                peer.call("timer.start", kind="countdown", seconds=1)
                core.state_dir.chmod(0o500)
                try:
                    time.sleep(1.6)
                    self.assertIsNone(core.process.poll(), which)
                    self.assertIn("timers", peer.request("status"), which)
                finally:
                    core.state_dir.chmod(0o700)
                self.assertIn("Exception in callback", (core.runtime / "core.log").read_text(), which)

    def test_half_closed_client_gets_every_reply(self):
        """A peer that sends its requests, then shuts its write side, still reads every reply (more than the
        socket buffer holds), then the close."""
        count = 20000
        for which in ("python", str(FARTD_CPP)):
            with Core(which) as core, core.client() as peer:
                peer.send_raw(b"".join(b'{"id":%d,"op":"egg"}\n' % i for i in range(count)))
                peer.sock.shutdown(socket.SHUT_WR)
                time.sleep(0.5)  # the core's output piles up past the kernel buffer meanwhile
                got, closed = peer.until_closed(timeout=20)
                self.assertEqual(len(got), count, which)
                self.assertEqual(got[-1]["id"], count - 1, which)
                self.assertTrue(closed, which)


@built
class Rails(unittest.TestCase):
    def test_sigterm_right_after_start(self):
        """Signal handlers go in before anything else: a stop at any moment after the socket listens is exit 0."""
        for attempt in range(30):
            core = Core(str(FARTD_CPP))
            try:
                core.start()
                core.process.send_signal(signal.SIGTERM)
                self.assertEqual(core.process.wait(5), 0, f"attempt {attempt}")
                self.assertFalse(core.socket_path.exists(), f"attempt {attempt}")
            finally:
                core.close()

    def test_only_the_fixture_host(self):
        core = Core(str(FARTD_CPP))
        try:
            core._layout()
            core.env["FART_HOST"] = "serpantinum"
            with self.assertRaises(CoreGone) as raised:
                core.start()
            self.assertIn("only FART_HOST=fixture runs", str(raised.exception))
            self.assertFalse(core.socket_path.exists())
        finally:
            core.close()

    def test_needs_state_and_host(self):
        env = {k: v for k, v in os.environ.items() if not k.startswith("FART_")}
        result = subprocess.run([str(FARTD_CPP)], env=env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 1)
        self.assertIn("set FART_STATE_DIR and FART_HOST", result.stderr)

    def test_one_core_per_runtime_dir(self):
        with Core(str(FARTD_CPP)) as core:
            second = subprocess.run([str(FARTD_CPP)], env=core.env, capture_output=True, text=True, timeout=10)
            self.assertEqual(second.returncode, 1)
            self.assertIn("another core is already running", second.stderr)
            self.assertTrue(core.client().call("hello", client="cli", protocol=1)["ok"])

    def test_fixture_epoch(self):
        with Core(str(FARTD_CPP), env={"FART_FIXTURE_EPOCH": "1000000000"}) as core:
            started = core.client().hello()["core"]["startedAt"]
            self.assertLess(abs(started - 1_000_000_000_000), 60_000)
        with Core(str(FARTD_CPP), env={"FART_FIXTURE_EPOCH": "soon"}) as core:
            started = core.client().hello()["core"]["startedAt"]
            self.assertLess(abs(started - time.time() * 1000), 60_000)
            self.assertIn("FART_FIXTURE_EPOCH='soon' ignored: not a number", (core.runtime / "core.log").read_text())

    def test_log_and_socket_are_private(self):
        with Core(str(FARTD_CPP)) as core:
            self.assertEqual(os.stat(core.socket_path).st_mode & 0o777, 0o600)
            log = core.runtime / "core.log"
            self.assertEqual(os.stat(log).st_mode & 0o777, 0o600)
            self.assertIn("core 0.2.0 up (C++", log.read_text())


if __name__ == "__main__":
    unittest.main()
