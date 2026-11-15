.pragma library

// The workspace instrument's geometry and motion (Z199): an edge-on system seen from its own plane, wider than the
// island so most of the orbit runs past its edges. Shared by the face and the island's shape for it.

const width = 600;          // the island while it shows
const depth = 118;
const orbitRx = 330;        // past the face's half width on purpose: a slot onto a larger system
const orbitRy = 3;          // edge-on: the world in front crosses the star's face
const planeY = 57;          // the system's plane, from the face's top
const starRadius = 24;
const planetBase = 7;       // a planet's diameter with no windows…
const planetPerWindow = 2.6; // …plus this per window, up to
const planetWindowsMax = 4;
const transitGrowth = 0.15; // the world in transit reads a little larger…
const transitMax = 0.6;     // …but never wider than this share of the star's diameter: a transit, never an eclipse
const farScale = 0.55;      // the back of the orbit, relative to the front
const farOpacity = 0.55;
const scaleY = 92;          // the hairline scale under the plane
const scaleInset = 60;
const tickCurrent = 9;
const tickInhabited = 5;
const tickEmpty = 3;
const readoutY = 100;
const turnMs = 1100;        // the system turning, smooth, no bounce
const glintMs = 1600;       // one cold glint along the plane
// Fixed dust: [x share, y share, size px, opacity].
const dust = [[0.06, 0.19, 1.2, 0.6], [0.2, 0.76, 1, 0.4], [0.35, 0.12, 1.4, 0.5], [0.67, 0.81, 1, 0.4],
              [0.78, 0.15, 1.2, 0.6], [0.93, 0.68, 1, 0.35], [0.55, 0.88, 0.8, 0.3]];

function planetSize(windows) {
    return planetBase + Math.min(windows, planetWindowsMax) * planetPerWindow;
}
