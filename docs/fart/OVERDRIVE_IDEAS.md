# Overdrive: the idea atlas

Source: the user's research report, `docs/research/deep-research-report.md` (8 November 2026): 75 concepts and 5 wild ones. Its citations came through as broken tokens, so its references can't be followed; the ideas stand on their own. Its main point is adopted as the direction: **not more effects, but laws.** Things happen because of real state, leave history behind, and have consequences in space.

**Owners follow the user's file split.** A: orbit, Shell, Overlay, PanelBody, strata foundation, cues, sound, core Overdrive. B: rooms, faces, `view/ui`, creature and lore, sky, lyrics, telemetry.

**Rules that hold for every idea:** Silent never moves at rest (history-driven changes appear only on open); every effect scales with `Motion.drive` and dies at release; reduced motion stays still; controls stay readable; history stored on disk is room ids, counts and times only, never window titles, clipboard or notification contents.

| # | Idea | Size | Owner |
|---|---|---|---|
| 1 | Lagrange Shelves | L | A |
| 2 | Orbital Resonance Locks | M | A |
| 3 | Proper-Motion Drift | M | A |
| 4 | Redshift / Blueshift Navigation | S | A |
| 5 | Parallax Error Budget | M | A |
| 6 | Transit Windows | M | A |
| 7 | Folded Ephemeris | L | A |
| 8 | Dark Matter Routes | M | A |
| 9–11 | Home: Day Fold, Domestic Constellation, Editions | M S S | B |
| 12–14 | Media: Groove Geometry, Harmonic Typesetter, Stereo Cartography | M L M | B |
| 15–17 | Performance: Fault Lines, Thermal Stratigraphy, Interrupt Rainfall | L M M | B |
| 18–20 | Workspaces: Window Genealogy, Empty Desks, Focus Seismograph | L M S | B |
| 21–23 | Devices: Bus Topology, Battery Ledger, Phantom Ports | L M S | B |
| 24–26 | Tasks: Dependency Tectonics, Neglect Patina, Completion Negative Space | L S M | B |
| 27–29 | Timers: Isochrones, Temporal Shear, Beatless Metronome | L M S | B |
| 30–32 | Clips: Fossils, MIME Taxonomy, Copy Rhythm (from the list's kinds, sizes and times only; no new clipboard reading) | M S M | B |
| 33–35 | Inbox: Source Eclipse Map, Arrival Cadence, Silence Debt (counts and sources only) | M S M | B |
| 36 | Coordinate Exchange | M | A |
| 37 | Typeset Teleport | S | A |
| 38 | Causal Cut | M | A |
| 39 | Aberration Jump | L | A |
| 40 | Archive Match Cut | M | A |
| 41–45 | Typography: Load-Bearing Glyphs, Data Kerning, Counter Windows, Phase Change, Registration Voices | L M M L S | B |
| 46–49 | Sound: State Chords, Structural Foley, Quiet Telemetry, Spatial Room Voice | M S M M | A |
| 50 | Bar as Horizon Instrument | L | needs the user's approval: it changes Serpantinum's bar |
| 51 | Clock Occultation | M | A |
| 52–54 | Wallpaper Stress Field, Desktop Meridian, Off-Screen Ephemera (the T3 desktop tier, M16) | L S M | A |
| 55–58 | Lore: Survey Errors, Calibration Disagreement, Creature Parallax, Impossible Revision History | M S M L | B |
| 59–62 | Input: Ballistic Command Line, Chorded Room Grammar, Gesture Fossil, Intent Gate | M M S M | A |
| 63–66 | Time: Sidereal Margin, Habit Precession, Day-Length Compression, Recurrence Windows | M L S M | B |
| 67–70 | Music: Spectral Architecture, Phase Portrait, Keyless Harmony, Silence Geometry | L M M S | B |
| 71–75 | Telemetry: Cache Palimpsest, Context-Switch Weave, Network Letterpress, Process Spectrograph, Machine Weather Report | L M M L L | B |
| W1 | The False Room | XL | A (the orbit and, B being gone, the lore) |
| W2 | The Desktop Has an Eigenmode | XL | Astra (handed over by A, 9 November) |
| W3 | Its Own Coordinate Standard | L | B |
| W4 | Time Can Be Misregistered | M | B |
| W5 | The Machine Performs a Demonstration of Itself | XL | Astra (handed over by A, 9 November) |

**Shared foundation:** `core/journey.py` (A) keeps which rooms were visited, in what order and for how long, so 1–3, 7, 8, 10, 57, 64 and 66 read one history.

**A's share, on `main` since 9 November (`87218b3`)** (details in `docs/OVERDRIVE.md` §10–14):
- **Built and tested:** 1, 2, 3, 4, 6, 7, 8 (the orbit), 38 (the causal cut), 52, 53, 54 (the desktop tier), 59, 60, 61 (input).
- **Built, heard by the user:** 46, 47, 49 (sound).
- **Built, partly checked:** 39 (the aberration, not seen firing); 48 (quiet telemetry: tested, not heard yet).
- **Built 9 November:** 37 (`view/overdrive/Teleport.qml`); 5 (brackets on the orbit's tiles from which sensors are unavailable; data age isn't measured, because the daemon's data carries no per-item timestamps yet).
- **Built 9 November:** 36 (`view/overdrive/CoordinateExchange.qml`): the rulers turn a quarter over the flight's first half and each room's number rides one axis.
- **Built 10 November:** 51 (`view/overdrive/ClockOccultation.qml`, §50), 40 (`view/overdrive/MatchCut.qml`, §51), 62 (`view/shell/IntentGate.js`, §52); W1, the False Room (`view/overdrive/FalseRoom.qml`, §53), with its lore in the field book (B's half, done by A after B was gone).
- **A's atlas share is complete.** W2 and W5 went to Astra.

**B's share** (details in `docs/OVERDRIVE.md` §15–31 and §35 on):
- **Built and tested:** 12, 16, 17, 22, 23, 25, 26, 31, 33, 34, 35, 45, 55, 56, 57, 58, 63, 65, 66, 67, 70, 71, 73, 75, W3, W4; 41, 42, 43, 44 (the title under load, §35); 9, 11 (Home folded by the day and set as an edition, §36); 15, 72 (scheduling fault lines and the context-switch weave, §37); 21 (bus topology, §38); 13 (the harmonic typesetter, §39); 74 (the process spectrograph, §40).
- **Skipped, with the reason:** 10 (Home's constellation of rooms used together: the orbit already draws the journey's links, from the same history); 14, 68, 69 (the host gives no left/right samples or chroma); 30, 32 (they'd need clipboard interception, ruled out); 24 (tasks have no dependencies).
- **Handed to Astra:** 18, 19, 20, 27, 28.
- **B's own, for the user's veto (9 November):** handled paper (§41), the week as a ledger (§42), sundial rooms (§43), the disk as a tide (§44), the graphics card's chart recorder (§45), the swap as silt (§46), cockled paper (§47), the night log (§48), photocopy generations (§49).
