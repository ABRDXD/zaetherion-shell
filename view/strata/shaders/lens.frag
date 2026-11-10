#version 440
// The gravitational lens of a room switch (M13, view/strata/LensPass.qml): the room you are leaving is seen through a
// point mass standing at the room you chose. This is the lens equation itself: a ray at offset d lands at
// d - d * R^2 / |d|^2, so the picture folds into an Einstein ring of radius R, with a second, inverted image inside it.
// The colours split a little at the ring and the signal colour glows on it. R is 0 at either end of the pass.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec2 centre;
    // The Einstein radius and the colour split, in pixels.
    float einstein;
    float split;
    vec4 tint;
};
layout(binding = 1) uniform sampler2D source;

vec4 look(vec2 at) {
    vec2 uv = at / size;
    // Past the edge of the room there is no room: fade out over a couple of pixels instead of smearing the edge.
    vec2 edge = smoothstep(vec2(0.0), 2.0 / size, uv) * (1.0 - smoothstep(1.0 - 2.0 / size, vec2(1.0), uv));
    return texture(source, clamp(uv, vec2(0.0), vec2(1.0))) * edge.x * edge.y;
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 d = p - centre;
    float r2 = max(dot(d, d), 1.0);
    float r = sqrt(r2);
    vec2 n = d / r;
    vec2 at = p - d * (einstein * einstein) / r2;
    float off = (r - einstein) / (einstein * 0.14 + 2.0);  // squared by hand: pow() of a negative number is undefined in GLSL
    float ring = exp(-off * off);
    vec2 cs = n * split * ring;
    vec4 g = look(at);
    vec4 a = look(at + cs);
    vec4 b = look(at - cs);
    vec4 c = vec4(a.r, g.g, b.b, max(g.a, max(a.a, b.a)));
    float glow = clamp(tint.a * ring * (einstein > 0.5 ? 0.5 : 0.0), 0.0, 1.0);
    fragColor = vec4(c.rgb * (1.0 - glow) + tint.rgb * glow, c.a + glow * (1.0 - c.a)) * qt_Opacity;
}
