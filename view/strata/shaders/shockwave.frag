#version 440
// The ignition's shockwave (view/strata/Shockwave.qml): one ring runs out from the ignite plate across the
// panel and bends what it passes through. Ahead of the wavefront the content is pushed out, behind it pulled
// back, so the ring reads as a lens; at the ring the colour channels split and the signal colour glows.
// The panel is drawn into `source` only while the wave runs (about a second), then the stratum is destroyed.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The item's size and the wave's centre, in pixels.
    vec2 size;
    vec2 centre;
    // The wavefront's radius, the ring's half-width, how far it displaces and how far it splits the channels
    // (pixels), and the signal colour's glow strength.
    float radius;
    float ringWidth;
    float strength;
    float split;
    float glow;
    vec4 tint;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 d = p - centre;
    float r = length(d);
    vec2 n = r > 0.001 ? d / r : vec2(0.0);
    float x = (r - radius) / max(1.0, ringWidth);
    float ring = exp(-x * x * 2.2);
    // A lens profile: the derivative of the ring, so content bunches up at the front and stretches behind.
    vec2 uv = (p + n * x * ring * strength) / size;
    vec2 cs = n * split * ring / size;
    vec4 g = texture(source, uv);
    vec4 r1 = texture(source, uv + cs);
    vec4 b1 = texture(source, uv - cs);
    vec4 c = vec4(r1.r, g.g, b1.b, max(g.a, max(r1.a, b1.a)));
    float ga = clamp(tint.a * ring * glow, 0.0, 1.0);
    fragColor = vec4(c.rgb * (1.0 - ga) + tint.rgb * ga, c.a + ga * (1.0 - c.a)) * qt_Opacity;
}
