# Password lock · Z87–Z89

The owner approved both forms on 24 November. Open angular.png and fluid.png
at 1280 × 720. LockStudy.qml now hosts the reusable
[PasswordLockFace](../../view/lock/PasswordLockFace.qml) over the Sky.qml fixture.
The reference images are the approved renders from `490fa75`.

| Form | Entry | Rejection at normal speed | Reduced | Settled error |
| --- | --- | --- | --- | --- |
| Angular | [PNG](angular.png) | [Motion](angular-motion.webp) | [Reduced](angular-reduced.webp) | [PNG](angular-failed.png) |
| Fluid | [PNG](fluid.png) | [Motion](fluid-motion.webp) | [Reduced](fluid-reduced.webp) | [PNG](fluid-failed.png) |

Angular docks the slanted numerals against a stepped plane. The warm date strip
overhangs its return. On rejection only the password plane moves, with three
quick diminishing oscillations over 320 ms. Fluid suspends the lighter clock
in two offset ellipses above a floating dock. Its field makes two smaller,
softer oscillations in the same interval. Both reserve the retry line below
the field. At reduced motion the field stays centred and the retry line and
warm outline appear on the rejection frame. Subsequent rejections increment n.

Run `python tools/password-lock-study/render.py` to regenerate the eight images
in Qt 6 offscreen software rendering. The renderer checks that reduced motion
is stationary and matches the normal settled error. For a fixture replay, run
`QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qml6 tools/password-lock-study/LockStudy.qml -- --fluid --at 120 --out /tmp/lock-sample.png`.
Use --angular, --reduced, --attempt 2 or --hold 0.65 to select other samples.
Hold progress is illustrative. Releasing clears the fill. Native timings for
power, lock state, authentication, media and battery belong to the host.

Claude B can compare the centre, silhouette, band alignment, fixed error
baseline and stationary reduced state against the full-size PNGs. Use the
same readings and dimensions for parity.

## Native handoff to Claude B

Import `qs.view.lock` and place `PasswordLockFace` over the opaque lock background
on each output. The face scales its centred 1280 × 720 composition uniformly.
Supply the current wallpaper and sky cuts behind it. The title and field can
also be mounted over a plain background when sky rendering is unavailable.

Bind `fluid`, formatted `timeText` and `dateText`, and the password mask length.
Keep the secret and input focus in the native auth host. On rejection supply
`attempts` and elapsed `rejectionMs` from zero to 320, then hold the endpoint.
Set it negative when clearing the error. Set `reducedMotion` for OFF, MINIMAL
and REDUCED to suppress shake. The attempt indicator expands for larger counts.

Bind `mediaAvailable`, `trackTitle`, `artist`, `playing`, `batteryFraction`
(negative when unavailable) and `holdProgress` (0–1). Connect `mediaRequested`
(previous, play, pause, next) and the power hold start/end signals. Release and
cancellation end the gesture. The host owns confirmation, lifecycle and all
system actions. Visual sources are LockTitleCard.qml, PasswordPlane.qml and
LockBand.qml alongside the face.

Re-render with the command above, then compare the PNGs and both animated
references with `490fa75`. Check the second attempt and partial hold with
`--attempt 2 --at 400` and `--hold 0.65`. In the fixture, test the button
signals offscreen with `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
/usr/lib/qt6/bin/qmltestrunner -input tools/password-lock-study/tst_controls.qml`.
Native wiring, integration tests and the merge belong to Claude B.
