.pragma library

// Fluid Performance (owner's pick "A · The star", 15 November 2026): the machine as a star. Its colour is the CPU's
// temperature, as a real star's colour is its surface temperature; its size is memory in use; its glow is CPU load;
// the GPU is a companion on its own orbit. In Overdrive, one shell per core and the heaviest processes as planets.

// Temperature → the star's colour along the spectral classes, coolest (M, orange) to hottest (O, blue-white), °C.
const coolC = 40;
const hotC = 92;
// The star, as shares of the room's height.
const coreMin = 0.035;       // radius at no memory in use…
const coreMax = 0.075;       // …and at all of it
const glowBase = 0.18;       // the glow's radius at no load…
const glowLoad = 0.16;       // …plus this at full load
const shellGap = 0.014;      // between core shells (Overdrive)
// Orbits, tilted like the rest of the language; shares of the room's width (rx) and height (ry).
const tilt = -12;
const orbits = [[0.22, 0.11], [0.31, 0.155], [0.40, 0.2]];
const gpuOrbit = 1;          // which orbit the companion rides
const gpuAngle = 2.3;        // radians: where on it (the lower half, clear of the readings above)
const planetAngles = [0.6, 2.5, 1.2, 1.9, 0.2];   // the lower half of the orbits, under the readings
const planetCount = 5;
const sampleMs = 1000;       // how often the Overdrive layers ask the core

// 0 (cool) … 1 (hot) for a temperature; null when there is none.
function heat(celsius) {
    if (celsius === null || celsius === undefined || !Number.isFinite(celsius)) return null;
    return Math.max(0, Math.min(1, (celsius - coolC) / (hotC - coolC)));
}
// A point on a tilted orbit, relative to the centre.
function onOrbit(rx, ry, angle) {
    const t = tilt * Math.PI / 180, x = rx * Math.cos(angle), y = ry * Math.sin(angle);
    return { x: x * Math.cos(t) - y * Math.sin(t), y: x * Math.sin(t) + y * Math.cos(t) };
}
// The words for a heat, for the line under the reading.
function colourName(h) {
    if (h === null) return "";
    return h < 0.2 ? "orange" : h < 0.4 ? "gold" : h < 0.6 ? "white" : h < 0.8 ? "blue-white" : "blue";
}
