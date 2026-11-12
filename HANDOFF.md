# 12 November 2026 · Opus: island reply fix, Angular pass and wider media pill

- **Reply bug fixed.** When an OSD covered a notification, keyboard interactivity dropped to None and then returned to OnDemand. Hyprland gives click focus to an OnDemand layer only after the pointer moves, so the field took focus in Qt while the window stayed inactive and Enter delivered nothing. A queued reply draft now keeps OnDemand. A field that takes focus in an inactive window briefly claims Exclusive. The field regains focus when its notification returns, and Send dismisses the notification. Hidden nested Hyprland ran Sol's exact steps 3 times and the no-second-click path 3 times. Each run delivered `Synthetic reply` once, and `configerrors` was empty. Hyprland still drops the first click when the island grows under a pointer that has not moved.
- **Look.** Brought the island up to the approved study and FART. The changes are the app name on an inverted ink tag, the fixed-light rim, face and facet, shoulder-safe insets, the notched rule, an ink tag for the first action, a full-width reply field, a blade meter and readout for volume and memory, a track tile, and ink-plane keyboard focus. The new shared parts are `FTag` and `FBlades`. Captures and notes are in `docs/ui/README.md` (Opus pass).
- **Owner review: media pill.** The pill now runs up to the centred clock instead of a fixed 104 px. Network moved to the right group beside the bell and battery, which keeps the resting width at Z66's 420 px. Hovered, the centre opens to 500 px, so the title keeps its room when the clock gains seconds and the wings sit outside it. With the synthetic title `Synthetic Fixture Track With A Long Title`, the visible text grew from 9 to 14 characters at rest and from 9 to 18 on hover. The clock stays on the screen centre. Captures are in `docs/ui/island-s3-media-pill.png`. Island, layout, contract and qmldirs checks passed 22/22. Nested checks passed docked focus 6/6, and an exact reply arrived once.
- **Checks.** `test_island` 4/4, including the new `ReplyTest.qml`. Layout, contract and qmldirs 18/18. `qmllint` reported 0 syntax diagnostics on the changed files. The full suite passed 707/707 in 581 s with `FART_*` unset. No daemon or test-infrastructure files were changed.
- **Docked focus (Z148, owner's choice).** Super+Shift+I with the panel open now moves the keyboard to the island and keeps the panel open. The first Esc returns the keyboard to the panel and the second closes it. `Overlay` gained `islandHasKeyboard` and `holdsKeyboard`, and the island gained `keyboardPeer` and `wantsKeyboard`. Only the fixture wires the two, because `shell.qml` has no island yet. Hidden nested Hyprland passed 6/6 three times with Esc. Separate runs confirmed that typing reaches the panel's command line after Esc and that a click outside still closes the panel. The reply check and plain island focus pass again. The full suite passed 707/707 again after this change, with `FART_*` unset.
- **For Sol.**
  - **Commit split.** At the owner's request, Opus committed only its own island files and its own HANDOFF entry. Sol's working-tree changes stay uncommitted and untouched. Opus's files:
    - Modified: `view/shell/IslandExpansion.qml`, `IslandSurface.qml`, `IslandWindow.qml`, `IslandRest.qml`, `IslandGlyph.qml`, `Overlay.qml`; `view/ui/IslandFrame.qml`, `view/ui/qmldir`; `shell-island-fixture.qml`; `tests/test_island.py`.
    - New: `view/ui/FTag.qml`, `view/ui/FBlades.qml`, `tests/fixtures/island/ReplyTest.qml`, `docs/ui/island-s3-opus-review.png`, `docs/ui/island-s3-opus-docked.png`, `docs/ui/island-s3-media-pill.png`.
    - Shared: the Opus sections of `docs/ui/README.md` and `HANDOFF.md`, and Z148 in `docs/DECISIONS.md`.
    - Opus did not change daemon, launcher, faces or test-infrastructure files. Never push.
  - **Nested kit.** `/tmp/zi-reply-opus/` holds `check.py` (modes `exact`, `noclick`, `wiggle`), `docked_focus.py` (Z148, add `outside` for the click-outside close), and `pointer.c` with its built `pointer`. `pointer` is a virtual pointer on the nested display that takes `click` or `move`. Run each script from the repo root with nested Hyprland started. `/tmp` does not survive a reboot. If these checks should stay, they belong in `tools/`, which is Sol's to decide.
  - **Fixture IPC.** `state` also reports `lastReply` (synthetic text only) and `keyboard` (`none`, `ondemand` or `exclusive`). `title <text>` sets a synthetic track title.
  - **Timing in the Z148 handover.** The island waits 60 ms after the panel releases before it requests Exclusive. The panel resumes its focus grab 100 ms after it retakes the keyboard. Both delays were measured in nested Hyprland 0.57.1 and are not tuned. Recheck them on the real session and with a slow frame. While the island holds the keyboard, a click outside does not close the panel.
  - **Still open.** When the island joins `shell.qml`, wire `Overlay.islandHasKeyboard` to the island's `wantsKeyboard` and `IslandWindow.keyboardPeer` to `Overlay.holdsKeyboard`, as the fixture does. The Super+Shift+I compositor bind is still unset.

# 12 November 2026 · Daemon shutdown and Angular reply checks

- Pausing the fixture daemon after `core.sock` disappeared but before it released `core.lock` reproduced a failed stop-then-start at `0baeef2`. The existing `tools/fart_next.py` diff waited for the lock and restarted cleanly under the same check. The separate `zaetherion` entry point still failed under the forced timing. The earlier reply-ordering failure’s exact cause remains unconfirmed.
- Added a launcher regression test for the shutdown gap and made the reply-ordering test print `core.log` if startup fails. All 12 daemon and 8 launcher tests passed. The first private full run found that the Faces smoke test loaded the installed Mocha preset. The test now supplies a synthetic preset from a private home, and the focused rerun passed.
- In hidden nested Hyprland, a typed draft kept its text through a synthetic volume OSD with the pointer held still. Enter submitted the original text exactly once, including leading and trailing spaces. Fullscreen hide and remap passed. The nested `configerrors` output was empty, Quickshell logged a Qt Wayland warning about disabling an unfocused text-input surface, and the compositor was stopped. The first click under a stationary pointer on a newly shown layer remains a separate compositor limitation, recorded in `docs/ui/README.md`.
- Rechecked Opus’s Z148 handoff in hidden nested Hyprland. The fixture focus request kept the docked panel open and moved the keyboard to the island. The first Esc returned focus to the panel and the second closed it. Exact reply submission and fullscreen hide and remap passed again. Nested `configerrors` was empty and the compositor was stopped. Qt logged text-input focus warnings during the run.
- The full private suite on the Z148 handoff (`0baeef2` plus overlay `27e186cf`) discovered 707 tests in 581.330 s, with 703 passed and zero failures. Four checks skipped because the private home omitted the installed Serpantinum clock and FART archive. All 4 offscreen island tests and 10 room smoke checks passed. Qt 6 `qmllint` reported zero syntax diagnostics across 103 QML files. Issue #23 was closed after checking the owner’s recorded keyboard layout decision in OPEN 11.
- The owner set DMS functionality and responsiveness as the baseline, with measured performance gains as the goal. `docs/VISION.md` records the control centre’s scope and `docs/BUDGETS.md` records the priorities for idle CPU and wakeups, presented frame pacing, memory growth, state-driven widgets and hidden rooms. The fixture checks establish behavior. The DMS comparison and resident performance measurements remain open.
- Next, review Opus’s Angular captures with the owner and carry the shutdown wait over to the public launcher using the same private fixture check. Wire the island and panel together when the island joins `shell.qml`, then verify the compositor binding and measure the resident against DMS on the same workflows.

# 12 November 2026 · Island UI handed to Opus, daemon test isolated

- The owner assigned the S3 island UI and interaction work to Opus and left daemon and test infrastructure with Sol. In hidden nested Hyprland, a 15-character reply draft survived a synthetic volume pop-up. After the notification resumed, clicking the field and pressing Enter recorded no action. The nested compositor was stopped. Opus has the reproduction.
- The daemon tests inherited desktop settings, including `FART_SUPERVISE=dms`, which can start a real DMS child even with the fixture host. The tests now construct a private environment, and the reply ordering test checks the CLI startup result before opening the socket. All 12 daemon tests passed with the fix under the ordinary desktop environment. The earlier socket failure's exact cause remains unconfirmed.
- Next, rerun the full suite once the UI changes are ready. Verify exact reply submission in the nested fixture and review the updated Angular captures with the owner.

# 11 November 2026 · S3 Angular fixture checkpoint

- The Angular fixture now includes the resting modules, hover wings, tray menus, panel docking and keyboard navigation. It queues fixture notifications, OSD, memory pressure and workspace changes, and shows recording, timer, battery and backend status. The owner chose Roboto Condensed, omitted the keyboard layout indicator, and chose Super+Shift+I for island focus. The focus target is available over IPC. Launch and fixture commands are in `docs/ui/README.md`.
- Offscreen island and contract checks passed. Nested Hyprland confirmed the island layout, tray submenu, fullscreen hide and remap, notification preemption and resume, and the panel open and dismissal paths. Nested `configerrors` was empty. The combined fixture measurements are in `docs/BUDGETS.md`.
- The latest full suite passed 704 of 705 tests. The core daemon reply test failed because `core.sock` was missing. That test passed in the preceding full run. The preceding run's night log failure was fixed in the test and passed a focused rerun.
- The owner paused work here. On resumption, verify that a typed notification reply survives OSD preemption and reaches the fixture intact, then recheck the daemon socket test. The live adapter, compositor binding and resident performance checks are still pending. FARTland // Fluid remains a separate future mode.

# 11 November 2026 · S3 step 2 fixture shell ready for review

- **Built.** `IslandFrame` draws the Angular 420 × 36 trapezoid, 84° shoulders and 4 px bevel. `Design.islandFill` picks the darkest blue palette role, or the darkest role when no blue exists. `IslandWindow` uses the Top layer and `zaetherion-island` namespace. It unloads the surface for fullscreen on its active workspace.
- **Fixture.** `shell-island-fixture.qml` supports top and bottom notch and floating placement. The gap is 16 px in this preview, while both placements reserve 36 px. Launch and fullscreen fixture commands are in `docs/ui/README.md`.
- **Verified.** Offscreen frame and palette smoke, layout and contract tests, generated qmldirs, and Qt 6 qmllint with zero syntax diagnostics. The hidden nested compositor confirmed all four placements, 36 px reserved, the bevel, and fullscreen unload, release and remap. Its config error list was empty and the compositor was stopped after capture.
- **Full suite.** All 703 tests passed in 575.885 s with QML debug messages enabled for the test process. The first run inherited `*.debug=false`, which hid the markers expected by the older fixture tests.
- **Next.** Review the fixture shell. After review, begin UI_BRIEF step 3 with the resting modules and hover wings.

# 11 November 2026 · S3 step 1 approved

- **Look.** The owner approved the Angular island with the shallow 4 px bevel and inverted app tag (Z144). One navy trapezoid widens into hover wings and deepens into notification, volume or memory pressure. `docs/ui/island-s3-review.svg` compares it with FART's fixture Timers screenshot. `docs/ui/island-s3-motion.gif` shows the morph and a volume event interrupting a notification, then the notification resuming.
- **Future direction.** Angular keeps the approved look. The future rounded mode is named **FARTland // Fluid** and depends on **FART // Fluid**, which the owner plans to develop later. Recorded in `docs/VISION.md`.
- **Fluid island approved (Z145).** A compact matte edge notch with a 3 px underside, just the clock at rest, track and waveform during playback, and other controls on hover. `docs/ui/fartland-fluid-study.svg` shows the approved look and `docs/ui/fartland-fluid-motion.gif` animates it with synthetic playback. The 100 px idle and 224 px playing widths are mock-up proposals. SVG, PNG and GIF verified and layout tests 7/7. The S3 implementation uses Z144.
- **Owner decisions.** Roboto Condensed for the mock-ups (Z52). Power opens the session card and notifications open Inbox (Z143). Memory trigger, priority and pin remain OPEN 14. Expansion sizes and floating gap are visual proposals.
- **Checks.** Layout tests 7/7, static render and motion frames visually checked, review-palette text contrast passes. The repository contrast audit is absent. The previous screenshot runner reported `0/1 rooms saved` despite writing a PNG. The fixture render was independently verified in that review and is reused here. The full suite was not run for this documentation checkpoint.
- **Next.** UI_BRIEF step 2 with the fixture adapter. Build the island window, trapezoid and fill, notch and floating modes, top and bottom placement, and fullscreen hiding. Stop for review at the end of step 2.

# 11 November 2026, night: first login on the supervisor; F2-3 checked

- **Login on the new setup is clean:** one core, one `dms`, one UI, all fresh. Owner pressed Super+R four times in four seconds: each was adopted, never doubled. **Found:** each restart counts as a failure (`failures=4`, wait 4 s), so quick repeated owner restarts lengthen the wait; reset after 60 s up. Consider not counting a clean exit that has a new DMS.
- **Old core survived a logout once** (the previous session-start's stop). The runtime folder is wiped at logout, so the leftover record is now written to `~/.local/state/zaetherion/logout.log`; read it after the next login.
- **F2-3 done with the owner present:** scan, toggle and connect (saved network) answer as designed; see OPEN.md.

# 11 November 2026, night: switch-over built (not yet logged into)

- `zaetherion start` now sets `FART_SUPERVISE=dms`; `tools/session-start` only starts the core and waits (no DMS loop, no `pkill`); `stop_core` waits up to 12 s. **The owner's running session still uses the old loop until the next login.**
- Owner's answers built in `core/supervisor.py`: new state `held` (clean exit and no new DMS within 3 s = stays down; `zaetherion start` or a new DMS brings it back) and a duplicate DMS is swept with ours, then one fresh start. Tests: 26 OK in `tests/test_core_supervisor.py`; `tools/supervisor_check.py` 16/16.
- **Still to do:** the real login/logout test (owner present: log out, log in, check one `dms`, `Super+R` keeps one, `dms kill`/stop stays down, logout leaves no processes); live checks for `held` and the duplicate sweep; measure `dms kill`; OPEN 17, 19; named clients (SUPERVISOR.md §12 items 2–5).

# 11 November 2026, evening: F1 delivered (Fable 5.2): the supervisor

- **Design:** `docs/SUPERVISOR.md` (states, transition table, backoff, crash verdicts, owner restarts, logout sequence, `dms.path`, lock hand-over, named clients, each recon finding). New questions for the owner: OPEN 15–18.
- **Slice, finished:** `fartd` supervises `dms run` when `FART_SUPERVISE=dms` (`core/supervisor.py`, wired in `core/fartd.py` and `core/app.py`). **Off by default: the owner's session still runs on `tools/session-start`.**
- **Verified:** `tests/test_core_supervisor.py` 24 OK; `python3 tools/supervisor_check.py` 16/16 (twice) in the nested Hyprland with private folders: start, UI crash back in 0.37 s, DMS kill with orphan sweep, owner restart adopted in 0.8 s and not doubled, waits 0.25/1/3/4, shutdown and compositor exit leave no processes, the session's DMS untouched. Full unit suite on the F1 tree, from the repo root: 700 run, 698 OK; the 2 failures were the fixture ones that `7f24a1f` fixed afterwards (both pass now).
- **Measured, new:**
  - `dms restart` = SIGUSR1; the old one exits 0 in 0.07 s; a detached `dms run -d --daemon-child` appears 0.36 s later and **keeps the environment but drops the flags**. So the UI folder goes in `DMS_SHELL_DIR`, never `-c`, or Super+R would bring back DMS's stock UI.
  - `pgrep -x dms` (the interim loop) also matches `dms cl copy` and other one-shot commands; the supervisor uses pid files plus a liveness check.
  - Apps launched from DMS (`Quickshell.execDetached`) get parent 1 and their own session, so the tree sweep cannot reach them. Today's DMS (started by `session-start`) shares Hyprland's session with every app: an adopted DMS that does not lead its session is swept by descendants only.
- **The pattern, for whoever continues (Sonnet):**
  - Behaviour lives in `TABLE` in `core/supervisor.py`; the same table is in `docs/SUPERVISOR.md` §2 between `<!-- table:start/end -->` and a test compares them. **Change both together, table first.**
  - `Machine` is pure. `Child` runs actions named `_do_<action>`. Everything that touches real processes is a *port* (`DmsPorts`); tests use `FakePorts` and the fake clock. A new supervised thing = new ports + a `Policy`, not a new machine.
  - Anything involving a real DMS is checked with `tools/supervisor_check.py`: add a check there. Never run a test DMS in the session's own runtime folder.
  - Run the suite from the repo root: `python3 -m unittest discover -s tests` (from inside `tests/` three modules fail to import).
- **Next, in order (docs/SUPERVISOR.md §12):**
  1. **Switch-over, needs the owner's go:** `start_core` in `tools/zaetherion.py` sets `FART_SUPERVISE=dms`; `tools/session-start` becomes "start the core and wait" (drop the DMS loop and `pkill -x dms`); raise `stop_core`'s wait from 6 s to 12 s. No Hyprland config change. **Build the owner's answers with it, from `docs/SUPERVISOR.md` §13:** OPEN 16 (a DMS stopped on purpose stays down: state `held`) and OPEN 18 (a second DMS: stop both, start one). Ask OPEN 19 first (a deliberate stop while locked, before S7). Then a real login/logout test.
  2. Named clients `resident`/`panel` and the panel's snapshot adapter (§9), with `DMS_SOCKET` for the panel from the `supervisor` topic (F2's need, §13); `tests/test_core_view.py` must stay green.
  3. `session.log` trimming and `dms.log` rotation; who restarts `fartd`; measure `dms kill` with care (§13).
- The two fixture test failures found on the way were fixed in `7f24a1f`.
- F2 (the `dms` adapter design) ran in parallel: entry below. What it needs from F1 is answered in `docs/SUPERVISOR.md` §13.

# 11 November 2026, F2: `dms` adapter designed (note only, no code)

- **The owner cut F2 to the design note.** `docs/DMS_ADAPTER.md` holds the design (brief points 1–6), the link's transition table (§2), the network mapping (§4), the service ↔ domain ↔ lease table (§5) and the build and test list (§9). No `adapters/dms/` exists yet; nothing was run against a real DMS.
- **Owner's decision:** a DMS newer than the checked one (API 38) keeps working with a note in Settings; an older one is switched off. Z9 needs that sentence at the merge.
- **The pattern to copy per domain:** one `DmsFeed` per DMS service with `wanted:` set to the lease (`holds("…")`, or `true` for un-leased contract state); properties are bindings on `feed.data`; methods go through `link.call` and never update properties themselves; a pure `Dms<Domain>Map.js` does the mapping and is tested under Node against the fixture.
- **Needs from F1** (§7): the DMS socket path for the panel, at spawn and on change; stopping an orphaned resident; the source for Z123's expansions.
- **New open items:** OPEN.md F2-1 to F2-6.
- **Found on the way:** `tests/test_qmldirs.py` fails before any F2 change (`tests/fixtures/nested/{lock,pamcheck}/qmldir` missing). Left alone.
- **Next:** build §9 in order (stand-in, link machine with its row tests, network, smoke), then roll the pattern out to bluetooth, brightness and the rest.

# 11 November 2026, afternoon: nested Hyprland check (Z109) passed

- **Nested Hyprland is viable for tests.** `tools/nested_hypr.py` (start / run / shot / stop / selftest) parks a nested Hyprland on a hidden special workspace with a headless `ZTEST` output that renders while hidden. Self-test 9/9 twice: fake lock shows and clears, a crashed lock client keeps the screen covered, a new client takes over, fake PAM permit/deny work from private config files, real session untouched. Details: docs/NESTED.md. Fixtures in `tests/fixtures/nested/`; `tests/test_nested_fixtures.py` 3 OK.
- **F1 prepared for Fable 5.2:** brief `docs/F1_BRIEF.md`; recon `docs/F1_RECON.md` (DMS run nested with private folders: a UI crash takes DMS down and is not respawned; only TERM/INT stop the pair cleanly, HUP/KILL orphan the UI; the shared `dms.path` pointer is taken by any second DMS and deleted on exit).
- **Incident during recon (fixed):** the first test DMS shared the real runtime folder, overwrote `dms.path` and deleted it on exit, so the owner's DMS keybinds pointed nowhere for under a minute. Restored by hand to the real UI path; `dms ipc` lists the real targets again. Tests now use a private `XDG_RUNTIME_DIR`.
- **Next:** the F1 Fable session, from the brief. Also check `zaetherion start/stop/restart/status` fits the session.

# 11 November 2026, ~12:40: S1 session installed and tested; DMS bar tuned

- SDDM entry installed by the owner; the owner now logs into **ZÆTHERION** (Hyprland + `zaetherion.lua` → `session-start` → core → `dms run` with DMS's UI). Login clean; logout + login left no old processes, one fresh set.
- cliphist records in the ZÆTHERION session (owner's choice); DMS clipboard stays off.
- Owner design inputs recorded: Modern Clock widget (PARITY, S10), island module list and memory-pressure expansion (SURFACES §1, OPEN 14).
- DMS bar tuned for the owner (7 workspace dots, power button, CPU off); not in this repo.
- **Next:** nested Hyprland check (Z109), then F1 (supervisor design). See NEXT_CHAT_HANDOFF.md.

# 11 November 2026, midday: S0 done; S1 started (owner approved both parts)

- **S0 done.** Full unit suite in this tree: 673 OK (572 s). Quiet baseline of Serpantinum + FART-next measured with Serpantinum back for ~10 min; **total budget fixed at 768 MiB PSS** (BUDGETS.md). Serpantinum is off again (`*.off`), DMS keybinds back in `config/keybinds.lua` (copy: `keybinds.lua.dms-2026-11-11`). Note: `serpantinumd stop` leaves `serpantinum-audio daemon` running; it had to be killed by hand.
- **S1 so far (not yet installed or logged into):**
  - `~/.config/hypr/zaetherion.lua` + `~/.config/hypr/zaetherion/` (copies in `session/hypr/`): shared look/monitors, DMS keybinds, Super+` on ZÆTHERION's core, `allow_session_lock_restore`, no Serpantinum or cliphist autostart. `Hyprland --verify-config` says ok. `hyprland.lua` (Serpantinum's session) unchanged.
  - `tools/session-start`: interim starter (core, then `dms run` with DMS's own UI until the resident exists at S3; restarts dms with backoff; stops both when the Hyprland socket goes). Roadmap F1 (fartd supervising dms) replaces it.
  - `session/zaetherion.desktop` (template, `@HOME@`), installed by the owner with sudo.
- **Still owed for S1:** install the session file, a real login/logout test (no leftover processes), nested Hyprland check (Z109), F1 supervisor design.

# 11 November 2026: S0 nearly done

- **Done:** scrub test and fixture replay (`tests/test_dms_fixtures.py`, 10 OK; `tools/dms_replay.py`, a stand-in DMS server); the real lyrics, location and weather names (weather is UI-side in DMS); a first memory look. All in `docs/DMS_OBSERVED.md`.
- **Owed for S0:** the quiet baseline of Serpantinum + FART (Serpantinum is off while the owner tries DMS), then BUDGETS.md's total.
- **The owner's desktop now:** full DMS (`dms run`, detached) with their keybinds retargeted to DMS (`~/.config/hypr/config/keybinds.lua`; the Serpantinum version is `keybinds.lua.serpantinum-2026-11-10`). Serpantinum's `bin/serpantinum{,d}` are renamed `*.off`. FART running.
- **Next:** S1 (the session). It needs the owner's approval for the SDDM entry (root) and autostart.

# 10 November 2026, late: S0 started, the seed is in (branch `s0-seed`)

- **Seeded from FART-next tag `FARG`** (`c13d874`): code at the root, FART's docs in `docs/fart/`, its NOTICE as `licenses/FART-NOTICE`. NOTICE records it.
- **`zaetherion` launcher** (`./zaetherion`, `tools/zaetherion.py`): FART's CLI with its own runtime, state and cache folders (`zaetherion`), so it can't touch the everyday `fart`. Checked with `status` only; not started. Still named fart-next in help text and the core's own names.
- `test_orbit` passes from the seeded tree. The full suite hasn't run here yet.
- **OPEN 2 checked (read-only):** tesseract, zbarimg and satty are all installed.
- **OPEN 13 decided:** the heavy layer stays on NVIDIA, Overdrive only (BUDGETS.md changed).
- **DMS run for the first time, read only, with Serpantinum fully stopped and backed up:** see `docs/DMS_OBSERVED.md` (read it before touching DMS). Fixtures in `tests/fixtures/dms/`. **Problem first:** the clipboard manager ignored its off switch.
- **Was waiting on the owner (now partly done):** OPEN 13 (keep the heavy layer and change the "dGPU never woken" budget, or move it to the AMD chip); the first `dms run` for the fixtures; the quiet baseline. The FARG measurements are in FART's `docs/OVERDRIVE.md` §9: NVIDIA asleep in Silent and after release, about 38 % and 12–14 W while Overdrive is on.

# 10 November 2026: the plan says "bring FART over"; DMS installed

**State:** still design only, no shell code. Two things changed:
- **FART-next is past the start line (Z1).** It has built all of M0–M16, including what this plan had moved here (M13 lensing, M14's live previews, M15 discovery and the archive, M16's tiers), plus M11 sessions and the heavy layer on the NVIDIA card. **Z62 now says ZÆTHERION brings FART over:** all of it arrives with the S0 seed and is adapted, not rebuilt. S11 extends FART's Overdrive to the island, launcher, overview and lock card. MILESTONES, DECISIONS (Z1, Z9, Z62), DMS_BACKEND and README updated.
- **DMS is installed: `extra/dux-shell` 2.1.0-1** (the owner, 10 November, 14:18), not `dux-shell-git`. Z9 is changed to match. **Not run yet:** `dms.service` is disabled and inactive, and there's no DMS config directory.

**New open item:** OPEN.md 13, the heavy layer on the NVIDIA card against the "dGPU never woken" budget. The seed brings it in, so it needs the owner's answer at S0.

**Untouched:** `docs/ROADMAP.md` is an uncommitted local file from before this change; it still says `dux-shell-git` and "M13–M16 move here". Left as it is.

**Next task:** S0, when the owner says go:
1. Seed this repo from a tagged FART-next commit. FART-next first takes its 144 Hz measurements and finishes its optimisation pass, then tags.
2. Record and scrub the DMS fixtures (`dms run` for the first time, on the owner's go; check `apiVersion` against 2.1.0).
3. Read-only check for tesseract, zbarimg and satty (OPEN 2).
4. Measure the quiet baseline.

# 8 November 2026: planning complete, design docs published

**State:** design only. No shell code exists. The plan came from one long planning session in which the owner answered every design question: 142 decisions (Z1–Z142), plus 12 open items, each with the test or approval that settles it.

**Done:**
- The docs set: VISION, DECISIONS, SURFACES, ARCHITECTURE, CONTRACT, MILESTONES, BUDGETS, RISKS, PARITY, DMS_BACKEND and OPEN.
- A plain-language overview PDF for non-technical readers.
- The public GitHub repo, with milestones S0–S12 and issues.

**Not done, by design:**
- No package installed. DMS was researched from its source only.
- No Hyprland, SDDM or Serpantinum file touched.
- No FART-next code changed; a docs pointer branch exists there, unmerged.

**Next task:** wait. ZÆTHERION starts when the owner says FART-next's Overdrive has reached about M12. Then begin S0 (docs/MILESTONES.md):
1. Ask for approval to install `dux-shell-git`.
2. Seed this repo from a tagged FART-next commit.
3. Record and scrub the DMS fixtures.
4. Measure the quiet baseline.
