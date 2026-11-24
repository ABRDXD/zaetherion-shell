# Editing the Modern Clock

The two studies open inside *Edit widgets*, the editor reached from the desktop context menu (Z46, Z86). They show one invented monitor and its Morning preset. Changes last for this fixture session.

The form selects the approved placement by default. Angular opens Chase and Fluid opens Margin. Use an explicit placement flag to inspect either study in either form.

| Choice | Angular | Fluid | How to use it |
| --- | --- | --- | --- |
| A · Chase | [Open](chase-angular.png) | [Open](chase-fluid.png) | Drag the clock to move it. Drag the upper handle to rotate, or the lower-right tab to change its span. The handles follow the clock. |
| B · Margin | [Open](margin-angular.png) | [Open](margin-fluid.png) | Choose Move, Resize or Rotate in the margin. Drag the clock, or use the ruler to choose an exact starting column, width or angle. Its endpoints show the available range. |

The **Clock face** strip edits the clock in place. Toggle it in the header to give the desktop more room.

| Control | Choices | On the clock |
| --- | --- | --- |
| Day spacing | Close, Original, Wide | Changes the space between the Anurati letters. |
| Date | Full, Short | Angular can show the week ribbon or just today’s tab. Fluid can show the full written date or a short day and month. |
| Time | 12 h, 24 h | Displays the sample time as “– 7:24 AM –” or “– 07:24 –”. |
| Clock ink | Original, Copper, Tide | Tints the Angular backing and Æ stamp, or the Fluid lettering. |

**Reset face** restores the four face settings and keeps the clock’s position, size and angle. Face settings survive preview and workspace occupancy during the fixture session.

Watch the controls on [Angular Chase](face-angular.webp) or [Fluid Margin](face-fluid.webp). The [earlier placement comparison](comparison.webp) shows resize and rotation in the original placement-only view, with Chase on the left and Margin on the right.

Both editors work in the same 12-column space. Margin scales the desktop preview uniformly so opening the full preview preserves the widget’s placement. **Preview** hides the controls. **Edit widgets** brings them back. Escape toggles preview. Space simulates an occupied or empty workspace to exercise clock unloading (Z85).

The three-column lower limit is a fixture size for this clock sample. The monitor and preset names give the editing context. Preset management, the desktop menu and persistence belong to native integration after the visual pick.

### Approved desktop menus

Run `qml6 EditorStudy.qml -- --desktop --angular` or replace `--angular` with `--fluid` in an offscreen or isolated display. Right-click the fixture desktop to open the four actions from Z86. **Edit widgets** enters the approved placement editor. The other three rows dismiss the study menu. Use the arrow keys and Enter to choose, or Escape to dismiss. Escape from the editor returns to the fixture desktop.

Both forms use the shared [DesktopMenu QML](../../view/widgets/DesktopMenu.qml). The [Angular recording](desktop-menu-angular.webp) shows the cut index and Chase handles. The [Fluid recording](desktop-menu-fluid.webp) shows the curved rail and Margin ruler. Each has three offscreen frames captured through the fixture's pointer input.

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
