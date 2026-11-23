.pragma library

// The orbit's geometry (docs/ORBIT.md §0): a real perspective camera over a plane. The rooms ride
// concentric circles on the plane; the camera looks down at it from `elevation` degrees (45 at rest; 90
// would be straight down) from a distance of DISTANCE outer radii, so the near half of each orbit is
// larger than the far half, and a tile floating `h` px above the plane stands on a stalk with its shadow
// below. The picture is then sheared by FART's house angle (verticals lean to 78°, as the planes' edges
// do, so the stalks stand like the tiles' sides; the rings' long axis rises a little to the right). Pure: no
// QML, tested under Node (tests/test_orbit.py).

var ELEVATION = 45;
var DISTANCE = 3.4;
var SHEAR = Math.tan(12 * Math.PI / 180);
var FAR_OPACITY = 0.6;

// A camera for an elevation in degrees, over a system whose outer orbit has radius `outer` px.
function view(elevation, outer) {
    var e = elevation * Math.PI / 180;
    return { e: e, sin: Math.sin(e), cos: Math.cos(e), d: DISTANCE * Math.max(1, outer) };
}

// A world point (x across, h up from the plane, z towards the viewer) on screen, relative to the
// system's centre, with its perspective scale k.
function point(x, h, z, v) {
    var k = v.d / (v.d - h * v.sin - z * v.cos);
    var sx = x * k;
    var sy = (z * v.sin - h * v.cos) * k;
    return { x: sx - sy * SHEAR, y: sy, k: k };
}

// A tile's place: radius r and angle θ on the plane (θ = π/2 is the front, nearest the viewer), raised h px.
// x, y is the top of its stalk (where the tile stands), gx, gy its foot on the plane; scale is the
// perspective there, depth 0 at the back and 1 at the front, z the true depth (nearer is drawn over).
function project(r, theta, cx, cy, v, h) {
    var x = r * Math.cos(theta), z = r * Math.sin(theta), lift = h || 0;
    var p = point(x, lift, z, v);
    var g = lift ? point(x, 0, z, v) : p;
    var depth = (Math.sin(theta) + 1) / 2;
    return {
        x: cx + p.x, y: cy + p.y, gx: cx + g.x, gy: cy + g.y,
        scale: p.k, depth: depth, opacity: FAR_OPACITY + (1 - FAR_OPACITY) * depth, z: z
    };
}

// An orbit's outline on the plane as screen points, split into the far half and the near half, so the
// near half can be drawn stronger.
function outline(r, cx, cy, v, steps) {
    var n = steps || 72, back = [], front = [];
    for (var i = 0; i <= n; i++) {
        var t = Math.PI + Math.PI * i / n;                 // π → 2π: the far half
        var p = point(r * Math.cos(t), 0, r * Math.sin(t), v);
        back.push({ x: cx + p.x, y: cy + p.y });
        var u = Math.PI * i / n;                            // 0 → π: the near half
        var q = point(r * Math.cos(u), 0, r * Math.sin(u), v);
        front.push({ x: cx + q.x, y: cy + q.y });
    }
    return { back: back, front: front };
}

// The unit system's extent (outer radius 1) at an elevation: under perspective it is not centred. `near`
// and `far` are the perspective scales at the front and at the back.
function bounds(elevation) {
    var v = view(elevation, 1);
    var b = { minX: Infinity, maxX: -Infinity, minY: Infinity, maxY: -Infinity, near: 0, far: Infinity };
    for (var i = 0; i < 96; i++) {
        var t = 2 * Math.PI * i / 96;
        var p = point(Math.cos(t), 0, Math.sin(t), v);
        b.minX = Math.min(b.minX, p.x); b.maxX = Math.max(b.maxX, p.x);
        b.minY = Math.min(b.minY, p.y); b.maxY = Math.max(b.maxY, p.y);
        b.near = Math.max(b.near, p.k); b.far = Math.min(b.far, p.k);
    }
    return b;
}

// The largest outer radius whose system fits a field of halfWidth × halfHeight, with tiles of half-size
// (hw, hh) standing `lift` px over their orbits; and the shift (dx, dy) that centres it. A tile stands above
// its orbit point, so only the back tiles reach above the system (at the far scale); the front ones stay
// inside it.
function fit(halfWidth, halfHeight, hw, hh, lift, elevation) {
    var b = bounds(elevation === undefined ? ELEVATION : elevation);
    var top = (lift + 2 * hh) * b.far;
    var r = Math.max(0, Math.min((halfWidth - hw * b.near) / ((b.maxX - b.minX) / 2),
                                 (2 * halfHeight - top) / (b.maxY - b.minY)));
    return { r: r, dx: -r * (b.minX + b.maxX) / 2, dy: -(r * b.minY - top + r * b.maxY) / 2 };
}

// count orbits, evenly spaced from inner to outer.
function radii(count, inner, outer) {
    var out = [];
    for (var k = 0; k < count; k++)
        out.push(count > 1 ? inner + (outer - inner) * k / (count - 1) : inner);
    return out;
}

// Default angles: a golden-angle spiral from the front-left, so neighbouring orbits start far apart.
function spread(count) {
    var out = [];
    var golden = Math.PI * (3 - Math.sqrt(5));
    for (var k = 0; k < count; k++)
        out.push(wrap(Math.PI * 0.62 + k * golden));
    return out;
}

function wrap(a) {
    var t = a % (2 * Math.PI);
    return t < 0 ? t + 2 * Math.PI : t;
}

// A tile's screen box (centre and half-size): it stands on its stalk, so its bottom edge is at the top of
// the stalk.
function box(r, theta, size, v, h) {
    var p = project(r, theta, 0, 0, v, h);
    return { x: p.x, y: p.y - size.h * p.scale / 2, hw: size.w * p.scale / 2, hh: size.h * p.scale / 2 };
}

function overlap(a, b, pad) {
    var ox = a.hw + b.hw + pad - Math.abs(a.x - b.x);
    var oy = a.hh + b.hh + pad - Math.abs(a.y - b.y);
    return ox > 0 && oy > 0 ? Math.min(ox, oy) : 0;
}

// Nudge tiles that would overlap apart along their own orbits (so each stays on its orbit, near its
// stored angle). sizes[k] = { w, h } at scale 1; home = { x, y, hw, hh } is the Home tile's box, which
// nothing may cover. Deterministic: the same input gives the same output.
function separate(angles, rs, sizes, home, pad, v, h) {
    var out = angles.slice();
    var n = out.length;
    for (var pass = 0; pass < 240; pass++) {
        var moved = false;
        for (var i = 0; i < n; i++) {
            var a = box(rs[i], out[i], sizes[i], v, h);
            for (var j = i + 1; j < n; j++) {
                var b = box(rs[j], out[j], sizes[j], v, h);
                var o = overlap(a, b, pad);
                if (o <= 0)
                    continue;
                // Push apart in angle, each by its share of the overlap over its radius, away from the other.
                var d = wrap(out[j] - out[i]);
                var sign = d < Math.PI ? 1 : -1;
                var step = Math.min(0.08, (o + 1) / Math.max(1, rs[i] + rs[j]));
                out[i] = wrap(out[i] - sign * step);
                out[j] = wrap(out[j] + sign * step);
                a = box(rs[i], out[i], sizes[i], v, h);
                moved = true;
            }
            var c = overlap(a, home, pad);
            if (c > 0) {
                // Slide along the orbit towards the nearer side (left or right of Home).
                var toward = Math.cos(out[i]) >= 0 ? 0 : Math.PI;
                var delta = wrap(toward - out[i]);
                out[i] = wrap(out[i] + (delta < Math.PI ? 1 : -1) * Math.min(0.08, (c + 1) / Math.max(1, rs[i])));
                moved = true;
            }
        }
        if (!moved)
            break;
    }
    return out;
}

// The worst overlap left among the tiles and Home, for tests (0 when clear).
function worst(angles, rs, sizes, home, pad, v, h) {
    var boxes = [];
    for (var k = 0; k < angles.length; k++)
        boxes.push(box(rs[k], angles[k], sizes[k], v, h));
    var w = 0;
    for (var i = 0; i < boxes.length; i++) {
        w = Math.max(w, overlap(boxes[i], home, pad));
        for (var j = i + 1; j < boxes.length; j++)
            w = Math.max(w, overlap(boxes[i], boxes[j], pad));
    }
    return w;
}

// Parallax error budget (docs/OVERDRIVE_IDEAS.md #5): how much of what a room stands on can't be measured just now, 0..1. `sources` is one boolean per thing it reads; a room that
// reads nothing is certain. Rendered as a bracket that opens around the tile, not as a badge.
function errorBudget(sources) {
    if (!sources || !sources.length)
        return 0;
    return sources.filter(s => !s).length / sources.length;
}

