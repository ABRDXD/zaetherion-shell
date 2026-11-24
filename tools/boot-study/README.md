# Login sequence

**Angular · Register.** Four slices of the Æ move into alignment inside a FART room wedge. The index ribbon inverts the current log entry, with selection rules above and below it. Earlier lines remain readable. Each timestamp marks the start of its invented entry. [Angular render at 939 ms](register-angular.png)

**Fluid · Ligature.** A single log line types into the crossbar of the serif Æ. [Fluid render at 966 ms](ligature-fluid.png)

These are the defaults for their forms. The previous Angular Ligature is available with `--ligature`. The control-centre reference is [FART’s frame and index ribbon](../../docs/fart/DESIGN_SYSTEM.md#4-the-frame).

| Choice | Angular | Fluid |
| --- | --- | --- |
| A · Line printer | [Warm rule and block cursor](printer-angular.png) | [Cool rule and fine cursor](printer-fluid.png) |
| B · Aperture | [Brass exposure dial and condensed type](aperture-angular.png) | [Sea-glass dial and upright type](aperture-fluid.png) |

Line printer keeps four timestamped lines on the page as they type. Aperture gives the current line the most space and keeps the previous line above it. Each quarter of the dial fills as one line types. The text and timestamps are invented.

Both sequences type for roughly 1.2 seconds, hold the completed reading, and exit at 1.5 seconds. Any key skips. The fixture flag `--reduced-motion` bypasses the face and exits immediately. Claude A can wire the selected look to the session’s motion preference after the pick.

The four 960 × 540 PNGs show the same moment, 1.17 seconds into playback. Reproduce them from this directory with Qt 6.

```sh
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
qml6 BootStudy.qml -- --at 939 --out "$PWD/register-angular.png"
qml6 BootStudy.qml -- --fluid --at 966 --out "$PWD/ligature-fluid.png"
for form in angular fluid; do
    for face in printer aperture; do
        qml6 BootStudy.qml -- "--$form" "--$face" --out "$PWD/$face-$form.png"
    done
done
```

For another still, add `--at 750` (milliseconds). For a single playback, omit `--out` and its path. In a temporary display, any key closes the preview.
