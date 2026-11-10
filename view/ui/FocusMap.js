.pragma library
// Spatial focus moves (MONTAGE.md §3.3). Pure geometry, no Qt: rects are {x, y, width, height} in one
// coordinate space. The candidate must lie ahead of `from` inside a ±45° cone; the score weights the
// distance 1 along the axis and 2 across it. Returns the index in `rects`, or -1.
const DIRECTIONS = { left: [-1, 0], right: [1, 0], up: [0, -1], down: [0, 1] };

function centre(rect) {
    return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
}

function pick(from, rects, direction) {
    const step = DIRECTIONS[direction];
    if (!step || !from)
        return -1;
    const [dx, dy] = step;
    const origin = centre(from);
    let best = -1;
    let bestScore = Infinity;
    for (let i = 0; i < rects.length; i++) {
        const rect = rects[i];
        if (rect === from)
            continue;
        const c = centre(rect);
        const along = (c.x - origin.x) * dx + (c.y - origin.y) * dy;
        const across = (c.x - origin.x) * -dy + (c.y - origin.y) * dx;
        if (along <= 0 || Math.abs(across) > along)
            continue;
        const score = along + 2 * Math.abs(across);
        if (score < bestScore) {
            bestScore = score;
            best = i;
        }
    }
    return best;
}

// Where a move with no candidate goes (MONTAGE.md §3.3). Out of the room: towards the index, up to the
// command line. Out of the index: away from it into the room, up to the command line. From the header:
// down into the room. A list falls back to its room first. "" means the focus stays. `side` is the edge
// the index ribbon stands on in the current room ("left" by default; MONTAGE.md §4).
const FALLBACKS = {
    list: { left: "room", right: "room", up: "room", down: "room" },
    room: { left: "index", up: "command" },
    index: { right: "room", up: "command" },
    header: { down: "room" }
};

const MIRROR = { left: "right", right: "left", up: "up", down: "down" };

function fallback(zone, direction, side) {
    const turned = side === "right" && (zone === "room" || zone === "index") ? MIRROR[direction] : direction;
    return (FALLBACKS[zone] || {})[turned] || "";
}
