.pragma library
// The False Room (docs/OVERDRIVE_IDEAS.md W1, docs/OVERDRIVE.md §53). After weeks of use the orbit shows a room
// numbered −1 at the place the surveyor's errors keep pointing to (view/rooms/Survey.js, locus). It can't be clicked
// and its number does nothing. Only while several genuine conditions of the machine coincide does it grow one hairline
// stalk and let you in; inside are no controls, only a geometric reconstruction of metadata about past sessions: rooms
// visited, when, for how long, and the machine's state now in classes. Never contents. Once entered, that set of
// conditions is spent: the room waits for a different one. Pure: no Qt (tests/test_false_room.py).

// The survey errors it takes before the room is drawn at all: the surveyor makes at most one a day, about one station
// in 53, so this is weeks of use.
const SIGHTED_AFTER = 3;
// The navigation must have a history before a sequence in it can be rare.
const HISTORY_HOPS = 40;
// A hop is rare if it has been made at most this many times.
const RARE_HOP = 2;

function hash(s) {
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = Math.imul(h, 16777619) >>> 0;
    }
    return h >>> 0;
}
function sighted(book) {
    return !!book && Array.isArray(book.errors) && book.errors.length >= SIGHTED_AFTER;
}
// Local mean sidereal time, hours, from the civil moment and a longitude in degrees east (Meeus 12.4, to a second).
function sidereal(ms, longitude) {
    const d = ms / 86400000 + 2440587.5 - 2451545.0;
    const gmst = 280.46061837 + 360.98564736629 * d;
    return (((gmst + longitude) % 360 + 360) % 360) / 15;
}
// The room's own sidereal hour, from the survey's seed: once a sidereal day, four minutes earlier each civil day.
function hour(seed) {
    return hash("false-room:" + seed) % 24;
}
// The conditions, each a real reading: the sky at the room's hour; the machine on its own battery; nothing playing;
// and the last two hops through the rooms both rare in a history long enough to say so.
// state: { lst, seed, battery: { available, charging }, playing, recent: [[room, t]], edges: { "a>b": n } }
function conditions(state) {
    const s = state || {};
    const lst = Number(s.lst);
    const sky = Number.isFinite(lst) && Math.floor(lst) === hour(s.seed ?? 0);
    const battery = !!(s.battery && s.battery.available && !s.battery.charging);
    const quiet = s.playing === false;
    const edges = s.edges || {};
    let hops = 0;
    for (const k in edges)
        hops += Number(edges[k]) || 0;
    const recent = Array.isArray(s.recent) ? s.recent.slice(-3).map(r => r[0]) : [];
    const rare = hops >= HISTORY_HOPS && recent.length === 3 && recent[0] !== recent[1] && recent[1] !== recent[2]
        && (edges[recent[0] + ">" + recent[1]] ?? 0) <= RARE_HOP && (edges[recent[1] + ">" + recent[2]] ?? 0) <= RARE_HOP;
    return { sky: sky, battery: battery, quiet: quiet, rare: rare, all: sky && battery && quiet && rare,
             signature: Math.floor(lst) + ":" + recent.join(">") };
}
// Open only for a set of conditions not already spent.
function open(conds, spent) {
    return !!conds && conds.all && !(Array.isArray(spent) && spent.indexOf(conds.signature) >= 0);
}
function spend(spent, signature) {
    const list = Array.isArray(spent) ? spent.filter(s => typeof s === "string" && s.length <= 64) : [];
    return list.indexOf(signature) >= 0 ? list : list.concat([signature]).slice(-16);
}
// Where it stands on the orbit: the locus's bearing as the orbit's angle, its range (6–9 doorways) as a radius past
// the outermost room. Returns { theta, r } with r in units of the orbit's outer radius.
function place(locus) {
    const e0 = Number(locus?.e), n0 = Number(locus?.n);
    const e = Number.isFinite(e0) ? e0 : 0, n = Number.isFinite(n0) ? n0 : 6;
    const range = Math.sqrt(e * e + n * n);
    return { theta: Math.atan2(e, n), r: 1.18 + Math.max(0, Math.min(3, range - 6)) / 3 * 0.22 };
}
// The field book's notes on it (the archive, under the surveyor's own lines): the surveyor learns the room one error at
// a time. Two errors that agree, then where it stands, then each of its conditions in turn, then how often it has
// been entered. Lines as Survey.lines makes them: { text, tone }. `locus` is Survey.locus(seed).
function notes(book, locus, spent) {
    const k = book && Array.isArray(book.errors) ? book.errors.length : 0;
    const out = [];
    if (k < 2)
        return out;
    out.push({ text: "THE ERRORS DO NOT SCATTER · THEY CLOSE ON ONE POINT", tone: "faint" });
    if (k < SIGHTED_AFTER)
        return out;
    const e = Number(locus?.e) || 0, n = Number(locus?.n) || 0;
    const bearing = Math.round((Math.atan2(e, n) * 180 / Math.PI + 360) % 360);
    out.push({ text: "STATION −1   E " + e.toFixed(2) + "  N " + n.toFixed(2) + "   BEARING " + String(bearing).padStart(3, "0")
                     + "°   A FRAME WHERE THE PLAN HAS NO ROOM · THE SURVEYOR SITS FACING IT", tone: "error" });
    const seen = [
        "SEEN STANDING ONCE AT " + String(hour(book.seed ?? 0)).padStart(2, "0") + "H BY THE STARS · NOT BY THE CLOCK",
        "ONLY WHILE THE MACHINE RAN ON ITS OWN CELL",
        "ONLY IN SILENCE · NOTHING PLAYING · EARS UP THE WHOLE TIME",
        "ONLY AFTER A ROUTE THROUGH THE ROOMS SELDOM WALKED"
    ];
    for (let i = 0; i < seen.length && k > SIGHTED_AFTER + i; i++)
        out.push({ text: seen[i], tone: "" });
    const entered = Array.isArray(spent) ? spent.length : 0;
    if (entered > 0)
        out.push({ text: "ENTERED " + entered + (entered === 1 ? " TIME" : " TIMES")
                         + " · INSIDE, ONLY THE RECORD OF THE OTHER ROOMS · THE SAME WAY IN DOES NOT OPEN IT TWICE"
                         + " · THE SURVEYOR WAITED ON THE STEP EVERY TIME", tone: "faint" });
    return out;
}
// What the machine is doing now, in classes only.
function pressure(usage) {
    if (!Number.isFinite(usage))
        return "—";
    return usage < 15 ? "I" : usage < 40 ? "II" : usage < 75 ? "III" : "IV";
}

// The reconstruction, in a square of side `size` centred on 0,0: one spoke per room (Home at the top, clockwise), its
// length the log of the time spent there; a tick along it per visit (forty at most); the day's twenty-four hours as a
// ring of bars, the hours the rooms were used in; and the last hops as a path between the spokes' tips, each stop
// stamped with its minute. rooms: ids in order; journey: core/journey.py's state.
function reconstruct(rooms, journey, size) {
    const j = journey || {};
    const seconds = j.seconds || {}, visits = j.visits || {}, hours = j.hours || {};
    const R = size / 2, inner = R * 0.12, reach = R * 0.62;
    let most = 1;
    for (const id of rooms)
        most = Math.max(most, Math.log(1 + (Number(seconds[id]) || 0)));
    const spokes = rooms.map((id, i) => {
        const a = -Math.PI / 2 + i * 2 * Math.PI / rooms.length;
        const len = inner + (reach - inner) * Math.log(1 + (Number(seconds[id]) || 0)) / most;
        const n = Math.min(40, Math.max(0, Math.floor(Number(visits[id]) || 0)));
        const ticks = [];
        for (let k = 1; k <= n; k++) {
            const t = inner + (len - inner) * k / (n + 1);
            ticks.push({ x: Math.cos(a) * t, y: Math.sin(a) * t });
        }
        return { id: id, index: i, angle: a, x: Math.cos(a) * len, y: Math.sin(a) * len, ticks: ticks };
    });
    const day = [];
    let peak = 0;
    for (let h = 0; h < 24; h++) {
        let sum = 0;
        for (const id of rooms)
            sum += Array.isArray(hours[id]) ? Number(hours[id][h]) || 0 : 0;
        day.push(sum);
        peak = Math.max(peak, sum);
    }
    const ring = day.map((v, h) => {
        const a = -Math.PI / 2 + h * 2 * Math.PI / 24, r0 = R * 0.72, r1 = r0 + (peak > 0 ? R * 0.2 * v / peak : 0);
        return { hour: h, x0: Math.cos(a) * r0, y0: Math.sin(a) * r0, x1: Math.cos(a) * r1, y1: Math.sin(a) * r1 };
    });
    const tip = {};
    for (const s of spokes)
        tip[s.id] = s;
    const path = (Array.isArray(j.recent) ? j.recent.slice(-12) : []).filter(r => tip[r[0]]).map(r => {
        const d = new Date(r[1] * 1000);
        return { id: r[0], x: tip[r[0]].x, y: tip[r[0]].y,
                 stamp: String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0") };
    });
    return { spokes: spokes, ring: ring, path: path };
}
