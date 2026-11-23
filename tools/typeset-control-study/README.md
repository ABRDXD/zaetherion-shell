# Typeset this picture

**Owner pick, 23 November 2026. B · Split print.** The native control is on `codex/split-print`.

[Angular](angular.png) and [Fluid](fluid.png) show two choices below the wallpaper colour control. A uses a solid accent key with a large Tt. B uses a quieter surface with a small split print, half continuous tone and half letters. The split print is a fixed illustration of the command. It costs no wallpaper conversion to display.

Both use the Reading first action and caption sizes. The busy label names the operation and gives the existing approximate wait. Converted plates show the palette note already in Wallpaper Settings. The native action should use the existing Z215 command and image, plate, busy and error states.

The standalone QML fixture draws an invented moon. Activate either sample to see its busy state and the resulting lettered example. Everything stays inside the example window.

To render an offscreen sheet in this directory:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qml6 TypesetStudy.qml -- --out "$PWD/angular.png"
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qml6 TypesetStudy.qml -- --fluid --out "$PWD/fluid.png"
```

Add `--narrow` after `--` to preview a 220 px control.
