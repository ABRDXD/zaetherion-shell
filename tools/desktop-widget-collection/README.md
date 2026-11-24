# Desktop widgets and layout presets

The four 1280 × 720 references are Qt Quick fixture renders. Compare
[Angular Morning](angular.png), [Angular Studio](angular-studio.png),
[Fluid Morning](fluid.png) and [Fluid Studio](fluid-studio.png).

The music plane pairs a sleeve and current lyric. The sky plane plots the sun
against the horizon. Notes use a light writing surface, free text uses a
one-line inscription, and the image has a print margin. The editor's per-display
preset strip shows a miniature arrangement for each choice. Morning and Studio
are invented layouts for review. Music, sky, notes, text and image move
together when changing layouts. Clock placement has its own approved study.

The proposed choice is whether the preset selector should show these miniature
arrangements in the editor. Treat the examples as fixture layouts. The owner
can also mark any widget face for revision before native component extraction.

From this directory run the following in Qt 6.

```sh
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
qml6 Collection.qml -- --fluid --presets --studio --out /tmp/widget-preset.png
```

Omit --studio for Morning. Omit --presets for the desktop. Use --no-track or
--no-lyrics for the fallback faces and --occupied for workspace occupancy.
In the fixture Tab toggles preset editing, arrows switch layouts and Space
unloads/recreates the widget family. The two preset buttons also accept clicks.
Claude B owns native placement, persistence and per-monitor switching after
approval. Compare the widget top-lefts, type, art crops and selection mark on
an empty workspace. Occupancy should unload the widget objects.
