.pragma library
// Field coordinates use the sheet's height as their unit. One propagation unit = 1800 s.
// The scalar is a smooth earliest-arrival envelope; each active deadline supplies its
// real remaining seconds. The stopwatch is an elapsed emitter, with a 60 s phase.
var slope = Math.tan(78 * Math.PI / 180);
function clamp(value, low, high) { return Math.max(low, Math.min(high, value)); }
function fraction(remaining, duration) { return duration > 0 ? clamp(remaining / duration, 0, 1) : 1; }
function compression(remainingFraction) { return 0.18 + 0.82 * Math.sqrt(clamp(remainingFraction, 0, 1)); }
function seam(y, aspect) { return aspect * 0.58 + (0.5 - y) / slope; }
function warp(x, y, aspect, remainingFraction) {
    const cut = seam(y, aspect);
    return [x <= cut ? x : cut + (x - cut) / compression(remainingFraction), y];
}
function closeness(a, b) {
    return a.deadline && b.deadline && a.running && b.running ? clamp(1 - Math.abs(a.seconds - b.seconds) / 60, 0, 1) : 0;
}
function crowd(x, y, anchors, aspect) {
    let pressure = 0;
    for (let i = 0; i < anchors.length; i++) for (let j = i + 1; j < anchors.length; j++) {
        const a = anchors[i], b = anchors[j];
        const dx = x - (a.x + b.x) * aspect * 0.5, dy = y - (a.y + b.y) * 0.5;
        pressure += closeness(a, b) * Math.exp(-8 * (dx * dx + dy * dy));
    }
    return pressure;
}
function value(x, y, anchors, aspect, remainingFraction) {
    if (!anchors.length) return 0;
    const p = warp(x, y, aspect, remainingFraction);
    const density = 1 + 1.6 * crowd(x, y, anchors, aspect);
    const arrivals = anchors.map(a => {
        const q = warp(a.x * aspect, a.y, aspect, remainingFraction);
        return (a.deadline ? a.seconds : -(a.seconds % 60)) + Math.hypot(p[0] - q[0], p[1] - q[1]) * 1800 * density;
    });
    const earliest = Math.min(...arrivals);
    // Stable soft-min, smoothing only 24 s. Subtracting earliest prevents overflow.
    return earliest - 24 * Math.log(arrivals.reduce((sum, t) => sum + Math.exp(-(t - earliest) / 24), 0));
}
// Marching squares with an asymptotic centre decision for saddle cells.
function segments(width, height, anchors, remainingFraction, pitch) {
    if (!anchors.length || width <= 0 || height <= 0) return [];
    const step = 5, nx = Math.ceil(width / step), ny = Math.ceil(height / step);
    const sx = width / nx, sy = height / ny, aspect = width / height, values = [];
    for (let y = 0; y <= ny; y++) {
        const row = [];
        for (let x = 0; x <= nx; x++) row.push(value(x * sx / height, y * sy / height, anchors, aspect, remainingFraction));
        values.push(row);
    }
    const out = [];
    for (let y = 0; y < ny; y++) for (let x = 0; x < nx; x++) {
        const v = [values[y][x], values[y][x+1], values[y+1][x+1], values[y+1][x]];
        const points = [[x*sx,y*sy],[(x+1)*sx,y*sy],[(x+1)*sx,(y+1)*sy],[x*sx,(y+1)*sy]];
        for (let level = Math.ceil(Math.min(...v) / pitch) * pitch; level < Math.max(...v); level += pitch) {
            const crossings = [];
            for (let e = 0; e < 4; e++) {
                const f = (e + 1) % 4;
                if ((v[e] < level) === (v[f] < level)) continue;
                const t = (level - v[e]) / (v[f] - v[e]);
                crossings.push([points[e][0]+t*(points[f][0]-points[e][0]),points[e][1]+t*(points[f][1]-points[e][1])]);
            }
            if (crossings.length === 4 && (v[0]+v[1]+v[2]+v[3])/4 < level) crossings.push(crossings.shift());
            for (let i = 0; i + 1 < crossings.length; i += 2) out.push([crossings[i],crossings[i+1],level]);
        }
    }
    return out;
}
