#version 440
// The Medium's gas (view/strata/Medium.qml): a compressible flow on a grid, one solver step per frame. xy is velocity in grid cells per step, z is density
// (its gradient is the pressure force), w is the curl, kept for the next step's vorticity confinement. The grid feeds back on itself through a float texture.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 texel;
    float aspect;
    float dt;
    float swirl;        // vorticity confinement
    float buoyancy;     // how hard heat rises
    vec4 well;          // the hole: x, y, pull, spin
    vec4 kick;          // a strike: x, y, radius, strength
    vec4 kickDir;       // its direction; 0,0 pushes outward
    vec4 p0; vec4 p1; vec4 p2; vec4 p3; vec4 p4; vec4 p5; vec4 p6; vec4 p7;     // emitters: x, y, radius, strength
    vec4 v0; vec4 v1; vec4 v2; vec4 v3; vec4 v4; vec4 v5; vec4 v6; vec4 v7;     // and their push: vx, vy, -, -
};
layout(binding = 1) uniform sampler2D gas;
layout(binding = 2) uniform sampler2D dye;

vec2 emit(vec4 p, vec4 v, vec2 uv) {
    if (p.w == 0.0)
        return vec2(0.0);
    vec2 d = (uv - p.xy) * vec2(aspect, 1.0);
    return v.xy * p.w * exp(-dot(d, d) / max(1e-6, p.z * p.z));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec4 c = texture(gas, uv);
    vec4 l = texture(gas, uv - vec2(texel.x, 0.0));
    vec4 r = texture(gas, uv + vec2(texel.x, 0.0));
    vec4 b = texture(gas, uv - vec2(0.0, texel.y));
    vec4 t = texture(gas, uv + vec2(0.0, texel.y));
    // A cold texture reads as nothing at all: start from still gas at unit density.
    float rc = c.z > 0.01 ? c.z : 1.0, rl = l.z > 0.01 ? l.z : 1.0, rr = r.z > 0.01 ? r.z : 1.0, rb = b.z > 0.01 ? b.z : 1.0, rt = t.z > 0.01 ? t.z : 1.0;

    float div = 0.5 * (r.x - l.x + t.y - b.y);
    vec2 grad = 0.5 * vec2(rr - rl, rt - rb);
    float curl = 0.5 * ((r.y - l.y) - (t.x - b.x));

    // Semi-Lagrangian: the value here is what the flow carried here.
    vec4 a = texture(gas, uv - dt * c.xy * texel);
    vec2 v = a.xy;
    float rho = (a.z > 0.01 ? a.z : 1.0) * (1.0 - dt * clamp(div, -0.5, 0.5));

    // Pressure, and a little viscosity from the four neighbours.
    v -= dt * 0.42 * grad;
    // (Central differences leave an odd-even checkerboard the pressure can't see; the viscosity is what damps it.)
    v += min(dt, 1.2) * 0.17 * (l.xy + r.xy + b.xy + t.xy - 4.0 * c.xy);
    rho += min(dt, 1.2) * 0.17 * (rl + rr + rb + rt - 4.0 * rc);

    // Vorticity confinement: the numerics smear the small whirls away; this hands them back.
    vec2 gw = 0.5 * vec2(abs(r.w) - abs(l.w), abs(t.w) - abs(b.w));
    float gl = length(gw);
    if (gl > 1e-5)
        v += dt * swirl * (gw / gl).yx * vec2(1.0, -1.0) * curl;

    // Heat rises (towards the top of the panel, which is y = 0 here).
    vec4 d = texture(dye, uv);
    v.y -= dt * buoyancy * d.g;

    // The hole: pulls, and drags the gas round with it.
    if (well.z != 0.0 || well.w != 0.0) {
        vec2 to = (well.xy - uv) * vec2(aspect, 1.0);
        float r2 = dot(to, to) + 0.0009;
        vec2 inward = to / sqrt(r2);
        vec2 spin = vec2(-inward.y, inward.x);
        v += dt * (inward * well.z + spin * well.w) * 0.0009 / r2;
    }

    v += dt * (emit(p0, v0, uv) + emit(p1, v1, uv) + emit(p2, v2, uv) + emit(p3, v3, uv) + emit(p4, v4, uv) + emit(p5, v5, uv) + emit(p6, v6, uv) + emit(p7, v7, uv));

    if (kick.w != 0.0) {
        vec2 q = (uv - kick.xy) * vec2(aspect, 1.0);
        float f = exp(-dot(q, q) / max(1e-6, kick.z * kick.z));
        vec2 dir = dot(kickDir.xy, kickDir.xy) > 0.0 ? kickDir.xy : q / max(1e-4, length(q));
        v += dir * kick.w * f;
        rho += abs(kick.w) * f * 0.08;
    }

    v *= 1.0 - 0.0016 * dt;
    float speed = length(v);
    if (speed > 5.0)
        v *= 5.0 / speed;
    // The panel's walls.
    vec2 edge = min(uv, 1.0 - uv) / texel;
    if (edge.x < 1.5) v.x = 0.0;
    if (edge.y < 1.5) v.y = 0.0;
    rho = clamp(mix(rho, 1.0, 0.012 * dt), 0.4, 2.2);
    fragColor = vec4(v, rho, curl);
}
