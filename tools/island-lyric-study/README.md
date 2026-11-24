# Island title slot · Z121

[Angular and Fluid motion](title-slots.webp) and [track fallback](fallback.png).
This plate magnifies each isolated title slot 2×. Angular uses the 140 px
minimum media run from IslandRest as an upper bound for the lettering study.
In the native pill the cover and gutter also use part of that run. Elide to
the actual available width. Fluid uses the 240 px maximum title width.
The surrounding plate and ticks are review furniture.

Both forms follow the same invented two-line cue. Angular exchanges lines
along the reading direction; Fluid lifts the incoming line. The proposed
transition is 200 ms. Reduced motion replaces the line in place. Missing lyrics
or a released lease returns to the track title. During normal playback the
resting island keeps its existing clock, cover and waveform rules.

Run `python tools/island-lyric-study/render.py` to reproduce the plate and check
the reduced and fallback endpoints. If picked, Claude B supplies the active
player and lyric timing and releases subscriptions with the lease. Use the
two existing title sites in `view/shell/IslandRest.qml` at `0c1df3a`.
