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

**Parity harness first** (built 23 Nov: docs/PARITY_HARNESS.md; what fartd-cpp must offer it, e.g. the
fixture log and `FART_FIXTURE_EPOCH`, is listed there). Of 147 test files, 8 drive the core over its socket; 43 import Python modules
directly. Stage 0 turns the core's behaviour into socket-level checks (requests in, replies and topic events
out, state files written), run against **both** cores. A stage merges only when both cores pass it.

| Stage | What moves | Done when |
|---|---|---|
| 0 | `core-cpp/` skeleton, build, protocol server; **the JSON writer** (below); parity harness and socket-level checks for every topic; `session-start` and `live-restart` know both cores (they match `core/fartd.py` by path today) | both cores answer `hello`; harness green on Python; JSON writer equal to Python's on a corpus |
| 1 | foundations and plain state: protocol, store, errors, command parsing and verbs (base, lines, modes, timers, tasks, clips, island), topics, clock, timers, tasks, sessions, clips, island | parity green; state files byte-compatible |
| 1b | plain state added after stage 1 merged: widgets (desktop widget layout, 24 Nov) | parity green; widgets.json byte-compatible |
| 2a | view supervision: view.py, guards (spawn, reap, restart, PSI), hostcalls, ignite | parity + nested restart checks (the restart race and host-call deadlock fixes keep their tests) |
| 2b | DMS supervision: supervisor.py, dms_bar (writes the owner's DMS settings: byte-equal), the login `fits` check | parity + `supervisor_check.py`; bar off/on round-trip leaves DMS's file byte-equal |
| 3a | sound: host profiles, sfx, equalizer, eq_chain | parity; no live actuation in tests |
| 3b | the bus and the launcher: notifications, notification_mirror, track (both read `busctl monitor`: keep busctl for parity, native QtDBus later), launcher, matching, inline | parity; `launcher_keycheck.py`; matching ranks equal on a corpus |
| 3c | pictures: capture (Z221/Z222), wallpaper, palette, palette_catalog, presets, typeset; adapters/common's helpers | parity; capture nested check |
| 4 | the sky and Overdrive: sky, skywatch, weather, journey, genealogy, telemetry, orrery, quiet, buses, overdrive, exhibit, discovery | parity; sky figures and exhibit scores equal to the Python core's |
| 5 | `zaetherion` CLI (small C++ client), lyrics tool, recording helper, GPU sample, `fart_next` (update), `dms_quiet` (run at every login), typeset generator (tools/typeset, PIL today) | CLI verbs equal; lyrics cache format unchanged (Z220); typeset plates pixel-equal or owner-approved |
| 6 | `fartd-cpp` becomes the default; the Python core stays one week as the fallback, then goes | a week live without falling back |

## Claude B's review (23 November): what changed above and why
- **Unplaced modules now have a stage.** The first table left out about twenty: app (the glue, grows each stage),
  store, errors, the verbs package (818 lines), buses, clips, dms_bar, host, hostcalls, ignite, island, matching,
  notification_mirror, orrery, palette, palette_catalog, presets, quiet, track, typeset. `inline` moves to 3b beside
  the launcher it serves.
- **Stages 2 and 3 split.** 2 had the two riskiest jobs (keeping the view alive, keeping DMS alive) in one merge;
  3 was ~2,600 lines across audio, DBus and images. Smaller merges, same order.
- **Scope gaps (desktop-run, not in the first list):** `tools/dms_quiet.py` (session-start runs `fits` at every
  login), `tools/fart_next.py` (FART's update command opens it), `adapters/common/*.py` (imported by the core),
  `tools/typeset` (the Typeset button and `wall typeset`). One-off Serpantinum cutover tools (`clock_hook.py`,
  `tools/cutover.py`) stay Python as developer tools.
- **Typeset needs QtGui** (images, fonts, drawing; PIL today). QtGui is already installed (Quickshell runs on it),
  so no new install, but it breaks "Core/Network/DBus only". Proposal: a separate `zaetherion-typeset` binary links
  QtGui; `fartd-cpp` stays Core/Network/DBus.
- **The JSON writer is stage 0 work.** QJsonDocument can't give byte-compatible files: it sorts keys (Python keeps
  insertion order), writes `1.0` as `1`, escapes differently (store.py writes ASCII escapes; protocol.py and
  dms_bar.py don't), and has no `indent=2` in Python's shape. Exhibit's score is seeded from a SHA-256 of Python's
  `sort_keys` JSON, so its digits must match Python's `repr` exactly. Plan: a small ordered JSON value with int and
  float kept apart, Python's float repr (shortest round-trip digits, Python's exponent rules) and Python's `round`
  semantics, checked against a corpus Python writes.
- **Other parity traps to test on purpose:** local time and DST (datetime vs QDateTime; run parity under a fixed
  TZ and across a DST change), regexes (Python `re` vs PCRE2 in inline, matching, command parsing), subprocess
  exit and kill timing (asyncio vs QProcess) in guards and the supervisor.
- **No partial core runs live.** Until stage 4 is done the C++ core lacks topics, so from stage 2a on, each stage
  also runs the real view against it in a nested Hyprland. The owner's first live trial (`FART_CORE=cpp`, opt-in)
  is after stage 4, well before stage 6's week.

## Rules
- Same socket protocol, same topic snapshots, same state and cache files. The view never knows which core runs.
- No new runtime dependency beyond Qt 6 Core/Network/DBus (AGENTS.md: a dependency needs a concrete benefit).
- Each stage: full suite, parity on both cores, RSS/PSS/private dirty measured, a code review, then merged.
- **Who:** Claude B leads the port (core, CLI and adapters are Claude B's); Claude A wrote the parity harness.
  Since 24 November (owner: Claude A moves to another project) Claude B also measures and merges, so each stage
  gets a separate code-review pass before it merges. Astra and the owner see no change.
- **Started** 23 November (owner: "you carry on"); the focus-tracker decision (Z225) and Astra's review of the
  22 November builds are both done (24 November).
