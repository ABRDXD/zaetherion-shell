# Island performance: next session

Prepared 12 November 2026. Scope: finish the performance follow-up, using isolated fixtures. The diagnosis was measured at `9662778`; preparation HEAD was `4ef6920` on `s0-seed`. Check fresh state because other agents share the checkout.

## Start here

Read the newest Astra entry in `HANDOFF.md`, [the one-page diagnosis](ISLAND_DIAGNOSIS.md), and this brief. Follow repository instructions for any behavior being changed. [Scrubbed measurement evidence](measurements/island-9662778.json) preserves ten runs, CPU samples, memory breakdowns, allocator statistics, object counts and driver totals. No raw smaps, environment dumps, device identifiers or personal paths are included.

At preparation time, the report and handoff were uncommitted. Preserve those and any new unrelated work. Do not stage, commit or push. Create a detached worktree from the then-current HEAD for implementation experiments. Uncommitted documentation will not follow HEAD into that worktree; consult these notes in the shared checkout before starting.

## Established findings

- Default jemalloc, pointer cycles: folded Private_Dirty 118.2 / 166.3 / 193.5 / 193.5 / 188.5 MiB at 0 / 1 / 21 / 50 / 100 cycles. It plateaus. Live jemalloc allocations remain around 56–57 MiB after first open.
- The inherited `MALLOC_CONF=thp:never,narenas:4,dirty_decay_ms:3000` materially changed results. At cycle 100 it gave PSS/Private_Dirty 135/101 MiB versus default 222/188. Explicitly control and record this variable in every comparison. The three settings were tested together; their individual effects have not been isolated.
- Room slots release; sampled leases and satellites empty; objects, Connections, Loaders and Shapes stay constant after first open. Keeping Shell costs roughly 4 MiB of live allocations; precompilation 2–3 MiB. These ablations overlap. Disabling morphing did not help. Keep the established warm-open behavior unless new evidence requires a change.
- Rest CPU 0.03%; 24-bin Fluid playback 6.53%; spectrum computation without publishing 0.67%; timer stopped 0%. At 20 Hz: 4.33% with 24 bins and 4.37% with 56 active simulated bins. A Shape-renderer change alone still exceeded 5%.
- No island memory budget has been set. CPU budgets are at most 2% of one core at rest and 5% with media. CAVA's separate process remains unmeasured. The newer integration has not earned a performance pass from these old-revision results.

## Work in this order

1. **Inspect the actual launch and spectrum paths.** Check fresh git status/history, `core/view.py`, the resident launch path if different, `shell-island-fixture.qml`, `tools/cava.conf`, and the adapter that supplies spectrum in the current integration. The report's CAVA proposal targets the measured Serpantinum adapter path; establish whether the current DMS path uses it before calling it a production fix.
2. **Reproduce a current-code baseline.** Hidden nested Hyprland only, GPU renderer, private runtime, home, config, cache and state directories, and non-live DBus. Remove inherited `FART_*`; leave `QT_QUICK_BACKEND` unset. Verify the nested display/signature differs from the live session. Give the compositor a private state record so its start/stop cannot reuse another agent's nested instance.
3. **Test the minimal proposal in the detached worktree.** Copy the child environment and set a jemalloc default only when `MALLOC_CONF` is absent; preserve an explicit owner value. Try a 50 ms fixture interval and a matching 20 Hz real spectrum source. Do not change `keepShell`, room lifetime, island morphing or Shape renderer to chase this plateau. The report contains the candidate diff; its behavioral choices remain proposals.
4. **Measure fairly.** Compare default versus tuned allocation under identical stimuli, form, open/fold timings and settling. Sample cycles 0, 1, 21, 50 and 100. Report RSS, PSS, Private_Dirty, shared mappings and huge pages separately; deduplicate DRM fdinfo by client and keep driver allocations separate. Use live allocated bytes and GC/purge probes if a new trend needs diagnosis. If short on time, reduce repeated ablations rather than dropping the final plateau sample.
5. **Close the CPU gap.** Use 30-second process-CPU windows, preferably three repeats for the candidate near the 5% threshold. Measure rest, 24-bin and 56-bin playing, compute-without-publish, and timer stopped. Keep all 56 synthetic bins active: scale the amplitude envelope by the bin count rather than retaining the 24-bin denominator. Measure CAVA separately with generated PCM through a supported private FIFO/raw-input configuration; include a synthetic input generator as a separately reported cost. Do not connect it to the owner's audio devices or change real playback. If that private input route is unavailable, record the producer cost as unmeasured and leave the full media verdict open.
6. **Verify the change and leave a reviewable result.** Check that an existing allocator value is preserved and only the intended child receives the fallback. Run the relevant view/launcher tests, island/contract tests and offscreen checks; count only Qt 6 qmllint `syntax*` diagnostics. After integration changes inspect fixture logs and nested `hyprctl configerrors`. Check that the 20 Hz waveform remains acceptable in the fixture. Save the tested minimal diff and updated measurements before removing the worktree.

## Finish conditions

- A measured current-code comparison, an explicit CPU accounting boundary (view, producer, combined), and an honest pass/fail against the two CPU budgets. Do not infer a live-session pass from synthetic input alone.
- An updated one-page report and HANDOFF entry naming the tested revision, remaining uncertainty and exact next task. Apply no runtime change to the shared checkout as part of a report-only continuation; leave a concrete patch for review.
- Stop the owned nested compositor and every owned fixture/producer/generator process, remove the detached worktree, and verify cleanup. No installs, session/config/keybind edits, real playback/volume/network/power/lock actions, staging, commits or pushes. Preserve the separate owner-review/session-enablement work.

## Optional recovery material

The earlier disposable harness and raw logs were still present under `/tmp/zaetherion-astra` when this brief was prepared. They are optional, untracked recovery material and may disappear. `mem.py`, `alloc2.c` and `probe.cpp` contain the measurement/probe approach; the suite runners contain hardcoded paths, old process IDs and mutations and must not be rerun blindly. Build any reused probe fresh. Prefer the scrubbed evidence above for recorded results; do not copy raw logs or smaps into this public repository.
