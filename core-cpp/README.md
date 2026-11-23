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
| `src/json.*` | ordered JSON with Python's semantics: key order kept, int/float apart, big ints kept, Python's float repr and `round`, `json.dumps`'s five styles, `json.loads`'s strictness |
| `src/pystr.*` | Python `str` where behaviour depends on it: strip/split/len by code point, Unicode whitespace and digits, `repr`, `str()`, truthiness, `int()`/`float()` of a value |
| `src/protocol.*` | the socket server (protocol.py): framing, 1 MiB lines, 4 MiB output, per-client order, `host.done` fast path, argument binding as `inspect.signature().bind`, topics and revs |
| `src/op_table.inc`, `src/verb_table.inc` | every op's signature, every topic and every command-line verb, generated from the Python core by `tools/cpp_op_table.py` (`--check` in tests/test_cpp_core.py) |
| `src/core.*` | app.py's wiring: hello, status, shutdown; topics `core` and `supervisor`; the subsystems below |
| `src/store.*` | store.py: atomic private state files, the same temp names and bytes |
| `src/clock.*` | boottime + wall clock (`FART_FIXTURE_EPOCH`), `Run`, the CLOCK_BOOTTIME timerfd scheduler |
| `src/tasks.*`, `src/timers.*`, `src/sessions.*`, `src/settings.*` (island, clips) | stage 1's subsystems, function for function |
| `src/command.*` | command.py and the stage-1 verbs (tim, focus, sw, task, island, session, ?) |
| `src/host.*` | the fixture host profile (FART_FIXTURE_LOG) and sfx.py's gate for the three alert cues |
| `src/placeholders.h` | what isn't ported: `{}` status parts; topics not ported are offered with `{}` snapshots |
| `src/log.*`, `src/main.cpp` | the log in the Python core's line shape; fartd.py's `main`/`serve` |
| `tests/json_check.cpp` | `json-check`: tests/parity/json_corpus.json byte for byte |

An op the Python core has but this core hasn't ported binds its arguments as Python would, then answers
`{"code": "unported"}`; a topic not yet ported is offered with a `{}` snapshot. A verb not yet ported, a bare room
verb and the launcher fallthrough (both need the view, stage 2a) give a `cmd.run` result with code `unported`.
