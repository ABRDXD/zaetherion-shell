# Type roles

**Owner pick, 23 November 2026. A · Reading first.** Native implementation on `codex/reading-first`.

The two columns show the same focus timer and Bluetooth row. [Angular](angular.png) uses the shell's condensed lettering and mono labels. [Fluid](fluid.png) uses its upright sans. Each proposal gives both forms the same sizes for the same jobs.

**A · Reading first** gives task names, device names and headings more room. The timer uses the room's own lettering. **B · Numbers first** gives the clock large fixed-width digits. Its headings and supporting text are smaller.

| Role in the interface | A (px) | B (px) |
| --- | ---: | ---: |
| Caption or status | 12 | 12 |
| Action | 15 | 14 |
| Body | 16 | 14 |
| Section heading | 26 | 20 |
| Secondary number | 34 | 40 |
| Page headline | 42 | 52 |
| Main clock or countdown | 72 | 88 |

The fixture shows the roles used by these two views. The secondary number and page headline sizes are proposed steps for rooms that use them. Existing lyric emphasis, italics, control hit areas and icon sizes have separate purposes.

Run the native fixture offscreen from this directory.

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qml6 TypeStudy.qml -- --out "$PWD/angular.png"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qml6 TypeStudy.qml -- --fluid --out "$PWD/fluid.png"
```
