# Eclipse · missing selector states

**Owner pick, 22 November 2026 · A · Pilot light.** Use the Pilot light column and its full-size sheet for the native selector.

Open [Pilot light](a-pilot-light.png) or [Corner signals](b-corner-signals.png). Each sheet shows the same two invented desktops. The last row shows the two displays together during a drag.

| Moment | A · Pilot light | B · Corner signals |
| --- | --- | --- |
| Before pressing | A small lime cross with an open centre follows the pointer. The footer says “Drag to select”. | Four short lime marks sit at the active display’s outer corners above the footer. A plain cross marks the pointer. The footer says “Drag to select”. |
| Window mode, over the desktop | An ordinary arrow and “Point at a window”. | The screen corners stay lit. An ordinary arrow and “Point at a window”. |
| Window under the pointer | The whole candidate window returns to its original brightness. A lime tab outside its edge reads “Window” and the source-pixel size. The footer says “Click this window”. | The screen marks give way to the window’s four corners. Its lime tab carries the size. The footer says “Click to select window”. |
| Other display | The frozen desktop stays dim. A small pause mark and lower-left label say “Move here to select”. | The frozen desktop stays dim. A full footer gives the screen number and says “Move here to select”. On a multi-display layout the active footer identifies its screen too. |

For either option the pointer's display owns the active treatment. With a drag in progress, the originating display keeps the selection, and the other display keeps its quiet treatment. During the drag, the other display reads “Selection on other screen”. A newly active display uses its own frozen pixels. The numbered mock uses example screen order.

Claude A's stage on `a-eclipse` already supplies the mode, hover box, drag state, source scale and per-screen rectangle. For wiring, the visuals also need to know which display owns the pointer or drag. Clear the old hover highlight when the pointer leaves. Use one pointer mark at a time. Keep the approved crop frame and “Release to select” for a region drag. Keep overlays outside the selected pixels, including the existing footer avoidance and full-screen case. If a candidate leaves insufficient room for the window instruction below it, show the instruction in free space above it when available. A full-screen candidate clears the overlay.

Rebuild both sheets with `python3 tools/selector-study/states.py`. Artwork and sample text are generated locally using the original atlas fixture.
