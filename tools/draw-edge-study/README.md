# Draw and right-edge quick actions · Z106 / Z107

| Form | Annotated fixture | Empty blank canvas | Right edge |
| --- | --- | --- | --- |
| Angular | [Draw](draw-angular.png) | [Blank](blank-angular.png) | [Actions](edge-angular.png) |
| Fluid | [Draw](draw-fluid.png) | [Blank](blank-fluid.png) | [Actions](edge-fluid.png) |

Angular keeps its instruments on a left rail. Fluid floats a horizontal
palette below the work. The active instrument and selected colour use separate
marks. Compare the canopy annotation, blank canvas, and disabled undo/redo.
The edge plane enters from the right with Calculator and Draw. Its Draw row
opens the fixture. Escape returns to the edge. Idle hover uses eased travel,
and --reduced snaps to the endpoint.

Render from this directory with Qt 6 software rendering.

```sh
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software
qml6 DrawStudy.qml -- --fluid --out /tmp/draw-study.png
```

Add --blank --empty, --edge, or --edge --half. Source, tool and colour
selection plus undo/redo change fixture presentation. Frozen uses an original
architectural drawing. Copy, Save, Calculator and pen input are visual
references for Claude B after design approval.
