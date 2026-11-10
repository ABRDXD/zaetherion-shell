# Cold start and warm open (branch `coldstart`)

Status: **measured on the desktop on 7 November 2026; proposals 1–5 approved and worked through the same day; the disk-cache experiment run that afternoon (−80 ms with cache hits).** Owner: Claude B. Budgets (DAILY_DRIVER §1, kept by you on 6 Nov): **cold ≤ 450 ms** and **warm ≤ 1 frame** (6.9 ms at 144 Hz), from the request to the first frame swapped with the command line focused in an active window.

## Method

`tools/measure/cold_breakdown.py` splits one cold open into phases, using the core log, Quickshell `--log-times` (a PATH wrapper) and `FART_COLD` markers (only with `FART_COLD_PROBE=1`):

| Phase | From → to |
| --- | --- |
| core | `view.open` sent → the core spawns `qs` |
| exec | spawn → Quickshell's "Launching config" |
| load | launch → the root object is created (module scan, engine, imports, compile, create) |
| hello | created → the core's open command arrives |
| open | command → the open is handled (Shell built) |
| frame | handled → the first frame swapped with the command line focused in an active window |

Modes: offscreen (software renderer), `--desktop` (the fixture view in a toplevel), and `--real` (Overlay's layer surface with the Serpantinum adapter, a private core, runtime and state, UI sounds and the mirror off, and copies of your live `settings.json`, `preferences.json` and `tasks.json`). `--compare TREE` interleaves two checkouts (A/B). Each run records the CPU power state, because the same tree measures about 215 or about 480 ms offscreen depending on it. I never change the power profile.

## Changes on this branch

| Commit | Change | Effect |
| --- | --- | --- |
| `ff037c6` | The core runs its foreign-instance check (`qs list`) when it starts, not on the first open | the core phase is 58 → 1 ms on the desktop (offscreen A/B −83 ms) |
| `46e44cc` | FArchive and FProfile (which pull in QtQuick.Dialogs) load by URL when opened | offscreen A/B −40 ms |
| `2527960` | `fart-next key down|up` (the bind's form) is sent before the CLI's other imports | **−46 ms on every Super+` press**, before `view.open`: about 30 against 76 ms per edge (fixture core, 2 × 15 runs) |
| `510a6d1` | `cold_breakdown --real`; `desktop_nav --cold --core-settle S` | measurement only |

## Desktop results (7 Nov 2026, quiet, low-power profile, EPP `power`, on AC)

Every run was quiet (0 interrupted). Medians in ms; raw data in `docs/measurements/cold-breakdown-510a6d1-*.json`.

| | core | exec | load | hello | open | frame | **total** (min–max) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| fixture view, main `4dfca6c` (7) | 58 | 39 | 248 | 4 | 54 | 115 | **514** (399–559) |
| fixture view, this branch (7) | 1 | 52 | 240 | 3 | 55 | 128 | **484** (409–534) |
| **real panel, this branch (5)** | 2 | 53 | 344 | 8 | 39 | 140 | **588** (574–610) |

- The fixture A/B paired difference is a median of −30 ms (7 pairs, one of which went the other way).
- The real panel is 104 ms slower than the fixture in `load`: the Serpantinum adapter and Quickshell's service modules (offscreen: the adapter compiles in about 110 ms and is created in about 20; Hyprland about 28 ms, and Pipewire, MPRIS, Networking, UPower and Bluetooth 6–9 ms each).
- `frame` is 3–4 ms offscreen and 115–140 ms on the desktop: the Wayland map, the first GL frame and the compositor's keyboard focus (split below).
- **What you feel on Super+`** is the CLI edge plus the total, about 30 + 588 ≈ 620 ms. Main's CLI edge alone is about 76 ms, and main's real panel was not measured. A clock click doesn't pay the CLI edge.
- The warm open of the real panel is **not measured yet**: the fixture's warm open was 33–62 ms on 6 Nov.

**The cold budget fails by about 140 ms on the real panel.**

## Proposals: approved 7 Nov 2026, built and measured

All the real-panel A/B runs below were quiet (low-power profile, on AC), 5 pairs each, and every panel stayed open. Data: `docs/measurements/cold-breakdown-*`.

| # | What | Result | Kept |
| --- | --- | --- | --- |
| 1 | `ColdProbe` splits `frame` into first swap, active window and focus (`64871ef`) | Focus is immediate. The first frame is out at about 48 ms after `handled`, and the window turns active at about 100–110 ms. | yes (probe only) |
| 1a | Grab focus once the panel has drawn, not after 2% of the unfold (`c4e2615`). The archive's `expansion > 0.02` held the grab back. | frame 148 → 103 ms | **yes** |
| 2 | Defer audio and its equalizer, bluetooth, notifications, lyrics and clipboard until the first open settles (`75f6e86`, ADAPTER_CONTRACT §1) | Paired −18 ms (load 354 → 339). Offscreen, the adapter is created in 95 ms against 111. | **yes** |
| 3 | Reap a closed view after 60 minutes instead of 10 (`0242ffd`) | Most opens become warm; the closed view (about 237 MiB PSS) stays resident longer. PSI pressure still reaps. | **yes** |
| 4 | A surface mapped before the open (scratch experiment) | active 112 → 114 ms: no gain. **Not built.** | no |
| 4a | Exclusive keyboard focus (scratch experiment) | active about 7 ms sooner, within noise. Not built. | no |
| 4b | Hold the first room until interactive (`8c644c1`, taken out in `1a1cc3d`) | frame 108 → 97, pairs mixed, and the room moved into the unfold | no |
| 5 | Upstream disk cache | Already reported: quickshell-mirror/quickshell #735 (acknowledged by the maintainer in April: "known … in the next couple months") and #1434 (3 Nov, with a patch, no reply). No duplicate filed; a comment for #1434 is drafted, awaiting your OK to post. | – |

**Where the frame phase goes** (Qt render-loop timing, `QSG_RENDER_TIMING=1`, 3 runs): the first frame is synced and rendered by about 37 ms after `handled`. Then no frame comes for about 57 ms, and the frame callback and the window's keyboard focus arrive together. The fixture toplevel shows the same gap, and neither a pre-mapped surface nor holding the room shortens it. So it is the compositor/GPU side of a new surface's first frame, not FART's GUI work.

**Where this leaves the budget:** the real panel's medians across today's runs are 500–550 ms, with one session at 432 ms (`64871ef-real-split`). The same tree varies by about 100 ms between sessions with the CPU state. **The cold budget of 450 ms still fails in most sessions.** What remains: `load` (300–350 ms, mostly QML compilation that the missing disk cache repeats on every start), `exec` about 40–50 ms, and the compositor's first-frame gap of about 57 ms. The biggest lever left is the upstream disk cache (#1434's approach measured 3.2 → 1.2 s for a large config). With the view kept for 60 minutes, the daily case is the warm open, which is the next thing to measure.

## Warm open (real panel, 7 Nov 2026)

`cold_breakdown --real --runs 2 --warm 5`: 10 quiet runs, every panel stayed open. Median ms (min–max):

| relay | handle | first frame | active | **total** |
| --- | --- | --- | --- | --- |
| 1.1 | 2.0 | 38.5 (35–50) | 44 (40–62) | **59.5** (46–71) |

**The warm budget (≤ 1 frame, 6.9 ms) fails.** FART's part (the relay and the open's handling) is about 3 ms. The rest is the panel surface: Overlay unmaps it when the panel folds, so every open maps it again, waits for its first frame and for Hyprland's focus. One frame is reachable only with a surface that stays mapped (fully transparent, with no input region) while the panel is closed. That conflicts with the M5 rule of no FART surface when idle, so it is your decision, and nothing here builds it.

## Disk-cache experiment (run 7 Nov 2026, afternoon)

You approved testing #1434's approach on a scratch build. You ran the build yourself (the session's classifier had blocked it), then gave the go-ahead for the desktop runs.

**Setup.** Nothing was installed, and your own QML cache was never written.
- **Source:** Quickshell 4f508be, the revision `/usr/bin/qs` reports. It was cloned from the mirror your AUR build left in `~/.cache/dots-hyprland/…/illogical-impulse-quickshell-git/quickshell`, because GitHub downloads were stalling.
- **Build:** `tools/measure/quickshell/build.sh SCRATCH ORIGIN` builds with the AUR package's CMake flags, twice:
  - `qs-control`, unpatched;
  - `qs-patched`, with `tools/measure/quickshell/1434-file-urls.patch`. `QsUrlInterceptor` gets the scanner's `fileIntercepts`. For `DataType::QmlFile`, it returns `file://` for a `.qml` that has no in-memory override and whose folder has a real `qmldir`.
- **Bundle:** one copy of `coldstart` (`ad2282c`), with real qmldirs in all 14 module folders written by the generator (now `tools/make_qmldirs.py`). The root `shell.qml` has no qmldir, so it stays on `qs:` and is never cached.
- **Runs:** `cold_breakdown --real --runs 6 --bundle-dir B [--qs BIN]`, each arm with its own scratch `QML_DISK_CACHE_PATH`.

**Offscreen check first** (a one-module probe config):
- Stock and control write no `.qmlc` ("File has to be a local file.").
- Patched writes the module's unit and reuses it on the next start without rewriting it.
- A changed source is recompiled, and the new value shows. A plain `touch` without a content change keeps the unit.

**Desktop results.** Real panel, private core. Conditions: **on battery**, low-power profile, EPP `power`. So every arm is slower than this morning's 500–550 ms on AC; compare within this table only. 3 stock runs were interrupted by input and are excluded. Median ms (min–max):

| Arm | n | exec | load | open | frame | **total** |
| --- | --- | --- | --- | --- | --- | --- |
| stock `/usr/bin/qs` (two sessions, before and after) | 9 | 65 | 564 (540–684) | 71 | 186 | **903** (856–1077) |
| `qs-control` (same source, scratch build) | 6 | 72 | 440 (429–451) | 72 | 183 | **777** (762–798) |
| `qs-patched`, run 1 (empty cache) | 1 | 66 | 450 | 66 | 180 | 775 |
| `qs-patched`, runs 2–6 (cache hits) | 5 | 70 | **371** (340–393) | 73 | 185 | **697** (681–755) |

- **The patch's effect** (patched hits against control: same build, same bundle, same session): `load` −69 ms, total −80 ms. With an empty cache it costs nothing measurable (450 against 440). The cache is 70 units, 628 KiB.
- The ranges don't overlap. But the arms ran one after another, not interleaved (`--compare` takes two checkouts, not two binaries), so this is not a paired difference.
- **Not all of `load` is compilation:** about 370 ms remains with every module cached. That is the module scan, engine and imports, type creation and the Serpantinum services, plus the uncached root.
- **A separate finding: the stock binary's location.** Stock loads about 125 ms slower than the control on the desktop. The same bytes copied to the scratchpad (tmpfs) loaded as fast as the control offscreen (2 × 3 runs: 205 against 248 ms). So the cause is where `/usr/bin/quickshell` lives (ext4 on LVM), not how it was built. A follow-up test, whether the binary's directory having 3989 entries matters, was inconclusive: the machine's speed changed mid-run. The cause is unknown, `strace` is not installed, and I stopped there.
- **Memory is not measured.** Units loaded from the cache are file-backed mappings rather than heap, so private dirty should fall. That is an expectation, not a result.
- **What it means for the 450 ms budget:** −80 ms on top of this morning's 500–550 ms AC medians would be about 420–470 ms. That estimate is not measured on AC, so it doesn't pass the budget yet. It needs an upstream fix (or a carried patch) and real qmldirs in FART's tree; both are your call.
- **Carried in the tree (approved 7 Nov 2026):** every module folder now keeps a generated `qmldir`; see LAYOUT.md. With stock Quickshell nothing changes: the files match what it synthesizes, line for line, checked against its scanner's debug output for all 14 folders, and the smoke passes. With the patched build they make the tree cacheable as it is (offscreen: 54 units written, none by stock).
- Data: `docs/measurements/cold-breakdown-ad2282c-diskcache-{stock,stock-repeat,control,patched}.json`.

**The #1434 comment:** the earlier draft lived only in the old session's scratchpad and is lost. A new draft with these numbers is below, for you to post (not posted by me):

> Measured this approach on a real config (Quickshell 4f508be, Qt 6.12, ~100 QML files in 14 module dirs, Wayland/Hyprland). The patch makes `QsUrlInterceptor` return a `file://` URL for `DataType::QmlFile` when the file has no in-memory override (not in `scanner.fileIntercepts`) and its directory has a real on-disk `qmldir`; generation.cpp passes `scanner.fileIntercepts` to the interceptor. With real qmldir files added, the same build with and without the patch: time from launch to root object created went 440 → 371 ms (median, 5–6 runs each; cold-cache first run 450 ms), total time to first focused frame 777 → 697 ms. 70 units, 628 KiB in the cache; edited sources are recompiled correctly. The root shell.qml and directories with a synthesized qmldir stay uncached, so extending the rewrite to synthesized qmldirs would cover the common case.

## Verification

- `python3 -m unittest discover -s tests`: 238 tests pass, including `test_the_bare_edges_take_the_fast_path`, the deferring verb harness (a `vol` call loads and follows the audio swap; it fails with `follow()` removed) and the REAP_AFTER view tests.
- `python3 tools/smoke.py` passes, and checks the deferred Serpantinum domains (placeholders before `loadDeferred()`, the real ones after).
- The private cores, temporary bundles and runtime directories were removed after each run. No FART layer was left mapped.
- Not touched: the live fart-next core (stopped throughout), the archive, the `fart` launcher, the clock hook, the bind file and the power profile. The scratch experiment trees stayed in the scratchpad.
- Disk-cache experiment: the scratch builds ran only from the session scratchpad and were never installed; every run used a scratch `QML_DISK_CACHE_PATH`. `sh -n` passes on `tools/measure/quickshell/build.sh`.
