# Handoff: Claude B, branch `coldstart` (7 November 2026, evening)

Worktree `../next-coldstart`. You approved the merge and all five COLDSTART.md proposals. Results: [COLDSTART.md](COLDSTART.md), "Proposals: approved". Nothing was pushed or installed. The archive, its `fart` launcher, the clock hook, the bind file and the power profile were not touched. The live fart-next core stayed stopped.

## Done

- First merge into main: `462d902` (the `qs list` check, dialogs by URL, the key fast path).
- Kept on the branch: the focus grab at the first drawn frame (`c4e2615`), the 60-minute reap (`0242ffd`) and the deferred Serpantinum domains (`75f6e86`, ADAPTER_CONTRACT §1), plus the `ColdProbe` markers and `cold_breakdown --keep-logs`.
- Measured and not kept: a pre-mapped surface, exclusive focus, and holding the first room.
- Upstream: no new issue. Quickshell #735 and #1434 already cover the disk cache. A comment for #1434 is drafted in the reply to you, and is not posted.

## Later the same evening (you approved all three next steps)

- Warm open measured: 59.5 ms median, failing ≤ 1 frame (COLDSTART.md, "Warm open"). Meeting it needs a mapped-while-closed surface: your call.
- The #1434 comment and the Quickshell build were blocked by the permission classifier. The patch, the qmldir generator and the tool options are ready (COLDSTART.md, "Disk-cache experiment").

## Afternoon: the disk-cache experiment (you built, then said go)

- Result (COLDSTART.md, "Disk-cache experiment"): on battery, with real qmldirs, the patch with cache hits against the same build without it: `load` 440 → 371 ms, total 777 → 697 ms. An empty cache costs nothing measurable.
- Found on the way: `/usr/bin/qs` loads about 125 ms slower than the same source built in the scratchpad. The same bytes copied to tmpfs are as fast, so it is the binary's location, not the build; the cause is unknown.
- #1434 still had 0 comments. The old draft was lost with the old scratchpad, so a new one with these numbers is in COLDSTART.md, for you to post.
- The patch, the build script, the measurements and a NOTICE entry (Quickshell, LGPL-3.0) are on the branch. Nothing was installed or posted.

## Next

1. You approved both: post the new #1434 comment (the classifier blocks me), and carry real qmldirs. They are on the branch (`tools/make_qmldirs.py`, `tests/test_qmldirs.py`). After a merge, any branch that adds a `.qml` file (such as Claude A's `m6-design`) must run the generator, or the test fails. **Git shows no conflict**, but a real qmldir switches Quickshell's synthesis off for its folder, so a type missing from it is "not a type" at runtime. `m6-design` adds `FWeek`, `IndexBand`, `Grid`, `Halo`, `Plane` and `Reticle` and removes `FCalendar`: whoever merges it runs `python3 tools/make_qmldirs.py` in the merge commit.
1a. Merging `coldstart` into main: your call.
2. Triage Astra's review of the coldstart changes when `docs/review-coldstart.md` lands (not there at 15:30).
3. Your call on a mapped-while-closed surface for the warm budget.
4. Still open: the live check of Devices, Media lyrics, Clips and Inbox after the first open settles.
