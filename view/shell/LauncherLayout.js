.pragma library

// The launcher's geometry (S6, docs/S6_LAUNCHER.md §3), shared by the face that draws it and the island window that
// must be deep enough to hold it without resizing (a layer surface resized during a morph shows stretched frames).
// The results ride one closed orbit under the line you type in (Z196): the pick at perigee (bottom), the rest paired
// left and right by rank, the last at apogee (top). Symmetric about the island's axis.

const edgePad = 10;        // the island face's padding to its edges (IslandExpansion reads it from here)
const contentWidth = 760;  // the orbit's chart
const inputHeight = 36;    // the island's resting height: the line the launcher grows from
const notice = 20;         // the line under the input for a refusal (`> BLOCKED · SESSION`)
const chartHeight = 470;   // the orbit, the headline under perigee and its detail line

// The orbit inside the chart (origin: the chart's top-left).
const orbitX = contentWidth / 2;
const orbitY = 178;
const orbitRx = 300;
const orbitRy = 124;
const perigeeRadius = 44;  // the accretion ring around the pick
const labelWidth = 160;    // a body's name under it, centred
// The barycentre's scenery for a lone inline result (LauncherScenery.qml).
const sceneryRx = 130;     // a sum's binary orbit
const sceneryRy = 44;
const binaryStar = 18;     // a scenery star's diameter
const sceneryLabel = 200;  // a binary star's label: what you typed, the answer
const beam = 250;          // a pulsar's beam, a comet's tail
const nebula = [[0, 0, 120], [-90, -20, 80], [100, 14, 90], [30, -46, 64], [-40, 40, 70]];  // clouds: [dx, dy, radius]
// The launcher's own motion, slower than a button's so the orbit reads as moving (scaled by the host's motion profile).
const swingMs = 320;       // the orbit swinging one step, with overshoot
const drawMs = 720;        // the orbit drawing in on open
const revealMs = 680;      // the ring's flare, the headline's rise and the scenery's entrance
const birthStagger = 28;  // ms between bodies popping in, by rank
const headlineY = orbitY + orbitRy + perigeeRadius + 34;

// Fixed points of the chart's sky: [x share, y share, size px]. Static, drawn once.
const sky = [[0.06, 0.12, 2], [0.93, 0.08, 2], [0.81, 0.62, 1.5], [0.15, 0.7, 2], [0.66, 0.04, 1.5], [0.3, 0.9, 1.5],
             [0.97, 0.45, 1.5], [0.03, 0.42, 1.5], [0.55, 0.96, 1.5], [0.4, 0.06, 1]];

function depth(rows, edgePad) {
    return 2 * edgePad + inputHeight + notice + chartHeight;
}
