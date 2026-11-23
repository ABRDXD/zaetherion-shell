# Register into Day index

**Owner pick for Angular, 23 November 2026.** The approved motion is revision `59c34af`. Its timing is in [FoldMotion.qml](FoldMotion.qml).

[Watch the 1.5-second login](login-clock.webp) · [Watch the handoff at one-third speed](fold-detail.webp) · [View the settled desktop at full size](desktop.png)

Four invented log lines seat the pieces of the Æ. The final row pulls back for a moment, sweeps left and turns edge-on. It changes to the date as it turns over, then climbs the 78° seam into Wednesday’s place. Behind it, the log sheet is cut away. The dark weekday plane draws in from the left, the gold backing and ivory DAY plane arrive from the right, and the Æ stamps the clock’s shoulder. The last piece settles before the 1.5-second mark.

The full loop holds the settled desktop for comparison. The slower loop begins at 900 ms and plays the same samples at one-third speed.

Any key during playback lands immediately. Reduced motion opens directly on the desktop. An occupied workspace ends on the fixture wallpaper. After landing, Space toggles occupancy and destroys or rebuilds both the clock and its stamp.

The fixture uses the Day index and Offcut wallpaper components from the widget study. The installed Modern Clock plugin supplies Anurati and Poppins when present. The previous Angular studies remain separate references on their branches.

Render a still from this directory using Qt 6. Change the millisecond value to inspect the handoff. Omit both `--at` and `--out` and their arguments to play once in a temporary display. Add `--reduced-motion` or `--occupied` to exercise those paths.

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qml6 LoginClock.qml -- --at 1290 --out "$PWD/mid-fold.png"
```

`python3 render.py` reproduces both WebPs and the final PNG with Qt 6 and Pillow.
