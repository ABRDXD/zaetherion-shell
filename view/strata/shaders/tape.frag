#version 440
// The archive on a bad tape (view/strata/Tape.qml, Overdrive only): the field archive is drawn as if played back
// from a worn VHS cassette. A tracking band rolls down the picture, tearing the lines it crosses sideways and
// washing them out with noise; the bottom rows jitter where the heads switch and the top flags; the colour channels
// bleed apart; scanlines and a slow vertical wobble sit over everything. The tape wears where it has been played
// (`wearSource`, one column: red is a passage's wear, blue a crease): worn lines slip further and bleed wider, shed
// oxide as white dropout streaks that flicker frame to frame, and fade, and a crease slips its band sideways for
// good. `alive` (the engine) scales all of it, so at 0 it is the archive exactly.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    // The roll's phase (0..1), the engine, and a glitch burst (0..1, decaying).
    float phase;
    float alive;
    float glitch;
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D wearSource;

float hash(float n) {
    return fract(sin(n * 91.3458) * 47453.5453);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;
    float t = 6.2831853 * phase;
    vec4 worn = texture(wearSource, vec2(0.5, uv.y));
    float wear = worn.r * alive;
    float crease = worn.b * alive;
    float d = uv.y - fract(phase * 2.0);
    d -= floor(d + 0.5);
    float band = exp(-d * d * 700.0) * (0.6 + 0.4 * glitch);
    float line = floor(px.y / 2.0);
    float frame = floor(phase * 900.0);
    float jitter = hash(line + frame * 7.0) - 0.5;
    float head = smoothstep(0.95, 1.0, uv.y);
    float flag = pow(max(0.0, 1.0 - uv.y * 14.0), 2.0);
    float shift = (jitter * (1.2 + 18.0 * band + 30.0 * head + 40.0 * glitch * hash(floor(px.y / 24.0) + frame)) * (1.0 + 2.5 * wear)
                   + sin(uv.y * 38.0 + t * 9.0) * 0.7 + flag * 10.0 * sin(t * 5.0)) * alive
                   + crease * (9.0 + 3.0 * sin(t * 2.0));
    float wobble = sin(t * 3.0) * 0.8 * alive;
    vec2 suv = uv + vec2(shift / size.x, wobble / size.y);
    float bleed = (1.6 + 3.5 * band + 6.0 * glitch) * (1.0 + 2.0 * wear) * alive / size.x;
    vec4 g = texture(source, suv);
    vec4 r = texture(source, suv + vec2(bleed, 0.0));
    vec4 b = texture(source, suv - vec2(bleed, 0.0));
    float a = max(g.a, max(r.a, b.a));
    vec3 c = vec3(r.r, g.g, b.b);
    // Worn tape fades: colour drains, blacks lift.
    float luma = dot(c, vec3(0.299, 0.587, 0.114));
    c = mix(c, vec3(luma), 0.45 * wear);
    c = mix(c, c * 0.86 + 0.07 * a, 0.5 * wear);
    float scan = mix(1.0, 0.9 + 0.1 * sin(px.y * 3.14159), alive);
    float noise = hash(px.x * 0.37 + px.y * 13.1 + frame) * (band * 0.4 + head * 0.25 + crease * 0.3) * alive;
    c = c * scan + vec3(noise) * a;
    c = mix(c, c * 1.12 + 0.05 * a, band * 0.5 * alive);
    // Dropouts: where the oxide has shed, a line loses its picture to a white streak for a frame.
    float row = floor(px.y);
    float shed = step(1.0 - 0.03 * wear, hash(row * 1.37 + frame * 3.1));
    float from = hash(row + frame * 11.0) * size.x;
    float len = 16.0 + 140.0 * hash(row * 7.0 + frame);
    shed *= step(from, px.x) * step(px.x, from + len);
    c = mix(c, vec3(0.94) * a, shed * 0.85);
    fragColor = vec4(c, a) * qt_Opacity;
}
