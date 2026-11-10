# Daily driver B: montage and navigation (M6)

Status: **reviewed 7 November 2026**: every recommendation in section 11 was approved (section 12). Branch `m6-design` (worktree `../next-m6`), base `4dfca6c`.

M6 (PROJECT_PLAN) delivers:
- D2: the contrast guard.
- D12: the density budget per room.
- D13: the layered Silent montage, with angles −12°/78°, a 12-column grid and three colour roles.
- D14: the diagonal index (replaced on 7 November by the canvas and the cut, §4).
- D15: the spatial reticle, with hjkl, arrows, `[ ]` and `/`.
- The "Room decisions → milestones" list for M6 and Astra's P3 acceptance table, with the type scale revised to 11/12/13/20/52.
- A rewritten DESIGN_SYSTEM.

It builds on the cue system (CUES.md, §15 host motion profile), the contract (ADAPTER_CONTRACT.md) and the M5 shell (DAILY_DRIVER.md, M5-VIEW.md).

Out of scope:
- Overdrive (strata, shaders, lease UI): M8.
- The astronomical sky (positions, orbits): M10. The Home sky in M6 is a static stand-in (Q5).
- Workspace thumbnails: M14.
- The cold-start and warm-open budgets: a separate branch, `coldstart`, owned by Claude B.
- The Archive's 10th band: M15. M6 only reserves its slot.

## 1. Tests and budgets

| Budget (PROJECT_PLAN) | Definition | Harness |
| --- | --- | --- |
| Contrast ≥ 4.5:1 body, ≥ 3:1 large | WCAG 2.x ratio of every guaranteed role pair (§3.2). Text is measured against the opaque plane it sits on, never against the blurred panel. Large means ≥ 24 px regular or ≥ 18⅔ px bold (WCAG); 20 px readouts are not large and need 4.5:1 (corrected from the draft per CONTRAST.md). | `tools/contrast_audit.py` over every usable Serpantinum preset (94 of 96: Nightfox is empty, Matugen has no generated output), as a unit test. The review set is 5 named presets (§3.2). Design: Astra's `docs/CONTRAST.md` (branch `m6-contrast`). |
| Keyboard reaches every control in every room | Each room is walked with Tab and with the four spatial directions from every focusable. Every visible, enabled control is reached. The reticle rect equals the control's rect each time. No key is lost to a hidden item. | new `tools/keytest.py` fixture harness (offscreen, the same pattern as `cmdtest`) |
| Silent open ≤ 2% of one core when static | Each room is opened and left still for 60 s, with `motion.active == 0`. Media is measured paused here and playing below. | `desktop_idle.py --room <id>` (new flag), fixture view |
| Silent and Media playing ≤ 5% of one core | Playing, lyrics visible, blades drawing | the same tool, but this needs playback **you** start; FART does not start it |
| Navigation p99 ≤ 6.9 ms | The existing desktop budget: 0 steady misses, ≤ 1 per room load | `desktop_nav.py`. Workspaces is the known offender (28–37 steady misses), see §8. |
| No new idle cost | Closed: 0 frames and 0 ticks, as now. The montage adds no timers. The Home sky redraws at most once a minute. | `desktop_idle.py` |

Static lint (tests/test_layout.py, extended):
- Rooms use no colour literal (`Design` or palette roles only) and no `pixelSize` literal outside the scale tokens.
- Every `FText` under 20 px lies inside a `Plane` whose `backing` is true.
- Hit areas are ≥ 24 px.

Today there are 33 literal `pixelSize` values in view/ (counted with grep). Each one becomes a token or a named exception.

## 2. Tokens (view/ui/Design.qml)

**Type scale** (PROJECT_PLAN, revised):

| Token | Size | Was |
| --- | --- | --- |
| `caption` | 11 | 13 |
| `body` | 12 | 15 |
| `control` | 13 | new |
| `readout` | 20 | `subheading` 20 |
| `headline` | 52 | `heading` 52 |
| `display` | 80–98, numerals only | literals today (the clock, the index) |

Body text shrinks by 3 px. That is the biggest visible change of M6, so it lands first and on its own (§10, step 1), and you can judge it before any montage work.

**Grid.** There is one `Grid` singleton per room width:
- 12 columns.
- The gutter is 16 px, or 12 px when compact (width < 920, which matches `Shell.compact`).
- The baseline unit is 4 px.

`Grid.span(first, count)` returns `{x, width}`. Rooms place planes by span, never by pixel.

**Angles.** There is one family:
- **−12°**: the shear of headings, numerals and the selected band. The `Design.shear` constant already exists.
- **78°**: its perpendicular, the slope of plane edges and of the index.

No other angle is allowed. Only three values may appear in rooms: `Design.shear`, `Design.slope` (tan 78°, new) and 0.

**Roles.** There are three, from D2/D13:
- **paper** is the backing plane.
- **ink** is the text and line on paper.
- **signal** is the one accent per room.

They are derived from the host palette by the contrast guard (§3.2), never fixed. The existing tokens (`ink`, `muted`, `faint`, `accent`, `warm`, `danger`, …) stay as the guard's repaired outputs, so the rooms migrate without renames.

## 3. Primitives (view/ui)

### 3.1 Plane

`Plane` is the montage's only surface. Each one has these properties:
- `role`: paper, ink, signal or clear.
- `slant`: 0, or the 78° edges on the left side, the right side or both.
- `cut`: the corner cuts, in px.
- `backing`: it carries small text, so it is opaque.
- `depth`: 0–2, the layer order. Silent never animates it.

Two renderers sit behind one API:
- **Rectangle with a `Matrix4x4` shear**, for planes with no cut. This is what the selected navigation slab does today. It batches with the other rectangles and adds no geometry rebuild.
- **`Shape` with one `ShapePath`**, only for cut or irregular planes. It replaces `CutCornerFrame` in the montage; `CutCornerFrame` stays for controls.

Q1 asks whether the split is worth its complexity. The alternative is one renderer.

The plane geometry is computed once on resize, so it adds no per-frame work in Silent. Reduced motion changes nothing here, because Silent planes are static by D13.

### 3.2 Contrast guard

The guard is pure and runs once per palette revision (`PaletteDomain.revision`). For every guaranteed pair it computes the ratio. If the ratio is under the minimum, it moves the foreground's OKLCH lightness toward the far end and keeps its hue and chroma, clamped to the gamut. It falls back to `ink` if that still fails.

The repaired tokens are what `Design` exposes. Passing pairs are untouched. The rule, the pair set and the five-preset review set come from Astra's `docs/CONTRAST.md`, and I port it into `view/ui/Contrast.js` after your review.

The rule must be identical in the QML and in `contrast_audit.py`. A test runs both over the 96 presets and compares the results.

### 3.3 Reticle and the focus model (D15)

There is one `Reticle` in `Shell`, drawn as four sheared corner ticks around `Window.activeFocusItem`.
- It is visible only after keyboard navigation (Tab, arrows, hjkl, `[ ]`) and hidden on any pointer press. That is the "focus reticle shows only on keyboard use" rule.
- It moves with a `Tween` of `Motion.settle`, which is instant when motion is reduced.
- It owns no focus. It only draws.

| Key | Where | Action |
| --- | --- | --- |
| Tab / Shift+Tab | anywhere | next or previous control in the room, then the index, then the command line (the order exists today) |
| arrows | no text field focused | spatial move inside the room (below) |
| h j k l | no text field focused **and the reticle shown** | the same as the arrows |
| `[` / `]` | no text field focused | previous or next room (index order, wrapping) |
| `/` | no text field focused | focus the command line, inserting nothing |
| Escape | room control focused | back to the command line (a second Escape folds, as in M5) |
| Ctrl+0–8 | anywhere | the room shortcuts, kept |

**The hjkl conflict.** M5 sends any printable key, pressed with no text field focused, to the command line ("type anywhere", DAILY_DRIVER §4.1). So hjkl cannot also move focus. The table resolves it with a mode: hjkl move only while the reticle is shown, that is, after the user has already chosen to navigate by keyboard. Every other letter still goes to the command line and hides the reticle. Q2 asks you to choose between this and the alternatives.

**Spatial move.** `FocusMap` walks the room's item tree on demand (on a key press, never per frame). It collects the visible, enabled items with `activeFocusOnTab`, maps their centres into room coordinates, and picks the nearest item inside a ±45° cone in the pressed direction. The distance is weighted 1 along the axis and 2 across it. With no candidate, the move goes left into the index or up to the command line. Rooms can override it per item with `KeyNavigation`. List views move by row inside themselves first.

## 4. The canvas and the cut (replaces the diagonal index, D14)

Your review of 7 November: every room sat in the same frame (the index column on the left, the room on the right), so the UI felt repetitive. You chose both of your examples together: an infinite spatial canvas (pan and zoom between clusters, "the layout itself becomes navigation") and an asymmetric editorial layout after Persona 5 (large type, diagonal cuts, panels that transform). The material follows the YoRHa reference (§4.4). The studies are in the artifact "FART Shell Studies".

### 4.1 The canvas (`view/shell/Shell.qml`, `Cluster.qml`)

**Retired on 9 November 2026** (`m6-rooms`, job 5): the orbit is the canvas (§4.6, `docs/ORBIT.md`). The lattice, its map (`Ctrl+Shift+M`), the free canvas camera and its script calls, the `shell.travel` cue and its choreography, Alt+arrow neighbours, the links, `SheetGrid` and `ViewState.mapCamera` are gone. `Cluster.qml` became `RoomSheet.qml`: the shown room's sheet with its cut, at the field's margin. Kept as history below.

- **The field** is the panel between the header and the footer. It is a camera over one canvas. Each room is a **cluster** the size of the field, placed on a lattice that leans on the −12° shear: a snake in index order (Home, Media, Performance across; Workspaces, Devices, Tasks back; Timers, Clips, Inbox across), each nudged off the lattice (`Shell.stagePlan`: `u`, `v`, `jx`, `jy`).
- **Zoomed in**, the current cluster fills the field and the live room is laid over it (the one `Flickable` with the two `RoomSlot`s moves to the shown room's cluster). Every other cluster shows a still card (symbol, number, name, description), so the canvas costs nothing to keep.
- **Travel:** going to another room glides the camera there over `Motion.travel` (380 ms, InOutCubic, one `shell.travel` Cue) with a shallow zoom dip (12 %) mid-way. A new room chosen mid-travel retargets from where the camera is. Reduced motion cuts. Nothing moves at rest.
- **The map** (`Ctrl+M`, the map button, `Shell.overview`): the camera zooms out to the whole canvas; each cluster is a button (Tab, Enter, click) to its room; Escape or any room key returns. The open room stays live in its cluster.
- **Links** between clusters (each room to the next in index order, and three across) are dashed curves behind the sheets. A static ruling grid (`view/ui/SheetGrid.qml`, 12 px) covers the canvas and travels with it.

*As built (7 November 2026, night), the canvas made obvious, after the user's brief "it must not feel like page navigation disguised as a canvas":*
- **Neighbours in view.** A cluster is smaller than the field: `peekX` 92 px (44 compact) and `peekY` 46 px (26) on each side, across a 30 px `gap`, so the adjacent sheets (their wedges, grid and registration marks) show at every edge at rest. Each neighbour is named by a tag on its peek (`← 00 HOME`, `02 PERFORMANCE →`, `↑`/`↓`), which goes there on click. The room's box is the cluster's width minus the wedge, the ribbon and the gutters; the panel grew to 1360 × 860 to pay for the peeks.
- **Pan and zoom are real.**
  - **Pan:** drag the sheet with the left button anywhere a control does not take the press (peeks, gaps, the wedge, the map), or with the middle button anywhere.
  - **Zoom:** Ctrl+wheel or a touchpad pinch zooms about the pointer, from 0.7 × the map's fit to 1.15. On the map the plain wheel zooms too.
  - **Letting go** (or 260 ms after the last wheel step): above scale 0.6 the camera snaps to the nearest cluster, and that becomes the room. Below it the camera stays where it is, as the map.
  - `Alt+←/→/↑/↓` go to the spatial neighbour.
- **Persistent positions.** Clusters never move. The map's camera (`ViewState.mapCamera`, in `preferences.json`) is kept across opens, so the map reopens where it was left. `Ctrl+M` from a room returns to that view.
- **The API** (for scripts and `tools/measure/desktop_canvas.py`): `Shell.panCanvas(dx, dy)`, `zoomCanvas(px, py, factor)`, `releaseCanvas()`, `goDirection(dir)`, and `camera` `{ x, y, s, free }`.
- **Travel choreography,** all read from the one `shell.travel` value `t` (560 ms InOutQuart):
  - the room left behind retracts its wedge (`t` 0–0.32);
  - an ink slash with an accent edge crosses the field in the direction of travel (0.12–0.78);
  - the camera leans up to 1.4° and dips 20 %;
  - the arriving wedge slams in with an OutBack overshoot (0.52–1), and the room slides 48 px out from under it while fading in (0.42–1).
  - From a free camera there is no dip and no slash: the camera simply settles.

### 4.2 The cut (`view/ui/CutTitle.qml`)
- Each room has an ink **wedge** on one edge of its cluster: 150 px wide (104 compact), its outer edge at 78°, its inner edge straight against the room. The room's name runs along the outer edge in large Black type (a computed fit, `// scale:`), reading up on the left and down on the right, and the straight inner edge crops it where the wedge narrows.
- `Shell.cuts[id].side` (was `stagePlan.side`) puts the wedge left or right; `span` (0.58–1) and `align` set how much of the height it covers and from which end. Where it covers part of the height, the free part of the column carries the room's number (`figure`, accent) and its line (`voice`).
- The large type is only ever the room's name, never data.

### 4.3 The index ribbon (`view/shell/IndexBand.qml`)
- A column of nine tabs on the edge the room's wedge leaves free (`Shell.ribbonSide`), 60 px (40 below 640 px). At rest a numeral; selected, an inverted ink tab (number and fitted name) with a thin rule above and below. It moves to the other edge when the side changes. Ctrl+0–8 and `[ ]` are unchanged.
- Focus fallbacks follow the ribbon: from the room towards the ribbon's edge reaches the index, the other way returns (`FocusMap.fallback(zone, direction, side)`).
- Appearance, Archive and Power moved to the header, beside the orbit button (once the map button).

### 4.4 The sheet material (YoRHa reference)
- The reference is flicko's Hyprland YoRHa rice (no license: techniques only, no files). Built so far: the ruling grid, darkened left and right field edges (static gradients, 12 % of the width), inverted selection with rules (the ribbon), registration crosses on the clusters.
- **The inversion wipe** (`view/ui/Wipe.qml`): an ink plane wipes in from the left edge, its leading edge at 78°, over `Motion.feedback`; the control's text turns to paper past half-way. Selection adds a 1 px rule above and below. Used by `FButton` (hover, press, selected; primary and danger keep their fills), `FChoice` (hover, open) and `FToggle` (on). One sheared Rectangle in a clip, so a wipe re-tessellates nothing.
- **The pointer** (`view/ui/Pointer.qml`): a small arrowhead with a 78° back edge beside the chosen row: the `FChoice` popup's highlighted row and every `FMenuItem`.
- **Menus** (`view/ui/FMenuItem.qml`): a ruled row with a square node and the label, plus a right-aligned `detail` caption; hover or focus wipes it to ink with the pointer beside it. Home's upkeep and desk actions use it instead of button rows.
- **Hatched bands** (`view/ui/Hatch.qml`): 78° strokes as one tiled inline-SVG cell (`pitch` wide, pitch / tan 12° tall, so strokes meet across seams). Home's signal band carries one on its edge.
- Not yet built: a tan-paper preset (a host palette question).

### 4.5 Idle life (Silent, alive)

**Cut on 8 November 2026:** every loop below runs only in Overdrive (`Motion.overdrive`, off until M8). Their cost was over budget (B, ClaudeB_note §6), and the user cut them: at rest nothing moves.

The user, 7 November: Silent means resource-efficient, not lifeless. The kinetic principles are Persona 5's (expressive type, intentional micro-motion, subtle idle movement); the assets and palette are not.
- **One gate, one clock.**
  - `view/cues/Idle.qml` opens only while `Motion.ambient` (bound to `ViewState.ambientEnabled`, "Ambient detail") is on, motion is not reduced and the scope is visible. When the panel folds or the window hides, every loop stops.
  - `view/cues/IdleLoop.qml` gives a `phase` 0–1 per `period`. All loops read one shared clock, `Motion.idleNow`, ticking at 30 Hz only while at least one loop runs. So idle motion together redraws the window at most 30 times a second, never at the display's 144, and not at all when closed.
  - Running loops are reported as `idle.<name>` in `Motion.activeNames`. Raw `SequentialAnimation` or infinite loops outside `view/cues` fail `test_motion_goes_through_cues`.
- **Rule:** idle loops bind transforms, opacity or colour only, never width, height, anchors or Layout, so they add no polish.
- **The loops:**

  | Name | Where | What | Period |
  | --- | --- | --- | --- |
  | `field.scan` | Shell | a faint accent scan line down the field, then a rest | 9 s |
  | `field.motes` | Shell | 12 small squares rising through the field | 40 s |
  | `halo` | Halo | the back pills sway ±0.16 rad along the orbit (the front pill stays) | 12.8 s |
  | `cover.spin` / `cover.orbit` | CoverDisc | the cover turns while playing; paused, a comet circles the ring | 14 s / 7 s |
  | `cut.rail` | CutTitle | a hatch rail runs on the current room's wedge | 1.2 s |
  | `home.clock` | Home | the clock breathes towards the accent | 2.4 s |

- **Tests:** cuetest `view.idle.ambient` (loops run when shown with ambient on, none when hidden or off). The cue harness runs with ambient off, so its other checks measure cues alone.
- **Measured:** by Claude B (`tools/measure/desktop_idle.py`, `desktop_canvas.py`), to be added here.

*History:* step 4 built the diagonal index (`83cb91d`); this section replaces it.

### 4.6 The orbit (`view/shell/OrbitSystem.qml`)

The orbit is the canvas: Home at the centre, rooms 01–08 on concentric orbits, seen from 45° and sheared to 78°, and every switch flies through it. The tiles are house tiles, not pictures of planets. `docs/ORBIT.md` §0 has the decisions and the as-built notes, and `docs/DESIGN_SYSTEM.md` §5 the summary. It replaced §4.1's lattice on 9 November.

## 5. Montage per room (Silent)

Each room follows the same pattern:
- One hero.
- At most 2 elements that ever move (D12).
- At least one untouched span of 3+ grid columns.
- Planes from §3.1 only.

Each row below lists the room decisions PROJECT_PLAN puts in M6 and Astra's P3 acceptance evidence. The "Core/adapter work" column is what is not built yet; where the backend already exists it says so.

| Room | Hero and planes | M6 features | Core or adapter work | Acceptance (P3 and plan) |
| --- | --- | --- | --- | --- |
| **Home** | Portrait cut into planes (`ShapePath.fillItem`, no offscreen mask), with the sky showing through the gaps. Slanted display clock and date. | Today strip (next task, timer, now playing; each one clicks through to its room). Mini calendar with due marks. Action row (Wallpaper, Presets, Settings, Lock, Updates). Spotify player preference. | `CoreTasks` due dates (core has them, `core/tasks.py`). The player rule moves into `media` (Q6). | Each strip item is reachable by keyboard and goes to its room. An absent portrait, player or task is a designed empty state. |
| **Media** | Album art cut into planes. Mirror seek bar of −12° blades (spectrum mirrored around the seek line; the played part solid, the unplayed part faint; the whole bar seeks). | Karaoke lyrics: word fill, fading neighbours, small mono translation lines. Subpanels (Lyrics, Output, Player, Equalizer, Local .lrc), only the active one loaded. | Lyrics order: host cache (read-only), then lrclib, then FART's cache (`LyricsSource` exists). EQ through the `equalizer` domain, never a second filter chain. | Long metadata, missing or remote art, player loss and lyrics failure all keep the controls usable. One analyser. ≤ 5% CPU playing. |
| **Performance** | One large readout plane, with graphs on paper. *As built:* the halo (`view/ui/Halo.qml`), a tilted 3D orbit of leaning pills: the selected reading is the accent pill at the front and large in the centre, with its figures as tiles under it and its trace beside it. | AI model block (Ollama `/api/ps` at the configured host). `dGPU · ASLEEP` unless `runtime_status` is already active. A one-tap Performance power mode when a model loads. | Ollama polling only while the room is open. It is new, so it goes through the adapter, `system` domain. | Unavailable is distinct from zero. Histories are bounded. NVIDIA is never woken. |
| **Workspaces** | Geometry miniatures on a 78° plane stack. | Event-driven geometry overview (D22, Silent part). | The adapter's `Quickshell.Hyprland` models are already event-driven; window geometry is added to `workspaces` (the core's Hyprland socket is a guard used only under Overdrive, so it is not used here). | Multiple outputs and scales, special workspaces, odd aspect ratios map correctly. **Navigation budget met** (§8). |
| **Devices** | Two toggle planes (Wi-Fi, Bluetooth), each one click away. | Power mode. Wi-Fi and BT quick connect. | `network.scan/connect` and `bluetooth.connect` exist (M1, unused). | Clear enabled, disabled and error states. Tested on the fixture only; live checks are read-only (no toggling). |
| **Tasks** | A list plane per task list. | Lists and due dates, overdue in signal (no nagging). The surveyor nearby (finite reactions). | Done in the core (M2). | Empty and long lists, undo races, keyboard entry, persistent drafts. No duplicate commits. |
| **Timers** | One large display numeral plane. | — (the DONE satellite shipped in M5) | — | Completion while closed, pause and resume, sleep and wake, laps. The service stays authoritative. |
| **Clips** | The result list on paper; the selected row inverted. | `clip <query>` drives the filter (M5 left it unread). Image thumbnails decoded small, only for visible rows. | `sourceSize` decode, `ListView` reuse | Large histories stay responsive. External deletion is handled. No private preview in reports. |
| **Inbox** | A grouped list, with critical items in signal. | The private-apps list UI. Clear. | Both exist in the core (`notifications.private_apps`). | Bursts, long bodies, persistent items. No duplicate popup, no stolen focus. |

*As built (7 November 2026, night), the editorial rooms on the canvas:*
- **Media** is a spread. The round cover (`view/ui/CoverDisc.qml`, up to 340 px) sits inside an **audio ring** of 64 radial ticks: their length follows the spectrum while playing (the `spectrum` lease, ambient on), and the ticks up to the position are in the accent, so the ring is also the track's clock. An offset accent outline of the disc sits down and to the left. The transport is centred under the cover. On the right: the artist on an ink tag, the title as large as two lines of the column allow (`Text.Fit`, up to 112 px, `// scale:`), the album, then the **lyrics** (the line before faint, the current one in the accent at `readout` Bold, two after muted) or, with lyrics off, the source and the remark; then a short seek band and the times. The foot keeps Open player, Lyrics and the cat.
- **Home:** the media card is now an open band between two node rules, with a hatched edge and the `CoverDisc` thin ring (the position arc). The resident's name is on an ink tag. The two button rows became two sheet menus, UPKEEP (Check updates with its state as the detail, Host updates…, Update FART) and DESK (Wallpaper, Presets, Settings).
- **Performance** is unchanged in this pass (the instrument sheet and the halo).

*As built (branch `m6-rooms`, Claude B, 7 November 2026):*
- **Tasks:** the head names the lists as sheet tabs (the selected one inverted, ruled above and below). The entry line reads `@list` and `!due` exactly as the `task` verb (`view/rooms/TaskEntry.js`, tested against `core/verbs/tasks.py`) and shows how it will be read before Enter; an unknown `@list` is created. Lines (`TaskRow`) carry a 78° check, the user's words upright in the sans at `readout`, and the due date; overdue is in signal and stated ("05 NOV · 2 D LATE"), never scolded. The plate beside the sheet: open (display), today, late, done, the voice, the surveyor, Begin focus.
- **Timers:** the modes are the head's tabs; the numeral sits between four registration marks. The ruler is sixty −12° blades, the elapsed part a clipped copy in signal (a tick moves one clip edge). Focus shows the set's cycles as leaning pills; the stopwatch its last four splits, the fastest in signal.
- **Devices:** Wi-Fi and Bluetooth are whole 78° planes, filled with signal when on (`LinkPlane`). The power mode is a row of sheet tabs. The link panel has three pages: the mixer (default), nearby networks and paired devices (`LinkRow`). The `scan` lease is held only while the nearby page is shown (smoke checks Devices does not hold it).
- **Workspaces:** one large geometry miniature (the current workspace, or the plane being looked at) beside a stack of 78° planes; hover or focus previews, a click goes. The window lines always list the current workspace. §8's trim is met: 27 → 0 steady misses (8 passes, desktop, fixture view).
- `SheetTab` (room-local) does statically what `view/ui/Wipe.qml` (Claude A) animates; after the merge it should use `Wipe`.

The creatures (CUES Q7) are revisited here. The cat stays in Media, reacting to music; the surveyor goes near Tasks. Both keep their finite reactions and gain no idle animation.

## 6. DESIGN_SYSTEM

`docs/DESIGN_SYSTEM.md` is new and replaces the archive's version, which describes end-4 paths and a fixed palette. It records:
- The roles and the guard.
- The scale, the grid and the angles.
- The plane, index and reticle.
- The density budget.
- The voice rules, which stay as they are: uppercase is the system voice, lowercase italics are asides, CJK stays upright, and critical states carry no jokes.

It is written last, from what was built.

## 7. What stays

The M5 shell (unfold, command line, satellites, sound), the cue system and the §15 motion profile, the room slot swap and precompiler, the adapter contract, and every core verb. M6 adds no dependency.

## 8. Workspaces navigation trim

M5 measured 28–37 steady misses on Workspaces, against a budget of 0. The nav-timing note blamed its polish on the swap frame (8–26 ms). The M6 rebuild of the room is the place to fix it:
- Miniatures as plain `Rectangle`s in a `Repeater` keyed by window address, with no `Shape`s.
- Geometry updated from Hyprland events rather than rebuilt.
- No `Layout` nesting deeper than 2.

This is measured before and after on the fixture view, quiet runs only.

## 9. Risks

- **The 12 px body on a translucent panel.** The backing-plane rule is what keeps it legible. If the guard has to move many host colours, the host identity weakens. Astra's audit reports ΔL per preset, so we see it before porting.
- **Spatial navigation in lists and flows.** A `Flow` or `GridView` can strand items. The keytest walks every room to catch it.
- **The scope is large.** Hence the batches in §10, each one reviewable and mergeable on its own.

## 10. Implementation order (after review)

Each step is a commit series on `m6-design`, then a checkpoint (HANDOFF entry, tests, smoke, `qmllint` syntax). Steps 1–3 can merge before the rooms. I recommend a merge after each of steps 3, 5 and 7 (Q4).

1. Tokens: the type scale and the 33 literals, then the grid and slope. A visual check by you (screenshot through the fixture view).
2. The contrast guard (after `CONTRAST.md` is reviewed): `Contrast.js`, the `Design` wiring, and the audit test.
3. `Plane`, `FocusMap`, `Reticle` and the key table. `keytest.py`.
4. The diagonal index and band title plane. Rooms drop `FHeading`.
5. Rooms, batch A (daily core): Home, Tasks, Timers.
6. Rooms, batch B: Media (blades, karaoke, subpanels), Devices, Performance.
7. Rooms, batch C: Workspaces (with the §8 trim), Clips, Inbox. The creatures.
8. DESIGN_SYSTEM.md. Then the full budget pass: contrast, keytest, idle per room, navigation, and Media playing when you start playback.

## 11. Questions for review

| # | Question | Recommendation | Alternative |
| --- | --- | --- | --- |
| Q1 | Plane renderer | **Two renderers behind one API** (a sheared Rectangle for plain planes, a Shape for cut planes) | `Shape` everywhere: simpler, but every plane becomes a geometry node and is re-tessellated on resize |
| Q2 | hjkl versus type-anywhere | **hjkl move only while the reticle is shown**; otherwise they type into the command line | (a) hjkl always move and type-anywhere loses those four letters; (b) no hjkl, arrows only |
| Q3 | Room titles | **The selected band is the title**; rooms drop `FHeading` | Keep a heading in each room and the band stays a selector |
| Q4 | Merge cadence | **Merge after steps 3, 5 and 7**, each after your review | One merge at the end of M6 |
| Q5 | The Home sky before M10 | **A static field tinted by palette roles and the time of day** (4 states, redrawn on the hour) | Leave the gaps as plain paper until M10 |
| Q6 | The Spotify preference (Home, Media) | **Move the rule into the adapter's `media.active`** (Spotify wins unless paused while another plays), configurable, so both rooms and the satellite agree | Keep it per room in the view |
| Q7 | The 12 px body | **Adopt it in step 1 and judge it on screen**, with 13 px as the fallback | Keep 15 px body until the montage is done |

## 12. Review decisions (7 November 2026)

You approved every recommendation in section 11: Q1 two renderers behind one API; Q2 hjkl only while the reticle is shown; Q3 the selected band is the title; Q4 merges after steps 3, 5 and 7; Q5 a static palette and time-of-day sky; Q6 the player rule in the adapter's `media.active`; Q7 the 12 px body, judged on screen in step 1, with 13 px as the fallback.

Step 1 check (7 November 2026): you accepted the 12 px body on screen; the 13 px fallback is not needed.
