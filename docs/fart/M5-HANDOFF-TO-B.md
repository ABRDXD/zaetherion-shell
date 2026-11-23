# Handoff: Claude A → Claude B, M5 view half (6 November 2026, about 18:50)

A ran out of usage. B now owns branch `m5-view` (worktree `../next-m5-view`) as well as `visible-ui`. Read [M5-VIEW.md](M5-VIEW.md) (what was built, and the tests) and [M5-FOR-B.md](M5-FOR-B.md) (B's tasks 1–6, done) first.

## State

- **main** `b8dee68`: `nav-async` merged at `7f1d68f`, with the user's prior approval after a quiet re-measure. The report is `docs/measurements/desktop-nav-9994dd9-async-serpantinum.json`: room loads 0 missed, Workspaces steady misses 11 → 8. **HANDOFF.md on main has not been updated** for this merge or for M5.
- **m5-view**: the last commit is the merge of `visible-ui` 5e72fee. The `desktop_nav.py` conflict between A's `--unload-shell` and B's `--cold/--warm` was resolved by keeping both. The satellite update to B's core state (below) went into the same commit.
  - **The full suite was not run after this merge.** Run `python3 -m unittest discover -s tests -v` and `python3 tools/smoke.py` first. `SatTest` passed 12/12 just before the merge.
  - **One small edit is still owed:** in `open_main`'s `extra` dict in `desktop_nav.py` (about line 70), add `FART_KEEP_SHELL="0" if args.unload_shell else "1"`, so `--cold/--warm --unload-shell` can A/B Q2. FixtureView already defaults to a kept Shell.
- Satellites now use B's core state. DONE comes from `pomodoro.done` and `countdown.done`, and a click sends `core.timers.ack()` with no kind. The track label comes from the core `track` topic: it shows when `at` is less than `Motion.dwell` old, including right after the core spawned the view. The adapter's `host.media` is the fallback, and the two sources are deduplicated by the label text. The view-local phase detection is gone. New check: `sat.track.core`.

## Measured (fixture view, desktop, Serpantinum profile; quiet runs only, interrupted runs discarded)

| What | Result |
| --- | --- |
| Command line while typing (`desktop_cmdline.py`, 8 lines at 30 ms per character) | 0 missed over 570 intervals; GPU p99 0.59 ms; render-thread p99 2 ms. **Pass.** |
| Warm unfold first frame, Shell unloaded | 10.3–16.6 ms, 1 missed |
| Warm unfold first frame, Shell kept (Q2, now the default) | 6.8–7.5 ms, 0 missed |
| Closed PSS offscreen, kept vs unloaded (3 runs each) | 99.5–101.8 vs 101.8–103.9 MiB, within noise |
| Closed-view wakeups offscreen (fixed) | Kept Shell was 126 switches/min, caused by the focused TextInput's cursor blink. Fixed in `CommandLine.reset()` by dropping focus on fold; now 0/min. Open: about 4/s either way, as before M5. |
| `hyprctl layers` (live, read-only) | No `fart-*` layers. The live view is absent and still runs main code. |
| Navigation on m5-view | Room loads 0 missed; Workspaces steady 8–11 misses (an M6 trim) |

**Still unmeasured:**
- **Cold start ≤ 450 ms to an interactive command line.** Use B's `desktop_nav.py --cold N --warm N`.
- **Desktop closed-idle PSS and wakeups with the kept Shell.** Use `desktop_idle.py` (it now takes `--unload-shell` for the A/B). The only run so far was interrupted, so discard it. That run's open-idle showed 2629 frames and 588 ticks in 60 s, which needs a quiet rerun to confirm or rule out. The offscreen probe showed no continuous rendering.

Retry desktop runs until one is quiet. The user's input interrupts most of them. A's helper was a loop that reruns while the exit code is 2, with 90 s between attempts.

## Next, in order

1. Make the `desktop_nav.py` edit above, then run the suite and smoke on m5-view and fix anything the merge broke.
2. Run the quiet desktop runs: `--cold 5 --warm 5`, `desktop_idle.py` (kept Shell), `desktop_cmdline.py` and `desktop_nav.py --unfolds 4`. Copy the quiet reports into `docs/measurements/`. Report RSS and PSS separately.
3. Update HANDOFF.md on **main** with: the nav-async merge, the m5-view and visible-ui status, these numbers, and that the user's approval is needed to merge `visible-ui` and then `m5-view` into main.
4. Still needing the user's approval: the Super+` bind (then the ignite prototype, DAILY_DRIVER §4.6), the socket unit, installing the hook variant (cutover, M7), and any push.

## Not tested

- The Keys → handlers mapping on the desktop (Return, Escape, Up/Down, Tab, type-anywhere). Offscreen has no keyboard.
- The real Overlay or PanelWindow path, the satellite layer surface placement on the real bar, and the blur and mask following the origin scale. All of these need the real view, which means `fart-next restart` after a merge to main.
