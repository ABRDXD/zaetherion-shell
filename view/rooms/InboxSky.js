.pragma library

// The Inbox as the day's sky (Z211): each notification a comet at the time it came, high when urgent, low when
// quiet, with a tail while unread. Pure layout, so tests can run it under Node. Times are ms since the epoch.

const HOUR = 3600000;
// The sky shows at least this many hours back from now, and at most a day.
const MIN_SPAN = 6 * HOUR;
const MAX_SPAN = 24 * HOUR;
// Heights by urgency, as shares of the sky from its top (critical high, low near the horizon).
const BANDS = { critical: 0.16, normal: 0.46, low: 0.78 };
// Comets in the same band are staggered by this share so near neighbours don't sit on one line.
const STAGGER = 0.09;

function ms(time) { return time > 1e12 ? time : time * 1000; }

// The sky's time span: from the oldest notice (at least MIN_SPAN, at most MAX_SPAN back) to now.
function span(items, now) {
    let oldest = now;
    for (const n of items) oldest = Math.min(oldest, ms(n.time));
    const back = Math.max(MIN_SPAN, Math.min(MAX_SPAN, now - oldest));
    return { from: now - back, to: now };
}

// 0 (left edge, oldest) – 1 (now). Older than the span pins to the left edge.
function along(time, s) { return Math.max(0, Math.min(1, (ms(time) - s.from) / Math.max(1, s.to - s.from))); }

// 0 (top) – 1 (horizon) for the k-th notice.
function height(urgency, k) {
    const base = BANDS[urgency] ?? BANDS.normal;
    return base + (k % 2 ? STAGGER : 0);
}

// Whole hours inside the span, each as { at: 0–1, hour }; every `step` hours so they don't crowd.
function hours(s) {
    const total = (s.to - s.from) / HOUR, step = total > 12 ? 3 : total > 6 ? 2 : 1;
    const out = [];
    const first = new Date(s.from); first.setMinutes(0, 0, 0);
    for (let t = first.getTime() + HOUR; t <= s.to; t += HOUR) {
        const h = new Date(t).getHours();
        if (h % step === 0) out.push({ at: (t - s.from) / (s.to - s.from), hour: h });
    }
    return out;
}

// The notice the reading panel starts on: the newest unread, else the newest; null when there are none.
function initial(items) {
    for (let i = items.length - 1; i >= 0; i--) if (!items[i].read) return items[i].id;
    return items.length ? items[items.length - 1].id : null;
}

// "Claude Code, Discord" for the apps with something unread (in order of first arrival), or "all caught up".
function unreadLine(items) {
    const apps = [];
    for (const n of items) if (!n.read && apps.indexOf(n.appName) < 0) apps.push(n.appName);
    return apps.length ? apps.join(", ") : "all caught up";
}

const RANK = { critical: 2, normal: 1, low: 0 };

// Notices that would sit on one spot become one comet (Z211, after real use: 59 notices smeared into one blur).
// Within one urgency, a notice closer than `bin` (a share of the sky's width) to the cluster's newest joins it.
// Each cluster: { ids (newest first), id (the newest), time, urgency, unread (any), count, appName (the newest's), row }.
function clusters(items, s, bin) {
    const sorted = items.slice().sort((a, b) => ms(a.time) - ms(b.time));
    const open = {};   // urgency → the cluster still taking notices
    const out = [];
    for (const n of sorted) {
        const u = RANK[n.urgency] !== undefined ? n.urgency : "normal";
        const at = along(n.time, s);
        const c = open[u];
        if (c && at - c.at <= bin) {
            c.ids.unshift(n.id);
            c.id = n.id; c.time = n.time; c.at = at; c.appName = n.appName;
            c.unread = c.unread || !n.read;
            c.count += 1;
        } else {
            const fresh = { ids: [n.id], id: n.id, time: n.time, at: at, urgency: u, unread: !n.read, count: 1, appName: n.appName, row: 0 };
            out.push(fresh);
            open[u] = fresh;
        }
    }
    // alternate rows within a band so neighbouring comets don't share a line
    const seen = {};
    for (const c of out) { c.row = seen[c.urgency] || 0; seen[c.urgency] = 1 - c.row; }
    return out;
}

// Which clusters get a name under them: the newest first, each only if no named neighbour in its band and row is
// nearer than `gap` (a share of the width); the chosen one always.
function labelled(list, gap, chosenId) {
    const named = [];
    const keep = {};
    const order = list.slice().sort((a, b) => ms(b.time) - ms(a.time));
    for (const c of order) {
        const isChosen = c.ids.indexOf(chosenId) >= 0;
        const clash = named.some(o => o.urgency === c.urgency && o.row === c.row && Math.abs(o.at - c.at) < gap);
        if (isChosen || !clash) { keep[c.id] = true; named.push(c); }
    }
    return keep;
}

// The next notice to read when a cluster is clicked: its newest, or (already reading one of it) the next older, wrapping.
function step(cluster, currentId) {
    const i = cluster.ids.indexOf(currentId);
    return i < 0 ? cluster.ids[0] : cluster.ids[(i + 1) % cluster.ids.length];
}
