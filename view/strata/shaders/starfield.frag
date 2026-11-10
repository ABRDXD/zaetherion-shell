#version 440
// Deep space behind the orbit (view/strata/Starfield.qml, Overdrive only): three layers of procedural stars
// that move with the camera at a third, a sixth and a tenth of its speed (parallax), zoom less than the scene
// and twinkle on one phase. No textures: each star is a hash of its grid cell. A few burn in the warm colour.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The item's size, the camera's centre in scene pixels and its zoom.
    vec2 size;
    vec2 cam;
    float zoom;
    // The twinkle's phase (0..1), the engine (0 at rest), the share of cells holding a star.
    float twinkle;
    float alive;
    float density;
    vec4 starColor;
    vec4 warmColor;
};

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// x: the star's light at this pixel, y: its hash (for its colour).
vec2 layer(vec2 px, float depth, float cell, float seed) {
    float z = mix(1.0, zoom, 1.0 / depth);
    vec2 world = (px - size * 0.5) / z + cam / depth;
    vec2 g = world / cell;
    vec2 id = floor(g);
    vec2 f = fract(g);
    float h = hash(id + seed);
    if (h > density)
        return vec2(0.0);
    vec2 at = vec2(0.15) + 0.7 * vec2(hash(id + seed + 1.7), hash(id + seed + 9.1));
    float d = length(f - at) * cell * z;
    float r = 0.7 + 1.5 * hash(id + seed + 3.3);
    float tw = 0.5 + 0.5 * sin(6.2831853 * (twinkle * (1.0 + floor(4.0 * h)) + h * 13.0));
    return vec2(smoothstep(r, 0.0, d) * (0.35 + 0.65 * tw), h / max(density, 0.001));
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 a = layer(px, 10.0, 34.0, 0.0);
    vec2 b = layer(px, 6.0, 58.0, 17.0);
    vec2 c = layer(px, 3.0, 96.0, 41.0);
    float light = a.x * 0.45 + b.x * 0.7 + c.x;
    float warm = step(0.9, c.y) * c.x;
    vec3 colour = mix(starColor.rgb, warmColor.rgb, clamp(warm / max(light, 0.001), 0.0, 1.0));
    float alpha = clamp(light, 0.0, 1.0) * alive * starColor.a;
    fragColor = vec4(colour * alpha, alpha) * qt_Opacity;
}
