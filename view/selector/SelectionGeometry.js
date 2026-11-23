.pragma library
// The frozen-screen selector's geometry (Z48, Z221). Pure, no Qt: rects are {x, y, width, height} in one
// screen's logical pixels, `bounds` is that screen ({x: 0, y: 0, width, height}).

// A press and release closer than this is a click, not a drag.
const MIN_DRAG = 4;

function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value));
}

// The rect spanned by a drag from (ax, ay) to (bx, by), clamped to the screen, in whole pixels.
function span(ax, ay, bx, by, bounds) {
    const x1 = clamp(Math.round(Math.min(ax, bx)), bounds.x, bounds.x + bounds.width);
    const y1 = clamp(Math.round(Math.min(ay, by)), bounds.y, bounds.y + bounds.height);
    const x2 = clamp(Math.round(Math.max(ax, bx)), bounds.x, bounds.x + bounds.width);
    const y2 = clamp(Math.round(Math.max(ay, by)), bounds.y, bounds.y + bounds.height);
    return { x: x1, y: y1, width: x2 - x1, height: y2 - y1 };
}

function isDrag(ax, ay, bx, by) {
    return Math.abs(bx - ax) >= MIN_DRAG || Math.abs(by - ay) >= MIN_DRAG;
}

// The size the saved picture will have: source pixels, not logical ones.
function sizeText(rect, scale) {
    return Math.round(rect.width * scale) + " × " + Math.round(rect.height * scale) + " px";
}

// Where the size label goes: "above" the crop, "below" it when the top screen edge leaves no room, or "none"
// when neither side has room (the crop fills the screen's height, so nothing covers its contents).
function labelSide(rect, bounds, labelHeight, gap) {
    const need = labelHeight + gap;
    if (rect.y - bounds.y >= need)
        return "above";
    if (bounds.y + bounds.height - (rect.y + rect.height) >= need)
        return "below";
    return "none";
}

// The label's left edge: aligned with the crop, moved in so it stays on the screen.
function labelX(rect, bounds, labelWidth, inset) {
    return clamp(rect.x - inset, bounds.x, bounds.x + bounds.width - labelWidth);
}

function fills(rect, bounds) {
    return rect.x <= bounds.x && rect.y <= bounds.y && rect.x + rect.width >= bounds.x + bounds.width
        && rect.y + rect.height >= bounds.y + bounds.height;
}

function intersects(a, b) {
    return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
}

// The window box under (x, y): the smallest that holds the point, so a dialog wins over the window behind it.
// Returns the index in `boxes`, or -1.
function boxAt(boxes, x, y) {
    let best = -1;
    for (let i = 0; i < boxes.length; i++) {
        const b = boxes[i];
        if (x < b.x || y < b.y || x >= b.x + b.width || y >= b.y + b.height)
            continue;
        if (best < 0 || b.width * b.height < boxes[best].width * boxes[best].height)
            best = i;
    }
    return best;
}

// Layout boxes moved into one screen's logical coordinates, keeping only those on it, clipped to it.
function boxesOn(boxes, screen) {
    const out = [];
    const bounds = { x: 0, y: 0, width: screen.width, height: screen.height };
    for (const b of boxes) {
        const local = { x: b.x - screen.x, y: b.y - screen.y, width: b.width, height: b.height };
        if (!intersects(local, bounds))
            continue;
        out.push(span(local.x, local.y, local.x + local.width, local.y + local.height, bounds));
    }
    return out;
}

// slurp's answer format, in layout coordinates, so the core's reader stays the same.
function answer(rect, screen) {
    return (rect.x + screen.x) + "," + (rect.y + screen.y) + " " + rect.width + "x" + rect.height;
}

// The frozen grab's pixels behind one screen: the grab starts at the layout's top-left and renders at `scale`.
function sourceRect(screen, origin, scale) {
    return { x: Math.round((screen.x - origin.x) * scale), y: Math.round((screen.y - origin.y) * scale),
             width: Math.round(screen.width * scale), height: Math.round(screen.height * scale) };
}
