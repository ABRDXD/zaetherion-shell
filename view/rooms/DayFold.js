.pragma library
// Home as a folded sheet and as an edition (docs/OVERDRIVE.md §36; atlas #9, #11). Pure: no Qt, no clock, so Node
// tests run it (tests/test_day_fold.py). Hours are local civil hours, 0–24, placed across the sheet as the day ruler
// places them (DayTime.x), so a crease stands right above its hour.
//
// Day Fold (#9): each time Home is opened in Overdrive the sheet is pressed with a crease where the day is. The paper
// keeps its creases through the day (older ones relax), so the day's openings stand on the sheet as a fold pattern;
// at midnight there is a fresh sheet. The newest crease splits the sheet into the past (folded under, in shade) and the
// rest; the next solar event is marked as a fold not yet made, and past it lies the next plane, tilted to the light.
// Editions (#11): Home is set as an edition of the day's paper: which one from the sun (early, morning, afternoon,
// evening, late final), its printing the number of creases, and its front page (the order of the Today cards, the lead
// card set wide) from the edition's priorities and the rooms you've used today.

// The day's sheet, kept for the session (not saved: a restart is a fresh sheet).
const kept = { sheet: null };

const MAX = 24;            // creases kept a day
const MERGE = 0.012;       // a crease this close (in sheet widths) to an older one presses that one again
const RELAX = 0.82;        // an older crease's depth, per newer crease

// The sheet's creases for `day` after an opening at hour `h`, placed at x (0–1). `sheet` is {day, creases: [{h, x, n}]}
// (n: times pressed). Returns a new sheet.
function press(sheet, day, h, x) {
    const fresh = !sheet || sheet.day !== day;
    const creases = fresh ? [] : sheet.creases.map(c => ({ h: c.h, x: c.x, n: c.n }));
    const near = creases.findIndex(c => Math.abs(c.x - x) < MERGE);
    if (near >= 0) {
        const c = creases.splice(near, 1)[0];
        creases.push({ h: h, x: x, n: c.n + 1 });
    } else {
        creases.push({ h: h, x: x, n: 1 });
    }
    return { day: day, creases: creases.slice(-MAX) };
}

// Each crease's depth (0–1): the newest is sharp, older ones relax; one pressed again holds deeper. Mountain and valley
// alternate as the paper is folded back and forth, newest first.
function folds(sheet) {
    if (!sheet || !sheet.creases.length)
        return [];
    const n = sheet.creases.length;
    return sheet.creases.map((c, i) => {
        const age = n - 1 - i;
        return { x: c.x, h: c.h, depth: Math.min(1, Math.pow(RELAX, age) * (1 + 0.25 * (c.n - 1))), valley: age % 2 === 0, newest: age === 0 };
    });
}

// The next solar event after `h`: {h, name}, from today's sunrise, noon and sunset (hours; NaN when there's no sky).
// After sunset it is tomorrow's sunrise, about the same hour (h + 24 wraps to the sheet's far edge: x = 1).
function next(h, rise, noon, set) {
    const events = [[rise, "SUNRISE"], [noon, "NOON"], [set, "SUNSET"]].filter(e => Number.isFinite(e[0]));
    for (const e of events)
        if (e[0] > h)
            return { h: e[0], name: e[1] };
    return Number.isFinite(rise) ? { h: 24, name: "SUNRISE", tomorrow: true } : null;
}

// The edition, from the sun (or the clock when there's no sky).
function edition(h, rise, noon, set) {
    const r = Number.isFinite(rise) ? rise : 6, s = Number.isFinite(set) ? set : 18;
    const m = Number.isFinite(noon) ? noon : (r + s) / 2;
    if (h < r) return "EARLY EDITION";
    if (h < m) return "MORNING EDITION";
    if (h < s) return "AFTERNOON EDITION";
    if (h < 22) return "EVENING EDITION";
    return "LATE FINAL";
}

function ordinal(n) {
    const t = n % 100;
    if (t >= 11 && t <= 13) return n + "TH";
    return n + (["TH", "ST", "ND", "RD"][n % 10] ?? "TH");
}
function printing(sheet) {
    const n = sheet ? sheet.creases.reduce((s, c) => s + c.n, 0) : 0;
    return n > 0 ? ordinal(n) + " PRINTING" : "";
}

// The editions' priorities: morning is readiness (the desk, timers, then tasks and the inbox); afternoon is the work;
// evening is what's left (tasks unfinished, timers, the inbox), the desk last.
const PRIORITY = {
    "EARLY EDITION":     ["timers", "notifications", "tasks", "workspaces"],
    "MORNING EDITION":   ["workspaces", "timers", "tasks", "notifications"],
    "AFTERNOON EDITION": ["tasks", "workspaces", "notifications", "timers"],
    "EVENING EDITION":   ["tasks", "timers", "notifications", "workspaces"],
    "LATE FINAL":        ["notifications", "tasks", "timers", "workspaces"]
};

// The front page: the cards' rooms in order. Each room scores its place in the edition's priorities, plus the visits
// it has had today (`today`: {room: visits}, the journey's day), so the rooms you're living in move up; ties keep the
// edition's order. The first is the lead.
function front(rooms, name, today) {
    const order = PRIORITY[name] ?? rooms;
    const visits = today ?? {};
    const most = Math.max(1, ...rooms.map(r => visits[r] ?? 0));
    const score = r => (order.length - Math.max(0, order.indexOf(r))) + 3.5 * (visits[r] ?? 0) / most;
    return rooms.slice().sort((a, b) => score(b) - score(a) || order.indexOf(a) - order.indexOf(b));
}
