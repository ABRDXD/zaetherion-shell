# Measuring the Silent fixture

From the worktree root, run two fresh private fixtures and keep both reports. Each default run takes about 3 minutes 10 seconds.

```sh
results=$(mktemp -d)
tools/check-budgets --output "$results/first.json"
tools/check-budgets --against "$results/first.json" --output "$results/second.json"
```

Each command writes JSON even when a measured budget is exceeded. Run the second command independently of the first one's exit code. Without `--output`, JSON goes to stdout. Exit 0 means within the fixture budgets, 1 means a budget was exceeded, 2 means interrupted, and 3 means insufficient data for a check. `--seconds N` changes each stationary sample window. Short windows are useful for checking the harness, but a single CPU tick or context switch then has a much larger effect on the reported rate.

## Two consecutive runs on 6 November 2026

Both 60 s runs used the same measurement code on x86-64 Linux 7.2.14-arch1-1, Qt 6.12 software rendering and fresh caches. The JSON records commit `58f9ef4`. Only test files were committed between launching the first run and its report being written. The interaction signal was `unknown` in both private environments.

| Metric | Run 1 | Run 2 | Absolute difference |
| --- | ---: | ---: | ---: |
| Core idle RSS, MiB | 21.0469 | 21.0508 | 0.0039 |
| Core idle PSS, MiB | 11.9922 | 11.9873 | 0.0049 |
| Core idle CPU ticks / context switches in 60 s | 0 / 0 | 0 / 0 | 0 / 0 |
| Closed view RSS, MiB | 155.184 | 153.684 | 1.500 |
| Closed view PSS, MiB | 94.973 | 93.347 | 1.626 |
| Closed view CPU ticks / context switches in 60 s | 0 / 1 | 0 / 1 | 0 / 0 |
| Open static CPU, % of one core | 0.0000 | 0.0167 | 0.0167 |
| Render-time median / p95 / p99, ms | 1 / 4 / 9 | 2 / 6 / 11 | 1 / 2 / 2 |
| Rendered frames over 6.9 ms / total frames | 1 / 97 | 4 / 99 | 3 / 2 |

**Observed two-run noise band.** For the stationary budget metrics the difference was within 0.01 MiB core RSS, 1.7 MiB closed-view PSS, one CPU tick per 60 s and zero idle-core switches. Frame percentiles differed by at most 2 ms. These rounded bounds describe this pair only. Two runs do not estimate a confidence interval. The noise band is independent of the performance thresholds.

**The original gate exited 1 in both archived reports.** The current gate reports offscreen frame timings as informational. Navigation p99 exceeded 6.9 ms each time. All other implemented thresholds were met in both runs. Full per-process counters, the sampled durations and the signed comparison are in [the first report](measurements/offscreen-1.json) and [the second report](measurements/offscreen-2.json).

## What runs

Each run starts this worktree's core directly with its own temporary home, state, cache, config, runtime, socket and log, `FART_HOST=fixture` and `FART_MIRROR=0`. Its view entry sits at the root of a private copy of the worktree's QML bundle. The core spawns Quickshell with the software Qt Quick backend and offscreen QPA. This fixture uses a 1120 × 760 `FloatingWindow` because offscreen Qt has no layer-shell `PanelWindow` backend. It uses the actual `CoreClient`, `Shell`, room Loader and fixture adapter. The core receives page acknowledgements from QML when the requested room loads. Closing unloads the dashboard. The core owns view shutdown.

| Scenario | Window and gate |
| --- | --- |
| Core idle | Wait 5.2 s for the debounced startup write, then observe 60 s without socket requests. Core RSS ≤25 MiB. “About zero” means ≤1 voluntary plus involuntary context switch per minute, consistent with the M2 observation. |
| Open and navigate | Collect render-loop timings from cold open through visits to Home, Media, Performance, Workspaces, Devices, Tasks, Timers, Clips and Inbox, with 250 ms per loaded page. The process-counter window starts after the initial Home acknowledgement. Record p99 and frames over 6.9 ms. The threshold applies to desktop or hardware validation only. With fewer than 100 samples, nearest-rank p99 selects the slowest frame. A missing frame log makes the fixture run incomplete. |
| Open static | Remain in Inbox, allow 1 s to settle, then sample 60 s. Combined core and view CPU ≤2% of one core. |
| Closed idle | Close after the nine visits, confirm the warm view is ready and closed, settle 1 s and sample 60 s. View PSS ≤200 MiB and zero observed CPU ticks. |
| Command line | Named skip until an interactive command line exists in M5. |

All enforced upper bounds live in `tools/measure/budgets.py`. The JSON records the host architecture and kernel, commit and dirty flag, UTC timestamp, platform, observer status, windows, raw process measurements, frame statistics and individual checks. The comparison subtracts the previous report's gate metrics and frame statistics from the current values. It declines interrupted or incomplete runs and mismatched machine, platform, observer mode or window length.

## Reading the counters

- **Memory.** `smaps_rollup` reports each PID's RSS, PSS, Private_Dirty, Pss_Anon and Pss_File in KiB. RSS charges resident shared pages in full to each mapping process. PSS apportions them among the sharers, so another Qt process coming or going can change a view's PSS. Compare each field with the same field across runs. The two PSS components cover anonymous and file mappings. Shmem can account for an additional portion of PSS.
- **CPU and wakeups.** The sampler differences userspace plus system ticks from process-wide `/proc/PID/stat`, divides by `SC_CLK_TCK` and elapsed monotonic seconds, and expresses utilization as a percentage of one core. A zero over a finite window means less than one measured tick. Wakeups are estimated from voluntary and involuntary context-switch deltas across matching threads. Preemption and blocking can both contribute. These counters do not identify hardware wakeups. An idle view can switch without accumulating a full CPU tick.
- **Coverage.** At both endpoints the sampler recursively walks every thread's child list, labels the core, view and named helpers, and checks process and thread start times. New, exited or reused PIDs have no full-window CPU delta. Thread churn flags partial context-switch coverage. A helper that starts and exits entirely between samples can escape both snapshots.
- **Frames.** `QSG_RENDER_TIMING=1` and the Qt render-loop logging category provide one total wall-time measurement per rendered frame. The pure parser uses the median and nearest-rank p95/p99. A missed frame here is one rendered frame over 6.9 ms. Qt reports whole milliseconds, truncated (`int(QElapsedTimer::elapsed())` in Qt 6.12), and on a vsynced desktop the total includes the swap's wait for the next vblank, so it is not used for desktop budgets. Idle intervals in `frameDelta`, individual render phases and separate GPU timings are excluded. These measures describe offscreen software rendering. Desktop presentation time, compositor drops, input latency and sustained FPS require a desktop measurement.

To run just the navigation and frame parser, use `python3 tools/measure/frames.py`. To sample a separately owned fixture, use `python3 tools/measure/smaps.py CORE_PID --seconds 60`, optionally supplying `--view-pid PID`. Both tools emit JSON.

## Desktop navigation (`tools/measure/desktop_nav.py`)

The fixture view (private core, fixture adapter) opens in a `FloatingWindow` on the caller's Wayland display (`QT_QPA_PLATFORM=wayland`, OpenGL, `QSG_RHI_PROFILE=1`, `FART_FRAME_PROBE=1`). After Home settles for 1.5 s the read-only Hyprland observer starts and `--passes` (default 4) walk the nine rooms with `--dwell` 0.25 s each. `--source` measures another checkout's view with this harness, and `--cache-home` keeps `XDG_CACHE_HOME` between runs. The report stores the source with `~` for the home directory, the dGPU `runtime_status` before and after, and the refresh rate from `hyprctl monitors -j`.

Per room (`frames.desktop_stats`), with the window's first open excluded:

| Field | Source | Resolution |
| --- | --- | --- |
| `load_frame_ms`, `load_frames_in_order_ms` | the first GUI frame interval after each navigation command; it spans the synchronous room swap | sub-ms (`FrameAnimation.frameTime`) |
| `interval_ms` | every later GUI frame interval in that room (entrance and steady) | sub-ms |
| `create_ms_in_order` | the synchronous part of the command (old room destroyed, new one created) | whole ms (`Date.now`) |
| `polish_max_ms_in_order` | the largest GUI polish phase in the segment (layouts) | whole ms, Qt |
| `gpu_ms` | RHI GPU timestamps | sub-ms |
| `render_thread_work_ms` | `sync + render`, the vsync wait excluded; skipped frames ignored | whole ms, Qt |
| `vsync_wait_ms` | the `swap` phase (shown only to explain the old total) | whole ms, Qt |

A **missed presentation** is an interval over 1.5 refresh periods (10.42 ms at 144.003 Hz); an interval of *n* periods (rounded) skipped *n* − 1 presentations (`frames.missed_presentations`). While the probe runs, a `FrameAnimation` keeps a frame coming every vsync, so these are sustained-cadence intervals, not idle gaps.

**The desktop budget** (approved 6 November 2026, `BUDGETS["desktop_navigate"]`, checked by `frames.desktop_checks` into the report's `checks`): 0 missed presentations outside room-load frames, at most 1 on any single room load, and per-room p99 of GPU time and of render-thread work ≤ 6.9 ms. The 6.9 ms "p99 frame" in PROJECT_PLAN means exactly this on the desktop. Qt's render-loop total stays informational (offscreen gate only). Exit codes: 0 quiet and within budget, 1 quiet and over budget, 2 interrupted, 3 observer unavailable or no data for a check.

## Interaction exclusion

By default the observer receives the private fixture's environment. With no Hyprland socket it records `unknown`. An explicitly requested observer that loses either socket also records `unknown` and makes the run incomplete. After authorization, `--observe-interaction` lets **only the observer** use the caller's Hyprland sockets while the benchmark view stays offscreen.

The stdlib observer listens on `.socket2.sock` for active-window, workspace, special-workspace and focused-monitor events. It samples `j/cursorpos` on the request socket at roughly 100 ms intervals, including a final check. A changed position or matching event excludes the whole run, even when individual metrics meet their budgets. Reports store only the classification. The observer discards event payloads and coordinates. Focus changes can be programmatic, and same-window typing, stationary clicks or movement away and back between samples can go undetected. “Quiet” means no signal from these probes. A private synthetic cursor change produced `interrupted` and exit 2.

## Fixture and desktop coverage

`python3 -m unittest discover -s tests -v` exercises cold open, room changes, warm open/close reversals, actual reaping and a fresh PID on reopen. Only the reap test overrides the in-memory deadline to 1 s in its child interpreter. The performance runs use the production ten-minute value. A separate cold reversal across two clients exposed an M2 race, recorded in `docs/review-m2.md`. The existing smoke test additionally exercises palette mapping, leases, tasks and stopwatch round trips.

Still pending desktop authorization are hardware-rendered frame times, layer-shell unfold and focus, real compositor input observations, dGPU sleep, the warm view with the real mirror and helpers, and performance under actual compositor load. M5 owns cold start to an interactive command line (≤450 ms). Later milestones own media playback, Overdrive and release budgets.
