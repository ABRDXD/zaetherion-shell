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
