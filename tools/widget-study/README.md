# Modern Clock

**Current study · C · Offcut.** The owner wants Anurati and wants familiar visual devices taken out. The two cropped shapes on the fixture wallpaper are an enlargement of the S and D in WEDNESDAY. The widget itself contains only the day, date and time. Angular spreads the two readings to the ends of the day. Fluid centres them together.

[Angular](offcut-angular.png) · [Fluid](offcut-fluid.png)

Offcut opens by default. Run the commands below with `--offcut` for this study. The earlier A and B studies are available for comparison.

A Wednesday morning on an invented desktop. Both clocks sit in the upper third. The wallpaper is part of the fixture.

| Choice | Angular | Fluid |
| --- | --- | --- |
| A · Open sky | [Warm date between short rules](open-angular.png) | [Pale tide-coloured date on open sky](open-fluid.png) |
| B · Folio | [Dark plane with square ends and brass marks](folio-angular.png) | [Rounded plane with two small lights](folio-fluid.png) |

Open sky keeps the installed Modern Clock’s 72 px day, 17 px tracking and 19 px date and time. Folio sets a slightly smaller day inside an island-coloured panel to give the letters a consistent background on patterned wallpapers. Both try the installed plugin’s Anurati and Poppins, then the system font families of the same names, then DejaVu Sans.

Space toggles a fixture window count between zero and one. The Loader releases the clock on an occupied workspace and creates it again on an empty one (Z85). The eventual editor is reached through the desktop context menu (Z46, Z86).

From this directory, reproduce the PNGs with Qt 6.

```sh
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
for form in angular fluid; do
    for face in offcut open folio; do
        qml6 WidgetStudy.qml -- "--$form" "--$face" --out "$PWD/$face-$form.png"
    done
done
```

Omit `--out` for the keyboard preview in a temporary display. Add `--occupied` to open on the wallpaper alone.
