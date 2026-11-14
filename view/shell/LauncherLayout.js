.pragma library

// The launcher's geometry (S6, docs/S6_LAUNCHER.md §3), shared by the face that draws it and the island window that
// must be deep enough to hold it without resizing (a layer surface resized during a morph shows stretched frames).

const edgePad = 10;        // the island face's padding to its edges (IslandExpansion reads it from here)
const contentWidth = 560;  // Z75: about 600 px with the island's shoulders
const inputHeight = 36;    // the island's resting height: the line the launcher grows from
const rowHeight = 40;
const gap = 4;             // between the line and the rows, and under the last row
const notice = 20;         // the line under the input for a refusal (`> BLOCKED · SESSION`)

function depth(rows, edgePad) {
    return 2 * edgePad + inputHeight + notice + gap + rows * rowHeight + gap;
}
