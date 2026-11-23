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
