# Register into Day index

[Watch the combined Angular study](login-clock.webp) · [View the settled desktop at full size](desktop.png)

Four invented log entries assemble the Register Æ inside FART’s cut wedge. At 1.13 seconds the last selected row moves to Wednesday’s slot in the week ribbon. The wedge shrinks into a stamp on the leading edge of the Anurati weekday. The clock is at rest by 1.5 seconds. The WebP holds the final frame briefly and loops for comparison.

Any key during playback lands immediately. Reduced motion opens directly on the desktop. An occupied workspace ends on the fixture wallpaper. After landing, Space toggles occupancy and destroys or rebuilds both the clock and its stamp.

The fixture uses the Day index and Offcut wallpaper components from the widget study. The installed Modern Clock plugin supplies Anurati and Poppins when present. The previous Angular studies remain separate references on their branches.

Render a still from this directory using Qt 6. Change the millisecond value to inspect the handoff. Omit both `--at` and `--out` and their arguments to play once in a temporary display. Add `--reduced-motion` or `--occupied` to exercise those paths.

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qml6 LoginClock.qml -- --at 1290 --out "$PWD/mid-fold.png"
```

`python3 render.py` reproduces the WebP and final PNG with Qt 6 and Pillow.
