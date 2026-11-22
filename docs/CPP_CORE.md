# The core in C++ (Z226)

**Owner, 22 November 2026:** "I wanted my project to be pure C++ and QML" → "YES, if it's feasible".
**Scope:** everything that runs on the desktop: `fartd` (core/, ~10,600 lines of Python), the host profiles
(adapters/*/core.py, ~530), the `zaetherion` CLI and the helpers the view starts (lyrics lookup, recording
helper, GPU sample; ~1,200). **Not in scope:** tests and developer tools (tests/, tools/ renders and
measurements), which never run on the desktop and stay Python.

## Feasible: what was checked (22 November)
- Toolchain on the machine: g++ 16, CMake 4, Ninja, Qt 6.12 with Core, Network, DBus and Sql (the Qt
  Quickshell runs on). No new install needed.
- The Python core uses the standard library only (asyncio, json, socket, subprocess, pathlib, re, datetime,
  struct, fcntl). Each has a QtCore equivalent: QLocalServer/QLocalSocket, QJsonDocument, QProcess, QTimer,
  QSocketNotifier (PSI), QFileSystemWatcher, QtDBus (notifications), QStandardPaths.
- The view talks to the core in JSON lines over a Unix socket (core/protocol.py, PROTOCOL 1). A C++ core that
  speaks the same lines needs **no QML change**.
- Not a speed project: `fartd` is ~20 MiB PSS of ~620 and mostly asleep. The aim is one language family.
  Each stage must still meet BUDGETS.md and is measured against the Python core.

## How: side by side, one stage at a time
`core-cpp/` (CMake, Qt6 Core/Network/DBus, C++20) builds `fartd-cpp`. `FART_CORE=cpp` makes the session start
it instead of `core/fartd.py`; the Python core stays the default until the last stage.

**Parity harness first.** Of 147 test files, 8 drive the core over its socket; 43 import Python modules
directly. Stage 0 turns the core's behaviour into socket-level checks (requests in, replies and topic events
out, state files written), run against **both** cores. A stage merges only when both cores pass it.

| Stage | What moves | Done when |
|---|---|---|
| 0 | `core-cpp/` skeleton, build, protocol server; parity harness and socket-level checks for every topic | both cores answer `hello`; harness green on Python |
| 1 | protocol, command parsing, topics, clock, timers, tasks, sessions, modes | parity green; state files byte-compatible |
| 2 | view supervision: view.py, supervisor.py, guards (spawn, reap, restart, PSI) | parity + `supervisor_check.py` + nested restart checks |
| 3 | host work: capture (Z221/Z222), wallpaper, launcher, notifications (DBus), equalizer, eq_chain, sfx | parity; capture nested check; no live actuation in tests |
| 4 | sky, skywatch, weather, journey, genealogy, telemetry, overdrive, exhibit, discovery, inline | parity; sky figures equal to the Python core's |
| 5 | `zaetherion` CLI (small C++ client), lyrics tool, recording helper, GPU sample; host profiles compiled in | CLI verbs equal; lyrics cache format unchanged (Z220) |
| 6 | `fartd-cpp` becomes the default; the Python core stays one week as the fallback, then goes | a week live without falling back |

## Rules
- Same socket protocol, same topic snapshots, same state and cache files. The view never knows which core runs.
- No new runtime dependency beyond Qt 6 Core/Network/DBus (AGENTS.md: a dependency needs a concrete benefit).
- Each stage: full suite, parity on both cores, RSS/PSS/private dirty measured, then merged by Claude A.
- **Who:** Claude B leads the port (core, CLI and adapters are Claude B's); Claude A writes the parity harness,
  measures, reviews and merges. Astra and the owner see no change.
- **Starts** after the focus-tracker decision (OPEN 1 / Z225, run ends 24 November 18:59) and Astra's review of
  the 22 November builds, so nothing in flight moves underneath them.
