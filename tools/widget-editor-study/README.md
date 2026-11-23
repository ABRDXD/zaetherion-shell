# Placing the Modern Clock

The two studies open inside *Edit widgets*, the editor reached from the desktop context menu (Z46, Z86). They show one invented monitor and its Morning preset. Changes last for this fixture session.

| Choice | Angular | Fluid | How to use it |
| --- | --- | --- | --- |
| A · Chase | [Open](chase-angular.png) | [Open](chase-fluid.png) | Drag the clock to move it. Drag the upper handle to rotate, or the lower-right tab to change its span. The handles follow the clock. |
| B · Margin | [Open](margin-angular.png) | [Open](margin-fluid.png) | Choose Move, Resize or Rotate in the margin. Drag the clock, or use the ruler to choose an exact starting column, width or angle. Its endpoints show the available range. |

[Compare resize and rotation in motion](comparison.webp). Chase is on the left. Margin is on the right. The ring follows the synthetic pointer in each offscreen session.

Both editors work in the same 12-column space. Margin scales the desktop preview uniformly so opening the full preview preserves the widget’s placement. **Preview** hides the controls. **Edit widgets** brings them back. Escape toggles preview. Space simulates an occupied or empty workspace to exercise clock unloading (Z85).

The three-column lower limit is a fixture size for this clock sample. The monitor and preset names give the editing context. Preset management, the desktop menu and persistence belong to native integration after the visual pick.

Reproduce the four PNGs with Qt 6 from this directory.

```sh
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
for form in angular fluid; do
    for look in chase margin; do
        qml6 EditorStudy.qml -- "--$form" "--$look" --out "$PWD/$look-$form.png"
    done
done
```

For pointer input in a temporary display, omit `--out` and the path. The clock uses the locally available Anurati and Poppins samples credited in NOTICE.
