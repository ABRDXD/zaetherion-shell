# core-cpp: fartd-cpp (Z226)

The FART core in C++ (docs/CPP_CORE.md). Same socket protocol, topics and state files as `core/fartd.py`; the
Python core stays the default until stage 6, and until the port is whole this one **runs only with
`FART_HOST=fixture`** (it refuses any other host at start).

```
cmake -S core-cpp -B core-cpp/build -G Ninja && cmake --build core-cpp/build
ctest --test-dir core-cpp/build                                  # the JSON writer against Python's corpus
FART_PARITY_CORE=core-cpp/build/fartd-cpp python3 -m unittest discover -s tests -p "test_parity*.py"
tools/parity.py --stage 0                                        # Python vs fartd-cpp, observation by observation
python3 -m unittest discover -s tests -p "test_cpp_core.py"      # protocol edges byte-equal to Python, rails
```

Qt 6 Core only for now (Network and DBus are found, and linked by the stage that needs them). C++20.

| File | What |
|---|---|
| `src/json.*` | ordered JSON with Python's semantics: key order kept, int/float apart, big ints kept, Python's float repr and `round`, `json.dumps`'s five styles, `json.loads`'s strictness; `repr(str)` for messages |
| `src/protocol.*` | the socket server (protocol.py): framing, 1 MiB lines, 4 MiB output, per-client order, `host.done` fast path, argument binding as `inspect.signature().bind`, topics and revs |
| `src/op_table.inc` | every op's signature and every topic, generated from the Python core by `tools/cpp_op_table.py` (`--check` in tests/test_cpp_core.py) |
| `src/core.*` | hello, status, shutdown; topics `core` and `supervisor` |
| `src/placeholders.*` | **stage-0 placeholders** that the stage-0 scenarios need: an in-memory `task.add` and `tasks` topic, `{}` status parts. Each goes when its stage ports the real thing |
| `src/clock.*`, `src/log.*` | boottime + wall clock (`FART_FIXTURE_EPOCH`), the log in the Python core's line shape |
| `src/main.cpp` | fartd.py's `main`/`serve`: signal handlers first, lock, log, socket (0600, LISTEN_FDS), clean exit 0 |
| `tests/json_check.cpp` | `json-check`: tests/parity/json_corpus.json byte for byte |

An op the Python core has but this core hasn't ported binds its arguments as Python would, then answers
`{"code": "unported"}`; a topic not yet ported is offered with a `{}` snapshot.
