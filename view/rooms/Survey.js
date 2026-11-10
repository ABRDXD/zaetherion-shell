.pragma library

// The surveyor's ground and its field book (Overdrive, docs/OVERDRIVE.md §16): pure geometry and bookkeeping, no
// Qt and no clock, so tests run it under Node (tests/test_survey.py). Rects are {x, y, width, height} and edges
// {x1, y1, x2, y2}, all in one coordinate space (the room's). The surveyor's body is w × h and stands with its feet
// on the edge: its box at centre c spans [c − w/2, c + w/2] × [y(c) − h, y(c)].

const MAX_SLOPE = Math.tan(14 * Math.PI / 180);   // steeper than this is a wall, not ground
const CLEAR = 3;                                   // px kept between the body and anything it must not cover
const SCALE = 100;                                 // the survey's scale: px to a metre, until it is corrected
const OFFSET = 7;                                  // a dimension line's distance from what it measures
const GAP = 2;                                     // an extension line starts this far from the object
const OVER = 3;                                    // and runs this far past the dimension line
const ERROR_ODDS = 53;                             // about one station in this many is a survey error…
const ERROR_FIRST = 24;                            // …once this many stations have been planted
const CALIBRATE_ODDS = 211;                        // a scale correction, rarer still
const OWN_UNIT_AFTER = 120;                        // stations before it trusts its own unit (W3)
const WIDTHS = 64;                                 // widths kept to set that unit
const READINGS = 24;                               // today's readings kept
const ERRORS = 40;

// [lo, hi] intervals minus (a, b).
function subtract(intervals, a, b) {
    const out = [];
    for (const [lo, hi] of intervals) {
        if (b <= lo || a >= hi) { out.push([lo, hi]); continue; }
        if (a > lo) out.push([lo, a]);
        if (b < hi) out.push([b, hi]);
    }
    return out;
}

// Where it can stand: each edge clipped to `bounds` and cut wherever its body would cover a keep-out rect (a control
// or text). A rect whose top is at or below the feet is the plane's own content, under the ground, so it is not in
// the way. Both feet stay on the edge (a third of the body in from each end). Segments are its centre's range, at
// least `min` long: {x1, x2, y1, y2, edge}.
function ledges(edges, keepOut, w, h, bounds, min) {
    const out = [];
    edges.forEach((e, i) => {
        let x1 = e.x1, y1 = e.y1, x2 = e.x2, y2 = e.y2;
        if (x2 < x1) { const tx = x1, ty = y1; x1 = x2; y1 = y2; x2 = tx; y2 = ty; }
        if (!(x2 - x1 >= 1)) return;
        const slope = (y2 - y1) / (x2 - x1);
        if (Math.abs(slope) > MAX_SLOPE) return;
        const yAt = x => y1 + slope * (x - x1);
        const lo = Math.max(x1 + w * 0.3, bounds.x + w / 2);
        const hi = Math.min(x2 - w * 0.3, bounds.x + bounds.width - w / 2);
        if (hi - lo < min) return;
        const top = Math.min(yAt(lo), yAt(hi)), bottom = Math.max(yAt(lo), yAt(hi));
        if (top - h < bounds.y || bottom > bounds.y + bounds.height) return;
        let free = [[lo, hi]];
        for (const r of keepOut) {
            if (r.y >= bottom - 1 || r.y + r.height <= top - h - CLEAR) continue;
            free = subtract(free, r.x - w / 2 - CLEAR, r.x + r.width + w / 2 + CLEAR);
            if (free.length === 0) break;
        }
        for (const [a, b] of free)
            if (b - a >= min) out.push({ x1: a, x2: b, y1: yAt(a), y2: yAt(b), edge: i });
    });
    return out;
}

function yAt(seg, x) {
    return seg.x2 - seg.x1 < 1e-6 ? seg.y1 : seg.y1 + (seg.y2 - seg.y1) * (x - seg.x1) / (seg.x2 - seg.x1);
}
function clampTo(seg, x) {
    return Math.max(seg.x1, Math.min(seg.x2, x));
}

// The standing point nearest (x, y): {seg, x, y, d}, or null when there is no ground. Segments cut from edge
// `skipEdge` (the floor it falls back on) are left out.
function nearest(segs, x, y, skipEdge) {
    let best = null;
    segs.forEach((s, i) => {
        if (skipEdge !== undefined && s.edge === skipEdge) return;
        const px = clampTo(s, x), py = yAt(s, px), d = Math.hypot(px - x, py - y);
        if (!best || d < best.d) best = { seg: i, x: px, y: py, d: d };
    });
    return best;
}

// Where it can hop to from (x, y) on segment `from`: the nearest point of every other segment within reach (it
// jumps `up` px at most and drops `down`), those ahead of it in `dir` first, then the nearest. [{seg, x, y, d}]
function hops(segs, from, x, y, dir, reach) {
    const out = [];
    segs.forEach((s, i) => {
        if (i === from) return;
        const px = clampTo(s, x), py = yAt(s, px), dx = px - x, dy = py - y, d = Math.hypot(dx, dy);
        if (Math.abs(dx) > reach.across || dy < -reach.up || dy > reach.down || d < 6) return;
        out.push({ seg: i, x: px, y: py, d: d, ahead: dx * dir >= 0 });
    });
    out.sort((a, b) => (a.ahead === b.ahead ? a.d - b.d : a.ahead ? -1 : 1));
    return out;
}

// A hop's arc at t ∈ [0, 1]: a parabola that clears the higher end by at least 18 px.
function arc(x0, y0, x1, y1, t) {
    const lift = 18 + Math.max(0, y0 - y1) * 0.75;
    return { x: x0 + (x1 - x0) * t, y: y0 + (y1 - y0) * t - lift * 4 * t * (1 - t) };
}
function hopTime(x0, y0, x1, y1) {
    return 0.32 + Math.hypot(x1 - x0, y1 - y0) / 900;
}

// The drafting for one measurement (dimension lines outside the object, as on a drawing): the width along the side
// facing the eye vertically, the height along the side facing it horizontally, kept inside `bounds`.
// {w: {y, x1, x2, ext: [{x, y1, y2}]}, h: {x, y1, y2, ext: [{y, x1, x2}]}, label: {x, y, below}}
function dimension(rect, eye, bounds) {
    const right = rect.x + rect.width, bottom = rect.y + rect.height;
    let below = eye.y > rect.y + rect.height / 2;
    let y = below ? bottom + OFFSET : rect.y - OFFSET;
    if (y > bounds.y + bounds.height - 1 || y < bounds.y + 1) { below = !below; y = below ? bottom + OFFSET : rect.y - OFFSET; }
    let left = eye.x < rect.x + rect.width / 2;
    let x = left ? rect.x - OFFSET : right + OFFSET;
    if (x < bounds.x + 1 || x > bounds.x + bounds.width - 1) { left = !left; x = left ? rect.x - OFFSET : right + OFFSET; }
    const from = below ? bottom + GAP : rect.y - GAP, to = below ? y + OVER : y - OVER;
    const side = left ? rect.x - GAP : right + GAP, past = left ? x - OVER : x + OVER;
    return {
        w: { y: y, x1: rect.x, x2: right, ext: [{ x: rect.x, y1: from, y2: to }, { x: right, y1: from, y2: to }] },
        h: { x: x, y1: rect.y, y2: bottom, ext: [{ y: rect.y, x1: side, x2: past }, { y: bottom, x1: side, x2: past }] },
        label: { x: rect.x + rect.width / 2, y: below ? y + 4 : y - 4, below: below }
    };
}

// Where a dimension's figure (w × h px) goes: on the width line's outer side (centred, then at either end), past the
// height line, or over the surveyor's head (`eye`), the first that covers no keep-out rect and stays in `bounds`.
// Returns {x, y}, its top left.
function labelSpot(d, keepOut, w, h, bounds, eye) {
    const below = d.label.below, wy = below ? d.w.y + 3 : d.w.y - 3 - h;
    const mid = (d.h.y1 + d.h.y2) / 2 - h / 2, left = d.h.x < d.w.x1;
    const spots = [
        { x: (d.w.x1 + d.w.x2) / 2 - w / 2, y: wy }, { x: d.w.x1, y: wy }, { x: d.w.x2 - w, y: wy },
        { x: left ? d.h.x - 4 - w : d.h.x + 4, y: mid },
        { x: eye.x - w / 2, y: eye.y - 34 - h }
    ];
    const inside = s => s.x >= bounds.x && s.y >= bounds.y && s.x + w <= bounds.x + bounds.width && s.y + h <= bounds.y + bounds.height;
    const free = s => !keepOut.some(r => s.x < r.x + r.width && s.x + w > r.x && s.y < r.y + r.height && s.y + h > r.y);
    return spots.find(s => inside(s) && free(s)) || spots[0];
}

// The nearest rect to (x, y) within `reach` whose index is not in `skip`, or -1.
function closest(rects, x, y, reach, skip) {
    let best = -1, bestD = reach;
    rects.forEach((r, i) => {
        if (skip && skip.indexOf(i) >= 0) return;
        const cx = Math.max(r.x, Math.min(r.x + r.width, x)), cy = Math.max(r.y, Math.min(r.y + r.height, y));
        const d = Math.hypot(cx - x, cy - y);
        if (d <= bestD) { best = i; bestD = d; }
    });
    return best;
}

// A w × h rect inside `bounds` touching no keep-out rect, as near (x, y) as a 16 px scan finds, or null: where the
// doorway that isn't there gets measured.
function freeRect(keepOut, bounds, w, h, x, y) {
    let best = null;
    for (let ry = bounds.y + 8; ry + h <= bounds.y + bounds.height - 8; ry += 16)
        for (let rx = bounds.x + 8; rx + w <= bounds.x + bounds.width - 8; rx += 16) {
            const hit = keepOut.some(r => rx < r.x + r.width + CLEAR && rx + w > r.x - CLEAR && ry < r.y + r.height + CLEAR && ry + h > r.y - CLEAR);
            if (hit) continue;
            const d = Math.hypot(rx + w / 2 - x, ry + h / 2 - y);
            if (!best || d < best.d) best = { x: rx, y: ry, width: w, height: h, d: d };
        }
    return best;
}

// The kind of thing measured, from a QML object's name ("FButton_QMLTYPE_12(0x…)"). Unknown things are a "spot":
// the surveyor has named all of them that (SurveyorNotes, the fifth note).
const KINDS = { FButton: "BUTTON", FToggle: "SWITCH", FChoice: "SELECTOR", FField: "FIELD", FMenuItem: "ROW", SheetTab: "TAB",
                LinkRow: "LINK", LinkPlane: "LINK", TaskRow: "TASK", FMeter: "METER", OrbitTile: "TILE", WorkspaceTab: "DESK",
                FWaveform: "SEEK", TextField: "FIELD", ComboBox: "SELECTOR", Slider: "SLIDER", CheckBox: "BOX", Switch: "SWITCH",
                TabButton: "TAB", Button: "BUTTON", AbstractButton: "BUTTON" };
// "SheetTab_QMLTYPE_246_QML_339(0x…)" → SheetTab; "QQuickSlider(0x…)" → Slider.
function typeName(described) {
    const m = /^([A-Za-z][A-Za-z0-9]*?)(?:_QMLTYPE_\d+)?(?:_QML_\d+)*\(/.exec(String(described));
    return m ? m[1].replace(/^QQuick(?=[A-Z])/, "") : "";
}
function kindOf(described) {
    return KINDS[typeName(described)] || "SPOT";
}

// A small, stable hash (FNV-1a), for the seeded schedule.
function hash(text) {
    let h = 0x811c9dc5;
    for (let i = 0; i < text.length; i++) {
        h ^= text.charCodeAt(i);
        h = Math.imul(h, 0x01000193) >>> 0;
    }
    return h >>> 0;
}

// The field book: what the surveyor writes while it walks in Overdrive, read back in the field archive. Room ids,
// kinds of control, sizes and dates only: never a label, a title or anything typed.
function fresh(seed) {
    return { version: 1, seed: seed >>> 0, day: "", stations: 0, total: 0, scale: SCALE, scaleDay: "", readings: [],
             walls: {}, errors: [], widths: [] };
}
function clean(saved, seed) {
    const b = fresh(seed);
    if (!saved || typeof saved !== "object" || Array.isArray(saved))
        return b;
    const num = v => typeof v === "number" && isFinite(v) && v >= 0;
    const str = v => typeof v === "string" && v.length <= 32;
    if (num(saved.seed)) b.seed = saved.seed >>> 0;
    if (str(saved.day)) b.day = saved.day;
    if (num(saved.stations)) b.stations = Math.floor(saved.stations);
    if (num(saved.total)) b.total = Math.floor(saved.total);
    if (num(saved.scale) && saved.scale >= 90 && saved.scale <= 110) b.scale = saved.scale;
    if (str(saved.scaleDay)) b.scaleDay = saved.scaleDay;
    if (Array.isArray(saved.readings))
        b.readings = saved.readings.filter(r => r && str(r.room) && str(r.kind) && num(r.w) && num(r.h)).slice(-READINGS)
            .map(r => ({ room: r.room, kind: r.kind, w: r.w, h: r.h, unit: r.unit === "SL" ? "SL" : "M" }));
    if (saved.walls && typeof saved.walls === "object" && !Array.isArray(saved.walls))
        for (const k of Object.keys(saved.walls)) {
            const w = saved.walls[k];
            if (str(k) && w && num(w.first) && num(w.last))
                b.walls[k] = { first: w.first, last: w.last, changes: num(w.changes) ? Math.floor(w.changes) : 0 };
        }
    if (Array.isArray(saved.errors))
        b.errors = saved.errors.filter(e => e && num(e.station) && typeof e.e === "number" && typeof e.n === "number" && str(e.day)).slice(-ERRORS)
            .map(e => ({ station: e.station, e: e.e, n: e.n, day: e.day }));
    if (Array.isArray(saved.widths))
        b.widths = saved.widths.filter(num).slice(-WIDTHS);
    return b;
}
function round2(v) { return Math.round(v * 100) / 100; }

// Its own unit (W3, "Its Own Coordinate Standard"): once it has planted enough stations, one survey length is the
// median width of everything it has measured, in metres. 0 until then.
function ownUnit(book) {
    if (book.total < OWN_UNIT_AFTER || book.widths.length < 8)
        return 0;
    const sorted = book.widths.slice().sort((a, b) => a - b);
    return round2(sorted[Math.floor(sorted.length / 2)]);
}
// A size in px as the surveyor reads it: metres at its current scale, or survey lengths once it has its own unit.
function measure(book, px) {
    const m = px / book.scale, unit = ownUnit(book);
    return unit > 0 ? { value: round2(m / unit), unit: "SL" } : { value: round2(m), unit: "M" };
}
function reading(book, w, h) {
    const a = measure(book, w), b = measure(book, h);
    return a.value.toFixed(2) + " × " + b.value.toFixed(2) + " " + a.unit;
}

// One station planted: the reading of a control (px), and the room's north wall (its width, px). A new day starts
// today's page; the walls and the errors are kept, and a wall that changes is counted.
function enter(book, r, day) {
    const b = clean(book, book.seed);
    if (b.day !== day) { b.day = day; b.stations = 0; b.readings = []; }
    b.stations += 1;
    b.total += 1;
    if (r.kind) {
        const m = measure(b, r.w), n = measure(b, r.h);
        b.readings = b.readings.concat([{ room: r.room, kind: r.kind, w: m.value, h: n.value, unit: m.unit }]).slice(-READINGS);
        b.widths = b.widths.concat([round2(r.w / b.scale)]).slice(-WIDTHS);
    }
    if (r.wall > 0 && r.room) {
        const wall = round2(r.wall / b.scale), old = b.walls[r.room];
        b.walls[r.room] = old ? { first: old.first, last: wall, changes: old.changes + (Math.abs(old.last - wall) >= 0.01 ? 1 : 0) }
                              : { first: wall, last: wall, changes: 0 };
    }
    return b;
}

// Survey errors (atlas #55): on a seeded schedule, past the first stations and at most once a day, a station records a
// coordinate where there is no room. Every error lies one doorway from the same hidden point, so in time they
// outline it: the False Room's place (W1), `locus(seed)`.
function isError(book, day) {
    if (book.total + 1 < ERROR_FIRST || book.errors.some(e => e.day === day))
        return false;
    return hash(book.seed + ":" + (book.total + 1)) % ERROR_ODDS === 0;
}
function locus(seed) {
    const h = hash("locus:" + seed);
    const bearing = (h % 3600) / 10 * Math.PI / 180, range = 6 + (h >>> 12) % 300 / 100;
    return { e: round2(Math.sin(bearing) * range), n: round2(Math.cos(bearing) * range), r: 1 };
}
function error(book, day) {
    const b = clean(book, book.seed), c = locus(b.seed), k = b.errors.length;
    const turn = k * 137.508 * Math.PI / 180;   // the golden angle: spread around the point, never twice the same
    b.errors = b.errors.concat([{ station: b.total + 1, e: round2(c.e + Math.sin(turn) * c.r), n: round2(c.n + Math.cos(turn) * c.r), day: day }]).slice(-ERRORS);
    return b;
}

// Calibration disagreement (atlas #56): rarely, it corrects its scale by a pixel. Its readings disagree with the
// earlier ones in the book from then on; the correction is undone the next day.
function calibrate(book, day) {
    const b = clean(book, book.seed);
    if (b.scaleDay && b.scaleDay !== day) { b.scale = SCALE; b.scaleDay = ""; }
    if (!b.scaleDay && b.total > ERROR_FIRST && hash("scale:" + b.seed + ":" + b.total) % CALIBRATE_ODDS === 0) {
        b.scale = SCALE + (hash("sign:" + b.total) % 2 ? 1 : -1);
        b.scaleDay = day;
    }
    return b;
}

// The rooms' names as the index shows them.
const NAMES = { home: "Home", media: "Media", performance: "Performance", workspaces: "Workspaces", devices: "Devices",
                tasks: "Tasks", timers: "Timers", clipboard: "Clips", notifications: "Inbox", codex: "Codex" };
// The book as the archive sets it: [{text, tone}] with tone "" (plain), "faint" or "error".
function lines(book, names) {
    const out = [];
    const name = id => ((names || NAMES)[id] || id).toUpperCase();
    if (book.total === 0)
        return out;
    const unit = ownUnit(book);
    out.push({ text: "STATIONS TODAY " + book.stations + " · SINCE THE SURVEY BEGAN " + book.total, tone: "faint" });
    if (book.scaleDay)
        out.push({ text: "SCALE CORRECTED · 1 M = " + book.scale + " PX", tone: "" });
    if (unit > 0)
        out.push({ text: "1 SURVEY LENGTH = " + unit.toFixed(2) + " M · THE MIDDLE OF EVERYTHING MEASURED", tone: "" });
    const seen = {};
    const recent = [];
    for (let i = book.readings.length - 1; i >= 0 && recent.length < 6; i--) {
        const r = book.readings[i], key = r.room + "/" + r.kind;
        if (seen[key]) continue;
        seen[key] = true;
        recent.push(r);
    }
    for (const r of recent)
        out.push({ text: name(r.room) + " / " + r.kind + "   " + r.w.toFixed(2) + " × " + r.h.toFixed(2) + " " + r.unit, tone: "" });
    for (const id of Object.keys(book.walls).sort()) {
        const w = book.walls[id];
        if (w.changes > 0)
            out.push({ text: "NORTH WALL OF " + name(id) + "   " + w.first.toFixed(2) + " M ON ARRIVAL · " + w.last.toFixed(2) + " M NOW", tone: "" });
    }
    for (const e of book.errors.slice(-4))
        out.push({ text: "STATION " + e.station + "   E " + e.e.toFixed(2) + "  N " + e.n.toFixed(2) + "   NO ROOM AT THIS COORDINATE", tone: "error" });
    return out;
}

// Creature parallax (atlas #57): where on the footer it is found. Once the journey has enough visits, the x of the
// room you have neglected most (least time), as the footer's ruler places the rooms; otherwise -1.
function neglected(journey, rooms) {
    if (!journey || !rooms || rooms.length === 0)
        return "";
    const visits = journey.visits || {}, seconds = journey.seconds || {};
    let total = 0;
    for (const k of Object.keys(visits)) total += visits[k] || 0;
    if (total < 30)
        return "";
    let best = "", least = Infinity;
    for (const id of rooms) {
        const s = seconds[id] || 0;
        if (s < least) { least = s; best = id; }
    }
    return best;
}
function stationX(rooms, id, width) {
    const i = rooms.indexOf(id);
    return i < 0 ? -1 : (i + 0.5) * width / rooms.length;
}
