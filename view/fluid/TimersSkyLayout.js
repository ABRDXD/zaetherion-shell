.pragma library

// The Fluid Timers sky (owner's pick, 15 November 2026: "B + C", "majestic"): you stand on a planet; a black hole
// crosses its sky over a stretch while the time still to go spirals into it and a pulsing light, now, falls inward.
// Positions are shares of the room so the scene keeps its composition at any panel size.

// The hole's path across the sky (a quadratic: rise, apex, set), as shares of the room.
const riseX = 0.045, riseY = 0.84;
const apexX = 0.5, apexY = -0.05;
const setX = 0.955, setY = 0.84;
// The hole rides a flattened copy of that path, pulled toward the middle and down, so it never leaves the sky.
const pathPull = 0.3;        // share of the way to the middle
const pathScaleY = 0.75;
const pathLiftY = 0.16;
// The planet: a vast ellipse whose top edge is the horizon.
const horizonY = 0.79;
const planetRx = 1.55;       // shares of the room's width
const planetRy = 1.33;
const airWidth = 3;          // the lit atmosphere's line, px
const airGlow = 12;
// The hole and its disc, px.
const holeRadius = 52;
const discRadius = 250;
const discFlat = 0.21;       // the disc seen at a low angle
const tilt = -12;            // the one angle family
const spiralOuter = 230;
const spiralTurns = 3;
const spiralFlat = 0.34;
const spiralSteps = 160;
const matterCount = 18;
const glowRadius = 420;
// The light: a slow breath while a timer runs.
const beaconRadius = 6;
const haloRadius = 10;
const beaconMs = 900;        // each half of the breath
// The readings.
const clockSize = 168;       // the numerals, px
const clockTracking = -6;
const sentenceWidth = 460;
// Fixed stars, [x share, y share, size px].
const stars = [[0.09, 0.11, 2], [0.23, 0.25, 1.6], [0.40, 0.08, 2.2], [0.56, 0.18, 1.4], [0.72, 0.09, 2], [0.85, 0.28, 1.6],
               [0.95, 0.14, 2.2], [0.15, 0.43, 1.4], [0.78, 0.46, 1.6], [0.47, 0.39, 1.2], [0.31, 0.59, 1.4], [0.65, 0.62, 1.6]];

function quad(u, a, b, c) {
    return (1 - u) * (1 - u) * a + 2 * (1 - u) * u * b + u * u * c;
}
// Where the hole stands at progress u (0 rise … 1 set), in px for a room w × h.
function holeAt(u, w, h) {
    const x = quad(u, riseX, apexX, setX) * w, y = quad(u, riseY, apexY, setY) * h;
    return { x: x * (1 - pathPull) + w * apexX * pathPull, y: y * pathScaleY + h * pathLiftY };
}
// A point on the inward spiral at u (0 at the rim … 1 at the photon ring), around the hole, untilted.
function spiralAt(u) {
    const a = -Math.PI / 2 + u * spiralTurns * 2 * Math.PI, r = spiralOuter - (spiralOuter - holeRadius - 4) * u;
    return { x: r * Math.cos(a), y: spiralFlat * r * Math.sin(a) };
}
function spiral(u0, u1) {
    const out = [];
    if (u1 <= u0) return out;
    for (let i = 0; i <= spiralSteps; i++) out.push(spiralAt(u0 + (u1 - u0) * i / spiralSteps));
    return out;
}
