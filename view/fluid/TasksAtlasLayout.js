.pragma library

// Fluid Tasks (owner's pick "B · Star atlas", 15 November 2026): each list a constellation on a sky chart seen at an
// angle. Sooner is nearer the centre (overdue at the very core, warm); undated tasks keep to the rim; done tasks are
// hollow. The constellation's line runs through the open tasks in the order they fall due: the route through the
// list. Pure, so tests can run it in Node.

const tilt = 0.5;            // the chart's vertical squash: seen at an angle, its top the far side
const horizon = 90;          // days: beyond this a dated task sits on the "later" ring
const coreR = 0.13;          // overdue
const todayR = 0.34;         // due today
const datedR = 0.56;         // the span from today's ring to the horizon's
const rimR = 1.0;            // undated
const golden = 2.399963;     // radians: spreads successive stars evenly round the chart
const labelled = 12;         // only the most pressing are named; the rest are stars
// The chart's rings, as [days, label]; null is the undated rim.
const rings = [[0, "Today"], [7, "Week"], [30, "Month"], [horizon, "Later"], [null, "Someday"]];

function radiusFor(days) {
    if (days === null || days === undefined) return rimR;
    if (days < 0) return coreR;
    return todayR + datedR * Math.min(1, Math.log(1 + days) / Math.log(1 + horizon));
}
function hash(text) {
    let h = 2166136261;
    for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
    return (h >>> 0) / 4294967296;
}
// Open tasks first by due (undated last), then done ones; each gets a radius and an angle. The list's id turns the
// whole figure so each constellation has its own shape.
function order(tasks) {
    const key = t => t.days === null || t.days === undefined ? Infinity : t.days;
    return tasks.slice().sort((a, b) => (a.done - b.done) || (key(a) - key(b)) || String(a.id).localeCompare(String(b.id)));
}
function place(tasks, listId) {
    const turn = 2 * Math.PI * hash(String(listId ?? ""));
    return order(tasks).map((t, i) => ({ id: t.id, r: radiusFor(t.days), a: turn + i * golden, rank: i,
                                         named: i < labelled, done: !!t.done, late: !t.done && t.days !== null && t.days < 0 }));
}
// Chart → room: (cx, cy) the centre, R the chart's radius across. depth 0 at the far (top) edge, 1 at the near.
function project(r, a, cx, cy, R) {
    return { x: cx + r * R * Math.cos(a), y: cy + r * R * tilt * Math.sin(a), depth: (Math.sin(a) + 1) / 2 };
}
// A star's size: the more pressing, the brighter; the far side smaller.
function magnitude(r, depth) {
    return (1.9 - r) * (0.7 + 0.3 * depth);
}
// Fixed background stars, the same every time: [x, y, size, alpha] in shares of the room.
function field(count, seed) {
    const out = [];
    let s = seed >>> 0 || 1;
    const next = () => { s = Math.imul(s ^ (s >>> 15), 2246822507) + 0x6b43a9b5 >>> 0; return s / 4294967296; };
    for (let i = 0; i < count; i++) {
        const big = next() > 0.93;
        out.push([next(), next(), big ? 1.6 + next() : 0.6 + next() * 0.7, big ? 0.55 + 0.3 * next() : 0.12 + 0.3 * next()]);
    }
    return out;
}
