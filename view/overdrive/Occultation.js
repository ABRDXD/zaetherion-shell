.pragma library
// Clock occultation (docs/OVERDRIVE_IDEAS.md #51, docs/OVERDRIVE.md §50): the header's clock never goes, but events
// pass in front of it or behind it, by how much they matter. A countdown's end splits the colon and sets its room's
// number between the hours and the minutes; a device coming or going crosses in front of the digits as a plate that
// prints them in negative; a new track passes behind them as a band. Pure: no Qt, so Node tests run it
// (tests/test_occultation.py). Nothing is kept: an event is a kind, a room number and the moment it began.

// rank: which event wins the clock while another is still crossing it; plane: in front of the digits or behind.
const KINDS = {
    timer: { rank: 3, plane: "split", duration: 2600 },
    device: { rank: 2, plane: "front", duration: 1700 },
    media: { rank: 1, plane: "behind", duration: 2300 }
};

function known(kind) {
    return Object.prototype.hasOwnProperty.call(KINDS, kind);
}
function duration(kind) {
    return known(kind) ? KINDS[kind].duration : 0;
}
function plane(kind) {
    return known(kind) ? KINDS[kind].plane : "";
}
// Where an event is in its crossing: 0 at first contact, 1 at last; -1 before or after, or with no event.
function progress(event, now) {
    if (!event || !known(event.kind))
        return -1;
    const u = (now - event.at) / KINDS[event.kind].duration;
    return u < 0 || u > 1 ? -1 : u;
}
function active(event, now) {
    return progress(event, now) >= 0;
}
// A new event takes the clock unless a weightier one is still crossing it; one of equal weight restarts it.
function admit(current, kind, room, now) {
    if (!known(kind))
        return current;
    if (active(current, now) && KINDS[current.kind].rank > KINDS[kind].rank)
        return current;
    return { kind: kind, room: Math.max(0, Math.floor(room)), at: now };
}
// The split's opening: the four contacts of an eclipse. 0 until first contact, up to 1 by the second (an eighth of
// the way), held until the third, closed by the fourth. Smoothstep at each limb.
function opening(u) {
    if (u < 0)
        return 0;
    const rise = Math.min(1, u / 0.125), fall = Math.min(1, (1 - u) / 0.15);
    const k = Math.max(0, Math.min(rise, fall));
    return k * k * (3 - 2 * k);
}
// A transiting body's left edge, crossing a clock `width` wide at a constant rate, as real bodies do: it enters
// wholly outside one side and leaves wholly outside the other. `fromRight` sends it right to left.
function transit(u, width, body, fromRight) {
    const x = -body + (width + body) * Math.max(0, Math.min(1, u));
    return fromRight ? width - body - x : x;
}
// Rooms are numbered as the index ribbon numbers them: Home 00, then 01 onward.
function roomNumber(index) {
    const n = Math.max(0, Math.floor(index));
    return n < 10 ? "0" + n : String(n);
}
