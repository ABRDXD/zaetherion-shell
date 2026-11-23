# Login sequence

**Current study · C · Ligature.** One log line types into a cut through the Æ in ZÆTHERION. The sample follows four shell states from the core coming online to the clock reaching the desktop. These are invented fixture readings. Angular uses a blunt sans ligature and Fluid uses a serif.

[Angular](ligature-angular.png) · [Fluid](ligature-fluid.png)

Ligature opens by default. To reproduce its stills, use `--ligature --at 966` with either form and an output path. Omit `--out` and its path to play it. Earlier studies follow for comparison.

| Choice | Angular | Fluid |
| --- | --- | --- |
| A · Line printer | [Warm rule and block cursor](printer-angular.png) | [Cool rule and fine cursor](printer-fluid.png) |
| B · Aperture | [Brass exposure dial and condensed type](aperture-angular.png) | [Sea-glass dial and upright type](aperture-fluid.png) |

Line printer keeps four timestamped lines on the page as they type. Aperture gives the current line the most space and keeps the previous line above it. Each quarter of the dial fills as one line types. The text and timestamps are invented.

Both sequences type for roughly 1.2 seconds, hold the completed reading, and exit at 1.5 seconds. Any key skips. The fixture flag `--reduced-motion` bypasses the face and exits immediately. Claude A can wire the selected look to the session’s motion preference after the pick.

The four 960 × 540 PNGs show the same moment, 1.17 seconds into playback. Reproduce them from this directory with Qt 6.

```sh
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
for form in angular fluid; do
    for face in printer aperture; do
        qml6 BootStudy.qml -- "--$form" "--$face" --out "$PWD/$face-$form.png"
    done
done
```

For another still, add `--at 750` (milliseconds). For a single playback, omit `--out` and its path. In a temporary display, any key closes the preview.
