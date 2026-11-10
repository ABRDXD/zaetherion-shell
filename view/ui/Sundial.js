.pragma library
// Sundial rooms (docs/OVERDRIVE.md §43; Claude B's own idea). Pure: no Qt, so Node tests run it (tests/test_sundial.py).
// In Overdrive the room's content casts a shadow on its sheet from where the sun really is: the screen read as a map
// lying face up with north at the top, so the sun in the east throws shadows west, a low sun throws them long and a high
// one short. At night the moon does it instead, as strongly as it is lit; with both below the horizon there are none.

const HEIGHT = 5;          // px the content stands above its sheet
const LONGEST = 64;        // px, the longest shadow drawn

function clamp01(v) { return Math.max(0, Math.min(1, v)); }

// The light: {body, azimuth, altitude, strength} or null. The sun once it is up (fainter in the first degrees, through
// more air); the moon once the sun is 6° down (civil twilight over) and the moon is up, by its illumination.
function light(sky) {
    const sun = sky?.bodies?.sun, moon = sky?.bodies?.moon;
    if (sun && sun.altitude > 0.5)
        return { body: "sun", azimuth: sun.azimuth, altitude: sun.altitude, strength: 0.5 * (0.35 + 0.65 * clamp01(sun.altitude / 8)) };
    if (sun && moon && sun.altitude < -6 && moon.altitude > 0.5)
        return { body: "moon", azimuth: moon.azimuth, altitude: moon.altitude, strength: 0.3 * clamp01(sky.moon?.illumination ?? 0) };
    return null;
}

// The shadow's offset in px on the sheet: away from the light (east is +x, north is −y), as long as the content's
// height over the tangent of the light's altitude, at most LONGEST.
function shadow(l) {
    if (!l || !(l.altitude > 0))
        return { x: 0, y: 0, length: 0 };
    const a = l.azimuth * Math.PI / 180;
    const length = Math.min(LONGEST, HEIGHT / Math.tan(l.altitude * Math.PI / 180));
    return { x: -Math.sin(a) * length, y: Math.cos(a) * length, length: length };
}

// The caption: "SUN 214° · 31°" or "MOON 97° · 12°".
function caption(l) {
    return l ? l.body.toUpperCase() + " " + Math.round(l.azimuth) + "° · " + Math.round(l.altitude) + "°" : "";
}

// The light's colour: amber while the sun is low (golden hour), warming to near white as it climbs; the moon cold.
function tint(l) {
    if (!l) return "#00000000";
    if (l.body === "moon") return "#cfdcff";
    return l.altitude < 6 ? "#ffc58a" : l.altitude < 20 ? "#ffe2b8" : "#fff4e2";
}
