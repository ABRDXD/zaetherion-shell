.pragma library
// Archive match cut (docs/OVERDRIVE_IDEAS.md #40, docs/OVERDRIVE.md §51): leaving the archive, one number that the
// archive and the room you return to both show is the cut's pivot. Pure: no Qt, so Node tests run it
// (tests/test_match_cut.py). Only what is on screen is read: a label's text, never anything stored.

// Where `number` (a room's, "05") stands in `text`: the first run of digits of the same value, leading zeros aside
// ("005", "5" and "05" are all room 05; "105" and "50" aren't). Returns { at, length } of the run, or null.
function find(text, number) {
    if (typeof text !== "string" || typeof number !== "string" || !/^[0-9]+$/.test(number))
        return null;
    const want = number.replace(/^0+(?=.)/, "");
    const runs = /[0-9]+/g;
    let m;
    while ((m = runs.exec(text)) !== null)
        if (m[0].replace(/^0+(?=.)/, "") === want)
            return { at: m.index, length: m[0].length };
    return null;
}
// The cut's timeline, in a 0..1 phase: the pivot holds still while everything else changes around it (to `hold`),
// glides its bounding box into the room's number (to `land`), then hands over to the real one.
const HOLD = 0.2, LAND = 0.82;
function glide(u) {
    if (u <= HOLD)
        return 0;
    if (u >= LAND)
        return 1;
    const k = (u - HOLD) / (LAND - HOLD);
    // Ease in and out: a cut's pivot leaves gently and settles exactly.
    return k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2;
}
function fade(u) {
    return u < LAND ? 1 : Math.max(0, (1 - u) / (1 - LAND));
}
// A box between two: x, y, w, h by the glide; the type's size goes geometrically, as a camera's scale does.
function box(a, b, k) {
    const mix = (p, q) => p + (q - p) * k;
    return { x: mix(a.x, b.x), y: mix(a.y, b.y), w: mix(a.w, b.w), h: mix(a.h, b.h),
             size: Math.exp(Math.log(Math.max(1, a.size)) + (Math.log(Math.max(1, b.size)) - Math.log(Math.max(1, a.size))) * k) };
}
// The ghosts the box leaves on its way: `n` earlier phases, each a little behind.
function trail(u, n, lag) {
    const out = [];
    for (let i = 1; i <= n; i++)
        out.push(glide(Math.max(0, u - i * lag)));
    return out;
}
