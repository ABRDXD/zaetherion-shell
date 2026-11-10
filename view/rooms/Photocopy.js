.pragma library
// Photocopy generations (docs/OVERDRIVE.md §49; Claude B's own idea): Clips' history is copies of copies. In Overdrive
// each clip's preview is set as the generation its place in the history makes it: the newest crisp; each older one a
// copy of the one before, so its ink thins, a second impression slips out of register, and toner speckle gathers.
// Pure: no Qt, so Node tests run it (tests/test_photocopy.py). Nothing is read but what the row already shows.

const MAX = 12;

function generation(index) {
    return Math.max(0, Math.min(MAX, Math.floor(index)));
}
// The ink's strength: 1 for the original, thinning to 0.62 by the twelfth generation.
function ink(gen) {
    return Math.round((1 - 0.38 * Math.pow(gen / MAX, 0.8)) * 1000) / 1000;
}
// The slipped impression: offset (px) and strength.
function slip(gen) {
    return { x: Math.round(gen * 0.35 * 10) / 10, y: Math.round(gen * 0.2 * 10) / 10, alpha: gen > 0 ? Math.min(0.35, 0.08 + gen * 0.025) : 0 };
}
// Toner speckle: [{x, y, r}] in a w × h preview, seeded by the clip's id so it stays put; more each generation.
function speckle(id, gen, w, h) {
    let a = 2166136261;
    const s = String(id);
    for (let i = 0; i < s.length; i++) a = Math.imul(a ^ s.charCodeAt(i), 16777619);
    const next = () => { a = Math.imul(a ^ (a >>> 15), 2246822507) ^ Math.imul(a ^ (a >>> 13), 3266489909); return ((a >>>= 0) % 100000) / 100000; };
    const out = [];
    for (let i = 0; i < gen * 6; i++)
        out.push({ x: next() * w, y: next() * h, r: 0.4 + next() * 0.8 });
    return out;
}
