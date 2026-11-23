# The parity harness (Z226 stage 0)

Claude A, 23 November 2026. The C++ core (docs/CPP_CORE.md) merges stage by stage only when it behaves like the
Python core over the socket. This harness is how "behaves like" is checked. It is test code: nothing here runs on
the desktop.

## Run it
- `python3 -m unittest discover -s tests -p "test_parity*.py"`: every scenario against one core (Python unless
  `FART_PARITY_CORE=/path/to/fartd-cpp`), plus the bookkeeping checks. About 11 s.
- `tools/parity.py`: every scenario on two cores, observation by observation (`--a`, `--b`, `-k name`,
  `--stage 1`). By default the second core is `core-cpp/build/fartd-cpp` once it is built, otherwise the Python core
  again. **Python against Python must stay 20/20 equal**: a difference there is run-to-run noise that
  `tests/parity/normalise.py` has to mask, not a real difference.
- `tools/json_corpus.py [--check]`: the JSON writer's corpus (below).

## Files
| File | What |
|---|---|
| `tests/parity/harness.py` | `Core` (one core process on throwaway directories, fixture host) and `Peer` (one socket connection: `call`, `request`, `error`, `notify`, `subscribe`, `event`, `drain`, `until_closed`) |
| `tests/parity/normalise.py` | masks times, pids and memory as type tags (`<int>`, `<float>`), so `1` vs `1.0` still shows; random task and list ids become `t#1`, `l#1` in order of first sight |
| `tests/parity/scenarios.py` | the scenarios. Each one asserts what any core must do (`rec.equal`, `rec.same`, `rec.true`) and records what it saw (`rec.see`, `rec.file`) for the cross-core diff |
| `tests/parity/coverage.py` | what is still owed, by stage: ops, topics and the checks that aren't one op |
| `tests/parity/json_corpus.json` | 204 values × 5 JSON styles, `round()` cases, one SHA-256 case |
| `tests/test_parity.py`, `tests/test_parity_coverage.py` | the unittest entry points |

## What a core must offer the harness
fartd-cpp has to honour these, exactly as `core/fartd.py` does, or the harness can't drive it:
- **Environment:** `FART_RUNTIME_DIR` (socket at `core.sock`, mode 0600), `FART_STATE_DIR`, `FART_CACHE_DIR`,
  `FART_HOST=fixture`, `FART_VIEW_ENTRY` (a path that doesn't exist: no view starts), `FART_MIRROR=0`, `TZ`.
- **The fixture host's log:** with `FART_FIXTURE_LOG` set, each host command the core would run is appended as one
  JSON array line, default JSON style (`["notify", "Timers", "⏰ Countdown finished"]`, `["dnd", "on"]`).
- **`FART_FIXTURE_EPOCH`** (epoch seconds, new 23 Nov): the core's wall clock starts there and runs at the real rate;
  boottime is untouched. Honoured **only with `FART_HOST=fixture`** (`fartd.fixture_epoch`; `test_parity`'s
  `FixtureClockGate`), so a stray variable can never move the desktop's clock. This is how the time-zone and DST
  scenarios pick their "now" without libfaketime.
- **Signals:** SIGTERM at any moment after the socket accepts gives a clean exit 0 and removes the socket.
- **`shutdown`** op: reply `{}`, exit 0, socket removed.

## Covered now (stages 0 and 1; 20 scenarios)
- **Protocol:** hello first, protocol and client checks, the view refused; `bad-request` for not-JSON, no op, a
  non-text op, non-object args, unpaired surrogates; `unknown-op`, `bad-args` (unknown or missing argument);
  notifications (no id, or `id: null`) answer nothing, success or failure; ids echoed whatever their JSON type;
  twenty pipelined requests answered in order; a frame split across writes; an unfinished last frame never
  answered; a line over 1 MiB closes that client only; a line just under is read; socket mode 0600.
- **Topics:** the 22 topics offered (read from the core's own `bad-args` message); snapshot keys and order for all,
  whole snapshots for ten; revs start at 0 and count changes; the event goes out before the reply that caused it;
  other subscribers get it, unsubscribed clients don't; a late subscriber gets the current rev.
- **Lifecycle:** `status` keys and order; RSS under 25 MiB; `shutdown`; SIGTERM.
- **Timers:** countdown start/pause/extend/reset/ack, its end notifies the host, bad lengths; stopwatch laps;
  pomodoro and its settings' validation; a paused countdown's elapsed survives a restart exactly and the file isn't
  rewritten.
- **Tasks:** every op and every validation error; the order rules (insert at index, move between lists, a removed
  list's tasks go home); remove then restore gives back the same task; `tasks.json` equals the snapshot; migration
  from `todo.json`; a restart rewrites no byte; ASCII escapes and compact separators; an invalid file is kept
  aside as `tasks.json.invalid`.
- **Sessions:** validation, one at a time, DND on and back off through the host, the debrief, the log line.
- **Island rest and clips settings:** validation, no event when nothing changes, kept across a restart.
- **Commands:** 34 command lines' whole replies (verbs, ambiguity, unknown verbs, durations, due words), the dates
  they give in Kolkata at 01:30, completion for eight prefixes, history order, prefix and limit.
- **Time zones and DST (Claude B's ask):** Europe/London's spring change (a session at 23:30 UTC on 29 March lands
  on the 30th: streak 1, best 2, where a fixed offset gives 3); New York's autumn change (streak and strip); due
  words on New York's change day, half an hour before the clocks go back.

## Owed (tests/parity/coverage.py)
Each stage of CPP_CORE.md moves its own entries out by adding scenarios before it merges:
2a view and ignite ops (`view.*`, `host.done`, `key.*`), a nested Hyprland run with the real view, spawn/reap timing;
2b the supervisor topic and **DMS's settings.json byte-equal after a bar off/on round-trip** (Claude B's ask);
3a sound and equaliser; 3b notifications, launcher, track and **regex ranks for inline and matching** (Claude B's
ask; the command corpus above covers command parsing now); 3c palette, wallpaper, presets, capture; 4 Overdrive,
journey, discovery, genealogy, sky, telemetry, **exhibit scores**. 65 of the 93 ops and 16 of the 22 topics are owed; 28 ops and 6
topics are covered.

## JSON
`tools/json_corpus.py` writes what Python's `json` produces in each style the runtime uses: `store` (state files:
compact, ASCII escapes), `protocol` (socket lines: compact, UTF-8), `dms` (DMS settings: `indent=2`, UTF-8, no
trailing newline), `exhibit` (`sort_keys`, compact: the score's SHA-256 seed), `default` (fixture log, capture's
spec). Inputs are given in compact form with floats in `repr`, so they read back exactly; fartd-cpp's writer must
reproduce every `out` byte for byte. `round` cases pin Python's `round(x, n)` (half to even on the binary value).
`test_parity_coverage` fails if the checked-in corpus no longer matches what this Python writes.

## Found while building it (fixed on `a-parity`)
- **`tim 90s` started a 9-minute countdown.** The duration pattern let minutes go without their `m`, so `90s` read
  as 9 min 0 s, `45s` as 4 min 5 s (any seconds of two or more digits). The help text's own example. Fixed in
  `core/verbs/base.py`; `DurationTests` in `tests/test_core_command.py`.
- **A SIGTERM just after start killed the core outright** (exit -15, socket left behind): the socket listened
  before the signal handlers were installed. 1 in 5 quick stops before; 0 in 40 after the handlers moved first.
