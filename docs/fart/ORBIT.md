# Orbital mechanics: the overview as a solar system

**Main goal for 8 November 2026.** This is a brief, and nothing is built yet. Claude A owns the build; Claude B measures it and supplies the faces of B's rooms (see §8). Do not merge or push without the user's approval. **Don't ask questions mid-build:** the user said to collect them and ask them all tomorrow. They are in HANDOFF.md's top entry.

## 0. Decided on 8 November 2026 (these override the text below)

- **The view is 45° above the plane** (90° would be straight down). The user first set 60° and then asked for "a bit more" angle for the 3D effect. Every orbit projects to an ellipse **0.707** as high as it is wide. Depth is strong: scale 0.78 → 1.16 and opacity 0.6 → 1.0, back to front.
- **The whole system leans 12°**, the house angle. Since the 3D pass it is FART's shear rather than a rotation: verticals (the stalks) lean to 78° like the tiles' edges, and the rings' long axis rises a little to the right.
- **3D, not panels orbiting** (8 November, evening): a perspective camera at 3.4 outer radii (near half larger, far half fainter and dashed); tiles float on stalks over shadows; the plane swings in flight (31° mid-switch, 62° → 45° on opening) and the tiles rise out of it one orbit after another as the orbit opens. Sounds `orbit.out`, `orbit.land` and `orbit.hover` go through the core's gate. The first two are FART's own whooshes (`tools/sounds/make_whoosh.py`, `assets/sounds/`); hover is the host's tick.
- **The solar system is a metaphor, not a picture.** Nothing looks like a literal planet or sun: no spheres, shading, rings or textures. Each room is a small FART tile (a sheared `Plane`) with its number, symbol and name. The highlighted tile is filled with the signal colour, and the current room is ink. Home in the centre is a larger tile with the clock. The orbits are hairlines, dashed except the current room's (signal) and the highlighted one's (ink).
- **Small tiles plus a side readout.** Seen this steeply the system is nearly round, so in the panel the 8 orbits are only about 31 px apart and the tiles are wider than that gap. The tiles are spread on a golden-angle spiral, so none touch. The free width on the left holds the readout: the highlighted room's number, name, line and description.
- **Fixed places:** each room always comes back to its stored angle (`ViewState.orbitAngles`, or the spiral). **Today's order:** 01 Media is the innermost orbit.
- **Every switch flies through the orbit** (user: "zoom out to show the orbit and then move to the selected tab"):
  - the room shrinks into its tile until the whole system shows;
  - a streak crosses from that tile to the chosen one;
  - the camera dives into the chosen tile until its room fills the field.
- **Idle motion is cut.** Idle loops, the breathing playback dot, the Media cat and the spectrum ring only run in **Overdrive** (`Motion.overdrive`, off; M8+ makes everything animate). At rest nothing moves.

### As built (step 1, `view/shell/Orbit.js`, `OrbitSystem.qml`, `OrbitTile.qml`)
- `Ctrl+M` and the header's hub button open the orbit over the field. The lattice map stays on `Ctrl+Shift+M` until the transfer (step 2) retires it. The orbit is a `Loader`, so closed it isn't instantiated.
- **Keys:**
  - the arrows (and hjkl) move to the nearest tile on screen, using `FocusMap.pick`, then the nearest tile ahead if the 45° cone is empty;
  - Tab and `]` / Shift+Tab and `[` walk 00 → 08 and wrap;
  - `0`–`8` land directly, as do Enter, Space and a click (today's travel);
  - Esc returns to the room you came from.
- The pointer hovers and clicks. Pan and zoom are off over the orbit for now (they belong to step 2's canvas).
- **At rest nothing runs.** The lattice's scan and motes and the hidden room's loops stop while the orbit is open (cuetest `orbit.rest`).
- Deviation from §2/§5: the tile numeral is set at half the tile's height, not `display`, which can't fit a 60 px tile. There are no separate square nodes: the tile sits on its orbit as its node.

### As built (the flight, step 2 part 1)
- **One `Cue`, `orbit.transfer`, drives the orbit camera** (`Shell` field: `fly()`, `orbitCam`, `lensRect`). Its key frames are `"overview"`, `"room:<id>"`, or the camera where it was when a new flight starts mid-way, so a burst retargets and never jumps.
- **A switch** (`Motion.transfer`, 1000 ms) runs in three parts:
  - 0 → 0.34: the room zooms out into its tile, anchored on the tile so it shrinks in place;
  - 0.34 → 0.6: a drift towards the chosen room while the streak (a dashed arc bowed away from Home, with a solid trail and a signal head) crosses;
  - 0.6 → 1: a dive into the chosen tile, anchored on it.
- **Opening (`Ctrl+M`), closing (Esc) and landing from the orbit** are one zoom each (`Motion.zoom`, 440 ms).
- **The lens:** the live room (the lattice stage) is drawn in the shown room's tile through the camera, clipped. It fades out below 0.46 of the field and is gone at tile size (< 0.16).
  - The room left stays live until the zoom-out ends (`swapReady`), and the new room swaps in at the drift.
  - In flight only the shown room's cluster is drawn: the curve renderer's shapes (the cut wedges, the links) ignore the lens clip under its scale.
- The orbit is loaded only while it is open or in flight. Reduced motion settles every flight at once.
- **Rooms no longer peek in** (8 November, the user's review): a room fills the field but for a 16 px margin, and the lattice (other clusters, links, neighbour tags, pan and zoom) shows only on the old map.
- **Hover:** tiles sweep the signal colour in along 78°, lift and grow a little (Tweens, so only while the highlight moves).
- **Drag through space** (8 November, evening): in a room, a drag (or Ctrl+wheel, a pinch) pulls the room out into its tile and the orbit around it; letting go springs back, or opens the orbit past a third. In the orbit, drag pans, the wheel zooms about the pointer, a release glides on and stays. The readout doesn't move with the camera.
- **Other systems** (8 November, night; `SpaceSystem.qml`): Workspaces (desks as moons, click switches) and Media (transport and players as moons, click acts) lie out in space beyond their planets, joined by dotted routes. A compass chip points home when the camera wanders (`.`, Home, double-click glide back); `G` frames the whole galaxy, keeping its suns out of the compass's band along the bottom (`systemBottom`; the compass once sat on Media's sun). `tools/cuetest/OrbitHitTest.qml` (in `tests/test_orbit.py`) checks every tile and every framed sun takes the pointer. These are the "moons" of §7, built as separate systems rather than moons around the planet tiles.
- **Every room a system** (8 November, late; `RoomSystems.qml`, `SunFace.qml`): all eight rooms have their own system on a ring of eight slots around the main one (each room in the slot nearest its planet's direction; the diagonal slots reach further, so no system meets another or the main system at any panel size). Moons act: Performance's readings (lease `resources` while open), Devices' switches (Wi-Fi, Bluetooth, output and mic mute, night light, stay awake), Tasks' open tasks (a click ticks one off), Timers' three instruments (start or pause; 1 Hz only while one runs), Clips' latest clips by kind only, never their text (a click copies one again; lease `history`), Inbox's quiet hours, mark-all-read and apps by unread count.
- **Zoom** (same night): the wheel and `-`/`=` glide (~0.1 s) from 20 % to 1000 %; an on-screen bar (−, level, +, every system) sits bottom right. Zooming into a room's tile, Home or a system's sun shows "ZOOM IN TO ENTER" filling as it nears, and dives into that room when the tile is three fifths of the field wide.
- **Spacetime fabric** (same night; `view/strata/SpaceFabric.qml`, the first stratum): a grid mesh a little under the orbit's plane, pressed down by Home, each room (the current one deeper) and each system's sun; a switch or a choice sends one ripple across it. GPU only (vertex-displaced `GridMesh`, uniforms for tilt, masses and ripple); absent under the software renderer, so offscreen shots don't show it (`tools/shots.py --window` does).
- **Systems build after the open** (8 November, after midnight): built once the orbit is open and still (or dragged), asynchronously, faded in, at the rest tilt; building them during the opening flight was the overview's lag.
- **Fullscreen** is an option (F11, `F` in the orbit, the header, Instrument settings): the whole panel covers the screen on the overlay layer. The separate fullscreen orbit layer of §3 is not built.
- **The fabric under every moon** (8 November): each room system's moons press their own small wells (depth 0.6 tile heights, radius 0.45 tile widths), deepening as the systems fade in. `SpaceFabric` has 80 wells (`wellCount`; Home, 8 rooms and 8 suns first, then the moons). `SpaceSystem.feet` follows only the moons' ring layout, so a reading changing on a moon doesn't move the wells.
- **Not done:** the lattice is still under the room (it snaps to the shown room; its travel cue only serves `Ctrl+Shift+M`); there is no distance scaling of the duration yet; pan and zoom in space are still off.

## 1. What the user asked (7 November 2026, night)

> "the infinite scroll inspiration is there, but i still feel like it's not enough. Like niri's overview, i should be able to click some keybind and it should show all the tabs, but showing all the tabs bare is kinda bad, so i propose **ORBITAL MECHANICS**: like the solar system, Home will be the Sun and 01–08 will be orbiting Home just like planets … and when we switch tabs, it should feel like we're moving from one planet to the other … i recommend having a full screen version and a non full screen version … this will tie in so well with all the other orbit halo things being like planets or moons of the tab (not telling you to implement the submoon part)."

The user wants five things:
1. **One keybind shows every room at once**, as niri's overview does, but staged as a system rather than a bare grid.
2. **Home is the Sun, and rooms 01–08 are planets** orbiting it.
3. **Switching rooms is interplanetary travel**: you leave one planet and arrive at another. This applies to every switch, not only the overview.
4. **Two sizes:** in the panel (1360 × 860), and a **fullscreen** version.
5. **Moons are future work.** The halos inside rooms (Workspaces' desks, Home's ring) would be the moons of their planet. Leave room for this in the design, but **don't build it**.

## 2. The system

The planets keep the current page order (`Shell.pages`), so `Ctrl+1…8` and the number tags stay true:

| Orbit | Planet | Orbit | Planet |
| --- | --- | --- | --- |
| 00 | **Home**, the Sun | 05 | Tasks |
| 01 | Media | 06 | Timers |
| 02 | Performance | 07 | Clipboard |
| 03 | Workspaces | 08 | Notifications |
| 04 | Devices | | |

**Geometry.** This stays in FART's one angle family:
- The orbits are concentric ellipses on one plane, seen at a tilt (minor/major about 0.32, the Halo's 3D style). The major axis is rotated −12°.
- Depth is faked as it is in `Halo`: a planet in front of the Sun is larger, in full ink, and drawn over it; a planet behind is smaller, dimmer and partly hidden by the Sun's disc.
- The orbit radii grow outwards. Orbit 01 is close; 08 sits near the frame's edge.
- Orbits are hairlines with square nodes at the planet. The current room's orbit is drawn in the signal colour.
- Planet sizes vary a little, so the system doesn't read as a grid: bigger for rooms with more in them (Media, Workspaces, Tasks), smaller for Clipboard and Notifications.

**Planets.** A planet is a disc showing that room's **face** (§5): its number, name in Black, and one live fact. The Sun is Home's face: the clock, the resident's ink tag and the signal ring. Planets are discs, while rooms are sheets: that contrast is what makes the overview different from the lattice map.

**Positions persist.** Each planet's angle on its orbit is stored (`ViewState`, next to `mapCamera`), so the system looks the same next time. Angles only change when the system moves (§6). A room is never somewhere unexpected.

## 3. The keybind and the two sizes

- **In the panel:** `Ctrl+M` becomes the orbit. Today's lattice map is replaced, or kept on `Ctrl+Shift+M` while we compare them. The orbit fills the panel's field. Esc returns to the room you came from.
- **Fullscreen:** a second `PanelWindow` on `WlrLayer.Overlay`, anchored to all edges, with exclusive keyboard focus while open. The same `OrbitSystem` component is drawn at the screen's size, and the screen's edges are darkened like the sheet. Choosing a planet closes the fullscreen layer and opens the panel on that room. Inside FART it opens with `Ctrl+Shift+Space`, or with `F` from the windowed orbit.
- **A global key** (niri's "press a key anywhere"): fart-next gets an IPC verb, `fart_next.py overview [--full]`. **Adding the Hyprland bind needs the user's approval** (AGENTS.md). Propose a key, don't add it.
- **Keyboard inside the orbit:**
  - ←/→ move along the order (01→02…), and ↑/↓ move between inner and outer orbits;
  - `1`–`8` and `0` choose a planet directly;
  - Enter lands, and Esc leaves;
  - `F` toggles fullscreen.
  The pointer hovers and clicks planets, and the wheel or pinch zooms the system. keytest gets these cases.

## 4. Travel: "moving from one planet to the other"

Room switching becomes a transfer orbit. It is still one `shell.travel` value `t`, so it retargets and respects reduced motion as travel does now:
1. **Lift off** (`t` 0–0.25): the room you're leaving keeps its **live** content (B's finding: swapping to the still card on the first frame reads as a page change). It shrinks to its planet, and the camera pulls back until both orbits are in view.
2. **Transfer** (0.2–0.8): the camera follows a **Hohmann-like arc**, an ellipse segment tangent to the departure orbit and the arrival orbit, passing around the Sun. An ink slash with its signal edge rides the arc, as the slash crosses the field today. Going outward and going inward feel different: outward climbs with ease-out, inward falls with ease-in.
3. **Landing** (0.7–1): the arriving planet grows into its room. The wedge slams in with the existing outBack, and the content slides out from under the cut.

- **Duration:** about 560 ms for neighbouring orbits, scaled by the orbit distance up to about 800 ms (Home to 08). The travel token gains a distance factor; it doesn't get a second cue.
- **Inside a room, neighbours stay visible.** The peeks at the panel's edges show where you are in the system: the arcs of your orbit and the next one in, with the nearest planets on them. This replaces the lattice neighbours and their tags.
- Alt+arrows mean "inward / outward / along the orbit" instead of lattice directions.
- Pan and zoom still work: zooming out from a room passes through orbit view continuously, and letting go below the threshold stays in the system (it stays as the map today).

**Decided by the user (7 November, late):** the orbit **replaces the lattice as the canvas itself**. Rooms live at their planet positions, and every switch is a transfer. The lattice (`stagePlan` u/v, the lattice neighbours and the lattice map) goes once the orbit works. Build the overview first (§9 step 1), then the transfer.

## 5. Faces: what a planet shows

Each room provides a small, event-driven summary, `view/faces/<Room>Face.qml`. It is a circle about 180 px across at scale 1, read from the same services as the room. It never animates at rest, and it is loaded only while the orbit is visible.

| Planet | One live fact (first ideas) |
| --- | --- |
| Home (Sun) | the clock, the resident's tag |
| Media | the cover disc and the title, with its ring when playing |
| Performance | CPU and memory as two arcs |
| Workspaces | the desk count, and the current desk's number in ink |
| Devices | link state (Wi-Fi, Bluetooth, audio out), and the recording dot |
| Tasks | open/overdue count |
| Timers | the next timer's remaining time, stepped once per second |
| Clipboard | the item count only (no contents, privacy) |
| Notifications | the unread count only (no contents, privacy) |

## 6. Motion and its budget

B measured (`ClaudeB_note.md` §1 and §6, `docs/measurements/c66f20e-*`): **a drawn frame costs about 4.5–5 ms of CPU here, whatever moves**, so the 2 % open-at-rest budget allows about **4 frames per second in total**. A system of planets that orbits continuously at vsync would cost about 45 % of a core. Therefore:
- **At rest the system is still.** The planets don't drift while you look at them.
- **Opening the overview is the flourish:** the system spins up into place over about 600 ms. The planets advance along their orbits from their last angles (inner orbits faster, as in Kepler) and then stop. That is the one time it moves "by itself".
- **Idle as bursts:** every 20–30 s, one planet's face, or one orbit's signal node, plays a single cycle (staggered, never two at once). This is the pattern B recommends for all of today's idle loops (§10).
- **Interaction draws as much as it needs:** hover, pan, zoom and travel run at vsync while they last, then the frame rate falls back to the burst budget.
- **Faces are textures at rest:** each face is drawn once into a layer and updated only when its fact changes.
- **Fullscreen:** at the screen's size a frame costs more. B measures it separately; if a fullscreen frame costs much more than a panel frame, the flourish gets shorter.
- **Reduced motion:** no spin-up and no transfer arc. The system appears, travel cross-fades with the existing short `navigate` motion, and there are no bursts.
- **Closed:** 0 CPU ticks, as now. The fullscreen layer is destroyed, not hidden, when it closes.

## 7. How it ties in (later, not tomorrow)

The halos inside rooms become **moons**: Workspaces' desk pills orbit planet 03, and Home's ring orbits the Sun. The data model leaves a `moons` list per planet, empty for now. The user said explicitly: don't implement the moons yet.

## 8. Who does what

**Claude A** (`m6-design`):
- `view/shell/OrbitSystem.qml`: the scene, planets, orbits, depth, hit testing and the keyboard;
- the overview in the panel and the fullscreen layer;
- the transfer choreography in `Shell`;
- faces for Home, Media, Performance, Workspaces, Clipboard and Notifications;
- the IPC verb `overview`;
- MONTAGE §4 gets an "Orbit" section.
- A also turns today's idle loops into bursts (§10).

**Claude B** (`m6-rooms`), without editing A's tree:
1. **Faces for Tasks, Timers and Devices** in `view/faces/` on B's branch, to the contract in §5: a circle about 180 px, `required property` inputs only from existing services, and no animation at rest. The Timers face steps once per second at most.
2. **Measure the orbit prototype** when A gives the hash:
   - opening and closing the overview, windowed and fullscreen;
   - near (01→02) and far (00→08) transfers;
   - the overview at rest for 60 s;
   - the fullscreen layer's RSS/PSS against the panel alone;
   - closed: still 0.
   Record the frame interval p50/p99 and missed frames. Script it with A's API (A will name it the way it named `panCanvas`).
3. **The review page:** frame sequences of the spin-up and of a near and far transfer, for the user's review page (`demo_frames.py`).
4. **keytest cases** for the orbit keys (§3) once A's names are fixed.

## 9. Order of work tomorrow

1. **The windowed overview, still:** the Sun, eight planets with placeholder faces, orbits, depth, persisted angles, keyboard and pointer, and landing on Enter or click (with today's travel). Show it to the user live (`fart_next.py open`).
2. **The orbit as the canvas** (decided, §4): the transfer travel, the orbit neighbours as peeks, and then retire the lattice.
3. **Fullscreen**, then the IPC verb. Propose the global key.
4. **The spin-up flourish and bursts.** B measures, and A adjusts until it is within budget.
5. **Real faces** (A's and B's), then MONTAGE, HANDOFF and tests (contract, layout, keytest, cuetest: `orbit.spinup`, `orbit.transfer.near` and `orbit.transfer.far` cues).

## 10. Also carried into tomorrow (from B's measurements)

- **Idle loops become bursts or a 2 Hz step.** At the 30 Hz clock they cost 13.7–17.2 %, and even 4 Hz is over budget. Give `Idle` a burst mode (one cycle every 15–30 s, staggered) and re-measure with `desktop_idle --rooms all`.
- **`FStatusDot`'s breathing `Pulse`** keeps the window at 145 fps while music plays (about 46–50 % of a core). Make it a 1–2 Hz step or a one-shot pulse on state change. It belongs to `view/ui`, so A fixes it.
- **The live room is kept until it is off screen** during travel, instead of swapping to the still card on the first frame (§4).
- The 2 fps cursor blink at rest: confirm it, and stop it while the command line isn't focused.
