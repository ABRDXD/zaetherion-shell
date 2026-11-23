# FART's design system

What the view is made of, as built on `m6-rooms` (9 November 2026). It replaces the archive's version, which described end-4 paths and a fixed palette. Where something was designed but isn't in this tree, it says so.

How it got here is in `docs/MONTAGE.md` (the Silent montage, M6) and `docs/ORBIT.md` (the overview and the flight). Motion is `docs/CUES.md`. This file is the reference: what exists, where it lives, and the rules the tests hold it to.

## 1. Principles

- **Silent is still.** At rest nothing moves, nothing ticks and nothing redraws. Motion happens because you did something: a key, a click, a flight. Idle motion belongs to Overdrive (M8), and is off.
- **The host owns the colours.** FART takes its palette from the host (Serpantinum) and never ships a fixed one. The roles say what a colour is for; the host says what it is.
- **One angle family.** −12° and its perpendicular, 78°. Nothing else leans.
- **A metaphor, not a picture.** The orbit is a solar system in layout only. Rooms are house tiles, orbits are hairlines, and nothing is drawn as a planet, a sphere or a sun.
- **Data is never large type.** The large type is a room's name, a clock or a numeral. A notification body, a clip or a task is never set as a headline.

## 2. Tokens (`view/ui/Design.qml`)

### 2.1 Colour roles

There are three roles. Every surface is one of them:

| Role | Meaning | From the host |
| --- | --- | --- |
| **paper** | the backing plane | `surface` |
| **ink** | text and lines on paper; an inverted plane | `text` |
| **signal** | the one accent per room: the selected, the current, the alarm | `accent` |

`Design` also exposes the host's other colours as tokens: `background`, `hover` (`surfaceRaised`), `muted`, `faint`, `line`, `warm`/`warning`, `danger`/`recording`, `success`, `selected` (`highlight`). Each has a fallback, used until the palette arrives. Rooms use these tokens only: no colour literals (`tests/test_layout.py`).

**The contrast guard is not in this tree.** It was designed on Astra's branch (`m6-contrast`: `docs/CONTRAST.md`, the per-role publication and the audit). It repairs any foreground under 4.5:1 (3:1 for large text) by moving its OKLCH lightness. Until it merges, `Plane.textColor` falls back to `Design.background` on ink and signal planes (`onInk ?? background`). Measuring contrast across five presets is part of M6 acceptance.

### 2.2 Type

Two families: `Design.sans` (Roboto Condensed) for headlines and figures, `Design.mono` (the host's mono font) for everything else.

| Token | px | Use |
| --- | --- | --- |
| `caption` | 11 | technical labels, footers, tile captions |
| `body` | 12 | running text (the `FText` default) |
| `control` | 13 | buttons, menu rows, small headlines |
| `readout` | 20 | readings, task lines, asides, the archive's notes |
| `figure` | 32 | secondary numerals and the logo |
| `headline` | 52 | room headings |
| `display` | 86 | hero numerals and glyphs |

**The rule:** no `pixelSize` literal in the view. A size computed to fit (a tile's numeral, the Home clock, the cut's name) carries `// scale:` and its reason on the same line. `tests/test_layout.py` enforces both.

**`FText`** carries the voice (§7) as flags:
- `technical`: mono at `caption`;
- `headline`: the sans, tight tracking;
- `aside`: mixed case, italic when the host's italic preference is on;
- the rest: uppercase mono at `body`.

Numerals are tabular. A figure of 32 px or more shears to −12°.

### 2.3 Grid, angles and sizes

- **Grid** (`view/ui/Grid.qml`, one per room width): 12 columns, a 16 px gutter (12 px below 920 px wide), and a 4 px baseline. `span(first, count)` returns `{x, width}`, and `snap(v)` rounds to the baseline. Rooms place planes by span.
- **Angles:** `Design.shear` (tan −12°) for headings, numerals and the selected band, and `Design.slope` (tan 78°) for plane edges. Only these two and 0 appear in rooms.
- **Hit areas** are at least `Design.minHit` (24 px).
- **Radii** are 0–2 px inside the panel. The panel's own radius is the host's.

## 3. The Plane family (`view/ui`)

**`Plane`** is the only surface. It has these properties:
- `role`: paper, ink, signal or clear;
- `slant`: the 78° edges, left, right or both;
- `cut`: corner cuts in px;
- `backing`: it carries small text, so it is never transparent;
- `depth`: layer order 0–2, never animated in Silent.

Two renderers sit behind the one API: a sheared `Rectangle` for planes with no cut (it batches, with no geometry rebuild), and a `Shape` for cut or one-sided planes. Geometry is computed on resize only. `textColor` and `fillColor` give the colours to draw on it.

Built on `Plane`:

| Piece | What it is | Where |
| --- | --- | --- |
| `Wipe` | the ink inversion: an ink plane wipes in from the left, its leading edge at 78°, over `Motion.feedback`; text turns to paper past half-way; selection adds a rule above and below | `FButton`, `FChoice`, `FToggle` |
| `Pointer` | a small arrowhead with a 78° back edge beside the chosen row | `FChoice`'s highlighted row, `FMenuItem` |
| `FMenuItem` | a ruled row with a square node, the label and a right-aligned detail; hover or focus wipes it to ink | Home's upkeep and desk menus |
| `Hatch` | 78° strokes as one tiled SVG cell | Home's signal band |
| `CutTitle` | a room's wedge: an ink plane on one edge of its sheet, the name running along its 78° outer edge in Black, cropped by its straight inner edge | every room (`RoomSheet`) |
| `Register` | registration crosses in a sheet's corners | `RoomSheet` |
| `CoverDisc` | a round cover with a position ring | Media, Home |
| `Halo` | a tilted orbit of leaning pills | Performance |
| `CutCornerFrame` | the shared corner-cut geometry for controls (AGENTS.md) | controls |

The controls are `FButton`, `FChoice`, `FToggle`, `FField`, `FMenuItem`, `FMeter`, `FTrace`, `FWaveform`, `FRule` and `FStatusDot`. They take their surfaces from `Plane` and `Wipe`.

**A known quirk:** a `Shape` drawn with the curve renderer (`FRule`, the cut wedge, links) ignores an ancestor's `clip` under a scale. So a scrolling list hides its rules while they're out of view (the field archive does this), and in flight the lens draws only the shown room's sheet.

## 4. The frame

### 4.1 The panel

The panel is `min(1360, screen − 24) × min(860, screen − 24)`, or the whole screen when fullscreen (`ViewState.fullscreen`: F11, `F` in the orbit, the header, settings). It has these parts:
- **The header:** the logo, the command line, the orbit, fullscreen, appearance, archive and power buttons, the clock, and close.
- **The field:** the shown room on its sheet.
- **The footer:** the network, the key hints and the power state.

### 4.2 The room on its sheet

- **The sheet:** a room sits on `RoomSheet`, a plane the size of the field less a thin margin (16 × 12 px, 10 × 8 compact).
- **The cut:** its wedge stands on the edge `Shell.cuts[id].side` gives, covering `span` of the height from `align`. The room's content lies between the wedge and the ribbon, in one `Flickable` holding two `RoomSlot`s (the shown room, and the next one incubating).
- **The edges:** the field's left and right are darkened (static gradients, 12 % of the width).

### 4.3 The index ribbon (`IndexBand`)

Nine tabs on the edge the wedge leaves free: 60 px wide, or 40 px below 640 px. At rest each tab is a numeral. The selected one is an inverted ink tab carrying the number and the fitted name, with a rule above and below. The ribbon hides while the orbit is open or in flight.

### 4.4 The reticle and the keys

**`Reticle`** draws four sheared corner ticks round the focused control. It shows only after keyboard navigation, hides on any pointer press, and owns no focus.

**`FocusMap`** picks the nearest focusable in a ±45° cone, scoring distance along the move at 1 and across it at 2. Lists move by row first. A move with no candidate falls back towards the ribbon, or up to the command line.

| Key | With no text field focused |
| --- | --- |
| arrows; hjkl once the reticle shows | spatial move |
| Tab / Shift+Tab | the focus chain |
| `[` `]` | previous or next room |
| `/` | the command line |
| Esc | back to the command line; a second Esc folds |
| Ctrl+0–8 | a room |
| Ctrl+M | the orbit |

Any other printable key types into the command line.

## 5. The orbit (`view/shell/OrbitSystem.qml`, `Orbit.js`; `docs/ORBIT.md`)

### The system
- **Layout:** Home in the centre; rooms 01–08 on concentric orbits in index order, each on a stalk over its shadow.
- **Projection:** a plane seen through a perspective camera 45° above it, sheared to 78°.
- **Tiles:** the near half of each orbit is drawn stronger than the far half, and tiles scale 0.78 → 1.16 from back to front.
- **Places:** each room keeps its stored angle (`ViewState.orbitAngles`).
- **Colour:** the current room's tile is ink, the highlighted one signal; their orbits are drawn in those colours.

### Tiles (`OrbitTile`)
Each tile is a sheared `Plane` with the room's number, name, and its face or symbol. Highlighting sweeps signal across it along 78° and lifts it, through a `Tween`: it moves only while the highlight does.

### Faces (`view/faces`)
A face is a room's one live fact, laid out from the size it's given:
- **Tier 0 (a tile's corner):** the `brief` ("1 LATE", "CPU 25%", "25:00").
- **Tier 1:** the figure and a note.
- **Tier 2 (a readout):** the figure, note and detail.

An alarm (late, done, recording, unread) inverts the note into a tag, using the plane's own text colour, so it reads on paper, ink and signal without a new hue.

Faces are made only once the overview is open and still. They're live only while it's shown. They never animate, and they hold no lease longer than one probe (Devices: the recorder; Clips: one history listing).

### The room systems (`RoomSystems`, `SpaceSystem`, `SunFace`)
Each room has its own small system out in space: a sun carrying its headline reading, with moons that act. Moons are controls, not pictures, so a click does what the room's own control does. Clips' moons show kinds only, never contents. The systems are built asynchronously once the orbit is still, and fade in.

### The flight
- **One cue:** every room switch flies through the orbit, as one `orbit.transfer` cue: the room shrinks into its tile, a streak crosses to the next tile, and the camera dives in.
- **Length:** 550 ms for neighbours, up to 1000 ms across the system (`Shell.hop`).
- **Interruption:** a new choice mid-flight retargets from where the camera is.
- **The lens:** the live room stays live until it has shrunk away.
- **Opening and closing:** one zoom each (`Motion.zoom`, 440 ms).

### Space
- **Pointer:** drag pans with a fling; in a room, a drag pulls the room out into the orbit.
- **Zoom:** the wheel, `-`/`=` and the zoom bar glide from 20 % to 1000 %. Zooming into a tile dives into its room.
- **Framing:** `G` frames every system; `.` and Home glide back.

### The orbit's keys

| Key | Action |
| --- | --- |
| arrows, hjkl | the nearest tile on screen |
| Tab, `]` / `[` | 00 → 08, wrapping |
| 0–8, Enter, a click | land |
| Esc | return |
| **S** | step into the highlighted room's system; arrows and Tab walk its sun and moons, Enter acts, Esc steps out |

### Type to fly
`go <room | moon>` in the command line flies to a room, or opens the orbit and keys a moon by name (`go wifi`, `go timers stopwatch`, `go ws 3`).

## 6. Strata (`view/strata`)

The only place shaders may live (CUES §4.3; `test_contract.py`). A stratum exists while its owner holds it, and is destroyed, not hidden, when it's let go. With motion reduced, none is created.

| Stratum | What | When it exists |
| --- | --- | --- |
| `SpaceFabric` | the spacetime grid under the orbit: a 180 × 180 `GridMesh` displaced in the vertex shader by up to 80 wells (Home, the rooms, the suns, then every moon) and one ripple per switch or choice | while the orbit's Loader is active |
| `SpectrumBand` | Media's visualiser: one shader quad, the spectrum as 14 vec4 uniforms | while something plays, under the `spectrum` lease, with the visualiser on |

Shaders are GLSL in `view/strata/shaders`, compiled to `.qsb` with `tools/make_shaders.py`. `tests/test_shaders.py` checks the compiled files are current. Offscreen and software rendering draw no stratum, so check them with `tools/shots.py --window`.

## 7. Motion (`view/cues`; `docs/CUES.md`)

- **All motion goes through the cue system:** `Cue`, `Tween`, `Pulse`, `Timeline`/`Track` and `Activity`, with durations from `Motion`'s roles (the host's profile overrides FART's defaults).
- **What fails `test_contract.py`:** raw sequences, `Behavior`, `PauseAnimation` and infinite loops outside `view/cues`.
- **Reduced motion is a complete path:** every cue lands at once, nothing loops, and no stratum is made.
- **Idle loops are Overdrive only** (`IdleLoop`, `Idle`). They bind transforms and opacity only, read one shared clock and stop when the panel folds. With Overdrive off (now), none runs.

### The cost rule
On this desktop a drawn frame costs about 4.5–5 ms of CPU, whatever moves (B's measurements, `docs/measurements/`). So the ≤ 2 % open-at-rest budget allows about 4 drawn frames a second in all. That leaves room for event-driven change (a reading, a step once a second) and none for anything at vsync. A Timers face steps on the shown second, never on a fixed fast timer.

## 8. Density (D12)

Each room keeps to these limits:
- **One hero:** the cover, the numeral, the miniature or the readout.
- **Movement:** at most two elements that ever move.
- **Room:** at least one untouched span of three or more columns.
- **Surfaces:** planes from §3 only.

The orbit's readout keeps a fixed column beside the system (under it when narrow), and the system never draws under it.

## 9. Voice

- **Uppercase is the system's voice:** labels, readings, keys, states ("1 LATE", "ENTER LANDS · ESC RETURNS").
- **Lowercase italics are asides:** a room's line ("Signal, received."), the surveyor's remarks.
- **CJK stays upright,** never italic.
- **Critical states carry no jokes.** Late is stated ("05 NOV · 2 D LATE"), never scolded. Errors say what happened.
- **The field archive is fiction** and says so. It may be strange, once (the unsigned note), but it never imitates a system warning, plays a sound or touches the user's work.
- **Privacy:** clip and notification contents never appear outside their own rooms (faces and moons show counts and kinds), and never in screenshots or reports.

## 10. What the tests hold

| Rule | Where |
| --- | --- |
| Type scale, no literal sizes, no colour literals | `tests/test_layout.py` |
| Motion through cues, shaders only in strata, imports within layers | `tests/test_contract.py` |
| The keyboard reaches every control in every room, every orbit tile and every moon | `tools/keytest.py` (`tests/test_keytest.py`) |
| Cue behaviour: flights, the hop, the orbit at rest, idle only in Overdrive | `tools/cuetest/ViewTest.qml` (`tests/test_cues.py`) |
| Faces render in every slot; Timers steps per shown second | `tools/faces.py` (`tests/test_faces.py`) |
| Compiled shaders are current | `tests/test_shaders.py` |
| CPU, frames and memory | `tools/measure/` on the desktop (`docs/MEASUREMENT.md`) |
