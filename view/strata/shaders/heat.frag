#version 440
// The heat haze over the header (view/strata/HeatHaze.qml, Overdrive only): the header is drawn through a
// shimmering offset that grows with `heat` (the view's measured CPU against Overdrive's budget) and towards the
// top, and a warm glow rises off it. At heat 0 it is the header exactly.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The item's size in pixels, the heat (0..1) and the shimmer's phase (0..1).
    vec2 size;
    float heat;
    float phase;
    vec4 tint;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * size;
    float up = 1.0 - uv.y;
    float t = 6.2831853 * phase;
    // Two travelling waves, about 40 and 15 px long, bent by a slow vertical one: heat shimmer, not a ripple.
    float n = sin(px.x / 6.4 + t * 3.0 + sin(px.y / 5.0 - t * 2.0) * 2.0) * 0.6 + sin(px.x / 2.4 - t * 5.0) * 0.4;
    // At most about a pixel across and one and a half up, mostly over the top of the row: the header stays readable.
    vec2 off = vec2(n * 0.9, n * 1.4) / size * heat * (0.15 + 0.85 * up * up);
    vec4 c = texture(source, uv + off);
    float ga = clamp(heat * 0.3 * up * up * (0.75 + 0.25 * sin(px.x / 40.0 + t)), 0.0, 1.0);
    fragColor = vec4(c.rgb * (1.0 - ga) + tint.rgb * ga * (0.4 + 0.6 * c.a), c.a + ga * 0.25 * (1.0 - c.a)) * qt_Opacity;
}
