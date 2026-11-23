# M5 view half: command line, unfold origin, satellites, UI sounds

Status: **built on branch `m5-view`, 6 November 2026. Not merged or pushed.** This is the view half of M5 (DAILY_DRIVER §9 steps 2–4), built against Claude B's protocol on `visible-ui` (M5-COMMAND.md). `m5-view` contains `visible-ui` up to `2d55d8c` and `nav-async`. The hook variant and installer, `desktop_nav --cold`, and several core follow-ups were handed to Claude B ([M5-FOR-B.md](M5-FOR-B.md)).

## What was built

| Piece | Files | Notes |
| --- | --- | --- |
| Command line | `view/shell/CommandLine.qml`, `Shell.qml` | Replaces the header's Search button. Enter appends a log entry showing `…` and sends `cmd.run`, without waiting. At most 3 entries; each new one fades in with `feedback`; the oldest drops without animation; a fold clears them. The hint comes from `cmd.complete`, and stale replies are dropped. Up/Down browse `cmd.history`, prefix-filtered by the draft. Tab completes to `complete`, otherwise focus moves into the room. Escape clears a line, and on an empty line it folds the panel. Ambiguous: Enter puts the line back for refining. Fallthrough: the core folds the panel and opens the launcher, and the entry is dropped. A printable key with no text field focused moves to the line (`Shell` `Keys.onPressed`). |
| Focus | `Overlay.openPage`, `PanelBody` | Every open focuses the line (Q3). `PanelBody.interactive` fires once per open, on the first frame swapped after the line has active focus in an active window. The fixture view prints it as `FART_CMDLINE ready <ms>` for the cold and warm budgets. |
| Q7 report | `Overlay.reportState` | `view.state {open, page, cmdlineIdle}` is sent on every focus or text change of the line. |
| Unfold origin | `view/shell/PanelBody.qml` | The panel body as drawn, shared by `Overlay` and `FixtureView`. The body scales about `origin`: the clock's centre-x, clamped to the panel, on the bar-side edge. A bottom bar mirrors the rise. The mask and blur follow `shape`. The origin and screen are chosen only when opening from fully folded; a new rect while open is stored (`setHookRect`) and moves nothing. Clock rects are now screen-local (Serpantinum's estimate was in global layout coordinates). |
| Satellites | `view/satellites/` | `SatelliteState` holds plain state and is offscreen-testable. `Satellites` has one surface Loader (active only while something is due), with one Loader per kind inside it. `SatelliteWindow` is the `fart-satellite` layer surface: no keyboard focus, `ExclusionMode.Ignore`, sized to its cards, placed under the clock rect. Timer/session: minutes, per second in the last minute, one single-shot wake per change. DONE: inverted, with one `FlashGate` pulse (static when reduced); a click acks it. Track: `artist — title` for `Motion.dwell` (3 s, a new token) after a change seen while the view lives; the first track is not a change. All kinds are suppressed while the panel is shown or a fullscreen window is on the focused screen; the track also during a session. IPC `status` reports `surfaces` and `satellites`. |
| UI sounds | `view/ui/Feedback.qml` | Controls name the moment: `ui.click` (FButton, satellite cards), `ui.switch` (FToggle, FChoice, the room index) and `ui.key` (the command line, at most once per 40 ms). The entry routes it to `sfx.play`. The view plays nothing; `cmd.run`/`ui.error` come from the core. |
| Ignite meter | `CommandLine.qml` | A 2 px bar under the line, shown while `igniteData.holding`. It fills towards the 600 ms fire point from `since` and turns warm when `fired`. Its frame clock runs only while the key is held. The M8 effect replaces the look. |
| Kept Shell (Q2) | `PanelBody.keepShell` | Off by default. Keeps `Shell` loaded while folded, but releases its room. See measurements. |

## Tests

- `tests/test_cmdline_view.py` runs `tools/cmdtest/CmdView.qml`: the real core and CLI with the fixture view offscreen. It has 18 checks: focus on open, characters typed during the unfold landing in order, Enter during the unfold running at once, Enter ×5 in under 100 ms giving five ordered tasks, history and prefix filtering, the hint, ambiguity, `?` generated from the registry, the error tone, the Escape rules, the origin from a rect (a second rect moves nothing), the interactive report, Super+` folding an idle line (Q7, through `key.down`), Escape during the unfold folding without a jump, and the launcher fallthrough. It also checks that `ui.key`, `cmd.run` and `ui.error` reach the core's fixture player.
- `tests/test_cues.py::test_satellites` runs `tools/cuetest/SatTest.qml` with 11 checks: idle has no surface, timer wakes, the last minute, suppression, the DONE flash and its reduced form, unload, pomodoro phase, track dwell, session suppression, and idle at the end with `Motion.active == 0`.
- Keys → handlers (Return, Escape, Up/Down, Tab, type-anywhere) are not covered offscreen. Offscreen Qt has no keyboard, and a virtual keyboard would be a new dependency. That mapping is left to the desktop check.

## Not built here

The track satellite with the view reaped, DONE with the view reaped, and a core `pomodoro.done` (Claude B, tasks 2–4). The hook variant (B, task 5). The Clips filter does not read `query` yet (M6). The Super+` prototype waits for your approval of the bind.

## Desktop measurements (Claude B, 6 November 2026, 19:00–19:13)

Fixture view at `ca88a7a`, Serpantinum motion profile, eDP-1 at 144 Hz with VRR off, and the dGPU suspended before and after every run. Quiet runs only: two interrupted idle attempts were discarded. The first `--cold` attempt raised before measuring anything, because the window never got keyboard focus. That case now counts as interrupted (`7dd3a86`). Reports: `docs/measurements/desktop-*-ca88a7a-*.json`.

| Budget | Result | Status |
| --- | --- | --- |
| Cold start ≤ 450 ms to an interactive command line (`--cold 5`) | 787, 794, 821, 838, 846 ms (median 821) | **fail**. Each run starts a fresh private core, so it includes the core's one-off `qs list` check (125–131 ms here) and QML compilation with no disk cache (Quickshell's `qs:` URLs are never cached, nav-timing finding 3). An open after a reap, with the core already running, would be about 690 ms. That is estimated, not measured. |
| Warm open ≤ 1 frame (`--warm 5`) | 33–62 ms (median 42 ms, 6.1 frames; max 8.9) | **fail**. Each warm open maps a new toplevel (`FART_KEEP_MAPPED=0`) and waits for the compositor to give it keyboard focus. Typed input does not wait for this (offscreen check `cmdline.typed.during.unfold`). The real view maps a layer surface instead, which is not measured yet. |
| Unfold/fold (`--unfolds 4`) | 0 missed in the fold and unfold segments, in both runs | pass |
| Steady navigation | 40 and 46 missed (Workspaces 28/37, Media 8/7) | fail, but a same-session run of **main** `b8dee68` missed 44 (Workspaces 31). These are today's desktop conditions, not an m5-view regression. Workspaces is the M6 trim. |
| Command line while typing | run 1: 1 missed over 596; run 2: 0 over 594. GPU p99 0.80/1.38 ms, render-thread p99 3 ms | run 1 fails, run 2 passes (noise at the edge) |
| Closed idle | 0 frames, 0 CPU ticks, 1 view wakeup/min (kept and unloaded alike) | pass |
| Open idle ≤ 2% | 0.7% (42 ticks/60 s), 120 frames/60 s, `motion.active` 0 | pass. The 120 frames are the focused command line's cursor blinking (2 Hz); M4 open idle was 1 frame and 2 ticks. |

**Memory, closed idle (Q2 A/B, same session):**

| View | RSS | PSS | Private dirty |
| --- | --- | --- | --- |
| Shell kept (default) | 484.9 MiB | 236.9 MiB | 157.4 MiB |
| Shell unloaded (`--unload-shell`) | 478.9 MiB | 231.0 MiB | 151.5 MiB |
| M4 baseline (`58b2070`, earlier session) | 462.3 MiB | 187.2 MiB | 145.8 MiB |
| Core (both runs) | 21.6 MiB | 12.7 MiB | 11.8 MiB |

The kept Shell costs about 6 MiB in each column. **Both variants exceed the Q2 condition of closed PSS ≤ 200 MiB.** Against M4, private dirty grew 6–12 MiB but PSS grew 44–50 MiB. Most of the PSS growth is therefore in how shared pages are split among the Quickshell processes running at the time, not new FART memory. Only the archive's `qs` and Serpantinum's `quickshell` ran during these runs; what ran during M4's run was not recorded. The Q2 decision needs the user.
