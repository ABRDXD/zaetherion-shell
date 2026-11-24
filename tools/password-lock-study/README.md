# Password lock · Z87–Z89

Open angular.png and fluid.png at 1280 × 720. Each is the editable LockStudy.qml
in its masked-entry state. Sky.qml paints the seeded wallpaper. Glyph.qml draws
the lock and the band controls. All readings, including the track, are fixtures.

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
same readings and dimensions for parity. Both form choices await owner review.
