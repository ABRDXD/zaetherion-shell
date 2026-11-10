.pragma library

// Kinetic lyrics (M9): the pure timing under Overdrive's music-video type. No QML, no clock:
// times are passed in, so tests run it under Node (tests/test_kinetic_lyrics.py).
// Lines are LyricsDomain's { time, end, text, words: [{ time, end, text }] }, in seconds.

// Han, kana (with the half-width forms) and Hangul: each character is a sung unit, set vertically.
const CJK = /[぀-ヿㇰ-ㇿ㐀-䶿一-鿿豈-﫿ｦ-ﾟ가-힯]/;
// Punctuation that rides on the unit before it and weighs nothing.
const PUNCT = /[\s.,!?;:'"`’‘“”()\[\]{}\-–—…、。，．！？：；「」『』（）《》〈〉【】・〜~♪]/g;
const PUNCT_ONLY = /^[\s.,!?;:'"`’‘“”()\[\]{}\-–—…、。，．！？：；「」『』（）《》〈〉【】・〜~♪]+$/;

// The character-weighted fallback (lines with no word timing).
const CJK_WEIGHT = 2.5;       // one CJK character sings about as long as 2–3 Latin letters
const WORD_GAP = 0.5;         // each Latin word also pays for the breath before the next
const PACE = 0.3;             // a line's sung span is at most this many seconds per weight unit…
const MIN_SPAN = 0.8;         // …but never shorter than this, so short lines don't flicker
// Cuts (a new frame of type) at most 3 a second: CUES §7, the M9 cut cap.
const CUT_GAP = 1 / 3;

// Credits that some sources (NetEase-style LRC) time as lines, usually at 0:00 before an intro: "作词 : 中村未来",
// "作曲：…", "Composer: …". They are not sung, so the stage never slams them in.
const CREDIT = /^\s*(?:作词|作詞|作曲|编曲|編曲|填词|词曲|詞曲|原唱|制作人|製作人|监制|監製|出品|发行|發行|混音|母带|母帶|录音|錄音|和声|和聲|吉他|贝斯|貝斯|鼓|键盘|鍵盤|弦乐|弦樂|策划|统筹|词|詞|曲|(?:lyrics?|lyricist|words?|music|composer|composed|compos(?:ition|er)|arranger|arranged|arrangement|producer|produced|vocals?|mix(?:ed|ing)?|master(?:ed|ing)?|written)(?:\s+by)?)\s*[:：]/i;

function credit(text) {
    return CREDIT.test(String(text || ""));
}

function isCjk(ch) {
    return CJK.test(ch);
}

// The share of a text's sung units (tokens) that are CJK: "君の name" is two of three.
function cjkShare(text) {
    const parts = tokens(text);
    if (parts.length === 0) return 0;
    return parts.filter(t => [...t].some(isCjk)).length / parts.length;
}

// A line runs vertically when most of it is CJK.
function vertical(text) {
    return cjkShare(text) >= 0.5;
}

// The sung units of a text: each CJK character, each other word; punctuation joins the unit before it
// (or the one after, at the start).
function tokens(text) {
    const out = [];
    let word = "";
    let lead = "";
    const flush = () => { if (word) { out.push(lead + word); lead = ""; word = ""; } };
    for (const ch of String(text || "")) {
        if (/\s/.test(ch)) { flush(); continue; }
        if (PUNCT_ONLY.test(ch)) {
            if (word) word += ch;
            else if (out.length) out[out.length - 1] += ch;
            else lead += ch;
            continue;
        }
        if (isCjk(ch)) { flush(); word = ch; flush(); continue; }
        word += ch;
    }
    flush();
    if (lead && out.length) out[out.length - 1] += lead;
    return out;
}

function weight(token) {
    const units = [...String(token).replace(PUNCT, "")];
    if (units.length === 0) return 0.25;
    let total = 0, latin = false;
    for (const ch of units) {
        if (isCjk(ch)) total += CJK_WEIGHT;
        else { total += 1; latin = true; }
    }
    return total + (latin ? WORD_GAP : 0);
}

// The end of a line's singing: its end, but no later than its pace allows, so a line before a long
// instrumental doesn't stretch its last word across the gap.
function sungEnd(line, units) {
    const start = Number(line.time) || 0;
    const end = Number(line.end) > start ? Number(line.end) : start + MIN_SPAN;
    return Math.min(end, start + Math.max(MIN_SPAN, units * PACE));
}

// One line's words, each { text, time, end, weight, cjk, timed }. Real word timing when the line has it
// (ends clamped into order), otherwise the character-weighted fallback over the sung span.
function timeWords(line) {
    if (!line) return [];
    const start = Number(line.time) || 0;
    const given = (Array.isArray(line.words) ? line.words : [])
        .map(w => ({ text: String(w.text ?? "").trim(), time: Number(w.time) || 0, end: Number(w.end ?? w.endTime) || 0 }))
        .filter(w => w.text.length > 0)
        .sort((a, b) => a.time - b.time);
    if (given.length > 0) {
        const lineEnd = Number(line.end) > start ? Number(line.end) : Infinity;
        return given.map((w, i) => {
            const next = i + 1 < given.length ? given[i + 1].time : lineEnd;
            let end = w.end > w.time ? Math.min(w.end, next) : next;
            if (!isFinite(end)) end = w.time + MIN_SPAN;
            return { text: w.text, time: w.time, end: Math.max(w.time, end), weight: weight(w.text), cjk: cjkShare(w.text) >= 0.5, timed: true };
        });
    }
    const parts = tokens(line.text);
    if (parts.length === 0) return [];
    const weights = parts.map(weight);
    const units = weights.reduce((a, b) => a + b, 0);
    const span = sungEnd(line, units) - start;
    let t = start;
    return parts.map((text, i) => {
        const time = t;
        t += span * weights[i] / units;
        return { text, time, end: i === parts.length - 1 ? start + span : t, weight: weights[i], cjk: cjkShare(text) >= 0.5, timed: false };
    });
}

// The last word whose time has come, or -1 before the first.
function wordAt(words, t) {
    let low = 0, high = words.length - 1, result = -1;
    while (low <= high) {
        const mid = (low + high) >> 1;
        if (words[mid].time <= t) { result = mid; low = mid + 1; } else high = mid - 1;
    }
    return result;
}

// A word's size against the base, by how long it is sung: a clipped word is small, a held one huge.
function scaleFor(duration) {
    const d = Math.max(0, Number(duration) || 0);
    return Math.min(2.6, Math.max(0.7, Math.sqrt(d / 0.35)));
}

// A line's frames: the words shown together before a cut clears them. A frame closes when it would
// pass `maxUnits` (Latin letters; a CJK character counts double) or on a long held word, and a frame
// shorter than the cut gap is merged into the one before, so cuts never come faster than 3 a second.
// Each frame is { time, end, first, last } (word indices, inclusive).
function frames(words, maxUnits) {
    const limit = maxUnits > 0 ? maxUnits : 16;
    const out = [];
    let current = null, units = 0;
    words.forEach((w, i) => {
        const size = [...w.text].reduce((n, ch) => n + (isCjk(ch) ? 2 : 1), 0);
        const held = w.end - w.time >= 1.2;
        if (!current || units + size > limit || held) {
            if (current && w.time - current.time < CUT_GAP) {
                // Too soon for a cut: the word joins the frame on screen.
                current.last = i;
                current.end = w.end;
                units += size;
                return;
            }
            current = { time: w.time, end: w.end, first: i, last: i };
            out.push(current);
            units = size;
            return;
        }
        current.last = i;
        current.end = w.end;
        units += size;
    });
    return out;
}

// Beats from the host spectrum (lease "spectrum", 56 bins 0..1): half-wave-rectified spectral flux,
// the bass weighted double, against an adaptive threshold (mean + k·sd over the last `window` s).
// push(bins, t) returns the onset's strength 0..1, or 0 when there is none. t is in seconds.
function detector(options) {
    const o = Object.assign({ window: 1.0, k: 1.5, floor: 0.015, refractory: 0.12 }, options || {});
    let previous = null;
    let history = [];       // [{ t, flux }]
    let last = -Infinity;
    return {
        reset() { previous = null; history = []; last = -Infinity; },
        push(bins, t) {
            if (!Array.isArray(bins) || bins.length === 0) { previous = null; return 0; }
            let flux = 0;
            if (previous && previous.length === bins.length) {
                const bass = Math.max(1, Math.floor(bins.length / 4));
                for (let i = 0; i < bins.length; i++) {
                    const rise = (Number(bins[i]) || 0) - (Number(previous[i]) || 0);
                    if (rise > 0) flux += rise * (i < bass ? 2 : 1);
                }
                flux /= bins.length + Math.max(1, Math.floor(bins.length / 4));
            }
            previous = bins.slice();
            history = history.filter(h => t - h.t >= 0 && t - h.t < o.window);
            let threshold = o.floor;
            if (history.length >= 4) {
                const mean = history.reduce((a, h) => a + h.flux, 0) / history.length;
                const sd = Math.sqrt(history.reduce((a, h) => a + (h.flux - mean) ** 2, 0) / history.length);
                threshold = Math.max(o.floor, mean + o.k * sd);
            }
            history.push({ t, flux });
            if (flux <= threshold || t - last < o.refractory) return 0;
            last = t;
            return Math.min(1, (flux - threshold) / threshold);
        }
    };
}

// How many times this line's words were sung before (a returning chorus): case, spaces and punctuation ignored.
function echoes(lines, index) {
    const key = l => String(l?.text ?? "").toLowerCase().replace(PUNCT, "");
    const here = key(lines[index]);
    if (!here) return 0;
    let count = 0;
    for (let i = 0; i < index; i++) if (key(lines[i]) === here) count++;
    return count;
}

// A frame's words laid out in a box: each word at its own size (base × scaleFor of its sung length), in runs that wrap
// at the box's width, the block centred; or, when `upright` (CJK), columns of glyphs top to bottom, the first column on
// the right. If the block overflows, everything shrinks to fit. `measure(text, px)` is a word's advance at a size.
// Returns { fit, width, height, items: [{ x, y, size, width, height }] }: one item per word, x/y its top-left.
function layoutFrame(words, measure, width, height, base, upright) {
    const sizes = words.map(w => base * scaleFor(w.end - w.time));
    const place = k => {
        const items = [];
        if (upright) {
            let col = 0, y = 0, colWidth = 0, columns = [];
            words.forEach((w, i) => {
                const s = sizes[i] * k, glyphs = [...w.text].length, h = s * 1.04 * glyphs;
                if (y > 0 && y + h > height) { columns.push(colWidth); col++; y = 0; colWidth = 0; }
                items.push({ col: col, y: y, size: s, width: s, height: h });
                y += h;
                colWidth = Math.max(colWidth, s * 1.12);
            });
            columns.push(colWidth);
            // Right to left: column 0 at the right edge.
            const total = columns.reduce((a, b) => a + b, 0);
            const starts = [];
            let x = total;
            for (const c of columns) { x -= c; starts.push(x); }
            const tall = Math.max(0, ...items.map(it => it.y + it.height));
            return { width: total, height: tall, items: items.map(it => ({ x: starts[it.col] + (columns[it.col] - it.width) / 2, y: it.y, size: it.size, width: it.width, height: it.height })) };
        }
        let x = 0, y = 0, lineHeight = 0, wide = 0;
        const rows = [];
        let row = [];
        words.forEach((w, i) => {
            const s = sizes[i] * k, wWidth = measure(w.text, s), gap = s * 0.3;
            if (x > 0 && x + wWidth > width) {
                rows.push({ items: row, height: lineHeight, width: x });
                y += lineHeight;
                x = 0; lineHeight = 0; row = [];
            }
            row.push({ x: x, size: s, width: wWidth, height: s * 1.0 });
            x += wWidth + gap;
            lineHeight = Math.max(lineHeight, s * 1.0);
        });
        rows.push({ items: row, height: lineHeight, width: x });
        let top = 0;
        for (const r of rows) {
            const used = Math.max(0, r.width - (r.items.length ? r.items[r.items.length - 1].size * 0.3 : 0));
            wide = Math.max(wide, used);
            // Each run sits on its line's baseline: smaller words drop to meet the largest.
            for (const it of r.items) items.push({ x: it.x, y: top + (r.height - it.height), size: it.size, width: it.width, height: it.height, rowWidth: used });
            top += r.height;
        }
        return { width: wide, height: top, items: items };
    };
    let k = 1, laid = place(k);
    for (let tries = 0; tries < 6 && (laid.width > width + 0.5 || laid.height > height + 0.5); tries++) {
        k *= Math.min(width / Math.max(1, laid.width), height / Math.max(1, laid.height)) * 0.98;
        laid = place(k);
    }
    // Centre the block; each horizontal run is centred on its own width.
    const dx = (width - laid.width) / 2, dy = (height - laid.height) / 2;
    return {
        fit: k, width: laid.width, height: laid.height,
        items: laid.items.map(it => ({ x: it.x + (it.rowWidth !== undefined ? (width - it.rowWidth) / 2 : dx), y: it.y + dy, size: it.size, width: it.width, height: it.height }))
    };
}
