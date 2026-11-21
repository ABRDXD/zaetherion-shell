# Frozen-screen selector

Compare the same drag across an invented atlas page. In each image, the selected 444 × 300 pixels keep their source colour and brightness.

| A · Eclipse | B · Transit | C · Proof |
| --- | --- | --- |
| ![Eclipse](a-eclipse.png) | ![Transit](b-transit.png) | ![Proof](c-proof.png) |
| The page goes dark. Four bright corners mark the crop. | The page stays readable. Sight along the extended edges to line up the crop. | The page fades to paper. A dark film frame holds the crop. |

The plain instruction before a drag is “Drag to select”. During a drag it changes to “Release to select”. Escape is visible in both states. Keep the size in source pixels. At a screen edge, move the size label to the opposite outside edge. If the crop fills the screen, clear the labels and frame so its contents stay visible. These are visual proposals for Claude A’s Z48/Z221 selector.

The checked-in PNGs open directly. To redraw them, run `python3 tools/selector-study/render.py` with librsvg’s `rsvg-convert` available. All artwork and sample text originate in that script.
