.pragma library

// The Inbox as the day's sky (Z210): each notification a comet at the time it came, high when urgent, low when
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
