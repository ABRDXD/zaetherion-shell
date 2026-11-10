#version 440
// The Medium's smoke (view/strata/Medium.qml), carried by the gas. r is the first smoke, g is heat (it cools fast and rises), b is the second smoke, a is how long
// since this smoke was hot: the display turns it from flame to soot.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 gasTexel;
    float aspect;
    float dt;
    float time;
    float ambient;      // how much drifting gas the sky makes on its own
    vec4 well;          // the hole: x, y, its horizon's radius
    vec4 kick;          // a strike: x, y, radius, strength
    vec4 kickDye;       // what it leaves: smoke, heat, second smoke
    vec4 p0; vec4 p1; vec4 p2; vec4 p3; vec4 p4; vec4 p5; vec4 p6; vec4 p7;     // emitters: x, y, radius, strength
    vec4 c0; vec4 c1; vec4 c2; vec4 c3; vec4 c4; vec4 c5; vec4 c6; vec4 c7;     // and what they breathe: smoke, heat, second smoke, -
};
layout(binding = 1) uniform sampler2D gas;
layout(binding = 2) uniform sampler2D dye;

vec4 emit(vec4 p, vec4 c, vec2 uv) {
    if (p.w == 0.0)
        return vec4(0.0);
    vec2 d = (uv - p.xy) * vec2(aspect, 1.0);
    return c * exp(-dot(d, d) / max(1e-6, p.z * p.z));
}

float noise(vec2 x) {
    vec2 i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    vec2 h = vec2(127.1, 311.7);
    float a = fract(sin(dot(i, h)) * 43758.5453), b = fract(sin(dot(i + vec2(1.0, 0.0), h)) * 43758.5453);
    float c = fract(sin(dot(i + vec2(0.0, 1.0), h)) * 43758.5453), d = fract(sin(dot(i + vec2(1.0, 1.0), h)) * 43758.5453);
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 flow = texture(gas, uv).xy;
    vec2 from = uv - dt * flow * gasTexel;
    vec4 d = texture(dye, from);
    // Bilinear advection softens; give a little of the edge back, but never past what the four neighbours hold, or it feeds on its own noise.
    vec2 s = gasTexel * 0.5;
    vec4 n1 = texture(dye, from + vec2(s.x, 0.0)), n2 = texture(dye, from - vec2(s.x, 0.0)), n3 = texture(dye, from + vec2(0.0, s.y)), n4 = texture(dye, from - vec2(0.0, s.y));
    vec4 low = min(min(n1, n2), min(n3, n4)), high = max(max(n1, n2), max(n3, n4));
    d = clamp(d + 0.18 * (d - 0.25 * (n1 + n2 + n3 + n4)), low, high);

    d.r *= 1.0 - 0.0052 * dt;
    d.b *= 1.0 - 0.0052 * dt;
    d.g *= 1.0 - 0.028 * dt;
    d.a = min(1.0, d.a + 0.004 * dt);

    if (ambient > 0.0) {
        float n = noise(uv * vec2(aspect, 1.0) * 2.2 + vec2(time * 0.031, -time * 0.023)) * noise(uv * vec2(aspect, 1.0) * 4.7 - vec2(time * 0.017, time * 0.041));
        d.r += ambient * dt * 0.0026 * smoothstep(0.3, 0.62, n);
        d.b += ambient * dt * 0.0016 * smoothstep(0.72, 0.95, 1.0 - n);
    }

    vec4 e = emit(p0, c0, uv) + emit(p1, c1, uv) + emit(p2, c2, uv) + emit(p3, c3, uv) + emit(p4, c4, uv) + emit(p5, c5, uv) + emit(p6, c6, uv) + emit(p7, c7, uv);
    d.rgb += dt * e.rgb;
    if (kick.w != 0.0) {
        vec2 q = (uv - kick.xy) * vec2(aspect, 1.0);
        d.rgb += kickDye.rgb * exp(-dot(q, q) / max(1e-6, kick.z * kick.z));
    }
    // Fresh heat resets the soot clock.
    d.a *= 1.0 - clamp(d.g * 2.5, 0.0, 1.0);

    // Whatever crosses the horizon is gone.
    if (well.z > 0.0) {
        vec2 to = (uv - well.xy) * vec2(aspect, 1.0);
        d.rgb *= smoothstep(well.z * 0.8, well.z * 1.4, length(to));
    }
    fragColor = min(d, vec4(4.0, 3.0, 4.0, 1.0));
}
