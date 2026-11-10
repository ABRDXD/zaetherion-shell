.pragma library

// Inbox's attention band (docs/OVERDRIVE.md §23; atlas #33, #34, #35): pure, no Qt and no clock, so tests run it under
// Node (tests/test_attention.py). Items are the notifications contract's {appName, time (ms), urgency, read}; only
// sources, counts and times are used, never a summary or a body.

const DAY = 24 * 3600 * 1000;

function ms(time) {
    return time > 1e12 ? time : time * 1000;
}

// Arrival cadence (#34): each arrival in the last `span` ms as a tick, x from 0 (span ago) to 1 (now).
function cadence(items, now, span) {
    span = span || DAY;
    return (items || []).filter(n => now - ms(n.time) >= 0 && now - ms(n.time) <= span)
        .map(n => ({ x: 1 - (now - ms(n.time)) / span, unread: !n.read, urgent: n.urgency === "critical", app: n.appName }))
        .sort((a, b) => a.x - b.x);
}

// The sources with unread items, the longest-ignored first: [{app, unread, oldest}].
function sources(items) {
    const by = {};
    for (const n of items || []) {
        if (n.read) continue;
        const s = by[n.appName] || (by[n.appName] = { app: n.appName, unread: 0, oldest: Infinity });
        s.unread += 1;
        s.oldest = Math.min(s.oldest, ms(n.time));
    }
    return Object.keys(by).map(k => by[k]).sort((a, b) => a.oldest - b.oldest || (a.app < b.app ? -1 : 1));
}

// Source eclipse (#33): slabs across the attention axis, each as wide as its unread count calls for, each overlapping
// the one before by 40 %, compressed to fit `width`. [{x, w, app, unread}]
function eclipse(list, width) {
    const out = [];
    let x = 0;
    list.forEach((s, i) => {
        const w = Math.min(width / 3, 14 + 16 * s.unread);
        if (i > 0) x += out[i - 1].w * 0.6;
        out.push({ x: x, w: w, app: s.app, unread: s.unread });
    });
    const extent = out.length ? out[out.length - 1].x + out[out.length - 1].w : 0;
    const k = extent > width ? width / extent : 1;
    return out.map(s => ({ x: s.x * k, w: s.w * k, app: s.app, unread: s.unread }));
}

// Silence debt (#35): each unread item weighs by how long it has been left, a whole one after a day.
function debt(items, now) {
    let d = 0;
    for (const n of items || [])
        if (!n.read) d += Math.max(0, Math.min(1, (now - ms(n.time)) / DAY));
    return d;
}
// The overhang it hangs from the band's right edge, in px: nothing without debt.
function overhang(d) {
    return d <= 0 ? 0 : Math.min(120, 6 + 22 * Math.sqrt(d));
}
