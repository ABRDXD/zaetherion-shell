# Island · S3 step 1

Open [the review sheet](island-s3-review.svg) at full size, or use the [PNG preview](island-s3-review.png). The [motion study](island-s3-motion.gif) uses the same drawings to show the change in silhouette. The owner approved the Angular design with its shallow bevel for S3 (Z144).

The 420 × 36 notch widens for hover and deepens for events. Each frame has one continuous navy outline with 84° shoulders. The 78° notification tag and −12° meter blades sit inside that outline. The motion study shows volume taking over from a notification and the notification resuming, following the existing priority order. Its sizes, easing and hold times illustrate the proposal. Runtime motion will follow the host profile and the four levels in Z116.

The sheet compares the flat bar with 4 px and 8 px bevels at rest. The approved 4 px bevel appears throughout the sheet and motion study. The lit rim and lower face follow the same outline, using opacity from the ink role. The lighting stays fixed.

The sheet includes rest, hover wings, notification, volume, memory pressure, floating, bottom edge and absent media/battery. The resting media sample is paused. The recommended notification uses an inverted app tag, echoing the wedge in the FART Timers screenshot. The alternate uses a narrow signal slit. Both use the same expanding outline.

The sky guide marks, album tile, notification and readings are synthetic. OPEN 14 still covers the measured memory trigger, queue priority and pin control. The illustrated floating gap and expansion dimensions are visual proposals. Keyboard layout and focus binds remain open.

## Owner decisions

- Roboto Condensed for the mock-ups, matching the built panel. Z52 records the scope of that choice.
- Power opens the session card and the notification glyph opens Inbox (Z143).

## Sources and checks

- The mock-up palette and type sizes come from the existing Design tokens. The navy resolves to the darkest blue-hued role in the review palette. The SVG includes the role values in its stylesheet and uses classes in the drawing.
- The comparison reuses the 1360 × 860 fixture screenshot of the seeded FART Timers panel from the first review. The earlier offscreen capture wrote a valid PNG and exited cleanly in the private harness. The stock runner printed `0/1 rooms saved` because it did not see its expected `FART_SHOT` log marker.
- The layout check passed all 7 tests. The SVG was rendered with `rsvg-convert` and inspected alongside the motion study. The repository contrast guard and audit are absent. [Contrast ratios](contrast.txt) cover the text pairs in the mock-up palette.
- This step changes the review materials and handoff. The full unit suite was not run.

## S3 step 2 fixture

`shell-island-fixture.qml` runs the Angular frame with the inert adapter. It previews the top notch by default. Set `ZAETHERION_FIXTURE_EDGE=bottom` for the bottom edge or `ZAETHERION_FIXTURE_PLACEMENT=floating` for the 16 px gap from the mock-up. This gap is a fixture value. Both placements reserve 36 px.

Use the hidden compositor from [NESTED.md](../NESTED.md). Run the second command in one terminal and capture from another.

```sh
python3 tools/nested_hypr.py start
python3 tools/nested_hypr.py run env ZAETHERION_FIXTURE_OUTPUT=ZTEST qs -p shell-island-fixture.qml
python3 tools/nested_hypr.py shot island.png
python3 tools/nested_hypr.py stop
```

While the fixture is running, use its private IPC target to exercise fullscreen hiding. The command changes a fixture workspace record.

```sh
python3 tools/nested_hypr.py run qs ipc -p shell-island-fixture.qml call island-fixture fullscreen true
python3 tools/nested_hypr.py run qs ipc -p shell-island-fixture.qml call island-fixture fullscreen false
```

The offscreen frame and palette check runs with `python3 -m unittest discover -s tests -p test_island.py`. The native window requires a Wayland layer-shell compositor.

## Populated Angular preview

The same entry point now includes the resting modules, the 300 ms hover wings, and the expansion queue. The preview reads its own defaults and uses a disconnected core. Hover to see seconds, battery percentage, status glyphs, weather and the sample tray. Click the centre to open or fold the fixture panel. Hold the centre for 600 ms to show the fixture Overdrive lease line.

The IPC target also accepts `focus`, `playing true`, `track`, `volume 0.42`, `notification false`, `memory 1.2`, `workspace 2`, `recording true`, `battery 0.05 false` and `comeback 3`. These commands change synthetic records. Invoke them through `tools/nested_hypr.py run qs ipc -p shell-island-fixture.qml call island-fixture …`.

Super+Shift+I is the chosen shortcut. The fixture exposes the focus action through IPC. Arrow keys or hjkl move focus, Enter activates, and Escape leaves. The compositor keybind remains a separate session change.

## Opus pass on the Angular island (12 November 2026)

[Before and after](island-s3-opus-review.png) shows each state from the hidden nested compositor, at 0baeef2 and now. [Docked](island-s3-opus-docked.png) shows the island over the FART panel.

- **App tag.** The notification now puts the app's name on an inverted 78° ink tag, matching FART's resident and artist tags. A critical notice uses a signal tag, with a signal rule and a signal-tinted rim.
- **Depth.** `IslandFrame` uses the approved study's fixed light: a lit rim that fades from the left shoulder, a faint upper face and a graded 4 px facet.
- **Shoulders.** Expansion content keeps clear of the 84° sides. Memory rows and the first action button no longer touch the edge.
- **Faces.** The notification ends with FART's notched rule, the first action as an ink tag, and a full-width reply field with SEND inside. A body that wraps adds one line, so the face grows from 124 to 140 px. Volume adds its glyph. Memory adds a sheared readout, a blade meter and ruled rows. Track adds an inverted signal tile and a `> NOW PLAYING` line. The resting media mark is the study's signal tile.
- **Focus.** Keyboard focus on an island glyph is an ink plane at 78°, and hover is a quiet paper plane.
- **New shared parts.** `view/ui/FTag.qml` is the inverted tag, and `view/ui/FBlades.qml` is the −12° blade meter.

### Media pill (owner review)

[Media pill](island-s3-media-pill.png) shows the rest and hover states before and after the change, with the same long synthetic title. The red line marks the screen centre. The pill now runs up to the clock. At rest, network sits with the bell and battery, so the resting width stays 420 px (Z66). Hovered, the centre opens to 500 px before the wings begin. The visible title grew from 9 to 14 characters at rest and from 9 to 18 on hover. The fixture's `title <text>` call sets the synthetic title.

### Reply after a pop-up

When an OSD covered a notification, the island dropped keyboard interactivity to None, then restored OnDemand when the notification returned. Hyprland gives click focus to an OnDemand layer only after the pointer moves, so a click from a resting pointer focused the field in Qt but delivered no keys. A queued notification with a reply draft now keeps OnDemand through the pre-emption. If the field takes focus while the window is inactive, the island briefly asks for Exclusive until the window becomes active. The field regains focus when its notification returns, and Send dismisses the notification.

Hyprland still drops the first click when the island grows under a pointer that has not moved, because it sends no pointer enter. Any pointer movement before the click avoids this. The fix has to come from the compositor.

### Focus while the panel is docked (Z148)

Super+Shift+I with the panel open moves the keyboard to the island, and the panel stays open. Esc returns the keyboard to the panel. The handover follows a fixed order because Hyprland does not focus a layer that requests Exclusive while another Exclusive layer holds the keyboard. The island first sets `wantsKeyboard`, and the panel drops to None and pauses its focus grab. The island requests Exclusive 60 ms later. When the island lets go, the panel retakes Exclusive and resumes the grab 100 ms later, because resuming it while focus is still moving clears it and closes the panel. While the island holds the keyboard, a click outside does not close the panel.

`tests/fixtures/island/ReplyTest.qml` checks the keyboard policy and the handover offscreen. The fixture's `state` call reports `lastReply` and `keyboard` for nested checks.
