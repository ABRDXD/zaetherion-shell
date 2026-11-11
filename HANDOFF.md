# 11 November 2026, evening: F1 delivered (Fable 5.2): the supervisor

- **Design:** `docs/SUPERVISOR.md` (states, transition table, backoff, crash verdicts, owner restarts, logout sequence, `dms.path`, lock hand-over, named clients, each recon finding). New questions for the owner: OPEN 15–18.
- **Slice, finished:** `fartd` supervises `dms run` when `FART_SUPERVISE=dms` (`core/supervisor.py`, wired in `core/fartd.py` and `core/app.py`). **Off by default: the owner's session still runs on `tools/session-start`.**
- **Verified:** `tests/test_core_supervisor.py` 24 OK; `python3 tools/supervisor_check.py` 16/16 (twice) in the nested Hyprland with private folders: start, UI crash back in 0.37 s, DMS kill with orphan sweep, owner restart adopted in 0.8 s and not doubled, waits 0.25/1/3/4, shutdown and compositor exit leave no processes, the session's DMS untouched. Full unit suite: see FULL_SUITE below.
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
  1. **Switch-over, needs the owner's go:** `start_core` in `tools/zaetherion.py` sets `FART_SUPERVISE=dms`; `tools/session-start` becomes "start the core and wait" (drop the DMS loop and `pkill -x dms`); raise `stop_core`'s wait from 6 s to 12 s. No Hyprland config change. Then a real login/logout test, and OPEN 16 and 18.
  2. Named clients `resident`/`panel` and the panel's snapshot adapter (§9); `tests/test_core_view.py` must stay green.
  3. `session.log` trimming and `dms.log` rotation; who restarts `fartd`.
  4. **Routine, found on the way (not F1's):** two unit tests have failed since the nested fixtures were committed (`4db1718`): `test_qmldirs` (no qmldir in `tests/fixtures/nested/{lock,pamcheck}`) and `test_layout` (a font size literal in `tests/fixtures/nested/lock/shell.qml`). Both scan every `.qml` in the repo; test fixtures should be skipped by both. The supervisor check writes its test UI into its temporary folder for this reason.
- F2 (the `dms` adapter) was not started: it needs its own brief first.

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
