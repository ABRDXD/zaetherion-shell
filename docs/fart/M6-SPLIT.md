# M6 split: Claude A and Claude B (alive Silent, obvious canvas)

Written by Claude B on 7 November 2026, about 21:05, before starting work on the user's two new requirements. **Amended at about 21:35 to agree with Claude A's `ClaudeA_note.md` (21:11)**, which relays what the user told A directly: Workspaces is A's halo, and B measures. Where this file and A's note differ, A's note wins. B's reply is `ClaudeB_note.md` in `../next-m6-rooms`.

## The user's brief (7 November 2026, evening)

1. **Silent must still feel alive.** Silent means resource-efficient, not lifeless. Follow Persona 5's kinetic principles: expressive type, intentional microanimations, subtle idle movement, personality. Use event-driven or infrequent animation with measured CPU, memory and frame-time costs. No constant full-layout updates. Respect reduced motion.
2. **The infinite canvas must be obvious.** Neighbouring regions visible, meaningful pan and zoom, persistent positions, camera movement between clusters, a clear zoomed-out overview. Not page navigation dressed up as a canvas.
- Keep FART-next's identity. Take Persona 5's principles, not its assets or palette.
- Art direction and interaction before decorative complexity.
- **Order:** prototype the spatial navigation and the idle motion first, show them visually, measure them, and only then integrate broadly.
- **No merge and no push without the user's approval.**

## What exists right now

- **Claude A, `../next-m6` (`m6-design`, `b3717e9`), with uncommitted work at 21:01:**
  - `view/cues/Idle.qml`: an idle-loop gate. It runs only with ambient motion on, motion not reduced and the scope visible, and it reports `idle.<name>` to `Motion.activeNames`.
  - `Motion.ambient`, travel at 560 ms InOutQuart.
  - Changes in Shell, Cluster, CutTitle, Halo, CoverDisc, Home, Media and ViewTest.
  - **A rewritten `view/rooms/Workspaces.qml`**: a halo of workspace pills, a "burst" into the workspace's sheet, and Enter to switch.
- **Claude B, `../next-m6-rooms` (`m6-rooms`, `022237f`+):** Tasks, Timers, Devices and Workspaces rebuilt and committed, not merged. This Workspaces is a geometry miniature beside a 78° stack and meets the §8 navigation budget (27 → 0 steady misses, measured).

## The split

| Area | Owner | Notes |
| --- | --- | --- |
| **Spatial navigation prototype**: camera, clusters, neighbours visible at the field's edges, pan (drag, keys) and zoom (wheel, pinch), persistent camera and room positions, travel between clusters, the overview map | **A** | `view/shell/` (Shell, Cluster, IndexBand, Overlay). A already owns the canvas and is changing it now. |
| **Idle-motion framework**: `Idle.qml`, `Motion.ambient`, the reduced-motion and visibility gates, the shared kinetic vocabulary (type entrances, cut wipes, ambient drift) in primitives | **A** | `view/cues/`, `view/ui/`. One gate for every idle loop, so the measurement has a single switch. |
| Idle and kinetic touches in Home, Media, Performance, the cut titles and the ribbon | **A** | |
| **Measurement of both prototypes** (below) | **B** | `tools/measure/` only. New files where possible; any edit to an existing measure tool is announced in B's HANDOFF entry. |
| **Visual demonstration**: offscreen frame sequences of a travel, the overview zoom-out and back, a pan, and each idle loop, made into a contact sheet and a private review page | **B** | A new tool, `tools/demo_frames.py`. It uses the fixture view and changes no view code. |
| Kinetic and idle touches in Tasks, Timers and Devices | **B**: proposals now (HANDOFF), built **after** the user approves A's framework | Through A's `Idle` gate and `Motion` tokens only; no loops of B's own (`test_motion_goes_through_cues`). |
| Tests for idle gating (reduced motion → no `idle.*` activity; panel folded → none; ambient off → none) | **A** writes them in `tools/cuetest/ViewTest.qml`; **B** runs them in the measurement | ViewTest stays A's file, to avoid two editors. |
| **Workspaces** | **A** (the user asked A for the halo burst) | A's halo replaces the room. After the merge, B moves its geometry miniature (with hover-preview) into the `map` item of the halo's desk sheet and keeps the §8 navigation budget. The halo, the burst and the orbit stay A's. B's fixture additions stay. |
| Tasks, Timers, Devices on the larger panel (1360 × 860, and 860 wide); `SheetTab` on `Wipe`; `Pointer` on the chosen task row | **B** | `Wipe` and `Pointer` are on `m6-design` only, so that part waits for the user's OK to merge `m6-design` into `m6-rooms`. |
| MONTAGE §4 (canvas, idle: §4.5) | **A** | B adds measurement results under a "Measured" heading in §4 only after A has written the section. |
| MONTAGE §5 "As built" for B's four rooms, `docs/measurements/` | **B** | |
| HANDOFF.md | both | Each adds its own top entry. On merge, keep both. |

## How the measurement will judge the prototypes (B)

Run against the fixture view on the desktop, quiet runs only (interrupted runs are excluded, not counted). Results are reported per prototype with ambient on, ambient off and reduced motion:

- **Travel and overview:** GUI frame intervals during each camera move (median, p95, p99, max, misses over 1.5 periods at the monitor's refresh rate), GPU and render-thread time, and polish per frame. These come from the existing `frames.py` machinery, extended to mark travel segments. Target: the PROJECT_PLAN navigation budget (p99 ≤ 6.9 ms at 144 Hz, 0 steady misses).
- **Idle, open and at rest, per room:** CPU % of one core over 60 s, frames per second actually drawn (sustained, not nominal vsync), and RSS and PSS separately, with shared mappings noted. Targets are MONTAGE §1: ≤ 2 % static Silent, and no new cost when closed (0 frames, 0 ticks).
- **Gating:** with reduced motion, ambient off or the panel folded, `Motion.activeNames` has no `idle.*` and the frame count at rest is 0.
- **Layout:** each idle loop must animate only transforms and opacity (no width, height, anchors or Layout changes). B checks this with polish-phase timing: an idle loop must add 0 ms of polish per frame.

## Order

1. **A:** finish the spatial navigation and idle prototypes, and commit them on `m6-design` as a prototype commit (or a `m6-proto` branch).
2. **B (now, in parallel):** build the measurement and demonstration tools against the current trees. They change no view code.
3. **B:** measure A's prototype commit and publish the demonstration with the numbers for the user.
4. **The user** reviews the prototypes and decides on Workspaces.
5. **Then:** broad integration. A takes the shell and A's rooms; B takes B's rooms through A's gate.
6. No merge or push by either of us without the user's approval.

## Rules between us

- Neither edits the other's worktree. B dropped one untracked copy of this file into `../next-m6/docs/` and touched nothing else there.
- Each checks the other's latest commit before relying on it, and names the commit measured.
- Shared fixture data (`adapters/fixture/FixtureAdapter.qml`) changed on `m6-rooms`: more windows, networks under `scan`, and a second Bluetooth device. A trial merge with `b3717e9` was clean.

## B's tools (built 7 November 2026, night; they change no view code)

- `python3 tools/measure/desktop_canvas.py [--source TREE] [--rounds 2] [--script JSON] [--reduced] [--ambient off] -o OUT.json`: the camera's frame cost per move on the desktop. Steps:
  - `"map"` / `"back"`;
  - a room id (travel);
  - `{"call": "<Shell function>", "args": [...], "label": "pan_left"}`, for whatever pan or zoom API A's prototype adds.

  It reports a segment per step (`travel_<room>`, `map_in`, `map_out`, or the label) and lists any cue or `idle.*` loop still active after each step settles (`still_moving_at_rest`). **A: name your pan and zoom entry points in this file, and B will script them.**
- `python3 tools/measure/desktop_idle.py --rooms all [--reduced] [--ambient off] [--source TREE] [--seconds 60]`: per room, open and at rest. It reports frames per second actually drawn, CPU %, RSS and PSS, and the cues and loops active at the fold. Without `--rooms` it does what it always did.
- `python3 tools/demo_frames.py OUT [--source TREE] [--only travel,map,idle] [--extra JSON] [--gl]`: offscreen frame sequences (moves slowed ×4), an animated WebP at real speed and a contact sheet per sequence. This is for the user's review, not for timing.
- FixtureView now binds `Motion.reduced` to `ViewState.motionEnabled`, as Overlay does. `FART_REDUCED=1` and `FART_AMBIENT=0` set the user's preferences, so a gate bound to them is measured as the user would switch it.
- Baseline on `d061a10` + B's rooms (one round, quiet, 144 Hz): travel interval p99 is 8.1–10.4 ms, with 0–1 misses per move and 4 in all. Map in and out p99 is 8.2–8.4 ms with 0 misses. Nothing is still moving at rest. Idle Home and Tasks are about 2 fps when open and at rest (to check: probably the command line's cursor). The demo frames show the "barely perceptible" canvas: no neighbours at the edges, and the map's clusters are near-identical dark cards.
