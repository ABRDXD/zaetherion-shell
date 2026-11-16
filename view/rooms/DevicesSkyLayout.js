.pragma library

// Devices' signal map (Z211): the laptop as a planet, its levels as rings round it, its links as bodies around it.
// Pure layout, so tests can run it under Node. Radii are shares of the scene's half-size; angles in degrees for
// Shape arcs (0 = right, clockwise) and radians for positions.

// The three level rings, outermost first: output volume, microphone, screen brightness.
const RINGS = [0.62, 0.53, 0.44];
// The Wi-Fi satellite rides between these radii: nearer the planet the stronger the signal.
const NEAR = 0.72;
const FAR = 0.96;
// Nearby networks sit beyond the satellite's reach.
const STARS_FROM = 0.86;
const STARS_TO = 1.0;
const MAX_STARS = 6;
// A ring's arc starts at the top.
const ARC_START = -90;

// Strength as 0–1 whether the host gives 0–1 or 0–100.
function unit(strength) {
    const s = Number(strength) || 0;
    return Math.max(0, Math.min(1, s > 1 ? s / 100 : s));
}

function ring(index) { return RINGS[index]; }

// A ring's arc for a level 0–1: { start, sweep } in degrees.
function arc(level) { return { start: ARC_START, sweep: 360 * Math.max(0, Math.min(1, Number(level) || 0)) }; }

// Where the arc's end sits for a level, as { x, y } on a unit circle (for its label).
function arcEnd(level) {
    const a = (ARC_START + 360 * Math.max(0, Math.min(1, Number(level) || 0))) * Math.PI / 180;
    return { x: Math.cos(a), y: Math.sin(a) };
}

// The satellite's distance (share of the half-size) for a signal strength.
function satellite(strength) { return FAR - (FAR - NEAR) * unit(strength); }

// A stable angle for a name, so a network keeps its place in the sky between scans.
function angleFor(name) {
    let h = 2166136261;
    const s = String(name);
    for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
    return ((h >>> 0) % 3600) / 3600 * 2 * Math.PI;
}

// Up to MAX_STARS networks that are not the connected one, strongest first, each { id, ssid, known, angle, r, size }.
function stars(networks) {
    return networks.filter(n => !n.connected).slice().sort((a, b) => unit(b.strength) - unit(a.strength)).slice(0, MAX_STARS)
        .map(n => ({ id: n.id, ssid: n.ssid || "hidden", known: !!n.known, angle: angleFor(n.ssid || n.id),
                     r: STARS_TO - (STARS_TO - STARS_FROM) * unit(n.strength), size: 3 + Math.round(5 * unit(n.strength)) }));
}

// Where the battery's light ends across the planet (0–1 of its width): a full battery is lit to past the middle.
function lit(level) { return 0.12 + 0.5 * Math.max(0, Math.min(1, Number(level) || 0)); }

// "56" for 0.56; "—" when unknown.
function percent(level, available) { return available === false ? "—" : String(Math.round(Math.max(0, Math.min(1, Number(level) || 0)) * 100)); }
