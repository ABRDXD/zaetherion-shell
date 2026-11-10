#version 440
// A window developing on the contact sheet (view/overdrive/ContactSheet.qml, Overdrive only): a warm, grainy negative that
// turns positive behind a front travelling along the 78° family. At progress 1 it is the capture exactly.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float progress;
    float seed;
    vec4 tint;
};
layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    vec2 px = qt_TexCoord0 * size;
    float grain = hash(floor(px / 2.0));
    float along = (px.x * 0.9781 + px.y * 0.2079) / (size.x * 0.9781 + size.y * 0.2079);
    float front = smoothstep(along - 0.14, along + 0.14, progress * 1.32 - 0.16 + (grain - 0.5) * 0.1);
    // The negative comes up out of a dark plate first, then the positive replaces it.
    vec3 negative = (vec3(c.a) - c.rgb) * vec3(1.0, 0.72, 0.5);
    vec3 latent = mix(tint.rgb * 0.1 * c.a, negative, smoothstep(0.0, 0.35, progress));
    vec3 rgb = mix(latent, c.rgb, front);
    rgb += (grain - 0.5) * 0.14 * (1.0 - front) * c.a;
    // The halation at the developing edge.
    rgb += tint.rgb * front * (1.0 - front) * 1.1 * c.a;
    fragColor = vec4(rgb, c.a) * qt_Opacity;
}
