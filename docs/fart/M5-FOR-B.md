# M5: work handed to Claude B (from Claude A, view half)

Claude A builds the M5 view half on branch `m5-view` (worktree `../next-m5-view`). It is based on `visible-ui` 2d55d8c plus `nav-async`. Read it, but don't edit it. Work on `visible-ui` in `../next-visible` as before. Don't merge, push or install anything, and don't add the bind or the socket unit.

What the view already does with your protocol (on `m5-view`):
- `CommandLine` (`view/shell/CommandLine.qml`) uses `cmd.run`, `cmd.complete` and `cmd.history {limit: 100}`. It reads `fallthrough`, `code: "ambiguous"`, `complete` and `tone`.
- `view.state` sends `cmdlineIdle` on every focus or text change. `key.down` on an idle line folds, and that is tested end to end.
- UI moments go to `sfx.play {cue}`: `ui.key` while typing (at most one per 40 ms), `ui.click` from FButton, and `ui.switch` from FToggle, FChoice and the room index. The view sends no `cmd.run` or `ui.error` cue, because the core already emits them.
- `view.command` extras: `screen` picks the panel's output. `from` sets the unfold origin and is stored with `clockGeometry.setHookRect`. A new `from` while open is stored but moves nothing.
- `tests/test_cmdline_view.py` and `tools/cmdtest/CmdView.qml` hold 18 checks against the real core in the fixture view.

## Tasks for B, in order

1. **Fallthrough fold race (core, small).** `Context.fold()` folds only when `view.open` is true. `view.open` comes from the view's report, and the fixture view sends that only after the room loads. So a fast "type + Enter" after an open can open the launcher under an unfolded panel. Fix: send `close` whenever `view.state == "ready"`. A close on a closed panel is a no-op in both views. Add a core test.

2. **Pomodoro phase completion for the DONE satellite (core).** The timers snapshot has `countdown.done` but nothing for a completed pomodoro phase. DAILY_DRIVER §5 wants DONE for both, static until clicked, and surviving a reap. Proposal: `pomodoro.done: {phase, at} | null`, set on each phase end and cleared by `timer.ack {kind: "pomodoro"}` (or by `timer.ack` with no kind). Until this exists, the view keeps a view-local flag.

3. **DONE with the view reaped (core).** DAILY_DRIVER §5: "If the view is absent, the core spawns it in satellite-only mode (no panel)." Spawn the view closed, as `view.ensure()` does for host calls, when `countdown.done` (or the new `pomodoro.done`) becomes set while the view is absent. Leave the normal 10-minute reap in place. The view shows DONE from the timers snapshot without opening the panel.

4. **The track event, the committed Q8 deliverable (core).** Let the core watch MPRIS through its busctl monitor and publish `track {player, artist, title, at}` on a track change. The view half uses `host.media` while the view is alive. Your event is for the reaped case: spawn the view closed for the satellite, unless a session is active or a fullscreen window is focused. Send A the topic name and shape. It may land after M5, but no later than M16.

5. **The clock hook variant and its installer (DAILY_DRIVER §2, §9 step 6).**
   - Put the variant's text in `adapters/serpantinum/hook/`: the right-click handler with `fart toggle --from x,y,w,h --screen NAME`, where the rect is the bar-surface position plus the bar's margins.
   - Add a Python installer that refuses unless the upstream handler matches exactly. It keeps surrounding changes, is a no-op when the variant is already there, has `--remove`, takes the target file as an argument and never defaults to the live host file.
   - Test only against temporary copies of `TimeDateFace.qml`: apply, reapply, remove, a changed upstream handler and missing margins.
   - Read the archive's hook installer read-only, under `~/.local/share/fart/source`, for its checks.
   - Don't touch the live `TimeDateFace.qml`, the archive or the `fart` launcher.

6. **`desktop_nav.py --cold N` (measurement tooling).** Cold start is measured to an interactive command line, with a budget of 450 ms or less (DAILY_DRIVER §1).
   - The fixture view prints `FART_CMDLINE ready <Date.now() ms>` once per open, on the first frame swapped after the command line has active focus in an active window (`PanelBody.interactive`).
   - For each of N runs: `stop`, or reap the view; take a wall-clock timestamp; send `open`; read the marker from `FART_VIEW_STDOUT`; report the median and max.
   - Do the same warm: close, wait 1 s, open. The budget is ≤ 1 frame.
   - Keep the interaction observer and the exit codes the same as the other desktop tools. Test the parser offline.
   - A ≤ 450 ms check in `budgets.py` is welcome.
   - A will run the desktop measurements, so don't run them yourself.

When a task is done, commit it on `visible-ui` with the attribution trailer and add a line here (on your branch, in `docs/M5-COMMAND.md`). A merges `visible-ui` into `m5-view` and asks the user before anything reaches `main`.
