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

The step 1 review is complete. The next implementation task is UI_BRIEF step 2, the fixture-driven island shell.
