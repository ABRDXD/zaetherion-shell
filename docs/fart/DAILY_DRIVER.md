# Daily driver A: unfold, command line, satellites and sound (M5)

Status: **reviewed 6 November 2026** (decisions in section 11, which override the text above where they differ). The backend half is built on branch `visible-ui` ([M5-COMMAND.md](M5-COMMAND.md) there); the view half is not implemented yet.

M5 (PROJECT_PLAN) delivers D5 (no permanent exterior, unfold from the clock rect), D6 (the keyboard-first command line), D15 (keyboard first-class), D16 (the ignite hold, timing only; the Overdrive effect is M8), D18 (satellites) and D19 (minimal sound). It builds on the core (CORE.md), the contract (ADAPTER_CONTRACT.md) and the cue system with the Serpantinum motion profile (CUES.md §15).

Out of scope until you approve it separately (AGENTS.md): adding the Super+` bind, installing the systemd socket unit, the cutover (switching `fart` and the clock hook) and pushing. Until the cutover, the live clock keeps calling the archive's `fart open`. Everything in M5 is reachable through `fart-next` and the fixture.

## 1. Budgets and how they are measured

These are the PROJECT_PLAN budgets under the definition approved in step 1 (MEASUREMENT.md, "The desktop budget").

| Budget | Definition | Harness |
| --- | --- | --- |
| Cold start ≤ 450 ms to an interactive command line | From the moment the CLI sends `view.open` (core timestamp, boottime) to the view's first `view.state {cmdline: "ready"}` report. The view sends it on the first frame swapped after the command line's `TextInput` has active focus inside an exposed, keyboard-focused surface. Measured with the view absent (after a reap or `fart-next stop`), so it includes the `qs` process start. | `desktop_nav.py --cold N`: N reaps and opens, median and max. The fixture view and the real-view entry share `Overlay`, so the fixture times the same path minus the host adapter's start (measured separately, read-only, as the Serpantinum adapter's construction time). |
| Warm open ≤ 1 frame to interactive | The same report with the view warm and closed. Input never waits for the unfold (CUES rule 1). | the same, warm |
| Unfold and fold | 0 missed presentations during the Timeline, apart from the first frame after `open`, which builds `Shell` and the room and may miss ≤ 1. GPU and render-thread p99 ≤ 6.9 ms. | `desktop_nav.py --unfolds N` (added in this checkpoint) |
| Command line | 0 missed presentations while typing and while the suggestion list and log lines change. Keystrokes come from the fixture (`TextInput.insert` at 30 ms intervals), so this measures rendering, not input latency. Real key latency needs a virtual keyboard, which would be a new dependency. | `desktop_cmdline.py` (new) |
| Zero FART surfaces when idle | With the panel closed and no satellite due: `hyprctl layers -j` lists no `fart-*` namespace, and IPC `status` reports `surfaces: 0`. | read-only check in the live test, plus a view counter in the fixture |
| Idle cost | Closed: 0 CPU ticks and ≤ 1 view wakeup per second over 60 s. Open and static: ≤ 2% of one core, with `motion.active == 0`. | `desktop_idle.py` (added in this checkpoint) |

The baseline before M5 is in section 8.

## 2. The clock hook variant and the rect (D5)

**Today.** Serpantinum's `bar/faces/timedate/TimeDateFace.qml` runs `~/.local/bin/fart open` on a right-click, and the left button opens its calendar. That is the archive's hook and stays untouched until the cutover.

**The variant.** The same handler, plus the clock's rect and screen:

```qml
if (mouse.button === Qt.RightButton) {
    const p = root.mapToItem(null, 0, 0);                    // in the bar surface
    const m = root.barWindow?.margins;                       // the bar surface's offset on its screen
    const rect = [p.x + (m?.left ?? 0), p.y + (m?.top ?? 0), root.width, root.height].map(Math.round).join(",");
    Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/fart", "toggle", "--from", rect,
                             "--screen", root.barWindow?.screen?.name ?? ""]);
    return;
}
```

- Checked read-only today: the bar is a `quickshell` layer at (4, 4, 1912 × 40) on eDP-1. So bar-surface coordinates are off by the bar's 4 px margins, and the hook adds them. If `barWindow.margins` is not exposed, the adapter adds the offset from host settings instead. That gets checked when the variant is installed.
- The text lives in `adapters/serpantinum/hook/` with an installer that writes it only on your instruction at the cutover (M7), with the archive's checks (exact handler match, surrounding changes kept, host QML reloaded in process) and `--remove`. M5 tests it against a copy of `TimeDateFace.qml` in a temporary directory.
- **Toggle, not open** (Q1): a second right-click folds the panel, as Serpantinum's own calendar toggles.

**CLI and core.** `fart-next open|toggle [--from x,y,w,h] [--screen NAME]`. The core already accepts and validates `from`, and gains `screen` (a string, optional). It passes both in `view.command`. `Overlay` calls `host.clockGeometry.setHookRect(screen, …)`, so the exact rect is remembered per screen for later opens without one (Super+`, `fart-next page`).

**Fallback.** Without `--from`, the panel uses `clockGeometry.rectFor(focusedScreen)`. That is the estimate already in `SerpantinumClockGeometry`: a centred 160 px clock on the bar's edge, from `bar.position` and `bar.height`. Verified settings: top, 40 px, autohide available. When the bar autohides, the estimate is still used, because Serpantinum's calendar is placed the same way (`WindowRegistry.js`: top-centre, 52 px from the edge).

**Multi-monitor:** the panel opens on the hook's screen, or else on the focused screen (PROJECT_PLAN: a safety check, not a feature).

## 3. The unfold from the rect

The panel stays where it is today (top-centre, under the bar's exclusive zone, 1120 × 760 clamped to the screen), which is also where Serpantinum puts its calendar. What changes is where it grows from.

- **Origin.** `Unfold` gains `origin: point`, the clock's centre-x and the panel's top edge, in panel coordinates and clamped to the panel's width. The body's scale uses it as `transformOrigin` instead of the centre. The body's rise stays a rise, because a host popup on a top bar rises into place. A bottom bar mirrors it, so the rise becomes a drop (`edge` from the rect).
- **Timeline.** Unchanged from §15: body, header and index, room. The command line sits in the header plane, so it appears with the header (from 10% of the driver). It accepts keys from the first frame, because focus does not wait for opacity.
- **Interrupt and reverse.** These are the cue rules. `toggle` during the unfold reverses from the current value over `fold × distance`. `open` during the fold reverses back. A new `--from` while open moves nothing: the panel does not jump to another clock, and the rect is stored for the next unfold.
- **The first frame.** Opening builds `Shell` and the room in one turn (17–20 ms of creation measured today, section 8), so the first unfold frame misses 2–3 presentations. M5 makes the first frame cheap: `Shell` loads with an empty room slot and the command line, and the room incubates asynchronously (the nav-async prototype, section 8). It appears with the room track at 20% of the driver, about 200 ms later under the Serpantinum profile, so incubation has time.
- **Keep Shell warm?** (Q2) Folding currently unloads `Shell` (`retained`), so every open rebuilds it. Keeping it loaded while the view lives would make warm opens nearly free, at a cost in closed PSS that must be measured. The recommendation is to measure both and decide by the 200 MiB closed-PSS budget.

## 4. The command line (D6)

### 4.1 Where and when

- It is a `CommandLine` component in `view/shell/`, in the header row. It replaces the Search button, and the header keeps the logo, clock and Close.
- **Focus.** Every open focuses it, whether from the clock, Super+` or the CLI (Q3). Typing a character anywhere in the panel, with no text field focused, moves focus to it and inserts the character. Escape clears the line, and Escape on an empty line closes the panel. Tab moves focus into the room (M6 adds the reticle). Ctrl+0–8 keep working everywhere.
- **Keyboard focus on the layer.** It is `OnDemand` today. While the command line has focus the surface keeps `OnDemand`, which Hyprland already gives a newly mapped layer surface that asks for it. `Exclusive` is not needed, and it would break the outside-click fold. The ignite prototype (4.6) has to confirm that binds still fire while FART holds keyboard focus.

### 4.2 Grammar (v1, approved) and matching

A line is `verb [args…]`. A bare verb opens its room; a verb with arguments acts. Matching runs on the first word only:

1. An exact name or alias.
2. Otherwise a **unique prefix** among names and aliases. `pe` → `perf`, `cl` → `clip`.
3. Otherwise an ambiguous prefix (`t` → `task`, `tim`, `theme`). The candidates are listed inline, ranked by how often you used them (history counts), and Enter runs the top one only if it was used at least twice as often as the next. Otherwise Enter completes to the longest common prefix.
4. Otherwise it falls through to the host launcher (4.5).

There is no subsequence or typo matching, so a mistyped verb never runs something else (Q4). Arguments are parsed by the verb.

| Domain file | Verbs | Action (all through existing contract methods or core ops) |
| --- | --- | --- |
| `rooms.js` | `home med perf ws dev task tim clip inbox` | `navigate(room)` |
| `media.js` | `play`, `next`, `prev`, `lyr`, `out <device>` | `media.togglePlaying/next/previous`. `lyr` opens Media (M6 adds the lyrics subpanel). `out` fuzzy-matches an output name and calls `audio.setDefault("output", id)` under a short `mixer` lease. |
| `timers.js` | `tim <dur>`, `tim focus [min]`, `tim sw`, `tim lap`, `tim pause`, `tim stop`, plus top-level `focus [min]` and `sw` | the core's `timer.*` ops, with the same parsing as `fart-next tim` (CORE.md §8) |
| `tasks.js` | `task <text> [@list] [!due]` | `task.add`. `!today`, `!tomorrow`, `!mon`…`!sun` (the next one), `!+3d`, `!2026-11-12`. An unknown `@list` is an error, not a new list. |
| `session.js` | `session <preset> [dur]`, `session end` | `session.start`/`end`; presets focus, deep, study, read (M11) |
| `system.js` | `vol <0–100>`, `bri <0–100>`, `wifi [on\|off]`, `bt [on\|off]`, `power perf\|bal\|save` | `audio.setVolume` under `mixer`, `power.setBrightness`, `network.setWifiEnabled`, `bluetooth.setEnabled`, `power.setProfile`. A bare `wifi`/`bt` opens Devices. |
| `clips.js` | `clip <words>` | opens Clips filtered by the words. Enter in the command line copies the top match (copy only, no paste). |
| `modes.js` | `overdrive [20m\|sticky\|off]`, `silent` | `overdrive.request`/`release`. `silent` is `release`. |
| `host.js` | `wall`, `theme`, `settings`, `lock`, `update` | `hostActions.open("wallpapers"\|"themes"\|"settings"\|"updates")`, `power.lock()` |
| `help.js` | `?`, `? <verb>` | live help (4.4) |

**Registry.** `view/shell/verbs/<domain>.js` (`.pragma library`). Each file exports a list of `{ names, aliases, args, examples, run(context, words) }`. `run` returns `{ line, tone }` (tone: `ok`/`error`/`info`) or a promise-like callback for core requests. `verbs/Registry.js` imports every domain file, so adding a verb is a data change in one file plus its examples. `context` gives `navigate`, `host` (the adapter), `core` and `log`. Verbs never import adapters or host paths, so the contract lint applies to `view/shell/verbs`.

**The CLI.** `fart-next` keeps its own Python parsers for the verbs that work without a view (`tim`, `overdrive`, `session`, rooms). A test checks that both sides accept the same examples for those verbs (Q5).

### 4.3 Results: inline log lines

Enter runs the verb at once (CUES rule 1) and appends one line under the input, for example `tim 25 → countdown 25:00`, `vol 40 → output 40%`, or `task … → added to default, due Fri`. Errors use the signal role and name the problem in words. At most 3 lines show. A new line fades in with the `feedback` role, and the oldest drops without animation. The lines are view state, cleared when the panel folds. Core replies are asynchronous, so a line shows `…` until the reply arrives. A failed reply replaces it with the error, and nothing queues behind it.

### 4.4 History and help

- **History:** the last 100 lines that ran, newest last. Up and Down browse, prefix-filtered by what is typed. It is persisted by the core (`history.list`, `history.add`; `history.json`, mode 0600), so the view keeps writing only its two preference files. `clip` queries are not recorded (Q6). `fart-next` lines are not recorded.
- **Help:** `?` lists the verbs by domain with one example each. `? tim` shows that verb's grammar and examples. While a verb is being typed, a hint line shows its arguments (`tim <25 | 90s | 1h30 | focus [min] | sw | lap | pause | stop>`). Help is generated from the registry, so it cannot drift from it.

### 4.5 Fallthrough to the host launcher

An unrecognised first word runs `hostActions.openLauncher(text)`. Serpantinum 2.4.1 takes no query (ADAPTER_CONTRACT §4, §7.6), so the launcher opens empty. The panel folds first so the host popup is not under FART's layer, and the log line is not shown (the panel is gone). With `launcherAcceptsQuery` true on a future host, the text is passed through. There is no FART-side app search in M5.

### 4.6 Super+` and the ignite hold (D16, Ignite key)

**The bind (needs your approval before it is added).** An isolated include, `~/.config/hypr/fart-next.conf`, sourced by one line you add or approve, containing:

```
bind  = SUPER, grave, exec, fart-next key down
bindr = SUPER, grave, exec, fart-next key up
```

**Timing is the core's**, so it works with the view reaped and survives a view crash:

| Event | Core action |
| --- | --- |
| `key down` | Record `t0` (boottime). Send `view.command {action: "open", focus: "cmdline"}`, spawning the view if needed. Arm `ignite.meter` at `t0 + 150 ms`. |
| `ignite.meter` fires (still held) | Publish `ignite {holding: true, since: t0}`. The view shows the hold meter, bound to data (CUES §6: information, not motion). |
| `key up` before 600 ms | Disarm. Publish `ignite {holding: false}`. The command line stays. |
| `key up` at ≥ 600 ms, or `ignite.fire` at `t0 + 600 ms` while held | `overdrive.request {mode: "panel"}` (ends when the panel closes, D16). Publish `ignite {fired: true}`. The M8 effect hangs off this. |
| No `key up` within 3 s | Treated as released (a lost release must not leave the meter up). |
| `key down` again while held | Ignored (no auto-repeat: `bind` without `e` does not repeat). |
| `key down` while the panel is open with the command line focused and empty | Folds the panel (Q7) |

- Firing at 600 ms while the key is still down (rather than waiting for release) matches "hold to ignite" and avoids depending on the release for the effect itself. The release then only ends the meter. Both `fart-next key` calls are thin clients. Measured Python start-up for the thin client goes into the prototype report, because both edges pay it equally and the hold length is a difference.
- **Prototype first (the risk named in PROJECT_PLAN).** After you approve the bind: with FART's surface holding keyboard focus, check that (a) `bindr` fires when Super is released before the grave key, and when it is released after; (b) neither press nor release reaches FART's `TextInput` as a stray grave; (c) the outside-click fold still works. The fallback, if `bindr` with the modifier is unreliable, is `bindr = , grave, …` scoped by a submap entered on the press. That is recorded, not pre-built.
- Tests: the core's ignite state machine with the fake clock (press/release at 100, 149, 151, 599, 601 ms, a lost release, a double press, release with the view absent, a view crash while held), plus the fixture view showing the meter only from data.

## 5. Satellites (D18)

A satellite is a small layer surface beside the clock rect (below it on a top bar), with namespace `fart-satellite`, no keyboard focus, `exclusionMode: Ignore` and an input region that covers only itself. Each kind is a `Loader` that is active only while it has something to show. There is no surface, timer or animation otherwise, which is the "zero FART surfaces when idle" check. Satellites live in the view process. They never show while a fullscreen window is on the focused workspace (the `workspaces` domain), or while the panel is open (the panel already shows the same thing).

| Kind | Shows | Lifetime and cost |
| --- | --- | --- |
| **Timer / session** | Remaining time of the engaged timer or session, plus the active task (the first open task of the session's list, or of the default list during a focus pomodoro) on a second line | While a timer runs. The text changes on minute boundaries (`25′`), so a single-shot `Timer` wakes the view once a minute. In the last minute it changes per second. Click opens Timers. |
| **DONE** | An inverted `DONE` (paper/ink swap) when a countdown or pomodoro phase completes | One flash pulse through `FlashGate`, then static until clicked. Click sends `timer.ack`. With reduced motion, a static inverted state with no flash. If the view is absent, the core spawns it in satellite-only mode (no panel). |
| **Track change** | `artist — title` on a track change | 3 s (a `dwell` token added to `Motion`), then unloaded. Only while the view is alive (Q8). No persistent now-playing satellite (D18). Suppressed during a session. |

- Core side: the timer/session satellite and DONE follow the `timers` and `session` topics, which the view already receives. A view spawned for DONE stays under the normal 10-minute reap.
- The flash and the DONE pulse go through `FlashGate` (CUES §7). Track-change text fades in and out with the `swap` role.

## 6. Sound (D19)

Only **the core** plays sounds: `sfx.play {cue}` is a new core op, and the view calls it rather than `host.sfx.play` directly. One place applies the policy, and alarms play with the view reaped (CORE.md §10).

- **Gate:** play only if FART's sound setting is on, the host's `muteSfx` is off, the host's DND is off, and no session is active, unless the cue belongs to the session (`pomodoro.phase`, `session.end`). Volume is the host's `sfxVolume`.
- **Cues in M5:** `timer.done`, `pomodoro.phase`, `session.end` (the freedesktop `alarm-clock-elapsed`, as today). `ignite` is reserved for M8.
- **Following the host's UI sounds** (Q9): Serpantinum plays its own click, key, switch and error sounds from its source tree on its controls (`Sounds.qml`, read-only survey: `playSfx(clickSound)` ×10, `quick_click` ×8, `keySound` ×7 …). "Minimal sfx" says FART does not. If you want FART to feel like the host here too, the adapter can map `ui.click`, `ui.error` and `cmd.run` to those files, behind the same gate. The recommendation is not to, because D19 says minimal.

## 7. Fixture tests

| Area | Tests |
| --- | --- |
| Rect and unfold | The CLI parses `--from`/`--screen` (bad values give a usage error). The core validates them and forwards them. `Overlay` stores the hook rect. The unfold origin is clamped. Reversal during the unfold and fold follows the cue rules (`ViewTest`). A new `--from` while open does not move the panel. |
| Hook variant | The installer applies, reapplies (no-op) and removes the variant on a temporary copy of `TimeDateFace.qml`, and refuses a changed upstream handler. |
| Verbs | Every registry example runs against the fixture adapter and a private core, and produces the expected fixture call or core op. Unknown words call `openLauncher` once and fold. Ambiguous prefixes list candidates. History ranking and the 2× rule are tested. `?` output is generated from the registry. The examples for the CLI's verbs parse the same on both sides. |
| Queued input | Characters typed during the unfold all land in the line, in order. Enter during the unfold runs at once. Enter ×5 within 100 ms runs 5 lines in order, each with its own result line, and nothing waits for a reply. Escape during the unfold folds from the current value. |
| Ignite | The core state machine table in 4.6, with the fake clock |
| Satellites | Each kind loads only while due and unloads after. The DONE flash is granted once; under reduced motion it is static. Fullscreen and panel-open suppress them. Count = 0 when idle. |
| Sound | The gate truth table (setting × mute × DND × session × cue) against the fixture host profile; no `pw-play` in tests |
| No actuation | All verb tests use the fixture adapter. The live check uses read-only `status` and `hyprctl layers` only. |

## 8. Baseline at this checkpoint (desktop fixture, Serpantinum motion profile)

Quiet runs only (the interaction observer reported no input; 5 interrupted runs were discarded). eDP-1 at 144.003 Hz, VRR off, dGPU suspended before and after. Reports: `docs/measurements/desktop-nav-edfeb85-serpantinum.json`, `desktop-nav-bd51d5b-async-serpantinum.json`, `desktop-idle-58b2070-serpantinum.json`.

| Fixture view on the desktop, 4 unfolds + 4 passes × 9 rooms | main `edfeb85` | branch `nav-async` `bd51d5b` |
| --- | --- | --- |
| Missed presentations on room-load frames | 36 | 0 |
| Missed in steady frames | 5 | 12 (11 in Workspaces) |
| Unfold: first frame (builds `Shell` and Home) | 19.9–23.9 ms, 2 missed each | 11.0–16.2 ms, 1 missed each |
| Unfold and fold Timelines after the first frame | 0 missed | 0 missed |
| Synchronous part of a navigation command | 4–17 ms | 0–1 ms |
| GPU p99 / render-thread p99 (worst room) | 2.0 / 6 ms | 1.7 / 4 ms |

- On `nav-async`, a room's first layout polish lands on the frame the slots swap, which the harness counts as steady. Workspaces polishes in 8–26 ms there. So part of the room-load improvement moved into steady frames, but the total still fell from 49 to 16 missed presentations. The next step is to swap one frame after the incoming room is ready (it is laid out invisibly first), then trim Workspaces' miniatures.
- Idle (main `58b2070`, Serpantinum profile, 60 s windows): open and static: 1 frame rendered, `motion.active` 0, 2 CPU ticks, about 4 view context switches per second, view 462.5 MiB RSS / 187.4 MiB PSS / 146.0 MiB private dirty. Closed: 0 frames, `motion.active` 0, 0 ticks, 1 switch per minute, 462.3 / 187.2 / 145.8 MiB. Core: 21.3 MiB RSS / 12.1 MiB PSS, 0 ticks. This is the fixture view (no host adapter, mirror or helpers), so it is not comparable with the real view's M2 baseline (6 ticks and about 5 wakeups/s per 60 s closed). The real view was not measured, because that needs the real panel opened.
- Idle-time precompilation (fix 3) on `nav-async`: offscreen view PSS after opening Home and idling 4 s was 87.8–89.9 MiB (3 runs) against 89.8–91.9 MiB on main. That is within noise, so there is no measurable cost.
- Cold start to an interactive command line is not measurable until the command line exists. M2 measured a cold open at 0.39–0.63 s, so the 450 ms budget needs the cheap first frame from section 3.

## 9. Implementation order (after review)

1. Core: `screen` in `view.open`/`toggle`, `history.*`, `sfx.play` with the D19 gate, the ignite state machine and `fart-next key`. Python tests.
2. View: `Unfold` origin, the command line (registry, matching, results, history, help), the empty-room first frame. The `cmdtest` harness.
3. Satellites and the DONE flash. The idle-surface counter.
4. Measurement: `--cold`, `desktop_cmdline.py`, the surfaces check. Desktop runs on the fixture view.
5. With your approval: the bind include, then the ignite prototype (4.6) and its report.
6. The hook variant and its installer, tested on a copy. It is installed only at the cutover.

## 10. Questions for review

| # | Question | Recommendation | Alternative |
| --- | --- | --- | --- |
| Q1 | What does a right-click on the clock do while the panel is open? | **Toggle** (fold), like Serpantinum's calendar | Open only, as the archive's hook does (a second click does nothing) |
| Q2 | Should `Shell` stay loaded while the panel is closed? | **Measure both, and keep it** if closed PSS stays ≤ 200 MiB | Unload on fold as now (every open rebuilds `Shell`) |
| Q3 | Where does focus go when the panel opens from the clock with a mouse click? | **The command line**, always (keyboard-first) | The room, with only Super+` focusing the command line |
| Q4 | How fuzzy is matching? | **Exact, then unique prefix, then ranked prefix with the 2× rule**; no typo matching | Subsequence fuzzy matching, as in many launchers |
| Q5 | Where do verbs live? | **QML/JS registry in the view**; the CLI keeps its Python parsers for view-less verbs, with a parity test | One registry in the core that both use. The view would then send raw lines to the core, and adapter actions would round-trip back to the view. |
| Q6 | Command history | **Persisted by the core, 100 lines, 0600; `clip` queries excluded** | In memory only (lost on reap) |
| Q7 | Super+` while the command line is focused and empty | **Fold the panel** | Do nothing |
| Q8 | The track-change satellite when the view is reaped | **Not shown** (no 190 MiB view for a 3 s label) | The core spawns the view for it |
| Q9 | Host UI click and key sounds | **No**, alarms only (D19) | Map ui.click/ui.error/cmd.run to Serpantinum's own sounds |
| Q10 | The timer satellite while a timer runs | **Shown, minute resolution** (one wakeup a minute, per second in the last minute) | Shown only on start and phase change for 3 s |

## 11. Review decisions (6 November 2026)

| # | Decision |
| --- | --- |
| Q1 | Toggle (recommended) |
| Q2 | Measure both; keep `Shell` loaded if closed PSS stays ≤ 200 MiB (recommended) |
| Q3 | Every open focuses the command line (recommended) |
| Q4 | Exact, then unique prefix, then ranked prefix with the 2× rule; no typo matching (recommended) |
| Q5 | **The core registry** (the alternative), as built on `visible-ui`: `core/command.py` and `core/verbs/`, shared by `fart-next <verb>` and the command line through `cmd.run`/`cmd.complete`/`cmd.history`. Adapter actions round-trip through the view's `CoreHostCalls` under a brief lease (`vol` holds `mixer`). Section 4.2's view registry and the CLI parity test are dropped. |
| Q6 | History in the core, 100 lines, 0600, `clip` excluded (recommended; built) |
| Q7 | Super+` on a focused, empty command line folds the panel (recommended) |
| Q8 | **The track-change satellite may land after M5, but it is a committed deliverable**, recorded in PROJECT_PLAN: first while the view is alive, then also with the view reaped (the core watching MPRIS through its busctl monitor and spawning the satellite). It must not be dropped. |
| Q9 | **Yes: FART plays the host's UI sounds.** The adapter maps FART's UI cues (`ui.click`, `ui.key`, `ui.switch`, `ui.error`, `cmd.run`) to the files Serpantinum's own controls play (`Sounds.qml`), through the core's single D19 gate (FART sound setting, host `muteSfx`, DND, sessions) at the host's `sfxVolume`. Each UI cue can be switched off (`sfx.configure`). |
| Q10 | Timer satellite shown while a timer runs, minute resolution (recommended) |

Follow-up decisions after the M5 measurements (6 November 2026, evening): Shell stays loaded (Q2) although closed PSS is 237 MiB (231 MiB unloaded, both over the 200 MiB condition). The cold ≤ 450 ms and warm ≤ 1 frame budgets stay and are to be worked toward; they currently measure 821 ms and 6 frames on the fixture view (M5-VIEW.md).
