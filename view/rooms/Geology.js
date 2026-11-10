.pragma library

// The machine's geology (docs/OVERDRIVE.md §28; atlas #16, #22), from the weather's reports (core/weather.py): pure,
// no Qt, tests run it under Node (tests/test_geology.py). Entries come oldest first.

// Thermal stratigraphy (#16): each report deposits a layer, oldest at the bottom. A layer's thickness is its span
// (square-rooted, so a night doesn't bury the day), compacted by heat: hot periods press thin. Its tone is how hot it
// was, 0 (cool, pale) to 1 (hot, dense). Scaled to fit `height`: [{y, h, tone, temp}], y from the top.
function layers(strata, height) {
    const raw = (strata || []).filter(s => s && s.span > 0).map(s => {
        const hot = Number.isFinite(s.temp) ? Math.max(0, Math.min(1, (s.temp - 40) / 45)) : 0.3;
        return { h: Math.sqrt(s.span / 600) / (1 + 2 * hot), tone: hot, temp: s.temp };
    });
    const total = raw.reduce((a, l) => a + l.h, 0);
    if (total <= 0)
        return [];
    const k = height / total;
    let y = height;
    return raw.map(l => {
        const h = l.h * k;
        y -= h;
        return { y: y, h: h, tone: l.tone, temp: l.temp };
    });
}

// The battery ledger (#22): each report an entry across `width`, as wide as its span (square-rooted), sunk by the share
// of the battery it spent, or raised (a credit) when it charged. [{x, w, depth, credit}], depth 0–1.
function ledger(entries, width) {
    const raw = (entries || []).filter(e => e && e.span > 0 && Number.isFinite(e.battery)).map(e => {
        const spent = Number.isFinite(e.drain) ? e.drain * e.span / 3600 : 0;   // % of the battery over the entry
        return { w: Math.sqrt(e.span / 600), depth: Math.max(0, Math.min(1, Math.abs(spent) / 40)), credit: spent < 0 };
    });
    const total = raw.reduce((a, e) => a + e.w, 0);
    if (total <= 0)
        return [];
    const k = width / total;
    let x = 0;
    return raw.map(e => {
        const w = e.w * k, out = { x: x, w: w, depth: e.depth, credit: e.credit };
        x += w;
        return out;
    });
}
