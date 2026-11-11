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
