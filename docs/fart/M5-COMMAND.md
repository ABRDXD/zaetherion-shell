# M5 backend: command-line verbs, host calls and sound cues

Status: **built on branch `visible-ui`, rebased on main `9ba6ebf` (the M5 review decisions), 6 November 2026. Not merged or pushed.** This is the backend half of M5 (PROJECT_PLAN), step 1 of DAILY_DRIVER §9. The command line's UI, the satellites, the unfold origin and the hook variant are the view half. Nothing under `view/`, `tools/measure/`, HANDOFF.md or PROJECT_PLAN.md was edited here. The code is the source of truth; when this file disagrees with it, fix this file.

Commits, oldest first:

| Commit | What |
| --- | --- |
| `2c13496` | Core host calls (`core/hostcalls.py`, `core/client/CoreHostCalls.qml`). The fixture's audio levels now exist only under the mixer lease. |
| `408d08d` | The verb registry (`core/command.py`), `cmd.run`/`complete`/`history`, `vol`, and the CLI passthrough |
| `132f5b9` | The rest of grammar v1. `tim`, `overdrive` and `session` move from the CLI into the core. |
| `faf3ae5` | Sound cues (`core/sfx.py`): one D19 gate and `sfx.cue` events |
| (this commit) | Q9: the core plays the host's UI sounds. `--screen`, the ignite state machine (`core/ignite.py`) and `fart-next key`. |

The hashes above are from before the rebase onto main. After it, the first four are `1dff0d1`, `33c058e`, `d295b2c` and `c22bce9`.

## 1. Where the verbs live, and the M5 draft

You decided DAILY_DRIVER Q5 for the core registry built here (§11 there, 6 November). The main session's earlier request to leave `vol` out of the core predates that decision. Q5 keeps it in the core, holding `mixer` through the view's host calls, so `vol` stays. The reasons that held for this design:

- **One grammar.** `fart-next vol 40` and the future command line send the same text to `cmd.run`. One test checks every example in the registry, so the two cannot drift. The draft needed a parity test between two parsers instead.
- **The cost the draft named.** Adapter actions round-trip core → view → core (§3), at about 1 ms on the local socket, plus the hold. The command line shows `…` until the reply arrives (draft §4.3), so nothing queues behind it.
- Matching follows Q4. History follows Q6: persisted by the core, 100 lines, mode 0600, `clip` excluded. The draft's `history.list`/`history.add` are `cmd.history` here, and the core records a line itself when `cmd.run` runs it, so the view never writes history. Sound follows Q9 (§5).

## 2. Protocol additions (CORE.md §2.4)

| Op | Args | Result |
| --- | --- | --- |
| `cmd.run` | `{line, fallthrough?, record?}` | `{ok, tone, line, verb, data}`, or `{ok: false, tone, code, line}`. Both flags default to true for the view and false for the CLI. |
| `cmd.complete` | `{text}` | `{verb, usage, candidates: [{name, usage, summary}], complete}`: the live hint while typing |
| `cmd.history` | `{prefix?, limit?}` | `{lines}`, newest last |
| `host.done` | `{token, ok, result?: {read}, error?}` | **View only.** Answers a `view.host` event (§3). |
| `sfx.play` | `{cue}` | **View only:** `ui.click`, `ui.key`, `ui.switch` or `ui.error`. Reports a moment only the view sees. The core gates it and plays it. Returns the event. |
| `sfx.configure` | `{cues: {name: bool}}` | Switches UI cues (`sfx.json`, 0600). Alerts follow `timer.configure {sound}`. |
| `view.open`, `view.toggle` | gain `screen` (string, ≤ 64 printable characters; empty means the focused screen). `view.toggle` also takes `from`. | as before |
| `view.state` | gains `cmdlineIdle` (bool, default false): the command line has focus and no text | as before |
| `key.down`, `key.up` | none | `{action, holding, since, fired, outcome}`; `action` is `open`, `fold`, `ignored`, `released` or `fired` (§6) |

| Event or topic | Shape |
| --- | --- |
| event `view.host` (to the view) | `{token, domain, method, args, lease, ready, read, hold, linger}` (§3) |
| event `sfx.cue` (to `sfx` subscribers) | `{cue, seq, at, audible, reason, gain}`. An impulse: it is never stored or replayed. The core has already played it. |
| topic `sfx` | `{cues: [{name, kind, session, summary, enabled}]}`. Published when a switch or the timer sound setting changes. |
| topic `ignite` | `{holding, since, fired, outcome}` (§6). The hold meter binds to it. |
| `view.command` | It gains `query` (≤ 200 characters) for `clip <words>`, `screen` (the hook's output), `focus: "cmdline"` (from a key press) and `fly` (≤ 64 printable characters, from `go`; `""` opens the orbit alone). Each is present only when set. `CoreClient.command` passes them as a fourth argument, `extra`. The view ignores them until the view half reads them. |

`cmd.run` codes: `usage` (the line does not parse), `ambiguous` (`candidates` and `complete` are included), and the subsystem codes (`bad-args`, `not-found`, `conflict`, `unavailable`, `refused`). A failed verb is a result with `ok: false`, not a protocol error, so the command line always gets a line to show.

## 3. Grammar v1 and the registry

The registry is `core/command.py`. Each domain is a module in `core/verbs/` that lists `Verb(name, domain, usage, summary, examples, run, aliases, record)`, so adding a verb means adding one entry. `?` and `help` are built in.

**Matching** runs on the first word only:
1. An exact name or alias, case-insensitive.
2. A unique prefix.
3. An ambiguous prefix, ranked by history: the top verb runs only if it was used at least twice as often as the next one. Otherwise the line returns `ambiguous` with its candidates and their common prefix.
4. Anything else falls through to the host launcher, but only from the view. The panel folds first, then `hostActions.openLauncher(text)` runs. From the CLI it is a usage error.

There is no typo matching. A bare verb opens its room, and a verb with arguments acts.

| Module | Verbs | Acts through |
| --- | --- | --- |
| `rooms` | `home`, `med`, `perf`, `ws`, `dev`, `inbox` (aliases: the full room names) | `view.command open` |
| `rooms` | `go [room \| moon]`: a room by id, short name, number (`go 5`) or unique prefix flies there; any other words name a moon (`go wifi`, `go timers stopwatch`, `go ws 3`). A bare `go` opens the orbit. | `view.command open`, or `open` with `fly` (the view finds the moon: a leading room word narrows the search, then an exact name, a prefix, a substring, or a moon's number) |
| `timers` | `tim <25 \| 90s \| 1h30 \| focus [min] \| sw \| lap \| pause \| stop>`, `focus [min]`, `sw` | the timers, as CORE.md §8 |
| `tasks` | `task <text> [@list] [!today \| !tomorrow \| !fri \| !+3d \| !+2w \| !2026-11-12[T18:30]]` | `tasks.add`. An unknown `@list` is `not-found`, never a new list. `!fri` is the next Friday, a week away when today is Friday. |
| `modes` | `overdrive [20m \| sticky \| off]`, `silent`, `session [<preset> <dur> \| end]` | Overdrive and sessions. Bare forms report. |
| `media` | `play` (alias `pause`), `next`, `prev`, `lyr`, `out [device]` | host calls: `media.togglePlaying`/`next`/`previous`, `audio.setDefault`. A bare `out` lists the outputs. A device matches by exact name, then unique prefix, then unique substring. |
| `system` | `vol`, `bri <0-100 \| +n \| -n>`, `wifi`/`bt [on \| off]`, `power [perf \| bal \| save]` | host calls under `mixer` and `brightness` leases (§4). `power` checks the host's `profiles` first. |
| `clips` | `clip [words]` | `view.command open clipboard` with `query`. It is never kept in history. |
| `hostactions` | `wall`, `theme`, `settings`, `update`, `lock` | They fold the panel, then `hostActions.open(...)` or `power.lock()`. |

**CLI.** `fart-next <verb …>` sends `cmd.run`, so every verb has a CLI entry with no parser of its own. Exit codes are 0 for success, 2 for `usage`/`ambiguous`, 1 for other failures and 3 when the core is unreachable. `--json` prints the whole result. The builtins keep precedence: `open page close toggle status start stop restart update`. So `fart-next update` stays the read-only Git report, and the host's update page is the `update` verb in the command line only. Use `fart-next help` rather than `fart-next ?`, because the shell expands `?` against one-character file names. `fart-next status` takes its line helpers from `core/verbs/lines.py`, so the CLI and the core format alike.

## 4. Host calls: how `vol` holds the mixer

The adapter lives in the view, and audio levels exist only while the `mixer` lease binds the default sink (ADAPTER_CONTRACT §3). A verb that needs the host therefore asks the view:

```
core   HostCalls.call("audio", "setVolume", [{"$": "output.id"}, 0.4], lease="mixer", ready="output", read="output")
  ├─ view.ensure()             spawns the view closed if it is absent (no panel opens)
  └─ view.host event ────────► CoreHostCalls (core/client): acquire("mixer", "core:<token>")
                                wait ≤ 2 s until audio.available and audio.output is non-null
                                setVolume(output.id, 0.4)       ("$" arguments resolve on the domain)
                                wait hold (300 ms) so the level lands while the node is bound
                                read audio.output
     host.done ◄────────────── reply, then release after linger (0 unless asked)
```

- **Allowlist.** Only the `(domain, method)` pairs in `hostcalls.CALLS` and the leases in `LEASES` can be sent. The QML side also refuses lease, log and QObject methods.
- **`vol +5`** is two calls. The read call lingers 500 ms, so the set call's owner joins before the read's owner leaves, and the sink never unbinds in between. `test_verbs_view` checks this against the fixture adapter's lease log.
- **Failures.** If the view never becomes ready, the reply is `unavailable` with "audio is not ready". A lost reply times out after 5 s. A view disconnect fails its pending calls, and the QML side releases every lease it held.
- **Idle cost.** The QML step timer (20 ms) runs only while a call is pending or lingering. The core adds no timer.
- **Adapter changes.**
  - `SerpantinumAudio.endpoint` returns null until `PwNode.ready`, so a call never reads or sets a level on an unbound node.
  - `FixtureAdapter` now exposes `output`, `input` and `streams` only under the mixer lease, as the contract says. The Devices room holds that lease, and smoke is unchanged.
  - `CoreClient` takes `host` (set in `shell.qml` and `shell-fixture.qml`) and owns `CoreHostCalls`.

**Cost to decide (§7 A).** With the view reaped, `fart-next vol 40` from a terminal spawns the view closed: about 0.4 s cold and about 200 MiB PSS until the 10-minute reap. From the command line the view is already running, so this cost applies only to the CLI and future key binds.

## 5. Sound cues (D19, Q9)

`core/sfx.py` is the only gate and the only player. `Host.alert` sends its cue there, and so does the view, through `sfx.play`. You decided Q9 for the host's UI sounds. FART's UI cues therefore sound like Serpantinum's own controls: the host profile maps each cue to the file the matching host control plays by default. The view never runs `pw-play` itself.

| Cue | Kind | Raised by | Serpantinum file (`assets/sounds/`) | Audible in a session |
| --- | --- | --- | --- | --- |
| `timer.done` | alert | timers | freedesktop `alarm-clock-elapsed.oga` | no |
| `pomodoro.phase` | alert | timers | the same | yes (it belongs to the session) |
| `session.end` | alert | sessions | the same (it played nothing before; draft §6 lists it) | yes |
| `ui.click` | UI | the view | `reusables/clickbutton/click.wav` (`ClickButton.clickSound`) | no |
| `ui.key` | UI | the view | `reusables/input/type.wav` (`Input.keySound`) | no |
| `ui.switch` | UI | the view | `reusables/switch/sfx.wav` (`Switch.switchSound`) | no |
| `ui.error` | UI | the view; the core, for a failed command-line verb | `reusables/inputfield/error.wav` (`Input.errorSound`). **The host does not ship this file**, so the host's own inputs are silent on error too, and so is FART (`reason: "no-sound"`). | no |
| `cmd.run` | UI | the core, for a command-line verb that ran | `reusables/clickbutton/click.wav`. The host's `Input` plays nothing on Enter, so this is the host's standard button press. **This one is my choice, not the host's**: say if you would rather it be silent. | no |
| `ignite` | UI, reserved for M8 | nobody yet | none in the host | no |

- **The gate, in order:**
  1. The cue is on. For alerts, that is FART's timer sound setting. For UI cues, it is the cue's own switch: **every UI cue is on until switched off** with `sfx.configure`, because Q9 says FART plays them. The timer sound setting does not gate UI cues.
  2. No session quiets it.
  3. The host's sfx are not muted (`muteSfx`), and `sfxVolume` is above 0.
  4. The host is not in DND.
  5. The host has a file for the cue.

  The gain is the host's `sfxVolume`, as `Sounds.play` does. Host settings are read only for a cue that is on.
- **What changed from the earlier commit:** `panel.open`/`panel.close` are gone, because the host's popups open and close silently. `cmd.ok`/`cmd.error` became `cmd.run`/`ui.error`. `sfx.emit` is now `sfx.play`. The event dropped its `player` field, because the core plays every cue.
- **Who raises what.** The core raises `cmd.run`/`ui.error` on the view's `cmd.run` results, and nothing for CLI lines, ambiguous lines or fallthrough. The view must not also report `ui.error` for a failed verb. The view raises `ui.click`, `ui.key` and `ui.switch` through `CoreClient.playCue(name)`, and `ui.error` for an input it refuses. `CoreClient.cue(data)` carries every event, for display only.
- **Cost:** one socket line per cue, plus one `pw-play` process, the same as the host's own `Sounds.playSfx`. Typing therefore starts one `pw-play` per key, as the host's `Input` does.
- **Bug fixed earlier on this branch:** `fartd` built `Host` without its `quiet` callback, so a running session never quieted alarms. The gate now asks the sessions directly.

## 6. `--screen` and the ignite hold (DAILY_DRIVER §2, §4.6)

**`--screen`:** `fart-next open|toggle [--from x,y,w,h] [--screen NAME]`. The hook's variant uses `toggle` (Q1), so `toggle` now takes `--from` too. The CLI refuses a malformed rect, a non-positive size, or a name over 64 characters or with control characters (exit 2). An empty `--screen ""` is the hook's fallback when the bar reports no screen, and it means "the focused screen". The core validates the same rules again and forwards `screen` in `view.command`. Remembering the rect per screen (`clockGeometry.setHookRect`) is the view half's job.

**Ignite** (`core/ignite.py`, wired in `core/app.py`). The timing lives in the core, so it works with the view reaped:

| Input or deadline | What happens |
| --- | --- |
| `key.down`, the panel open, its command line focused and empty | Fold the panel (Q7). No hold starts, and the matching `key.up` is ignored. |
| `key.down`, otherwise | Record `t0` and arm three deadlines. Send `view.command {action: open, focus: cmdline}`, spawning the view if needed. The reply does not wait for the view. |
| t0 + 150 ms, still held | `ignite.holding` is true: the meter shows |
| t0 + 600 ms, still held | Fire: `overdrive.request panel`, then `ignite.fired` is true, with an `outcome` of `granted`, `refused` (a guard or a refusal) or `pending` |
| `key.up` | End: everything resets. A release after 600 ms whose fire deadline was not serviced yet fires first. The release never ends the Overdrive lease: the panel closing does (D16). |
| t0 + 3 s with no `key.up` | Treated as released |
| `key.down` while held | Ignored, and the deadlines keep counting from the first press |
| `key.up` with nothing held, or with no core running | Ignored. The CLI does not start a core for a release. |

- **A cold press.** At 600 ms the view may still be starting or unfolding, and `overdrive.request panel` needs an open panel. The fire then waits as `pending` and is granted when the view reports open, if that happens within 3 s of the press. If the view dies or the panel closes first, the pending fire is dropped, so a later panel never inherits it.
- **The view's part (view half):** report `cmdlineIdle` in `view.state`, bind the meter to `CoreClient.igniteData`, and focus the command line on `focus: "cmdline"`.
- **Not done:** the Hyprland bind and the prototype in draft §4.6 (does `bindr` fire with FART holding focus, does a stray grave reach the `TextInput`, does the outside-click fold still work). Both wait on your approval of the bind, so nothing here has run from a real key.

## 7. Verification

- **Python, after the rebase and this commit:** `python3 -m unittest discover -s tests` runs 199 tests, all passing (121 on main). This commit adds:
  - `test_core_ignite` (18 tests): the §4.6 press lengths of 100, 149, 151, 599 and 601 ms; the fire while held; a late fire deadline; a lost release; a double press; a release with no press; the Q7 fold; publishing only on change; a failing effect. In the core: the Overdrive lease lasting until the panel closes, a short tap, a cold press granted within the window, expiring and being dropped by a crash, a release with the view absent, and the fold following `cmdlineIdle`.
  - `test_core_sfx`: the UI cues on by default and played by the core at the host's gain, through each gate step; `no-sound`; the `sfx.play` allowlist; no sound on open or fold; the Serpantinum mapping against a temporary copy of the host's sound tree.
  - `test_core_view`: `screen` and `focus` in `view.command`, with their validation, and `cmdlineIdle` counting only while the panel is open.
  - `test_launcher`: `--from`/`--screen` on `open` and `toggle`, and `key down|up` parsing.
  - `test_core_daemon`: the real CLI and core for `key down`/`key up`, and a release with no core starting nothing. The test's view entry is a missing file, so no view can start.
- **Mutation checks for this commit:** each of these fails the new tests: dropping the double-press guard, the lost-release deadline, the Q7 fold, the meter, the pending-fire expiry or its drop on a crash, the `no-sound` rule, and the `sfx.play` allowlist.
- **Python, before the rebase:** 168 tests, all passing (120 before; 48 new, in five files):
  - `test_core_hostcalls`: the payload, error codes, the allowlist, timeouts and disconnects.
  - `test_core_command`: matching, history ranking with the 2× rule, fallthrough only for the view, persistence (0600, the 100 cap, a broken file), help, and `vol` with the fake view.
  - `test_core_verbs`: every verb against an in-process core with the fake clock. Every registry example parses.
  - `test_core_sfx`: the alert truth table (96 subcases), UI switches, events, panel and command cues, sessions quieting an alarm, and the snapshot following the sound setting.
  - `test_verbs_view`: the real core, the real CLI and a real offscreen view (`tools/verbtest/VerbView.qml`). The view runs `CoreHostCalls` against `FixtureAdapter`. The tests cover:
    - `vol 70` spawning a closed view and holding the mixer
    - `vol +5` keeping the sink bound between the read and the set
    - every host verb reaching the fixture once and releasing its lease
    - an alarm arriving as an `sfx.cue` and playing once in the core
- **Mutation checks:** removing the session rule, letting the core play UI cues, emitting panel cues without a change, or emitting command cues for CLI lines each fails `test_core_sfx`.
- **Smoke:** `tools/smoke.py` passes, and the fixture recorded 0 calls.
- **QML syntax:** 0 `syntax*` diagnostics in the changed files.
- **Core memory**, fixture profile, no mirror, three runs each:

  | Tree | RSS | PSS | Private dirty |
  | --- | --- | --- | --- |
  | base `6049f08` | 21.0 MiB | 11.9 MiB | 11.3 MiB |
  | this branch | 21.3 MiB | 12.2 MiB | 11.6 MiB |

  That is +0.3 MiB RSS, within the 25 MiB budget. I am not claiming an optimization.
- **Not actuated:** nothing touched real playback, volume, network, Bluetooth, brightness, power, recording or the lock. Every host verb ran against `FixtureAdapter` or a fake. The core used the fixture host profile, which records `pw-play` instead of running it. No live check was done on the desktop, and the running fart-next core was not restarted.

## 8. Open questions and remaining work

**Needs your decision:**
- **A.** `vol`/`bri`/`wifi`… from a terminal with the view reaped spawn the view (§4). The alternative is a view-less route in the host profile (`wpctl` for volume). That means a second implementation of each action outside the contract, and no lease. The recommendation is to keep the single route and revisit only if key binds for volume are wanted.
- **B.** `cmd.run` uses the host's button click, because the host's input is silent on Enter (§5). The alternative is silence.
- Resolved by your review: Q5 (the core registry), Q6 (history) and Q9 (host UI sounds, §5). The draft's §4.2 view registry and parity test are dropped (DAILY_DRIVER §11).
- **Still needing approval, untouched:** the Super+` bind and its prototype, the socket unit, the archive tag and the cutover.

**Not built here (the view half, DAILY_DRIVER §9 step 2 onwards):**
- `CommandLine` calling `cmd.run`/`cmd.complete`/`cmd.history`, and reporting `cmdlineIdle`
- `CoreClient.playCue` on clicks, keys and switches
- the hold meter bound to `igniteData`
- the Clips filter reading `query`
- the unfold origin from `from`/`screen`, and the satellites

Backend step 1 of DAILY_DRIVER §9 is complete on this branch.

## 9. Tasks from Claude A (`docs/M5-FOR-B.md` on `m5-view`)

1. **Fallthrough fold race, done.** `Context.fold()` now sends `close` whenever a view is connected (`state == "ready"`), not only after it has reported open. With no view it sends nothing and spawns nothing. Tests: `test_core_command` (fallthrough with the open report not yet arrived), `test_core_verbs` (host verbs fold every time).
2. **Pomodoro phase completion, done.** The timers snapshot gains `pomodoro.done: {phase, next, at, late} | null` (`at` is the true boundary in ms, `late` in seconds). It is set at every phase end, including the late, paused one after a suspend; the next phase keeps running. It is persisted in `timers.json`, so it survives a reap and a core restart. `timer.ack {kind: "pomodoro"}` clears it, `timer.ack` with no kind clears both DONEs, and `start`/`reset` of the pomodoro clear it. `CoreTimers` exposes `pomodoroDone`, and `ack(kind)` takes an optional kind. `status` gains `timers.pomodoroDone`. Test: `test_core_timers`.
3. **DONE with the view reaped, done.** When `countdown.done` or `pomodoro.done` becomes set (a new value, not one restored at core start) and the view is absent, the core spawns it closed through `view.ensure()`, as host calls do. No panel opens; the normal closed-idle reap still applies, so DONE shows for up to 10 minutes unless clicked. With a pomodoro running and the view reaped, that is one spawn per phase end. Test: `test_core_satellite`.
4. **Track event (Q8, the reaped case), done. For A: the topic is `track`, snapshot `{player, artist, title, at}`** (`at` in ms; all four null before the first change; `artist` null when the player sends none, several artists joined with ", "). It is a topic, not an event, so a view spawned for it reads the change from its first snapshot. `core/track.py` reads `PropertiesChanged` on `/org/mpris/MediaPlayer2` (interface `org.mpris.MediaPlayer2.Player`) and the MPRIS `NameOwnerChanged` off the same `busctl monitor` as the notification mirror (two more `--match` rules; players already running are found with `ListNames` when the monitor starts). A change is a new `(trackid, title, artist)` from a player that is playing; metadata that arrives while paused is announced when the player plays; the same track sent again is not a change. Titles are kept in memory only, never logged or written. `player` is the MPRIS name's first segment (`chromium`, `spotify`). With the view absent, a change spawns it closed, unless a session is active or the focused window is fullscreen (`guards.focused_fullscreen`, one read-only `j/activewindow` query, made only then). `CoreClient` subscribes to it and exposes `trackData`. Tests: `test_core_track` (message shapes captured from a real `busctl monitor` on a private bus), `test_core_busctl` (a fake player on a private bus, through the real monitor).
5. **The clock hook variant and its installer, done (not installed).** `adapters/serpantinum/hook/`: `upstream.qmlpart` (the host's handler), `variant.qmlpart` (right-click runs `~/.local/bin/fart toggle --from x,y,w,h --screen NAME`; left-click still opens the host calendar), `archive.qmlpart` (the archive's `fart open` hook, for recognition only) and `clock_hook.py FILE [--remove | --check]`. The file is always an argument; there is no default path. It installs only over the exact upstream hunk, and once only: a second run is a no-op, and so is `--remove` on an upstream file. It refuses anything else: a changed or duplicated handler, or the archive's hook. Surrounding text and the file mode are kept, and the write is staged and re-checked before an atomic replace. **The rect:** `fartPlacement()` adds the bar window's origin on its screen to `mapToItem(null, 0, 0)`. The origin comes from the window's anchors and margins, so a top bar gives margin-left/top (4, 4 here), a bottom bar counts from the screen's bottom edge, and a missing `barWindow`, `margins` or `screen` falls back to 0 and an empty screen name (the CLI then uses the focused screen). **Cutover sequence (M7, needs your approval):** remove the archive's hook with the archive's own tool, which restores the upstream handler; run `clock_hook.py` on the live file; roll back in reverse with `--remove`, then the archive's tool. Host QML reload is not done by this tool. Tests (`test_clock_hook`, temporary copies only): apply, reapply, remove, surrounding edits kept, four refused shapes, the archive's hook refused, no default file. A copy of the live face, with the archive's hook taken out, installs and removes cleanly; the live file is only read. The variant's own `fartPlacement()` text is also run offscreen in Qt's `qml` runner with a top bar, a bottom bar and missing margins. A copy of the live face with the variant has 0 `syntax*` diagnostics. NOTICE records the quoted host text.
6. **`desktop_nav.py --cold N` and `--warm N`, built, not run (A runs the desktop measurements).** Each run's latency is the view's `FART_CMDLINE ready <ms>` minus the wall-clock time just before `view.open` is sent. Cold: each run starts a fresh private core, so the view is absent and the run includes the `qs` start, the core's one-off foreign-instance check and, without `--cache-home`, QML compilation. Warm: one view, opened once uncounted, then N times close, wait 1 s, open. The report has per-mode `samples_ms`, median and max in ms and in refresh periods. `BUDGETS["desktop_open"] = {cold_ms: 450, warm_frames: 1}` is checked against the maxima, because every run must pass; a mode not run is not checked. Exit codes are as for the other desktop tools (0 pass, 1 fail, 2 interrupted, 3 unknown or insufficient). **Observer change:** these runs map their own window, which moves focus, so `Interaction(env, ignore=FOCUS)` drops `activewindow`/`activewindowv2` for them. The cursor, workspace and monitor events still interrupt. Each run is observed on its own, and any interrupted run makes the report interrupted. The default observer is unchanged. **To run it, use `m5-view` after merging:** `private_core` copies `FixtureView.qml` from the tool's own checkout, and only `m5-view`'s prints the marker. On `visible-ui` a run would time out waiting for the marker. Offline tests (`test_measurement`): marker parsing in Quickshell's log format, stats and checks, exit codes, `wait_marker`, and the observer ignoring its own focus events while still catching a workspace change.

All six tasks are done. The full suite and the smoke pass at the last commit. Nothing is merged, pushed, installed or bound.
