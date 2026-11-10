# Overdrive

Status: **approved by the user on 8 November 2026** ("OVERDRIVE BABY"), built by Claude A from M8 on. The mandate is in `CLAUDE.md`: nothing is held back, ideas are implemented, optimisation comes at the end. This file is the record of what Overdrive is, how it is built, and what it costs (§9, the ledger for the final optimisation pass).

## 0. The rules that hold

- **Silent stays Silent.** Overdrive runs only while the core's lease is *active* (`effective === "active"`): requested, not suspended by a guard, and motion not reduced. Anything else is Silent, where nothing moves at rest.
- **Release destroys.** Every Overdrive effect is a `Stratum` (a Loader) or an idle loop gated by the engine. When the engine reaches 0, they are destroyed, not hidden, and their textures go with them (PROJECT_PLAN M8: back to the Silent-open baseline ±10 MiB within 5 s).
- **Reduced motion wins.** With motion reduced, the engine is 0 even if the lease is held. The header says `OVERDRIVE · REDUCED MOTION`, and no stratum exists (CUES §6).
- **Unseen, nothing runs.** A folded panel snaps the engine to its target and stops every loop (CUES rule 3).
- **Safety (AGENTS.md):** no real playback, volume, network, power or recording is actuated to test, and no clipboard or notification contents are shown or captured. Comets for notifications (§8) carry no text and no app name.

## 1. The lease in the view (M8)

- **`Motion.overdrive`** is bound by `Overlay` (and by `tools/measure/FixtureView.qml`) to the core's `overdrive` topic: `effective === "active"`.
- **`view/overdrive/OverdriveLease.qml`** is the view's handle on the lease: `mode` (off, timed, panel, sticky), `effective`, `reasons` (the guards that are on), `guards` (availability on this machine), `until`, the `ignite` topic, and `request`, `release`, `holdDown` and `holdUp`.
- **`LeaseChip`** sits in the header beside `FART`:
  - a five-bar tachometer leaning at 78° that lights with the engine (`Motion.drive`);
  - the state in words: `SILENT`, `OVERDRIVE · PANEL` / `STICKY` / `19:42` (a timed lease counts down once a second, only while shown), `SUSPENDED · ON BATTERY`, `OVERDRIVE · REDUCED MOTION` or `SPINNING DOWN`.
- **`LeasePanel`** (click the chip; Esc closes it) is the lease manager:
  - the state and why;
  - the routes: this panel, sticky, 20 minutes, 1 hour, and release;
  - the four guards (dGPU, fullscreen, battery, session), each with whether this machine has it and whether it's on;
  - the tiers (D3): T1 panel is on, T2 and T3 come with M16;
  - the engine: the drive, the idle loops, the frames per second the panel is drawing (counted only while the manager is open) and the strata that exist.

## 2. Ignition (M8, D16)

- **The ignite plate is FART's logo.** Hold `F/` in the header (or hold **Ctrl+O**) for 600 ms to ignite Overdrive for this panel. Hold it again to cut it.
  - The core times the hold, with the same machine as Super+` (`core/ignite.py`). The view sends `key.down` with `panel: true`, so the press neither folds nor opens the panel. A tap does nothing, and the release always ends the meter.
  - A fire while Overdrive is on releases it (`core/app.py`, `_ignite_request`).
  - The Super+` bind itself still needs the user's approval; the plate and Ctrl+O don't.
- **The fuse:** the hold burns along the header's rule from the plate to its end over the 600 ms. A spark at its head throws sparks, and the burnt length glows in the signal colour (warm when cutting). Under reduced motion it keeps the length (information), with no sparks. The logo heats towards the signal colour as it burns, and stays lit with the engine.
- **The ignition** (`Ignition.qml`), when the engine turns on while the panel is seen:
  - one flash of the signal colour (a FlashGate grant);
  - **the montage break:** the header and its rule jump up along 78°, the field down. They slam back past each other (OutBack, overshoot 3.4) and settle;
  - **the shockwave** (`view/strata/Shockwave.qml`, GPU): a ring runs out from the plate across the panel and bends the content it passes through, splitting the colour channels at the ring.
- **The spin-down:** a release winds the engine down over 1.6 s (§3), and a cold band leaning at 78° sweeps down the panel with it.
- **Sounds** (FART's own, `tools/sounds/make_ignite.py`): `overdrive-ignite.wav` (a turbine spooling up, sparks, a sub thump and an air burst at the fire point) and `overdrive-off.wav` (the turbine winding down like a tape stopping). The core plays them on any route when a lease starts or ends (`ignite`, `overdrive.off`). A guard suspending or resuming a held lease is silent. They go through the usual gate (host mute, DND, sessions).

## 3. The engine (`Motion.drive`)

- **`Motion.drive`** runs from 0 (Silent) to 1 (Overdrive). It spins up over 900 ms (OutCubic) when the lease turns active and winds down over 1600 ms (InOutSine) when it ends.
  - `Motion.driving` is the target (`overdrive && !reduced`).
  - `Motion.engaged` is true while driving or still above 0: strata and idle loops exist while engaged.
  - The spin-down is the user's "release brings FART back to Silent": motion slows to rest instead of snapping.
- **Idle loops** (`IdleLoop`) integrate their phase at a speed scaled by the drive, and expose `level` (the same engine) for amplitudes, so at 0 everything is back at rest. `turns` counts whole periods for loops that drift rather than repeat.
- **The idle clock** ticks every frame in Overdrive (`Motion.idleInterval` 0, a `FrameAnimation`), where Silent's old loops ran at 30 Hz. A fixed interval (`FART_IDLE_MS`) still runs a timer, for the measurement sweep.
- **Unseen:** `Motion.seen` is bound to the panel being on screen; a change while folded snaps the engine.

## 4. Strata (D12)

- **`Stratum`** (`view/strata/Stratum.qml`) is the only way an Overdrive effect exists. It's a Loader, active while:
  - it is wanted and the engine is engaged;
  - motion is not reduced;
  - its scope can be seen;
  - for `gpu` effects (shaders), the scene graph is not the software renderer, which draws no shaders.
- **Asynchronous**, and listed in `Strata.live` as `<tier>:<name>` while its item exists. `fart status` reports it under `overdrive`, and a release must leave it empty.
- **`KeepOut`** is the control keep-out mask: the panel's content drawn at a quarter size into a texture. A stratum's shader fades itself out wherever a control, a plane or text is drawn, so effects keep to the negative space. Redrawn at most 15 times a second, live only while its source scrolls (§9, 10 November's pass).
- **Tiers** (D3): `tier: "panel"` (T1, inside the panel) for everything in M8–M15. T2 (clock and satellites) and T3 (the desktop `bottom` layer) come with M16.
- **The sheet alive** (`view/strata/SheetField.qml`, the hero for every room, KeepOut's first user): two hatch fields, one at 78° and one across it at −12°, drift against each other into a slow moiré on the room's sheet.
  - It breathes in bands, pulses with the bass, and lights up round the pointer.
  - It sits under the room's content and fades wherever the room draws a control, a plane or text (the keep-out mask of the room's viewport), and it never draws on the title wedge's column.
  - Not while the orbit is open.
- **Shaders** live only in `view/strata/shaders` (CUES §4.3) and are compiled by `tools/make_shaders.py`.

## 5. The orbit alive (wave 2)

All of this is in `OrbitSystem`, `RoomSystems`, `SpaceSystem` and `SpaceFabric`. Each term is multiplied by the engine, so Silent is exactly the still orbit, and a release winds everything back to its stored place.
- **Drift:** the tiles ride their orbits at Kepler's speeds. The inner orbit goes round in 45 s at full drive, each orbit further out slower by (r / r_inner)^1.5.
  - `driftOf(k)` is the offset from the stored angle, wrapped to ±π and scaled by the engine, so the spin-down brings each tile home the shortest way.
  - It's reset at rest, so every ignition starts from the stored places.
  - Hit-testing, the keyboard, the streak and the fabric's wells all follow the drifting tiles (they read `place(k)`). The systems stay at their rest places, and their routes stretch to the moving planets.
- **Bob and spin:** each system floats over its height in its own phase (`systemBob`, a 7.4 s loop). Its tether stretches with it, and its moons circle its sun (`moonSpin`): the inner ring 2.26× faster, alternate systems turning the other way.
- **The fabric breathes:**
  - its wells deepen and ease on the bob's phase;
  - Home sends gravitational waves out across it, a travelling sine fading with distance;
  - the bass presses Home's well deeper and makes the waves taller (`life` uniform).
- **The music:**
  - while Overdrive drives, the orbit is shown, ambient detail is on and something plays, the orbit leases the host's `spectrum`;
  - the bass is the first six bins, with a quick attack and a slow decay;
  - an onset (the bass jumping 0.16 over its running average, at most one every 240 ms) is a **beat**: the tiles hop (their stalks stretch 32 %), Home pulses, the systems bob higher, and the fabric rings out from Home.
- **Deep space** (`view/strata/Starfield.qml`, GPU): three layers of procedural stars behind everything, moving with the camera at a tenth, a sixth and a third of its speed. They zoom less than the scene, twinkle on one 9 s phase, and a few burn warm.
- **The pointer has mass** (Claude A's idea): where it hovers over the orbit, it presses its own well into the fabric.
- **Eclipses** (Claude A's idea): when a drifting tile passes in front of Home, Home dims by up to 45 % and a corona (warm, with an accent halo) shows round it.
- **Comets** (Claude A's idea): a new notification crosses space as a comet. It comes from beyond the galaxy's edge, bends round Home's well and falls into the Inbox tile, which rings the fabric and makes the orbit hop. Only the count going up is read, never the text or the app.

## 6. Kinetic lyrics (M9, Claude B)

Two parts, both Strata, so both exist only in Overdrive, while the Media room is shown and something plays (M9's test: no stratum when paused, hidden or in Silent):
- **The stage** (`view/rooms/KineticStage.qml`, mounted by Media over its lyrics area as `lyrics.stage`, while lyrics are on): the words become a music video of type, and Silent's karaoke roll cross-fades back as the engine winds down.
  - **A phrase builds word by word.** Each word slams in along 78° at its own size: how long it is sung (`Kinetic.scaleFor`, 0.7× to 2.6×).
  - **A held word** (0.9 s or more) swells while sung, and is left as its outline once sung: its glyphs stroked with `PathText`, since `Text.Outline` only fattens a fill.
  - **A cut** (the next phrase, or a rest between lines) throws the last one out along 78°. Every other cut inverts the stage (ink), if FlashGate allows. Phrases never cut faster than 3 a second (`Kinetic.frames` merges what comes sooner).
  - **Beats:** bass-weighted spectral flux against an adaptive threshold (`Kinetic.detector`), on the spectrum Media already leases. A beat kicks the phrase along 78° and flashes the rule under it.
  - **CJK** runs in columns, top to bottom, right to left. **A returning chorus** carries outlined ghosts of its earlier times. **Between lines,** the next line waits faint while a rule counts in to it.
  - **Everything is a function of the playback position,** so seeks and bursts never queue or jump. Its frame clock (`lyrics.stage`) runs only while playing.
- **The title wedge** (`view/overdrive/KineticLyrics.qml`, mounted by the Shell as `lyrics`): the track's name, cut on the beat, one word per cut, slammed in along the blade. A beat sooner than a third of a second after a cut punches the word instead. Every other cut swaps the blade's role through FlashGate. It leases only the spectrum.
- **Timing** (`view/rooms/Kinetic.js`, pure, tested under Node):
  - word times from enhanced LRC or TTML when present (`tools/lyrics/lyrics.py` now keeps them);
  - otherwise a character-weighted fallback: a CJK character weighs 2.5 letters, a word adds a 0.5 breath, and a line's sung span is capped at 0.3 s per unit, so a line before an instrumental doesn't stretch across it.
- **Tests:** `test_kinetic_lyrics` (timing, frames, layout, echoes, beats); cuetest `KineticTest` (words at their times, the cut cap, held and hollow, the rest, echoes, upright CJK, FlashGate, release); ViewTest `view.idle.playing` (stage and wedge in Overdrive, neither when paused or in Silent, nothing when hidden).

## 7. The archive on a bad tape (wave 4)

Rebuilt by Claude B with the wear of each note: see §17.
- **The surveyor wanders:** rebuilt by Claude B, see §16.

## 8. Claude A's own ideas, built

- **The black hole** (`PanelBody`): with the engine on, closing the panel makes it fall into the clock it came from.
  - It shrinks to a point at the origin, stretched towards it (spaghettified: x shrinks faster than y) and swirling in by up to 220°.
  - An event horizon flares at the clock as it passes.
  - Opening is the same in reverse: a small big bang out of the clock. It's always 0 in Silent.
- **The heat** (`view/overdrive/Heat.qml`, `view/strata/HeatHaze.qml`):
  - once a second while Overdrive drives and the panel is seen, the view reads its own CPU time (`/proc/self/stat`, utime + stime);
  - the header is drawn through a heat shimmer, with a warm glow rising off it, as strong as that CPU between the cool end (20 % of a core) and the hot end (140 %), the range §9 measured, on a square-root curve and eased per sample (it used to be CPU against 25 %, which real use always exceeded, so it sat pegged at maximum);
  - the lease manager prints the number. The cost is shown, not hidden.
- **The spin-down** (§2, §3): the release winds down like a turntable losing power.
- **Comets, eclipses, the pointer's mass, deep space** (§5).

## 9. The cost ledger

Measured on and off, for the optimisation pass at the end (the mandate: record, don't cut). RSS and PSS separately; CPU as a share of one core; frames as what the view actually drew per second, not the nominal refresh.

| Date | Commit | Scenario | Silent | Overdrive | After release (5 s) | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 8 Nov 2026 | `5d4c293` | Home | 2.0 fps; RSS 508.4, PSS 223.2 MiB; CPU 0.60 % | 145 fps; RSS 514.2, PSS 229.0 MiB; CPU 45.2 % | RSS 513.5, PSS 228.1 MiB (+5.1 / +4.9); CPU 0.20 %. **Sample interrupted by input: not a pass** | Silent and Overdrive samples quiet. CPU is over the plan's 25 % of a core. |
| 8 Nov 2026 | `5d4c293` | Orbit (`--cycles 2`) | 2.0 fps; RSS 524.4, PSS 238.9 MiB; CPU 1.17 % (quiet) | about 65 fps; RSS about 548, PSS about 260 MiB; CPU 133 %. **All Overdrive samples interrupted: indicative only** | after the second release (quiet): RSS 549.9, PSS 262.4 MiB (+25.5 / +23.5); CPU 1.00 % | **Fails M8's ±10 MiB.** The memory stops growing after the first ignition (first release 550.8, second 549.9 MiB RSS; the first sample was interrupted), so it looks like a one-off, not a leak. Cause not found. |

| 8 Nov 2026 | `5d4c293` | Home, **quiet**, `--cycles 2` | 2.0 fps; RSS 515.7, PSS 232.0 MiB; CPU 0.58 % | 144.7 fps; RSS 524.0, PSS 238.5 MiB; CPU 30.6 % | RSS 524.9, PSS 239.0 (+9.2 / +7.0); second release RSS 524.2, PSS 240.1; CPU 0.5–0.7 % | Within M8's ±10 MiB, RSS narrowly. First ignition of the process. CPU over the 25 % budget. |
| 8 Nov 2026 | `5d4c293` | Orbit, **quiet**, `--cycles 2`, after Home's cycles in the same process | 2.0 fps; RSS 570.2, PSS 284.8 MiB; CPU 0.92 % | 80.25 fps; RSS 572.0, PSS 282.3 MiB; CPU 135.5 % | RSS 576.6, PSS 286.8 (+6.4 / +2.1); second release RSS 577.8, PSS 288.1 (+7.6 / +3.3); CPU 1.0–1.2 % | Within ±10 MiB, but Overdrive had already been lit once in this process. No growth to speak of between cycles. Does not cancel the row above it: lit first on the orbit, it kept +25.5 / +23.5. |

**Reading these together:** nothing grows from one ignite to the next, so no leak shows. The first ignition of a process costs memory that stays: about 9 MiB RSS on Home, about 25 on the orbit. M8's ±10 MiB holds except when the orbit is the first place Overdrive is lit. What the first-ignition memory consists of has not been found. The orbit in Overdrive cannot hold 144 Hz (80 fps) and uses more than one core (135 %).

**9 November, `87218b3` (§10–13 and §15 and B's lyrics code, nothing playing), every sample quiet, `--cycles 2`, 20 s windows:**

| Commit | Scenario | Silent | Overdrive | After 1st release (5 s) | After 2nd release | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `87218b3` | Home | 2.05 fps; RSS 509.3, PSS 240.8 MiB; CPU 0.55 % | 144.2 fps; RSS 523.2, PSS 251.3 MiB; CPU 44.4 % | RSS 522.2, PSS 250.4 (+12.9 / +9.6); CPU 0.45 % | RSS 522.5, PSS 250.6 (+13.2 / +9.8) | **Over M8's ±10 MiB on RSS** (it was +9.2 on `5d4c293`); PSS just inside. No growth between cycles. CPU up from 30.6 %. |
| `87218b3` | Orbit, after Home's cycles in the same process | 2.0 fps; RSS 552.7, PSS 278.7 MiB; CPU 0.90 % | 100 fps; RSS 576.2, PSS 298.2 MiB; CPU 133.5 % | RSS 569.2, PSS 291.2 (+16.4 / +12.5); CPU 0.80 % | RSS 557.2, PSS 279.4 (+4.4 / +0.7); CPU 0.90 % | **First release over ±10 MiB, second well inside**: the memory is given back, later than the 5 s the test allows. Frames up from 80 fps. |

Not covered by these rows: the desktop tier (§14, `overdrive_cost.py` drives `FixtureView`, not `Overlay`), and anything while playing (`--playing`: lyrics, the wedge, the visualiser). No per-feature split: these are all of Overdrive together. fart's own live panel was open on the machine during the run. Raw: `docs/measurements/overdrive-87218b3.json`.

Raw reports: `docs/measurements/overdrive-clean-5d4c293.json` (all samples quiet), `overdrive-orbit-cycles-5d4c293.json`, `overdrive-5d4c293.json`. Fixture view on the GPU, 12–15 s windows, sticky lease, 5 s after each release. Still to run: `--playing`, the desktop tier and a per-feature split.

**10 November, `b6380c1` (the whole atlas, M11, M15), plugged in, the user away from the keys and the window kept in view.** Fixture view on the AMD chip (`overdrive_cost.py`, `room_cost.py`), 15–20 s windows, quiet samples only unless marked. Raw: `docs/measurements/overdrive-b6380c1.json` (the orbit; its Home rows were interrupted), `overdrive-home-b6380c1.json`, `rooms-b6380c1.json`, `heavy-b6380c1.json`.

| Place | Frames | View CPU | AMD chip (view's own) | RSS / PSS Silent → Overdrive → released (MiB) | Notes |
| --- | --- | --- | --- | --- | --- |
| Home (2 cycles) | 144.6 fps | 36.8 % | 69 % | 517.4 / 230.4 → 563.1 / 267.1 → 534.6 / 240.5 | **+17.2 RSS after release: over M8's ±10** (PSS +10.1). First Overdrive sample interrupted. |
| Orbit (2 cycles) | **48.6–49.5 fps** | **89–91 %** | 63–64 % | 617.2 / 314.3 (interrupted) → 625.3 / 318.3 → 601.5 / 297.5 | **Down from 78–100 fps on 9 November.** Memory is given back. |
| Media | 144.5 | 21.1 % | 69 % (44 %) | 516.1 / 230.1 → 533.9 / 243.1 → 513.2 / 222.4 | inside ±10 |
| Performance | 143.9 | **52.7 %** | 69 % (49 %) | 521.9 / 226.9 → 564.3 / 268.6 → 535.5 / 244.1 | **+13.6 RSS after release**; CPU twice the budget |
| Home (rooms run) | 144.6 | 36.9 % | 69 % (45 %) | 541.8 / 247.8 → 571.6 / 269.0 → 537.0 / 241.8 | inside |
| Inbox | 144.6 | 13.7 % | 69 % (42 %) | 545.7 / 245.2 → 559.1 / 261.3 → 534.4 / 239.4 | inside |
| Tasks | 144.7 | 13.7 % | 69 % (42 %) | 538.5 / 245.7 → 556.1 / 260.5 → 532.4 / 239.1 | inside |
| Devices | **72.3 fps** | 9.1 % | 69 % (47 %) | 541.4 / 243.8 → 565.0 / 263.3 → 539.0 / 243.2 | **half rate**: something in Devices' Overdrive holds every other frame |

**The heavy layer on the NVIDIA card** (`tools/measure/heavy_cost.py`, new: a private core on the fixture host, the real `Overlay` on the real screen, the heavy process by PRIME offload as in daily use; 15 s windows):

| Scenario | NVIDIA load (peak) | NVIDIA power | AMD chip | View CPU / RSS | Heavy process CPU / RSS |
| --- | --- | --- | --- | --- | --- |
| Home, Silent | asleep to FART | — | 3.2 % | 0.3 % / 501.2 | none |
| Home, Overdrive | 37.1 % (39) | 10.3 W | 48.9 % | 21.3 % / 565.2 | 8.0 % / 333.6 |
| Media, Overdrive | 39.1 % (45) | 10.2 W | 46.6 % | 13.9 % / 600.8 | 8.0 % / 334.1 |
| Performance, Overdrive | 38.5 % (42) | 10.4 W | 49.3 % | 32.8 % / 618.5 | 8.6 % / 333.9 |
| Flights (a room every 1.5 s) | 35.8 % (44) | 10.1 W | 35.8 % (peak 49) | **150 %** / 656.6 | 8.0 % / 333.9 |
| Released (5 s) | — | — | 3.5 % | 0.3 % / **600.9** | gone |

**Reading these:** the heavy layer itself is steady: about 37 % of the NVIDIA card and 10 W in every room, 334 MiB for its process, 8 % of a core, and it exits on release. The panel's own Overdrive keeps the AMD chip at about 69 % in every room (47–49 % with the real Overlay over the heavy layer), whatever the room draws, so most of that floor is shared, not per room. The targets for the optimisation pass, in order: **the orbit's frame rate** (half of 9 November's), **flights** (150 % of a core), **the real Overlay keeping about 100 MiB after flights and a release** (501 → 601 MiB RSS), **Devices at half rate**, the constant AMD floor, and Performance's CPU. The NVIDIA card was already awake before the run (runtime status active throughout), so its idle power wasn't seen.

**GPU, for the final pass (the user saw about 70 %, 9 November; don't cut anything for this until the end).** `3d89590`, most other applications closed, 20 s windows, quiet samples only. The NVIDIA card stayed asleep at every check; all of FART's GPU work is on the AMD chip (card1, `0000:06:00.0`).

| Place | Whole AMD chip, Overdrive | The view's own GPU time | Frames | CPU | Whole chip, after release |
| --- | --- | --- | --- | --- | --- |
| Home | 60.9 % mean, 62 % peak | 29.0 % | 143.5 fps | 44.3 % | 8.2–8.9 % |
| Orbit (second cycle; the first was interrupted) | 49.8 % mean, 52 % peak | 28.3 % | 77.9 fps | 135 % | 1.8–2.7 % |

Reading: the whole chip rises by about 50 points, and the view's own drawing accounts for about 29 of them. The remainder wasn't attributed; the compositor redrawing every frame is the likely part, not measured. The orbit is limited by CPU, not GPU (78 fps at 135 % of a core with the chip half busy). Home runs at the full 144 Hz, so a lower frame-rate cap is the first thing to try in the final pass.

**Release memory in this run** doesn't repeat the `87218b3` figures: orbit, against its quiet Silent sample, -9.2 RSS / -24.5 PSS after the first release, where `87218b3` showed +16.4 / +12.5. Home's Silent sample was interrupted, so it has no delta. The ±10 MiB verdict depends on the Silent baseline of that run, so M8's memory test needs several runs before it is called pass or fail. Raw: `docs/measurements/overdrive-gpu-3d89590.json`.

**Experiment, 9 November (`63579f8`): the whole panel on the NVIDIA card.** Private copy with the dGPU guard disabled, PRIME offload by environment variables, all samples quiet, one cycle, 15 s windows, Spotify and a browser open, nvidia-smi sampling once a second.

| | AMD (as shipped) | NVIDIA |
| --- | --- | --- |
| Cold start to open | 490 ms | 2476 ms |
| Home in Overdrive: frames, view CPU | 144.5 fps, 24.6 % | 144.6 fps, 31.7 % |
| Home: whole AMD chip | 61.3 % | 36.6 % |
| Orbit in Overdrive: frames, view CPU | 96.1 fps, 133 % | 49.5 fps, 138 % |
| Orbit: whole AMD chip | 58.0 % | 16.6 % |
| NVIDIA load in Overdrive | asleep | about 23 % Home, about 35 % orbit |
| NVIDIA power, temperature | asleep | 8-10 W at work, 3-4 W awake and idle; 43 °C peak |
| PSS, Home Silent | 233 MiB | 296 MiB (RSS 508 vs 459) |

Reading: the card has plenty of headroom but moving the panel to it doesn't help the orbit, which got slower; it isn't limited by the GPU (35 % busy, 138 % of a core on the CPU). Why it halved is not known. The cold start is four times the 600 ms hold, so a swap inside the hold can't work from cold. The card went back to sleep afterwards. Raw: `docs/measurements/overdrive-gpu-experiment-*-63579f8.json`.

**B's rows: room by room (`tools/overdrive/room_cost.py`, A's measurement opened in each room by name), 9 November, the view at `6eeb919` (the report names `77aa201`, a docs-only commit on top), fixture player playing, 15 s windows.** Only quiet samples in which the window was actually drawn count. The NVIDIA card stayed asleep throughout.

| Room | Silent | Overdrive | After release (5 s) | Notes |
| --- | --- | --- | --- | --- |
| Media, playing | 32.5 fps; RSS 491.3, PSS 215.1 MiB; CPU 5.7 %; AMD chip 11 %, the view's own GPU 2.8 % | 144.7 fps; RSS 489.7, PSS 215.6 MiB (−1.6 / +0.5); CPU 36.6 %; AMD chip 37 %, the view's own GPU 18.6 % | interrupted: not a result | Everything Media runs in Overdrive at once: B's kinetic stage, wedge, spectral architecture and groove, and A's cover ring, heat and the rest. No per-feature split. CPU over the plan's 25 % of a core. |

Excluded: Performance (Silent, Overdrive and release all interrupted), and every Home and Inbox window: the fixture window drew 0 frames in them (it was hidden behind the user's windows), so their CPU figures don't describe a drawn panel. To redo on a quiet desktop, nobody at the machine. Raw: `docs/measurements/overdrive-b-rooms-6eeb919.json`.

**The optimisation pass, B's share (10 November, evening): Devices' half rate, Performance's CPU, memory after release.** All on the hidden desktop (60 Hz, KWin's virtual screen has no other rate), the fixture view rendered on the AMD chip through Mesa with RHI timestamps (`tools/overdrive/gpu_probe.py`, new; `--off` switches strata off in a temporary copy), variants in alternating runs because the chip moves between two clock states from run to run. **Indicative only: the 144 Hz screen wasn't used** (no "poop"), and the user was at the keys, so `room_cost.py`'s windows all read interrupted.

- **Devices' 72 fps is not reproduced at 60 Hz** (59.5–60 fps there), and nothing in Devices halves frames by itself: no second window, no timer near 14 ms, CPU about 1.3 ms a frame. An exact half at 144 Hz with low CPU is the FIFO swap missing every other vblank, i.e. GPU time near the 6.9 ms budget (10 November: the view's own 47 % at 72 fps ≈ 6.5 ms a frame; Tasks 41.6 % at 144 ≈ 2.9 ms). On the hidden desktop Devices' GPU time a frame equals Tasks', so what tipped it over on the real screen wasn't found; the AMD floor (A's) is shared by both. **Done instead:** cut the GPU time every room spends, below.
- **The sundial was the largest single GPU cost in every room** (`--off sheet.sundial`: Devices 1.60 → 0.95 ms). Its 42 taps now run at the mask's quarter size into a cached layer (`72e18fe`): GPU a frame, before → after, Devices 2.6 → 1.5 ms, Tasks 2.95 → 1.6, Home 3.46 → 2.24, Performance 3.8 → 2.1–2.7. The frame differs by a mean 0.26/255 (the sundial itself makes 8.3).
- **Performance's CPU, taken apart** (60 Hz, view CPU): 34 % in all; its seven strata about 12 points; the shared strata about 11 there but about 1 in Tasks and Devices, because the room animates inside its own content and the sheet's and the sundial's KeepOuts each drew the whole room again on every frame. Now one KeepOut (the sundial borrows the sheet's), redrawn at 15 Hz and live only while scrolling; the rain's crater line on an 8 Hz clock; the silt painted at 30 Hz (`afb36ca`). Performance about 34 → 27 %, Home about 28 → 24 %, Tasks unchanged (13.7 → 13.1 %). The orrery's bodies keep the frame clock: their motion is the feature. At 144 Hz the saving should be larger (the captures scaled with the frame rate); to be measured on the screen.
- **Memory after release is a one-off cost of first use, not growth.** 10 November's rooms run: after Performance's first ignition every later room's release lands at 532–539 MiB; Home's second cycle keeps nothing more (534.8 → 534.6). On the hidden desktop, three runs each, Performance's first cycle keeps +10.5 to +20.6 MiB RSS with its strata, +6.9 to +10.1 with them switched off, and the second cycle adds nothing in either: about half is Performance's own seven strata (compiled types, JS heap, canvases' images), about half the shared first ignition. `gc()` plus `Window.releaseResources()` at rest after a release made no difference beyond the ±10 MiB noise, so it wasn't kept. Home, measured after Performance in the same process, stays inside ±10.
- **To do on the screen ("poop"):** `room_cost.py --rooms devices,tasks,performance,home` on `afb36ca`, Devices both first and last in the order, to see whether Devices is back at 144 and what Performance's CPU is at 144 Hz.

**The optimisation pass, A's share (10 November, evening): the orbit's frame rate, flights, the Overlay's memory after release, the AMD floor.** Hidden desktop only (60 Hz; no "poop" yet), so every figure is **indicative**. Two things about that desktop matter for reading them: the plain fixture view there draws **in software** (Mesa's llvmpipe: no DRM handle in the view, so `overdrive_cost.py`'s render-thread CPU and "GPU" there are software rasterising, not the chip; B's `gpu_probe.py` sets `DRI_PRIME` and is the one that measures the AMD chip), and its run-to-run noise is about ±4 points of a core. The main thread's CPU (QML bindings and JavaScript) is the same work on any desktop, so the orbit and flight rows below are main-thread figures. Profiles: `qs --debug PORT` with `qmlprofiler --attach` (call counts only; this Qt's durations come out negative).

- **The orbit's 49 fps on 10 November: an orphaned heavy-layer process, not the orbit's code.** A `shell-heavy.qml` started at 13:45 never linked to its panel (the panel went before the socket was up), so nothing ever closed its link; it drew a 1×1 window every vsync on the NVIDIA card for hours, keeping the card awake through every 10 November measurement (`card0` awake 20 of 20 checks) and the AMD chip compositing it. On 9 November the card was asleep in every run: until `1ca5d33` an awake card *suspended* Overdrive, so no earlier row ever ran beside an awake card. Reproduced on the hidden desktop with the old `shell-heavy.qml` started unlinked beside the orbit: 43.3 → 30.7 fps and 147 → 115 % CPU (fewer frames *and* less CPU, the 10 November pattern; the main thread 90 → 64 %). The orbit's own code changed little since 9 November (the Codex's tenth system, the False Room, the error brackets). Fixed in `971a17b`: the heavy process retries its link for 8 s and exits, and draws only while it shows. **The orphan from 13:45 is still running on the user's desktop (pid 548890 at 15:44; FART can't reach it); it goes with `pkill -f shell-heavy.qml` or a log-out.**
- **The orbit's own CPU** (main thread, Overdrive, 60 Hz): **90 % → 52 % of a core** (`162a28d`, `d567348`). Orbit.js's `point()` ran 66,000 times a second, now about 9,800. The fabric's mass list was a binding rebuilt with its 80 wells for every loop's tick, about nine times a frame (now once a frame in Overdrive, a binding in Silent); every caller projected its own room places and rects (the laws' transit check alone asked for about a hundred an evaluation; now `places`, `roomRects` and `homeRect`, once per change); each room system rebuilt and re-tessellated its rings whenever it bobbed (now drawn round (0, 0) and moved); rooms were found with `findIndex` 26,000 times a second (now `roomAt()`). At 144 Hz the 90 % was the ceiling (it was 133 % on the screen, all of one thread), so this is what should lift the orbit towards 144: unmeasured there.
- **Flights** (a room every 1.5 s, 30 s windows, main thread): **47 % on `b6380c1` → 38–39 %**. The same flights in Silent cost 21–22 %: about half of a flight is the rooms loading, which Silent pays too (B's rooms; the biggest creators are `OrreryField`, `LiveTitle`, `FText`). The main orbits now redraw at 36 steps a half while the tilt swings (72 at rest). Tried and dropped: keeping the orbit loaded for 3 s after a flight so a burst reuses it. It did stop the orbit being rebuilt for each switch (OrbitSystem creations 246 → 50 a second), but no CPU change could be measured, and it held the orbit's memory longer. 150 % on the screen was the real Overlay at 144 Hz beside the orphan; not remeasured there.
- **The Overlay's memory after flights and a release** (real Overlay, `shell-fixture.qml`, heavy layer off; RSS / PSS MiB): Home Silent 509.7 / 241.1 → **a Silent tour of the same rooms** 557.6 / 286.2, twice 576.9 / 295.2 → Overdrive, flights 685.3 / 386.0 → released 5 s 645.8 / 355.4 → released 20 s **606.5 / 327.1**. So of the ~100 MiB that heavy_cost.py saw: **about 67 is the first visit to each room, which Silent keeps as well** (component, image and glyph caches); about 20 is file mappings loaded once (Pss_File 52 → 75: Overdrive's libraries and shaders); the rest, about 12 MiB anonymous at 20 s, **comes back slowly, not leaked** (40 MiB returned between 5 and 20 s). Overdrive's own residue against the post-tour Silent baseline: +30 RSS at 20 s, +69 at 5 s. A `gc()` 1.2 s after the spin-down changed nothing (654 at 5 s), so not kept; B found the same with `releaseResources()`. M8's ±10 MiB at 5 s should be read against a Silent baseline taken *after* the same rooms have been visited.
- **The AMD floor.** `gpu_probe.py` on the merged tree (after B's sundial cache): the view's GPU time a frame is 1.92 ms on Home, 1.49 Devices, 1.40 Performance; at 144 Hz that's 20–28 % of the chip before the compositor's share. Software-rendered stand-in on the real Overlay at Home (render thread, 15 s): 10.9 % with all 19 strata, 5.1 % with none; only the sheet (8.7) and the sundial (8.8) move it alone, both B's and both cut in `72e18fe`/`afb36ca`; every other stratum alone is within the noise. The other half is the rate itself: in Overdrive the idle clock ticks every frame (`Motion.idleInterval` 0), so the panel and the compositor redraw 144 times a second in every room whatever it shows. A cap (the idle clock at 72 Hz) was put to the user and **declined (10 November): their screen is 144 Hz and they see the difference from 120.** So the floor comes down by cheaper frames, not fewer: cached and lower-resolution layers as B did with the sundial, slower clocks only for things that needn't change every frame. Also off the floor now: the orphan's compositing.
- **On the screen ("poop", 10 November, late evening, `6d82e18` = main `850a995` plus notes):** 144 Hz screen, the orphan gone, nothing else running. **On battery** (AC `online` 0), so the battery guard held the heavy layer off. Quiet samples throughout; raw output wasn't saved to `docs/measurements/`.

| Place | Frames | View CPU | AMD chip | RSS / PSS Silent → Overdrive → released (MiB) | Against `b6380c1` |
| --- | --- | --- | --- | --- | --- |
| Home (2 cycles) | 144.3–144.4 fps | 43.5–43.6 % | 56 % | 541.9 / 253.7 → 573.1–575.8 / 277.4–279.6 → 561.0–562.6 / 265.0–266.6 | AMD 69 → 56 %; CPU 36.8 → 43.6 % (battery clocks?); +19 RSS after release |
| Orbit (2 cycles) | **143.4–144.1 fps** | 127.5 % | 65–66 % | 581.1 / 286.5 → 592–593 / 291–293 → 580–587 / 279–286 | **49 → 144 fps** (the orphan was the cause); memory given back |
| Devices (first) | **145.0** | 30.3 % | — | 514.5 / 228.0 → 549.6 / 259.8 → 536.4 / 248.4 | **72 → 145 fps** |
| Tasks | 145.1 | 28.9 % | — | 551.9 / 256.8 → 562.9 / 265.0 → 549.3 / 253.5 | CPU 13.7 → 28.9 % |
| Performance | 145.1 | 45.8 % | — | 555.9 / 260.7 → 577.9 / 281.8 → 560.4 / 268.1 | CPU 52.7 → 45.8 % |
| Home (rooms run) | 145.1 | 43.4 % | — | 570.1 / 269.4 → 579.3 / 281.5 → 565.7 / 269.6 | inside ±10 |
| Devices (last) | 144.9 | 31.2 % | — | 493.8 / 207.5 → 532.3 / 242.8 → 519.4 / 232.0 | same as first |

- **`heavy_cost.py` doesn't count:** the lease read `suspended` in every Overdrive window (the battery guard), no heavy process ever started and the NVIDIA card stayed suspended. Flights then ran without the heavy layer: 68.2 % CPU and AMD 43.8 % (peak 56), not comparable with 150 %. The Overlay's memory: 495.6 Silent → 545.1 MiB released (+49.5, no heavy layer). **Rerun plugged in.**
- **Battery also skews the rest:** CPU on Home and Tasks is higher than on 10 November (plugged in), which fits lower battery clocks. Frame rates and the orbit's fix stand; CPU and AMD figures need a plugged-in rerun to compare like with like.

**The plugged-in rerun ("poop" again, `dedb464`, AC `online` 1).** These are the after rows. Raw: `docs/measurements/overdrive-dedb464.txt`, `heavy-dedb464.txt`, `rooms-dedb464.txt` (Devices first and last). Quiet samples except where marked.

| Place | Frames | View CPU | AMD chip | RSS / PSS Silent → Overdrive → released (MiB) | Against `b6380c1` |
| --- | --- | --- | --- | --- | --- |
| Home (2 cycles) | 144.6 fps | 22.0–22.1 % | 58 % | 521.2 / 233.8 → 554.2–557.2 / 258.5–259.0 → 541.2–545.8 / 245.1–247.8 | AMD 69 → 58 %, CPU 36.8 → 22 %; +20–25 RSS after release |
| Orbit (2 cycles) | **144.1 fps** | 121 % | 63 % | 559.0 / 264.3 → 575.4 / 274.5 → 563.6 / 262.7 (second release interrupted) | **49 → 144 fps**, CPU 90 → 121 % (three times the frames) |
| Devices (first / last) | **144.3 / 145.3** | 14.4 / 15.8 % | — | 493.2 / 206.9 → 534.7 / 245.0 → 522.7 / 234.9 | **72 → 144 fps** |
| Tasks | 144.4 | 12.9 % | — | 527.1 / 231.8 → 539.6 / 241.7 → 527.5 / 232.0 | same CPU, inside ±10 |
| Performance | 144.5 | 26.6 % | — | 526.5 / 231.3 → 547.9 / 251.8 → 536.0 / 243.7 (release interrupted) | CPU **52.7 → 26.6 %** |
| Home (rooms run) | 144.6 | 21.2 % | — | 540.7 / 244.2 → 556.4 / 258.2 → 545.8 / 247.2 | CPU 36.9 → 21.2 %, inside |

**The heavy layer, plugged in:**

| Scenario | NVIDIA load (peak) | NVIDIA power | AMD chip | View CPU / RSS | Heavy process CPU / RSS |
| --- | --- | --- | --- | --- | --- |
| Home, Silent | asleep | — | 19.0 % | 0.5 % / 498.8 | none |
| Home, Overdrive | 38.0 % (41) | 14.0 W | **69.5 %** | 22.1 % / 563.3 | 12.9 % / 334.0 |
| Media, Overdrive | 38.4 % (45) | 12.8 W | 69.6 % | 14.1 % / 588.7 | 12.0 % / 334.4 |
| Performance, Overdrive | 39.2 % (40) | 13.3 W | 69.6 % | 31.7 % / 603.1 | 13.9 % / 334.3 |
| Flights | 37.7 % (44) | 12.2 W | 68.8 % | **162 %** / 647.2 | 12.6 % / 334.8 |
| Released | — | — | 18.8 % | 0.3 % / **594.6** | gone |

- **Fixed:** the orbit (144 fps), Devices (full rate), Performance's CPU (halved), Home's CPU and its AMD share on its own (69 → 58 %).
- **Not fixed, still the targets:** **flights** 150 → 162 % of a core; **the Overlay keeps about 96 MiB after flights and a release** (498.8 → 594.6, as before); **the AMD chip with the heavy layer on** went *up*, 47–49 → 69.5 % (the heavy layer's frames are now composited at the full rate, where the orphan used to pin it lower), and the heavy process 8 → 13 % CPU, 10 → 13 W. The NVIDIA card is asleep at Silent and after release, so the "dGPU never woken" budget holds outside Overdrive.

## 10. The journey and the orbit's laws (`0baa09e`)

**The journey** (`core/journey.py`, topic `journey`, `CoreClient.journeyData`) is the shared history: which rooms were visited, in what order and for how long. Only room ids, counts and times are stored (`journey.json`), never what was in a room. Links and time fade by 8 % a day. The lease manager's "Forget my room history" wipes it (`journey.forget`).

**The laws** (`view/overdrive/OrbitLaws.qml`, Stratum `panel:laws`). Each is caused by a real habit, scales with the engine, and is gone at release. Silent is unchanged.
- **Lagrange shelves (#1):** two rooms you bounce between (weight 3 or more) grow a plate at the balance point between their orbits, tied to both tiles and saying how often. At most three. Each pushes the fabric up, and a new one is pinned with `foley.pin`.
- **Dark matter routes (#8):** any habit bends the two rooms' stalks and tiles towards each other. At weight 8 a hairline appears, foot to foot.
- **Proper motion (#3):** a room used more than last week moves ahead on its orbit, one used less falls behind (up to 0.35 rad). A ghost tick marks its old place.
- **Resonance locks (#2):** three rooms visited in a loop at least three times in the last hour line up for about 3 s, with `foley.relay`.
- **Tidal locking (Claude A's idea):** the room you've spent the most time in (at least 10 minutes) stops drifting and is marked `TIDALLY LOCKED`.
- **The barycentre (Claude A's idea):** Home is pulled a little towards where your time goes.
- **Transits (#6):** a tile crossing another's stalk swaps its name for the crossing's readout (`03 × 05  T+1:23`) for 300 ms. No flash.
- **Redshift (#4):** a keyboard focus move tints the numerals of the tiles it nears cool, and the ones it leaves warm, for about 0.6 s.
- **The folded ephemeris (#7):** hold **E** on a room to unfold its day, 24 hours as an accordion, the current hour in the signal colour.

## 11. Rooms as a language (`0baa09e`)

- **Chords (#60, `ChordPlane.qml`):** in the orbit, hold **C** and tap two room numbers. The pair opens a working plane that belongs to neither room: Media + Devices routes the sound, Tasks + Timers starts work on the next task, Devices + Performance sets the power profile against the load, Workspaces + Performance shows the desks beside the CPU. Buttons act only when clicked. A pair with no grammar says so. Esc closes it.
- **The ruler (#61, `RulerGesture.qml`):** the footer rule has a station per room. A quick stroke (at least 60 px in under half a second) goes to the station where it ends, and stays for 400 ms as a drafting mark with its angle and straightness. A slow drag does nothing.
- **The ballistic command line (#59, `BallisticHints.qml`):** the candidates fly out from the caret along −12°, each on its own plate. Type fast and the ray stretches; hesitate and it falls short.

## 12. The room switch: lensing and the cut (`0baa09e`)

- **Lensing (M13, `view/strata/LensPass.qml`, `shaders/lens.frag`):** for the first part of a switch, the room you leave is seen through a point mass standing at the room you chose. This is the lens equation itself: an Einstein ring with a second, inverted image inside it, the colours splitting at the ring. It captures nothing between switches.
- **The aberration (#39, `FlightCuts.qml`):** on a long jump (hop over 0.8) the destination's name appears as two images along 78° that converge as the camera dives. Not yet seen firing.
- **The causal cut (#38, `FlightCuts.qml`):** the last stretch of the dive is covered by two sheared panes that part from where the switch was asked for, the far side first, with `foley.splice`.

## 13. Sound: chords and foley (`0baa09e`)

All synthesized by `tools/sounds/make_foley.py`. **The user has heard them (9 November): "ON POINT".**
- **Room chords (#46) with a place (#49):** each of the nine rooms has its own two- or three-note interval, panned left, centre or right from where its tile stands, played once on arrival while Overdrive drives.
- **Foley (#47):** one short dry sound per kind of physical event: `pin`, `relay`, `ruler`, `splice`, and `paper` when the ephemeris unfolds (E held on the orbit).
- **Quiet telemetry (#48, `core/quiet.py`):** while Overdrive is in effect and the panel is open, counters are read every 2 s and compared with their own last two minutes (median and median absolute deviation). Only a sharp departure sounds, once on the way up: `quiet.thrash` (brushed noise: major faults and swapping), `quiet.burst` (a narrow click train: network totals, loopback excluded), `quiet.device` (a low double pulse: a USB device came or went). Each kind at most every 30 s, any two at least 8 s apart. Totals only, nothing on disk. The lease manager names the last one heard, so a faint sound can be looked up. The three sounds have not been heard yet.

## 14. The desktop tier (`2b397cf`, atlas #52–54; T3 built ahead of M16)

`view/overdrive/DesktopField.qml`, mounted by `Overlay.qml`: a surface on the `bottom` layer (namespace `fart-desktop`), over the wallpaper and under every window, with an empty input region so every click goes through. It never shows in fullscreen.
- **The stress field (#52, `StressField.qml`, `shaders/stress.frag`):** while the panel is open in Overdrive, fringes of equal stress spread across the wallpaper from the panel's corners, leaning to the house angle and turning with each room. Nothing animates at rest.
- **The meridian (#53):** one pixel wide, the height of the screen, through the current room's title edge. It moves only on a room switch.
- **The residue (#54):** when the panel closes while Overdrive goes on, the room's number, its name and the time stay on the wallpaper for 15 s, then the whole surface is gone.

## 15. The telemetry orrery (M12, Claude B)

Performance in Overdrive: the machine's processes orbit the halo's centre as bodies, on rings that lean at the house's 78° and cross the halo like an armillary (`view/rooms/OrreryField.qml`, the Stratum `performance.orrery`, behind the halo, so the halo's plate dims the bodies passing behind it).
- **The sampler** (`core/orrery.py`): pulled, not pushed. The room asks `orrery.sample` once a second while the stratum exists. The core reads `/proc/stat` (the fork counter), `/proc/uptime`, and each process's `stat` and `statm`: the command name (15 characters), CPU time, start time, flags and resident pages. **Never `cmdline`, `environ`, file descriptors or window titles,** and nothing goes to disk. It reads nothing unless the lease is active, and forgets everything when the view closes or after a 5 s gap. About 14 ms per sample on this machine (~220 processes).
  - A process's identity is its pid and start time, so a reused pid is a new process. Kernel threads are skipped.
  - The shown set has hysteresis: the 16 heaviest enter (1 % of a core weighs as 40 MiB), and a shown body stays while it ranks in the top 24.
- **The laws** (`view/rooms/Orrery.js`, pure, tested under Node):
  - **mass is memory:** a body's size is the cube root of its resident memory (so 4 GiB is about 7× 12 MiB, not 340×);
  - **speed is CPU:** a turn every 8 s at one whole core. An idle process stands still;
  - **depth is memory's history:** heavier sits deeper (64 MiB at the top, 4 GiB on the Roche limit), and growth (smoothed over 15 s) pulls a body below its place, so a leak spirals in. A body that sinks past the Roche limit is **torn into debris** along its orbit, in the danger colour, and named `ROCHE · name`;
  - **a born process** (started within 2 s) falls in from outside the outer ring and is captured: it swings past its ring once and settles. One that only grew into the shown set fades in where it belongs;
  - **an ended process** leaves its ring behind, fading over 8 s, with `ENDED · name` where it was last;
  - **forks:** each process the kernel created since the last sample is a meteor falling into the sun, up to 8 a second (beyond that, each stands for more);
  - **the busiest body** (5 % of a core or more) trails a comet tail pointing away from the sun, as long as it is busy.
- **What's printed:** the laws as the plate's caption, and the real counts (processes, shown, forks a second, resident total). The seven bodies that weigh most, with the comet and any torn body first, are named in a callout list in the instrument's lower-left corner, with hairline leaders to their bodies, so names never sit on the halo's figures.
- **The clock** is an idle loop (`idle.performance.orrery`), so the spin-down slows every body to rest. The stratum's requests stop when it's destroyed.
- **Tests:** `test_core_orrery` (CPU share, growth, ranking and hysteresis, exits once, reused pids, births, forks, gaps, the lease, the view closing, names only), `test_orrery_laws` (the laws, slots, captures, spirals, rings, meteors, the comet), ViewTest `performance.orrery` (nothing in Silent; a busy body turns and an idle one doesn't; a born one falls in; an ended one leaves its ring; release and reduced motion leave nothing).
- **Not yet:** GPU frames (the `--window` shot found its window not visible), the on/off cost (job 4's measurements), and seeing it on the live desktop.

## 16. The surveyor wanders the rooms (Claude B; atlas #55–57, W3)

In Overdrive, Mote (FCreature) leaves the footer and surveys the room you are in (`view/overdrive/Wanderer.qml`, the Stratum `surveyor`; the geometry and the book are `view/rooms/Survey.js`, pure).
- **Its ground:** the top edges of the room's planes, rules, hairlines, filled cards and controls (standing on a control's top edge covers none of it), plus the bottom of the room's window as a floor it climbs off when a ledge is within reach. Every edge is cut wherever its body (40 × 24 px) would cover a control or a piece of text, measured as the text's ink, not its row. So it never stands over anything you can read or click, and its only hit area is its own body. The ground is read again every 1.5 s (never per frame) and drawn through one affine map per frame, so it scrolls and flies with the room.
- **It walks and hops:** at a ledge's end it hops to another within reach (220 px across, 150 up, 240 down), on an arc that clears the higher end, leaning into the hop; otherwise it turns back. A room switch carries it over to the nearest real ledge of the new room.
- **It measures:** every few seconds it stops, sights the nearest control it hasn't measured in the last 90 s (within 320 px) along a dotted line, and drafts it as on a drawing: extension and dimension lines outside the control on the sides facing it, 78° ticks at their ends, drawn out over a third of a second. The figure (`1.27 × 0.28 M  TAB`) goes on the width line, at either end of it, past the height line, or over its head, whichever covers nothing. A metre is 100 px. Kinds come from the control's type (BUTTON, TAB, SWITCH, SELECTOR, FIELD, ROW, LINK, DESK, SEEK, SLIDER…); anything else is a SPOT, the name it gives everything (the fifth field note).
- **Stations:** each survey plants a triangulation mark with its number (`S 14`) where it stood, fading over 45 s.
- **The field book** (`ViewState.fieldBook`, saved with the preferences at most every 20 s): today's stations and readings, the total, and each room's north wall (its width) on arrival and now, so going fullscreen shows up as a discrepancy. Room ids, kinds, sizes and dates only: never a label, title or anything typed. The field archive prints it under its notes ("FIELD BOOK / KEPT BY THE SURVEYOR").
- **Survey errors (#55):** past 24 stations, about one station in 53 on a seeded schedule (at most one a day) measures a doorway that is not there: a dashed red outline in empty space, "1.00 × 1.00 DOORWAY", a red station mark `S n ?`, and in the book a coordinate where there is no room. Every error lies one doorway from the same hidden point (`Survey.locus(seed)`), spread by the golden angle, so over weeks they outline it: the False Room's place for W1's orbit side.
- **Calibration disagreement (#56):** about one station in 211, it corrects its scale by a pixel for the rest of the day ("SCALE CORRECTED · 1 M = 101 PX" in the book), so its readings quietly disagree with the morning's.
- **Its own unit (W3):** after 120 stations, it reads in survey lengths: one is the median width of everything it has measured. The book says so.
- **Creature parallax (#57):** with no room to walk (the orbit open, or no room passed) it walks the footer rule, and once the journey has 30 visits it is found at, and keeps returning to, the place the footer's ruler gives the room you've spent least time in.
- **Poked:** it startles, says one of its wandering lines (`SurveyorNotes.STRAY`; a poke mid-reading loses the reading) and hurries off the other way.
- **Rules:** its pace and every mark follow `Motion.drive`, so a release winds it to a stop as the stratum goes; reduced motion never creates it. It is an idle loop (`idle.surveyor`).
- **The mount (Shell, A's):** today `Wanderer {}` (the footer only). With `room: root.shownSlot.item`, `viewport: pageViewport`, `roomId: root.shownPageId`, `journey: root.core.journeyData` and `rooms: root.navigationPages.map(p => p.id)` it walks the rooms.
- **Tests:** `test_survey` (21, Node: ground, hops, drafting, the figure's place, kinds, the book and its privacy, errors, the scale, the unit, parallax) and `SurveyorTest` through `test_surveyor` (the real Shell: ground in all nine rooms with none under a control or text, 6 s of walking sampled every 16 ms, a hop, a measurement and the book, a survey error, the footer, release and reduced motion).
- **Not yet:** the on/off cost, and seeing it live (it needs the mount above).

## 17. The archive on a worn tape (Claude B; job 5)

In Overdrive, the field archive plays back from a worn VHS cassette (`view/strata/Tape.qml`, `shaders/tape.frag`, the Stratum `tape` the Shell lays over the dialog; A's mount is unchanged).
- **The deck (A's base, kept):** a tracking band rolls down twice per 7 s, tearing and washing the lines it crosses; the bottom rows jitter where the heads switch; the colour channels bleed; scanlines and a slow wobble; every other roll a harder tracking glitch. New: the top flags (bends sideways) as a real deck's does.
- **The law: the tape wears where it is played.** Every second a note is at least half in view while the archive is open with its fiction on, a second of tape runs over it (`ViewState.playTape`, by the note's label; saved at most every 20 s). Its wear is 1 − e^(−seconds / 300): 63 % after five minutes of reading. `FArchive.spans` gives the notes in view, clipped to the window, with their wear; the tape paints them into a one-pixel strip (red: wear; blue: a crease) that the shader samples by height, so the wear scrolls with the notes. A worn passage:
  - slips further on every jitter (up to 3.5×) and bleeds wider (up to 3×);
  - **sheds oxide:** white dropout streaks flicker on its lines, about 3 % of lines a frame at full wear;
  - **fades:** colour drains and blacks lift;
  - past half wear, carries a **crease**: a 5 px band at a place fixed by its label that slips sideways for good.
  The first notes, read most, wear first; a note never scrolled to stays clean. Silent shows none of it, and the counting itself only happens with the fiction on.
- **The deck's display**, in the top margin clear of the archive's controls: `▶ PLAY`, `SP`, `TRACKING` (amber) during a glitch, and the counter: every second the archive has ever played (`ViewState.tapeSeconds`), never rewound.
- **The promise holds:** text only, no sound, no scare, no fake fault of the system; the archive scrolls and clicks as before (the effect only draws).
- **Tests:** `ArchiveTest` through `test_surveyor` (the spans, a second played over exactly the notes half in view, the wear curve and creases, the field book printed, nothing counted with the fiction off). The shader: `tools/overdrive/archive_frames.py OUT` renders it on the GPU with the engine lit directly (the core's dGPU guard holds real Overdrive back while the NVIDIA card is awake), with seeded wear and a seeded field book.
- **Not yet:** the on/off cost.

## 18. The machine's weather (Claude B; atlas #75)

One short weather report for the time since you last looked, in Silent and Overdrive alike (it's static text).
- **The core** (`core/weather.py`): when the view opens, if ten minutes or more have passed since the last reading, it reads the kernel's running counters once and compares them with the reading it kept. No sampler, no timer, no wake-up: the kernel keeps counting in between. Counters only (`/proc/stat`, `/proc/vmstat`, `/proc/net/dev`, thermal zones, the battery); never a process, a name or an address. `weather.json` keeps the last reading and the last 60 reports; a reboot starts over without a report. Rates count only the time the machine was awake (the CPU counters stop in suspend).
- **The rules** (deterministic, never a diagnosis): pressure from how busy all the cores were (under 3 %: "high pressure, settled"; 10, 25, 50: "fair, steady", "falling", "low pressure, unsettled"; above: "a deep low"), and 1040 − 0.8 × busy as hPa for the barograph; wind from context switches a second (4k, 12k, 30k, 70k: "calm" to "a gale"); precipitation from major faults a second ("dry" to "heavy rain"; any swapping is "a downpour"). The second line: the hottest thermal zone ("cool" to "hot", "and warming/cooling" past 5 °C since the last report), the network ("still water" to "a flood") and the battery ("a rising tide" charging, "slack water", "an ebbing tide", "the tide going out fast" past 15 % an hour).
- **Where:** Performance's header, in place of "NO SYNTHETIC READINGS" once there's a report: a 64 px barograph of the last 24 reports' pressure and the sentence with its hPa; hovering shows the span ("SINCE 09:45 · 2 H 15 MIN") and the second line. The room asks `weather.now` once each time it's shown.
- **Tests:** `test_core_weather` (the counters, ten minutes, the categories, awake-time rates, a reboot, persistence and the cap, junk on disk, the core observing once per opening and the op, and `WeatherTest`: the header, the barograph, the detail).
- **Not yet:** Overdrive's part (the barograph's drum turning, the pen drawing the newest report), and an archive of reports.

## 19. The cache palimpsest (Claude B; atlas #71)

In Overdrive, Performance's figures remember what they said (`view/ui/Palimpsest.qml`, put inside a Text: the halo's centre figure and the data plate's figures). When a figure changes, the old value stays under the new one as a faint impression (at most 40 %, in the faint ink), a pixel or so out of register, alternating sides, so a busy reading builds up layers like a page written over. They fade by a half-life set by how full memory is (`Performance.memoryPressure`, used ÷ total from the `resources` lease): 1 s below 30 % used, rising to a minute when memory is full. On a roomy machine the page is clean in about three seconds; on a full one the old figures linger, stacked. At most six impressions per figure; each is dropped below 5 %.
- **Rules:** in Silent and under reduced motion it keeps and draws nothing; the impressions scale with `Motion.drive` and a release wipes the page. Its clock (`idle.palimpsest`) runs only while impressions remain.
- **Tests:** `PerformanceTest` (`palimpsest.kept`, `.clears`, `.release`), through `test_core_weather`.
- **Not yet:** the on/off cost; other rooms' figures (Devices' meters, Timers' readout).

## 20. Spectral architecture and silence geometry (Claude B; atlas #67, #70)

In Overdrive, while something plays, Media stands on columns the music composes (`view/rooms/SpectralArchitecture.qml`, the Stratum `media.architecture`, behind the room's content and taking no input; the rules in `view/rooms/Architecture.js`, pure).
- **Sections, not beats:** the spectrum is folded into bass (the bottom sixth of the bins), middle (the next third) and treble (the top half). A slow (8 s) and a fast (1.5 s) average of the three shares and the loudness are kept; a section begins when they part far enough, never sooner than 6 s after the last (the first after 1.5 s of sound). Silence keeps the section.
- **The composition:** the number of columns grows with the treble (one to eleven), and one column, chosen per section, takes a weight that grows with the square of the bass: a bass-heavy section stands as one massive column, a dense bright passage fractures into narrow cuts. Each column is a Plane with one 78° edge; one is ink, a few are signal, the rest paper, all faint (paper 30 %, signal 7 %, ink 5–12 % with the bass) so the text over them keeps its contrast. Deterministic per section.
- **The re-cut:** at a section boundary the planes slide from the old layout to the new over 0.6 s (cubic ease, at the engine's speed); new columns grow from the right edge. Between sections nothing moves but the ink column's tone. Its clock (`media.architecture`) runs only during a re-cut.
- **Silence geometry (atlas #70):** near-silence (the three bands summed under 0.03) held for 1.2 s snaps the room into exact registration: twelve equal columns on the grid, square-edged, all paper, "SILENCE · IN REGISTER". Any sound restarts the quiet's count; once registered, 0.25 s of sound lets the room go back to the section's composition. The quietest moment is the most ordered one.
- **The figures:** "SECTION 02 · BASS 11 · TREBLE 61 · 7 CUTS", small and faint, at the head of the widest column under the room's file line.
- **Rules:** never in Silent or under reduced motion; a release destroys it. It reads the spectrum Media already leases in Overdrive.
- **Tests:** `test_architecture` (bands, the warm-up, a section per change of character and never inside the gap, silence, the composition's extremes and determinism, the morph) and `MediaTest` (the real room: none in Silent, one massive column for bass, the cut to narrow columns, inert and behind, release).
- **Not yet:** the on/off cost while playing; seeing it with real music.

## 21. Home's day ruler (Claude B; atlas #65, #63, #66, W4)

Under Home's clock, in place of the plain rule (`view/rooms/DayRuler.qml`; the rules in `view/rooms/DayTime.js`, pure).
- **Day-length compression (#65), Silent and Overdrive:** the ruler labels civil hours (a tick each, longer and labelled every six), but daylight, from today's real sunrise to sunset (the core's `sky.now`, which Home already asks once a minute), always takes 60 % of its width, drawn as a heavier band, and the night the rest, split between morning and evening. So a winter's few daylight hours are wide and a summer's many packed close: the season changes the ruler's segmentation, never its labels. Without a sun (no sky yet, a polar day or night) it is linear. Now is a short accent mark; it moves once a minute. Nothing animates.
- **The sidereal margin (#63), Overdrive:** a second row of ticks above the line at each sidereal hour, the zero hour full, with "SIDEREAL hh:mm" at the end. Sidereal hours are 4 minutes short, so the row drifts against the civil one day by day, with one seam where the day folds.
- **The time-lapse's cursor, Overdrive:** a small open diamond on the ruler follows HomeSky's 24 s day.
- **Misregistration (W4):** on about one opening in nine (every opening in Overdrive), the moment is also marked in two other frames: solar time (the sun's own noon, the midpoint of sunrise and sunset) and local sidereal time. All correct, all apart. Hovering a mark only names its frame.
- **Recurrence windows (#66), Silent and Overdrive:** over each hour when a room keeps being opened, a small hollow window straddles the line; hovering it names the room and the hour. From the journey (A's `journey` topic): a room visited at least 6 times, at hours where its visits reach 75 % of its busiest hour; at most six windows, the strongest. It predicts and nags about nothing.
- **Tests:** `test_day_ruler` (the 60 % share whatever the day's length, wide winter hours and packed summer ones, monotonic and linear without a sun, the civil ticks, the sidereal ticks a sidereal hour apart with one seam, the three frames) and `HomeTest` (the real room: Silent, Overdrive, a misregistered opening, back to Silent).

## 22. Tasks: neglect patina and completion negative space (Claude B; atlas #25, #26)

Both in Silent and Overdrive alike: static, changed only when the room is opened or a task changes.
- **Neglect patina (#25)** (`TaskRow`, the rule `TaskEntry.patina`): a line left undone looks recopied, not alarmed. From its first day late a ghost of its text slips out of register (0.5 px at first, 2.2 px at most, by the square root of the days; the side fixed by the task's id) in the danger ink at 30 %; from the third day its rule is doubled, copied a little off; from the tenth a second ghost slips the other way in the accent. An undated open task starts to weather after two weeks, at half the rate. Done tasks are clean. The overdue colour (signal) is unchanged; the degradation is the new part.
- **Completion negative space (#26)** (`Tasks.shown`, `TaskRow.vanished`, the rule `TaskEntry.vanishedToday`): in the open list, a task finished today keeps its exact place as an empty cut-out, a dashed slab with 78° sides and "DONE 09:42", until midnight. It takes no input, and the line numbers count only the tasks still there.
- **Tests:** `test_task_entry` (patina by lateness and age, the shift, the side; finished today or not) and `TasksTest` through it (the copies, the doubled rule, the cut-out inert and labelled).

## 23. Inbox's attention band (Claude B; atlas #33, #34, #35)

In place of the rule above Inbox's footer (`view/rooms/AttentionBand.qml`; the rules in `view/rooms/Attention.js`, pure). Attention as structure, from sources, counts and times only: no summary or body is ever read. Static in both modes: it changes when a notification arrives or is read, and its clock moves once a minute.
- **Source eclipse (#33):** each source with unread items is a sheared slab across a hairline attention axis, 14 + 16 px per unread item (at most a third of the band), the longest-ignored source first, each overlapping the one before by 40 %, compressed to fit. Hovering a slab names its source and count.
- **Arrival cadence (#34):** the last 24 hours as a score under it, "24 H" to "NOW": a tick per arrival, taller when critical, in the accent while unread, faint once read.
- **Silence debt (#35):** every unread item weighs by how long it's been left, a whole one after a day; the debt hangs from the band's right edge as a 78° overhang, 6 + 22 × √debt px (120 at most), with "DEBT n". Reading cuts it away; when it drops by half or more while the room is open, `foley.paper` plays (A's sheet-shear, through the core's sound gate).
- **Tests:** `test_attention` (the score, the sources' order, the slabs' overlap and fit, the debt and its overhang; message text never used) and `InboxTest` through it (the real room: slabs, ticks and overhang; all read clears them).

## 24. Registration voices (Claude B; atlas #45)

Where a figure comes from is set a pixel off the line, in Silent and Overdrive alike, unnoticed until noticed (`FText.voice`, in the translation of its existing matrix): "kernel", the machine's own counters, sits 1 px low (Performance's halo figure, its data plate, the weather); "media", the player's, 1 px high (Media's position, length and percentage); the user's own data and everything else stays on the line. Every other text keeps a zero offset, so nothing else moved.
- **Tests:** `PerformanceTest` (`voice.kernel`) and `MediaTest` (`voice.media`).

## 25. Phantom ports (Claude B; atlas #23)

In Devices' paired list, in Silent and Overdrive alike (`view/rooms/Ports.js`, pure; `LinkRow.lost`/`gone`). Every time the room opens, and on every change while it's open, it notes which Bluetooth devices are linked (`ViewState.deviceSightings`, in memory for the view's session only, never saved). A device that was linked when last seen and isn't now is a phantom until it links again or the session ends:
- still listed but disconnected: its row says "LEFT hh:mm", and a click links it again as before;
- gone from the list: an empty socket, a dashed outline where its row was, with its name and "GONE hh:mm", and no click.
A device never seen linked leaves nothing. It shows absence without pretending the device is still there.
- **Tests:** `test_ports` (left, still left on a second look, linked again; gone; left then gone keeps its time) and `DevicesTest` through it (the real room: left, gone and inert, back).

## 26. The contact sheet (M14, Claude A)

`view/overdrive/ContactSheet.qml`, opened with W on the orbit or Ctrl+W anywhere in the panel. Every desk in use, the current one and the first free one are frames on one sheet of film, leaning on the 78° family, each window at the compositor's real geometry.

- **In Silent:** outlines only, nothing captured, nothing moves.
- **In Overdrive:** each window is captured once as the sheet opens (`ScreencopyView`, `live: false`, through the adapter's `thumbnailSource`) and develops from a warm grainy negative (`view/strata/Develop.qml`, `shaders/develop.frag`). Never written anywhere. A release destroys the captures and the sheet falls back to outlines.
- **Acting:** a click on a window goes to it, a click on a frame goes to that desk (both close the panel). Dragging a window to another frame moves it there without following (`moveWindow`, Hyprland 0.57's Lua dispatcher). Arrows or hjkl walk the frames, a digit jumps, Enter goes, Esc or W closes.
- **Checked on the real desktop, read-only:** a capture of each of five windows on five desks had content at full size. The Lua move with a window that doesn't exist reported ok and moved nothing, so its `window` selector is honoured.
- **Live previews (9 November):** in Overdrive a rolling shutter re-exposes one window every 66 ms, and the focused window runs at full rate. **Not seen with real windows yet:** there are none on the hidden desktop, and the user was at the machine.
- **Not checked:** an actual drag on a real window (nothing of the user's was moved to test it). Cost not measured. Each capture is full window size (about 1908x1024 here); Quickshell 0.3.2's `ScreencopyView` has no size limit, so memory while the sheet is open is an optimisation item.

## 27. MIME taxonomy (Claude B; atlas #31)

In Clips, in Silent and Overdrive alike: each clip's kind is read from the preview line the room already shows, in memory only (`view/rooms/ClipKinds.js`: IMAGE, LINK, PATH, COLOUR, NUMBER, CODE, TEXT), and set under its reference number with the kind's own editorial mark (`view/rooms/KindMark.qml`): text underlined, a link a forked stalk, an image a boxed corner, a path a stair, code a pair of brackets, a number a tally struck at the house angle, a colour its swatch. Static. Nothing new is read from the clipboard and nothing is stored.
- **Tests:** `test_clip_kinds` (the kinds, the swatch) and `ClipsTest` through it (the real room, every mark).

## 28. The machine's geology: thermal strata and the battery ledger (Claude B; atlas #16, #22)

Both from the weather's reports (§18; `weather.now` now also sends each recent report's span, hottest zone and battery), in Silent and Overdrive alike, static, asked once each time the room is shown. The rules are `view/rooms/Geology.js` (pure).
- **Thermal strata (#16)** (`ThermalStrata`, in Performance's corner above the sample line): one layer of sediment per report, the oldest at the bottom; a layer's thickness is its span (square-rooted, so a night doesn't bury the day), pressed thinner the hotter it was; its tone pale when cool, dense and warm toward the danger ink when hot. Hovering a layer gives its temperature. Heat as a geological record rather than a live effect (it complements A's heat haze, which is the live one).
- **The battery ledger (#22)** (`BatteryLedger`, on Devices' power row in place of its hairline): each report an entry along the line, as wide as its span (square-rooted), hanging below the line by the share of the battery it spent (40 % fills it) or standing above it, in the accent, when it charged. Until there are reports it is the plain hairline it replaced.
- **Tests:** `test_geology` (the layers' order, compaction and tone; the ledger's depths, credits and widths) and the real rooms: `PerformanceTest` (`strata.layers`), `DevicesTest` (`ledger.entries`); `test_core_weather` checks the op's new fields.

## 29. Groove geometry (Claude B; atlas #12)

In Overdrive, while something plays, Media's seek bar carries the track's own groove, cut as you listen (`view/rooms/GrooveLine.qml`, the Stratum `media.groove` over the seek bar; the rules in `view/rooms/Groove.js`, pure).
- **The cut:** the track is 160 cells; each spectrum frame cuts the cell under the playhead as deep as the music is loud there (the three bands summed), and the loudest heard stays. A cell heard only while paused, or never played, is a dead groove: straight.
- **The line:** over the played part, an engraved line in the background's ink, cut into the light blades: it wiggles (a half-wave every 3 px, kept 6 px inside the blades) by each cell's depth, and runs straight through dead cells. The unplayed part is untouched.
- **Kept per track for the session** (`ViewState.grooves`, the last 20 tracks by artist, title and length; never saved), so a track played again in Overdrive shows the record it already cut.
- **Rules:** never in Silent or under reduced motion; a release destroys the line (the session's grooves stay in memory). It takes no input: dragging still seeks.
- **Tests:** `test_groove` (only played cells cut, the loudest stays, paused and out-of-range cut nothing; the wiggle by energy and the straight dead groove; the key) and `MediaTest` (`groove.cut`: one frame at 50 s of 200 cuts cell 40 and only it).

## 30. Revision history, and the one impossible revision (Claude B; atlas #58)

In the field archive (the fiction on), in Silent and Overdrive alike. Each note is filed the first day it is seen in view (`ViewState.noteFiled`, saved: labels and dates only), and its header gains a faint metadata line: "FILED 2026-11-09 · REV 3", a revision for every two minutes it has been read (the tape's seconds, §17). Once the survey has gone on 21 days (the days the archive was opened), one note, fixed by the survey's seed, carries a second revision dated before it was filed: "… · REV 4 2026-10-27". Nothing remarks on it. Text only, as the archive promises.
- **Tests:** `test_revisions` (the line, the count, exactly one impossible note after 21 days and none before) and `ArchiveTest` (`archive.revision`: seen notes filed today, the line shown).

## 31. Interrupt rainfall and the network letterpress (Claude B; atlas #17, #73)

Both in Overdrive only, both fed by one small sampler in the core (`core/telemetry.py`, the op `telemetry.sample`): pulled once a second by the room's stratum, read only while Overdrive is in effect, forgotten when the view closes or after a 5 s gap, never saved. Counters only: `/proc/interrupts` folded into classes by the driver's name (timer, ipi, gpu, net, disk, input, usb, other) and `/proc/net/dev` (bytes in and out, loopback left out). A spike is a class at three times its own recent average and at least 50 a second.
- **Interrupt rainfall (#17)** (`view/rooms/InterruptRain.qml`, the Stratum `performance.rain` along the halo's foot): each second, a few ticks fall 14 px onto one baseline and fade where they strike, as many as the logarithm of the interrupt rate (up to 14), drawn from the classes by weight and coloured by class (the GPU in the accent, the network in the ink, the disk warm, timers and processor calls faint). A spike leaves an impact crater, a dent in the line that fills back over eight seconds. "IRQ n/S" (and any spiking class) in the corner, in the kernel's voice. Its clock (`idle.performance.rain`) runs only while drops or craters remain.
- **The network letterpress (#73)** (`view/rooms/Letterpress.qml`, the Stratum `devices.letterpress`; `LinkPlane.press`): the Wi-Fi plane's name is pressed by the traffic: bytes coming in deboss it (a dark edge above-left, a light one below-right), bytes going out emboss it (the reverse), as deep as the logarithm of the bytes a second (1 MB/s and up is the full 1.6 px). After a burst the impression holds for three seconds and then resets at once, with no fade. In Silent `press` is 0 and the plane is as it was.
- **Tests:** `test_core_telemetry` (the classes, the reading, rates, spikes and their floor, nothing outside Overdrive, gaps, the op and forgetting on close), and the rooms: `PerformanceTest` (`rain.drops`), `DevicesTest` (`press.deboss`).

## 32. The Codex, the tenth room (Claude A; the user, 9 November)

`view/rooms/Codex.qml`, room 09, id `codex`, on the orbit's outermost ring with a planet, a face (the element of the day), three moons, its own chord (`chord.9.*`) and a place in the journey, The Exhibit and `go`/`keys`/`elements`. Two sheets:

- **Keys** (`CodexKeys.qml`): the keybinds Hyprland describes (`hyprctl binds -j`, read-only, adapter domain `keybinds`), drawn as the keyboard, leaning on the house angle. Click a modifier to latch it, or hold the real one while the panel has the keyboard: the board and the list show what that combination does. With none chosen, the list is the whole sheet. In Overdrive a changing modifier sends a wave across the board.
- **Elements** (`CodexElements.qml`, data in `view/ui/Elements.js`): the 118 elements, one Canvas plus a text per symbol. The chosen element stands in the table's gap, its symbol cropped huge, with its atom drawn to the real shell counts. In Overdrive the table sweeps in by atomic number and the electrons circle.

## 33. The heavy layer: Overdrive on the NVIDIA card (Claude A; the user, 9 November)

`shell-heavy.qml`, a second `qs` process on the NVIDIA card (PRIME offload), kept alive by `view/shell/HeavyLayer.qml` while Overdrive runs and the panel is open. It only draws (empty input region, no keyboard), and it exits when its one socket to the panel closes, so a release leaves nothing and the card can sleep. Silent never starts it.

- **Stacking:** the heavy surface takes the Top layer and the panel moves to Overlay while it's up, so it sits under the panel. It starts drawing after a 2.5 s cold start; the panel only turns see-through once the card has drawn its first frames, so nothing ever flashes.
- **The first thing it draws: a Schwarzschild black hole** at the orbit's centre (`shaders/blackhole.frag`). Each ray is bent by the real null-geodesic equation, the disk lies in the orbit's own plane at its own tilt, and its near side is Doppler-brightened. The panel sends the camera and the theme (accent, text, background) over the socket, so the disk follows the theme live.
- **The dGPU guard is gone** (the user's call): Overdrive no longer pauses because the NVIDIA card is awake. The battery, fullscreen and session guards stay, so it stays off on battery. `DgpuGuard` is left in `core/guards.py`, unused.
- **Not measured yet:** the card's load and the frame rate with the hole running, and the hole's smoothness during flights.

## 34. The Medium: gas, smoke and dust under the panel (Claude A; the user's list, 9 November)

`view/strata/Medium.qml`, in the heavy process, under the panel in every room and under the hole on the orbit. Three float textures feed back on themselves, one solver step a frame:

- **Gas** (`shaders/medium_gas.frag`, half the panel's size): a compressible flow, with pressure from a density field, vorticity confinement, buoyancy from the smoke's heat, and the hole's pull and drag.
- **Smoke** (`shaders/medium_dye.frag`, panel size): two smokes and a heat channel, carried by the gas. The edge-restoring step is limited to what the neighbours hold; unlimited, it fed on its own noise and turned the sky to static.
- **Dust** (`shaders/medium_dust.frag`): one possible grain per pixel, so about 1.17 million slots at 1360x860, moved entirely in a fragment shader. Most slots are empty or very faint at any moment: **the number of visible grains hasn't been counted**, so don't call it "a million particles" as a measured figure.
- **Seen** (`shaders/medium.frag`): the smoke lit by its own relief, the heat through the theme's accent to its text colour, every colour from the theme.

**The rooms** (`view/strata/MediumLaws.js`, tests in `tests/test_medium_laws.py`), from levels and counts only: Home two slow lungs; Media a column per spectrum band, nothing in silence; Performance a furnace per few percent of load, one more for the GPU; Workspaces a whirl per desk in use; Devices a sweeping signal; Tasks open tasks as weight falling; Timers a jet going round like a hand; Clips two streams meeting; Inbox unread things falling; the Codex a candle. Going to a room strikes the gas from that room's side of the sky.

**The hole bends the Medium.** Each ray that escapes reads the Medium where it would have met the sky (`shaders/blackhole.frag`), so the smoke forms an Einstein ring around the shadow. The gas spirals in and is destroyed at the horizon.

**The panel in a room** keeps a backing of 0.62 so controls stay readable, and is fully clear on the orbit only.

**Checked:** frames looked at (the ring, plumes, the well). The real `Overlay` and the heavy process through all ten rooms, ignition, release and close: no script errors, the process gone after a release (`tools/heavy_check.py`, inside the hidden desktop). Full suite 507 OK, smoke OK, keytest 171 OK. About 60-140 fps on the AMD chip, the higher figure on the real desktop with the fixture emitters.

**On the NVIDIA card** (9 November, plugged in, the Medium and the hole on the bench at 1360x860, inside the hidden desktop, confirmed on the card by `nvidia-smi pmon`): 60 fps (the virtual desktop's own limit, so not the card's ceiling), about 40 % load, 10.6 W. **Indicative only:** the machine wasn't quiet (the user and Claude B were working), and no real panel was over it.

**Not checked:** how it looks live in each room against real controls (no frame of the real panel over the Medium has been looked at); whether 0.62 is the right backing. Overdrive is off on battery, so none of it can be seen live until the machine is plugged in.

**`tools/hidden_desktop.sh COMMAND...`** runs anything inside a private virtual KWin with its own config and D-Bus: windows and layer surfaces land there, shaders run, nothing reaches the user's screen. `hyprctl` from inside still sees the real session, so use it read-only. Use this for every frames tool and real-surface check.

## 35. The title under load (Claude B; atlas #41–44)

In Overdrive the room's big title is set again, glyph by glyph, over CutTitle's own name (which hands over as the engine rises and comes back as it falls): `view/shell/LiveTitle.qml`, the Stratum `title.type` in `RoomSheet.qml`, rules in `view/ui/TitleType.js`. One law in every room: **the room's content presses on its title.** The press is read from the room's own tree every 1.5 s (rects of its text ink and controls inside the viewport, and its scroll length; never the text), so it's the same in the Codex as in Tasks. The sheet finds the room's Flickable as its sibling in the Shell's stage, so the Shell needed no change.
- **Load-bearing glyphs (#41):** each glyph carries the content beside it: the share of its band of the sheet's height that the room's ink covers. A loaded glyph is set in a heavier real cut of Roboto Condensed (Light, Regular, Medium, Bold at 6, 16 and 32 % load) and pressed into the beam (up to 7 % shorter, 5 % wider), so a list in the lower half of Tasks makes the name's foot heavy and its head light. The most loaded glyph is the **bearing**, marked by an accent notch on the wedge's inner edge, which slides as the content moves.
- **Data kerning (#42):** the tracking is the room's **pressure**, read on entry and held until the room is entered again: +8 % of the size when the room is nearly empty, −4 % when it's full. Pressure is half how far the room overflows (three screens is full) and half how dense its ink is (42 % of the viewport is full).
- **Phase change (#44):** at pressure 0.72 the title stops being editorial and becomes an instrument: each glyph flips (a split-flap fold) into a mono cell on a tick scale, starting from the bearing and running outward 45 ms a glyph; the cells are set smaller, so more of the name fits the narrowing wedge; the pressure reading (`·81`) stands at the foot in the accent. It turns back only below 0.58. **History:** the session remembers each room's crossings (`TitleType.memory`, never saved), notched beside the reading.
- **Counter windows (#43):** the counters of the drawn glyphs (the O of HOME, the A, R, P, D of the others, and the mono cells' too) are found from the type itself: the glyphs are grabbed, and every transparent pixel the outside can't reach is a counter (`TitleType.counters`, specks under 12 px dropped). Through them you see what the room holds out of view: its content one fold below while there is more below, otherwise one fold above, kept level while the glyphs lean (`view/strata/TitleCounters.qml`, the GPU Stratum `title.counters`, `shaders/counters.frag`). A room that shows everything has blank windows.
- **Tests:** `test_title_type` (the rules in Node: band loads, weights, the bearing, pressure, tracking, hysteresis, the front, crossings, counters found in drawn shapes; and `tools/cuetest/TitleTest.qml` on the real RoomSheet: Silent untouched, the loaded foot and its bearing, tracking held until re-entry, the instrument and its crossings, hysteresis, the front, release, and the mask traced and kept through a resize).
- **Frames:** offscreen (software): the loaded editorial title and the instrument (`TITLE_SHOTS=dir`). On the GPU (`tools/overdrive/title_frames.py`, a real window): the counters stratum loads and finds its counters; the view through them was not looked at after the mask fix, because the user asked for no more windows on their desktop. **To check when allowed:** `title_frames.py DIR` with `TITLE_NAME=Home`.
- **Cost, partly measured:** the tree walk takes 0.25–0.9 ms a scan in the real rooms (Inbox 0.25, Tasks and Media 0.5, Performance 0.85, Home and the Codex 0.9; `tools/overdrive/room_frames.py` on the hidden desktop, 20 scans each), once every 1.5 s. Not measured: the per-glyph text, the counters' texture of the content and its grab on each change of shape.

## 36. Home folded by the day, and set as an edition (Claude B; atlas #9, #11)

Both in Overdrive only, decided when Home is opened and never moving after (`view/rooms/DayFold.js`, `DayFoldSheet.qml`, the Stratum `home.fold` laid over the whole of Home, and Home's Today strip).
- **Day Fold (#9):** each opening of Home in Overdrive presses a crease into the sheet where the day is, standing right over its hour on the day ruler (`DayTime.x`, so the season's day-length compression bends the folds too). The sheet keeps the day's creases for the session, up to 24; older ones relax (×0.82 each newer crease), and an opening within 1.2 % of an old crease presses that one again, deeper. Mountain and valley alternate, newest first: a shadow on the side folded away, a highlight on the side towards the light, a hairline. The newest crease splits off **the past** (folded under, shaded); the next solar event (sunrise, noon, sunset; after sunset tomorrow's sunrise) is **a fold not yet made** (dashed, "FOLD 18:15 · SUNSET"), and past it **the next plane** tilts to the light. Midnight brings a fresh sheet. So the day's openings stand on Home as a fold pattern: a busy afternoon is a crumpled stretch of paper.
- **Editions (#11):** Home is an edition of the day's paper. The TODAY rule becomes its masthead: EARLY EDITION before sunrise, MORNING until solar noon, AFTERNOON until sunset, EVENING until 22:00, then LATE FINAL, with its printing (every pressing of the sheet counts: "AFTERNOON EDITION · 3RD PRINTING"). The four Today cards are set as a front page: the edition's priorities (morning is readiness: the desk and timers first; afternoon the work; evening what's left: tasks, timers, the inbox) plus the rooms you've visited today (the journey's day), so the room you're living in moves to the front; the lead card is set wide (two fifths of the row). Silent's Home is unchanged.
- **Tests:** `test_day_fold` (creases pressed, merged and capped, a new day's fresh sheet, relaxing and alternating, the next solar event, editions from the sun, printings, the front page) and `tools/cuetest/HomeFoldTest.qml` in the real room (Silent untouched; the crease over its hour on the ruler, the edition and its printing, the wide lead; opened again in the same minute the crease is pressed again and the inbox, lived in all day, leads; release).
- **Frames:** offscreen (`HOME_SHOTS=dir`), looked at: the crease over 15:05 on the ruler, the shaded past, the dashed sunset fold, AFTERNOON EDITION · 1ST PRINTING with Tasks as the lead.
- **Not measured yet;** its cost is one Canvas drawn once per opening.

## 37. Scheduling fault lines and the context-switch weave (Claude B; atlas #15, #72)

Performance's record, under the trace, in Overdrive (`view/rooms/Plates.js`, `SchedPlates.qml`, the Stratum `performance.plates`), fed by a second reading of `core/telemetry.py`: `telemetry.sched` (registered in `core/app.py` beside `telemetry.sample`), pulled once a second while the stratum exists, read only under an active lease, forgotten with the rest. It reads `/proc/stat` (each core's busy share, the runnable and blocked counts, context switches a second) and every process's `voluntary_ctxt_switches` and `nonvoluntary_ctxt_switches` (`/proc/PID/status`: only those two counters, summed as deltas of the processes present in both readings, so a process starting or ending never counts; PIDs in memory only). About 10 ms a reading on 430 processes.
- **Fault lines (#15), under CPU only (§40):** each core is a plate of a power diagram (a weighted Voronoi, seeds on a jittered grid shaped like the record); a core's weight is how much busier it is than the mean (capped, so no plate is squeezed out), so a busy core's plate pushes its faults into its idle neighbours' and the faults migrate as the load moves (eased between samples). Only faults between plates are drawn, not the record's edge. **Stress:** when runnable processes outnumber the cores (stress = (runnable − 1) / cores), each fault slips: drawn twice, its sides thrown up to 6 px apart along the house angle, in the accent past half stress. **History:** the faults' positions every 4 s stay as up to five fading scarps. The busiest core's plate is labelled with its core and load ("CPU 3 · 99%"), and the scheduler's own figures sit in the corner in the kernel's voice ("RUNNABLE 14 · CSW 6000 / 5000 PREEMPTED").
- **The weave (#72):** voluntary switches (a process waiting) and involuntary ones (a process preempted) are two families of threads across the record, each as dense as the log of its rate (up to 28). The voluntary threads lean at the house angle (78°); the involuntary ones open away by 12° plus up to 66° as preemption's share grows (fully open at half), so a calm machine's weave is nearly one grain and a contended one a tight twill. Each family slides along by how many switches went by.
- **Tests:** `test_core_telemetry` (the files read, core shares and switch rates, processes starting and ending not counted, nothing outside Overdrive, the op), `test_plates` (seeds, the diagram tiling the record, a busy core's plate growing, none squeezed out, stress, scarps, the weave's angles and densities, threads clipped to the record), and `PerformanceTest` (`plates.faults`, `plates.release`).
- **Frames:** offscreen (`PERF_SHOTS=dir`), looked at: core 3's plate largest, the faults doubled under 14 runnable, a scarp, the weave.
- **Not measured yet:** the reading's 10 ms a second in the core, and one Canvas redrawn a second.

## 38. Bus topology (Claude B; atlas #21)

Devices, in Overdrive, in the spare foot of the Sound & Light column (`view/rooms/Buses.js`, `BusSchematic.qml`, the Stratum `devices.buses`, shown when the foot is at least 70 px tall): the machine's USB as it is wired. Fed by `core/buses.py` (`bus.usb`, registered in `core/app.py`), pulled every 3 s while the stratum exists and read only under an active lease: read-only sysfs, `/sys/bus/usb/devices` (each device's port path, speed, port count, class, its interfaces' classes, its product string) and each root hub's PCI parent (its controller). Nothing is written or kept by the core.
- **The schematic:** one column per controller ("XHCI 06:00.3"), its root hubs as rails (the USB 2 rail a hairline in the muted ink, the USB 3 rail heavier in the ink); each port is a tap off its rail, as heavy as the link's speed (12 M a hairline, 480 M 1.5 px, 5 G and up 2.5 px). An empty port is an unterminated stub; a plugged one ends in a node and the device: its kind read from the classes (HUB, RADIO, NETWORK, VIDEO, AUDIO, STORAGE, INPUT, DEVICE), its speed and, where the column is wide enough, its product. A hub's own ports hang indented under it.
- **History:** the session remembers what each port has held (`Buses.kept`, outliving Overdrive's release, gone at exit). A port that held something keeps its ghost ("STORAGE · OUT 15:17", faint); a device plugged in while the schematic is up is inked in the accent for 12 s. What was there at the first look is never "fresh".
- **Bluetooth islands and audio endpoints:** the Bluetooth devices linked now (or earlier this session, then as ghosts) hang off the radio's USB port as an island on broken, wireless taps; the audio outputs and inputs stand in an AUDIO column, the defaults marked (●), the default output with the count of streams playing into it. Both from the room's own lists (`host.bluetooth`, `host.audio`), not read again.
- **Tests:** `test_core_buses` (a fake sysfs tree: kinds, parents, controllers, hubs and nested devices, nothing outside Overdrive, the op), `test_buses` (speeds, rows following the wiring, the port memory: fresh, ghost, open) and `DevicesTest` (`buses.wired`, `buses.island`, `buses.release`).
- **Frames:** offscreen (`DEVICES_SHOTS=dir`), looked at: the receiver and hub in ink, the camera fresh in the accent, the stick's ghost, open stubs.
- **Not measured yet:** about 30 small sysfs reads every 3 s.

## 39. The harmonic typesetter (Claude B; atlas #13)

Media, while something plays in Overdrive (`view/rooms/Harmonic.js`, `HarmonicType.qml`, the Stratum `media.typesetter`): the track's title is re-set at each section change of the song and never in between, so it stays readable. The host's spectrum (56 bins) is split into low, mid and high shares, its energy and centroid, and eased into a six-second envelope. A **section change** is the mean energy of the last four seconds moving by more than a third from the four before, at least 8 s after the last; a song that never changes is re-set every 40 s. At each one the title takes a new set from the envelope, over 700 ms:
- **bass broadens it** (a horizontal stretch from 0.9 to 1.2, from the left edge, never past the title's free width),
- **brightness leans it** (an extra shear up to −0.28 as the centroid rises),
- **loudness thickens it** (Roboto Condensed's real Light, Regular, Medium and Bold),
- **dense mids tighten it** (tracking from +2 to −3 px).
The sections are counted in the title's corner ("§ 2", in the player's voice). Everything is scaled by the engine, and the Bindings restore the title on release (Black, −1.5 tracking, no stretch or lean). `FText` gained `stretch` and `slant` (1 and 0: no change) for it.
- **Tests:** `test_harmonic` (bands, the slow envelope, the set's directions, section changes and their spacing) and `MediaTest` (`type.sections`: a bass section sets the title broad, the bright section after it re-sets it leaning, and the weight follows; `type.release`).
- **Frames:** offscreen (`MEDIA_SHOTS=dir`), looked at: the bright section's lean and "§ 2".
- **Not measured yet;** a few arithmetic operations a spectrum frame.

## 40. The process spectrograph (Claude B; atlas #74)

Performance's record, with MEM chosen, in Overdrive (`view/rooms/Spectro.js`, `Spectrograph.qml`, the Stratum `performance.spectrograph`); the record's ground now follows the reading: the scheduler's plates (§37) under CPU, the spectrograph under MEM, nothing under the others. It reads the orrery's own samples (`OrreryField.last`, §15), so the core reads nothing more for it.
- **The plate:** each process is a vertical spectral line at its lifetime class (x: the log of its age, 1 s at the left to a week at the right, marked 1 S, 1 MIN, 1 H, 1 D, 1 WK), as tall as its CPU share (a log scale from 0.1 % to four cores), as thick as its memory (1 px under 16 MiB, 7 px at 4 GiB). Young and newborn lines are in the accent. The four tallest are named (the process's own 15-character name).
- **Interruptions:** each time a process stops using the CPU and starts again, a notch is cut out of its line; notches are kept a minute. So long-lived daemons stand thin, short and notched at the right, and a build's children as tall bright strokes at the far left.
- **History:** a process that ends leaves its line as a faint ghost for five seconds; forks since the last sample spark at the left edge (up to 24).
- **Tests:** `test_spectro` (the axes, thickness, interruptions as a stop and a restart, never-busy processes unnotched, ghosts, naming) and `PerformanceTest` (`spectro.lines`: MEM chosen, the plates go and the spectrograph comes; a daemon's notch, a compiler's tall thick line and its ghost, sparks; `plates.release` covers both).
- **Frames:** offscreen (`PERF_SHOTS=dir`), looked at.
- **Not measured yet;** one Canvas redrawn per orrery sample.

## 41. Handled paper (Claude B's own idea, for the user's veto)

Each room's sheet, in Overdrive, wears with the time you've spent in the room (`view/ui/Paper.js`, `view/shell/SheetWear.qml`, the Stratum `sheet.wear` in `RoomSheet.qml`, under the title and the room). The journey (`core/journey.py`) keeps each room's seconds and visits, decayed about a tenth a day, so the wear follows how you use the rooms now: a room you live in has handled paper, one you've left alone goes back to crisp. Wear is 1 − e^(−seconds / 3 h).
- **Thumbing:** the corner you'd hold, the sheet's lower outer corner (away from the wedge), is smudged in the ink, up to 20 %, reaching further as it wears.
- **Foxing:** up to 36 rust spots (the warning tone), gathered towards the margins, always in the same places for a room (seeded by its id), so a room's sheet is recognisably its own; more appear as it wears, the first ones staying.
- **The dog-ear:** after twenty openings the upper outer corner folds over (10 px), 8 px more with each doubling, at most 44.
- The sheet reads the journey through the room it carries (`shell.core.journeyData`), so the Shell's mount is unchanged; a mount can pass `journey` instead.
- **Tests:** `test_paper` (wear, foxing that is the room's own and grows from the same first spots, its margins, thumbing, the dog-ear) and `TitleTest` (`sheet.wear`: Tasks lived in for hours and opened eighty times; release).
- **Frames:** offscreen, looked at: the dog-ear, foxing at the margins, the smudge.

## 42. The week as a ledger (Claude B's own idea, for the user's veto)

Home's week strip, in Overdrive (`view/rooms/WeekLedger.js`, a Stratum `week.ledger.N` per day tile in `FWeek.qml`; Home passes the journey): each day the journey has kept (thirty days of visits per room) is inked from the bottom of its tile by how much FART was used that day, against the busiest day kept, and carries in its corner the number of the room it was spent in most ("05" for a day in Tasks). Days with no visits, and the days ahead, stay blank paper. Static: it changes when the journey does.
- **Tests:** `test_week_ledger` (a day's share of the busiest, the room a day was spent in) and `HomeFoldTest` (`week.ledger`: only today inked, the inbox's "08" on it; release).
- **Frames:** offscreen, looked at.

## 43. Sundial rooms (Claude B's own idea, for the user's veto)

In Overdrive the room's content casts a shadow on its sheet from where the sun really is (`view/ui/Sundial.js`, `view/strata/Sundial.qml`, `shaders/sundial.frag`, the GPU Stratum `sheet.sundial` in `RoomSheet.qml`, laid over the room's viewport, under the room). The screen is read as a map lying face up with north at the top: the sun in the east throws shadows west, a low sun throws them long and a high one short (the content stands 5 px off its sheet; the shadow is 5 px over the tangent of the altitude, at most 64). After civil twilight the moon does it, as strongly as it is lit; with both down there are none.
- **Drawing:** the content's alpha (a `KeepOut` of the viewport) is sampled back along the light's direction, 14 taps with a little sideways spread, nearer content darker, softening towards the shadow's end. The paper where nothing stands in the light's way gets a faint wash in the light's colour (amber while the sun is under 6°, warm to 20°, near white above; cold for the moon), so on a dark theme the shadows read as paper left unlit; on a light one they darken. The light's place isn't printed (a caption collided with the rooms' own corners in the real panel); the shadows carry it.
- **Data:** `sky.now` (the clock's sky, §M10), asked once a minute while the stratum exists; the room's core is found through the room, only in Overdrive.
- **Tests:** `test_sundial` (sun, moon or nothing; strength by altitude and by the moon's light; shadows falling away from the light; length by altitude) and `TitleTest` (`sheet.sundial`: absent on the software renderer; on the hidden desktop, a morning sun 10° up in the east throws a long shadow west).
- **Frames:** on the hidden desktop (`tools/hidden_desktop.sh python3 tools/overdrive/title_frames.py DIR`), looked at: the shadow layer alone, then the room: west-falling shadows on a faintly sunlit sheet.
- **Cost (10 November's pass, §9):** it was the largest single GPU cost in every room. Now drawn at the mask's quarter size into a cached layer, and it borrows the sheet's KeepOut of the same viewport (`RoomSheet.sharedMask`) instead of capturing the room again.

## 44. The disk as a tide (Claude B's own idea, for the user's veto)

Performance's record with DISK chosen, in Overdrive (`view/rooms/Tide.js`, `DiskTide.qml`, the Stratum `performance.tide`), completing the record's law: its ground is the chosen reading's machinery (CPU the plates, §37; MEM the spectrograph, §40; DISK the tide). Fed by `telemetry.disk` (`core/telemetry.py`, op registered in `core/app.py`): `/proc/diskstats` for the physical disks only (those with a `device` in `/sys/block`; partitions, device-mapper and zram left out), bytes read and written a second and the busiest disk's share of time doing I/O, once a second while the stratum exists, Overdrive only.
- **The water** stands as high as the disks are busy, rising fast (1.2 s) and ebbing slowly (4 s). Reads run its waves in (leftwards), writes draw them out (rightwards), as fast as the log of the bytes a second; two travelling sines make the surface, redrawn about 20 times a second while the engine runs and only while there is flow (`idle.performance.tide`).
- **History:** a burst (the level turning down after rising, from 12 % up) leaves a dashed wrack line at its high-water mark that fades over five minutes (eight kept); the session's highest water stays as the tideline, with its time ("HW 15:35"). The figures sit in the corner in the kernel's voice ("READ 10 KB/S · WRITE 0 B/S · BUSY 2%").
- **Tests:** `test_core_telemetry` (physical disks only, bytes and busy a second, nothing outside Overdrive, the op) , `test_tide` (rise and ebb, the waves' direction, a burst's wrack line and its fading, the tideline staying, a ripple leaving nothing) and `PerformanceTest` (`tide.wrack`).
- **Frames:** offscreen, looked at.

## 45. The graphics card's chart recorder (Claude B's own idea, for the user's veto)

Performance's record with GPU chosen, in Overdrive (`view/rooms/Recorder.js`, `GpuRecorder.qml`, the Stratum `performance.recorder`): a circular chart turning once a minute under a fixed stylus at the top, as a chart recorder's paper does. The outer trace is the integrated card's busy share (the inner ring idle, the rim flat out); the inner, stepped trace is the clock level it has engaged on its DPM ladder (`pp_dpm_sclk`), so each gear change is a step; VRAM in use is an arc on the rim from the top. The chart keeps exactly one revolution: the stylus writes over the minute before. The caption names the clock, the load, the VRAM and every other card awake or asleep ("AMD 800 MHZ · 11% · VRAM 300/512 MB · NVIDIA ASLEEP").
- **Data:** `telemetry.gpu` (`core/telemetry.py`, op registered in `core/app.py`), once a second while the stratum exists, Overdrive only. For every card only `power/runtime_status` is read: asking a sleeping card anything else could wake it. An awake AMD card gives its busy share, clock ladder and VRAM. (Checked live: the NVIDIA card stayed `suspended` through a reading.)
- **The record's law is complete:** its ground is the chosen reading's machinery: CPU the plates (§37), MEM the spectrograph (§40), GPU the recorder, DISK the tide (§44); SWAP the silt (§46).
- **Tests:** `test_core_telemetry` (an awake AMD card and a sleeping NVIDIA one on a fake drm tree, Overdrive only), `test_recorder` (the traced card, one revolution kept, the chart turning under the stylus, the radii, the caption) and `PerformanceTest` (`recorder.chart`).
- **Frames:** offscreen, looked at.

## 46. The swap as silt (Claude B's own idea, for the user's veto)

Performance's record with SWAP chosen, in Overdrive (`view/rooms/Silt.js`, `SwapSilt.qml`, the Stratum `performance.silt`), the last reading to get a ground. Fed by `telemetry.swap` (`core/telemetry.py`, op registered in `core/app.py`): pages swapped in and out a second (`/proc/vmstat`) and the swap in use (`/proc/meminfo`), once a second while the stratum exists, Overdrive only.
- **The bed** is as deep as the swap in use (80 % of the record when it's full). Pages swapped out fall through the record as grains (about one per doubling of the page rate, at most ten a second) and settle on it; pages swapped back in lift grains off it and up out of the record, in the accent. The grains move only while they're in flight (`idle.performance.silt`).
- **History:** the bed is laid in bands, a minute each (twelve kept), each darker as it ages under the newer ones, so a session's paging stands as strata.
- **Tests:** `test_core_telemetry` (the counters and their rates), `test_silt` (grains, depth, a band a minute and compaction, grains falling to the bed and rising out) and `PerformanceTest` (`silt.bed`: three minutes of paging out, three bands, grains in flight; `silt.rest`: they come to rest and nothing runs).
- **Frames:** offscreen, looked at.

## 47. Cockled paper (Claude B's own idea, for the user's veto)

Paper cockles in the heat. In Overdrive the room's sheet takes the processor's temperature with a two-minute thermal mass (`view/ui/Paper.js`, `view/shell/SheetCockle.qml`, the Stratum `sheet.cockle` in `RoomSheet.qml`), so it warms and cools slowly and a hot spell stays a while; the heat is kept for the session, so a release doesn't forget it. From 50 °C it cockles, fully at 90 °C: faint light and dark ripples across the sheet at the house angle, and a swell of up to 4 px that moves the sheet's register marks out.
- **Data:** `telemetry.thermal` (`core/telemetry.py`, op registered in `core/app.py`), every 5 s while the stratum exists, Overdrive only: the processor's own hwmon sensor (k10temp, coretemp…), else the hottest ACPI zone; never a graphics card's (a sleeping card's sensor could wake it).
- **Tests:** `test_core_telemetry` (the processor's sensor first, never a card's; ACPI otherwise), `test_paper` (the thermal mass, cockling from 50 °C, the swell, the ripples) and `TitleTest` (`sheet.cockle`: 88 °C cockles and swells it, a minute at 40 °C later it's still warm; release puts the marks back).
- **Frames:** offscreen, looked at.

## 48. The night log (Claude B's own idea, for the user's veto)

In the field archive, both modes, with its fiction on (`view/rooms/NightLog.js`, `FArchive.qml`, `ViewState.nightLog`): each night the archive is opened late (22:00–05:59), the surveyor logs the moon: the night (named by its evening), the time, the phase and how much is lit, from the moon's age in the mean synodic month (no core needed; within about a day of the true phase). One entry a night, thirty kept, saved with the rest of the view's state. The archive prints them newest first under "NIGHT LOG / THE SURVEYOR WATCHED THE MOON FROM THE DOORWAY", so it slowly becomes a lunar record of your late nights; on the worn tape in Overdrive, those lines wear like the notes. The moon is not the user's system, so the archive's promise holds.
- **Tests:** `test_night_log` (known full and new moons of November 2025, the phase names, one entry a night named by its evening, thirty kept, junk dropped on load, the line) and `ArchiveTest` (`archive.nightlog`).

## 49. Photocopy generations (Claude B's own idea, for the user's veto)

Clips, in Overdrive (`view/rooms/Photocopy.js`, `PhotocopyLayer.qml`, a Stratum `clips.copy.N` inside each preview, under it): the clipboard's history is copies of copies, so each clip is set as the generation its place in the list makes it. The newest is crisp; each older one's ink thins (to 62 % by the twelfth), a second impression slips out of register beneath it, and toner speckle (seeded by the clip's id, so it stays put) gathers in its gaps. Nothing is read but the preview the row already shows; release restores the ink.
- **Tests:** `test_photocopy` and `ClipsTest` (`clips.copies`, `clips.copies.release`). Frames: offscreen.

## 50. Clock occultation (atlas #51, Claude A)

The header's clock is a portal, never a label that gives way (`view/overdrive/ClockOccultation.qml`, rules in `Occultation.js`). In Silent it is the plain line it always was, and an event changes nothing. In Overdrive, events cross it by their weight, and the digits stay readable throughout:
- **A countdown ends** (`timer.done`, `pomodoro.phase`): the colon's dots part like an eclipse's limbs, the upper with the hours and the lower with the minutes; the header makes room, and Timers' number (`06`) stands between them on two hairlines in the warm tone, sliding its last pixels into register. 2.6 s, four contacts: open by an eighth, held, closed over the last 15 %.
- **A device comes or goes** (`quiet.device`, or a Bluetooth device connecting): a plate crosses in front of the digits at a constant rate, left to right, printing the ones it covers in negative, with Devices' number riding above its leading edge. 1.7 s.
- **A new track** (the active player's id, title or artist changing; only the change is noticed, nothing is kept): a band passes behind the digits right to left, Media's number under its head, and the digits lift to full ink in front of it. 2.3 s.
- **Weight:** a countdown holds the clock against a device or a track until it closes; an equal event restarts the crossing. Release clears the event mid-crossing and destroys the layer.
- **Tests:** `test_occultation` (the rules under Node; and `OccultationTest` on the real component: Silent ignores events, the split widens the clock with the number, a device can't take it from a countdown, front and behind, release mid-crossing). Frames offscreen, looked at.
- **Not seen:** firing from a real countdown or a real USB device on the live desktop.

## 51. Archive match cut (atlas #40, Claude A)

Story and interface share one editing grammar (`view/overdrive/MatchCut.qml`, rules in `MatchCut.js`, the Stratum `archive.matchcut` in `Shell.qml`). Leaving the field archive in Overdrive for the room still shown, the archive goes in a hard cut, but one number survives it: the room's own, found in an archive label still on screen. Any run of digits of the same value counts ("FIELD NOTE / 005", "DAY 5" and "05" are all room 05; "105" isn't), and the topmost one wins.
- **The cut:** the pivot holds still in the archive's type on a patch of ground while the room appears round it (the first fifth); then its bounding box, in crop marks and leaving three ghost boxes, glides into the room's number (the title wedge's, or the index ribbon's when the wedge hides it), the type growing geometrically and turning from the archive's mono to the room's black numerals; it hands over to the real number and fades. 820 ms.
- **When it doesn't run:** Silent, reduced motion, a room switch in flight, or no label on screen holding the number: the archive simply closes, as before.
- **Found by walking the items on screen,** so FArchive and the rooms needed no change: a label clipped out of its list doesn't count.
- **Tests:** `test_match_cut` (the rules under Node, and `MatchCutTest` on the real FArchive over a real RoomSheet: found, hold, landed, release) and ViewTest's `archive.matchcut` in the real Shell (the cut runs exactly when a pivot is on screen; the archive closes either way). Frames offscreen, looked at.
- **Not seen:** on the live desktop. With a short survey the archive's labels only hold the first few room numbers, so early on the cut fires mostly for Home, Media and Performance.

## 52. Intent gate (atlas #62, Claude A)

Confirmation as a geometric task, not a dialog (`view/shell/IntentGate.js`, in `CommandLine.qml`). In Overdrive, a typed line that cuts something off (`wifi off`, `bt off`, `session end`, `lock`, with the core's own aliases and off-words: `bluetooth no`, `wifi 0`) doesn't run on Enter. It splits into two planes of type, the accent's and the danger's, apart along the house angle by a notch per digit owed, and the right of the line asks "REGISTER 04 · ESC". Typing the number of the room that holds what it cuts (Devices for the radios, Timers for the session, Home for the desk) closes them a notch a digit; a wrong key throws them apart again. Registered, they print as one line in ink between two registration marks, and "ENTER CUTS THE NETWORK"; Enter runs it. Esc puts the line back unsent; so does a release.
- **Not gated:** Silent (nothing changes there), anything that turns something on, opens a room or adjusts it, and the header's power button, which hands off to the host's own session menu.
- **Accessible:** the line's accessible name says what to type while it waits.
- **Tests:** `test_intent_gate` (the rules under Node, and `GateTest` on the real CommandLine with a core that's never connected, so a sent line only reaches the log as "not connected" and nothing is ever actuated: Silent runs at once, the split, a wrong digit, registering, running, Esc, release, a line that cuts nothing). Frames offscreen, looked at.

## 53. The False Room (atlas W1, Claude A; the lore too, since Claude B is gone)

A secret astronomical event made of long-term use (`view/overdrive/FalseRoom.js`, `FalseRoom.qml` on the orbit, `FalseRoomSheet.qml` inside; the Strata `falseroom` in `OrbitSystem.qml` and `falseroom.inside` in `Shell.qml`). Overdrive only.
- **Sighted:** once the surveyor's errors number three (#55: at most one a day, about one station in 53, so weeks of use), a frame numbered −1 lies flat on the orbit's plane out past the outermost room, on the bearing of the hidden point the errors keep outlining (`Survey.locus`): its range of 6–9 doorways sets how far out. Dashed, faint, a red survey mark at its foot. It can't be clicked and no key reaches it.
- **Open:** only while every one of these holds at once, each a real reading: the local sidereal hour is the room's own (from the survey's seed: once a sidereal day, four minutes earlier each civil day; the longitude is the timezone's meridian); the machine is on its own battery; nothing is playing; and the last two hops through the rooms are both rare (made at most twice) in a history of at least forty. Then it rises on one hairline stalk, stands like the rooms, reads "UNSURVEYED" and takes a click.
- **Inside:** no controls. A reconstruction drawn once: a spoke per room, Home at the top, as long as the log of the time spent there, ticked once per visit (forty at most); the day's hours the rooms were used in as a ring of amber bars, midnight at the top; the last hops as a red path between the spokes' tips, each stop stamped with its minute; and beneath, the machine now in classes only (connected devices, a processor pressure class I–IV) and the conditions it was entered under. Room ids, counts and times: never anything a room holds. Esc, a click or a release leaves.
- **Spent:** entering records the conditions' signature (the sidereal hour and the hops) in `ViewState.falseRoomSpent` (sixteen kept, saved with the view's state), so the room stays shut until a different set comes together.
- **The field book's notes** (`FalseRoom.notes`, shown in the archive under the surveyor's own lines): it learns the room one survey error at a time. Two errors: they close on one point. Three: station −1, its coordinate and bearing, a frame where the plan has no room. Each error after that gives one condition, in order: its hour by the stars, the machine on its own cell, silence, a route seldom walked. Once entered: how many times, and that the same way in doesn't open it twice. Read from the error count and the spent list only.
- **Data added:** the journey's snapshot now carries `recent` (the last twelve stops: room id and time) and `edges` (directed hop counts), for the rare-hop condition.
- **Tests:** `test_false_room` (the rules under Node: sighting, sidereal time against J2000, each condition alone failing, spending, placing, pressure classes, the reconstruction holding only metadata; and `FalseRoomTest` on a stand-in orbit: unseen, sighted, open, entered, spent, release), `test_core_journey` (the new snapshot fields). Frames offscreen, looked at: shut, open, inside.
- **Not done:** seeing it on the real orbit (it needs weeks of survey errors, or a doctored field book). The notes were looked at in the real archive with a doctored book, offscreen.
