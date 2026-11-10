#version 440
// Sundial rooms (view/strata/Sundial.qml, Overdrive only; docs/OVERDRIVE.md §43): the room's content casts a shadow on
// its sheet away from the real sun (or the moon). `mask` is the content's alpha (KeepOut); `offset` is the shadow's
// full length in the mask's uv. A point is in shadow when content stands between it and the light, nearer content
// darker; the shadow softens towards its end. Drawn under the room, so the content covers its own footprint.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 offset;
    float strength;
    // The light on the paper where nothing stands in its way (premultiplied): warm for the sun, cold for the moon. On a
    // dark sheet the shadows read as the paper left unlit.
    vec4 wash;
};
layout(binding = 1) uniform sampler2D mask;

void main() {
    float shade = 0.0;
    const int TAPS = 14;
    vec2 side = vec2(-offset.y, offset.x) * 0.06;
    for (int i = 1; i <= TAPS; i++) {
        float t = float(i) / float(TAPS);
        vec2 at = qt_TexCoord0 - offset * t;
        float a = texture(mask, at).a;
        a = max(a, 0.5 * (texture(mask, at + side * t).a + texture(mask, at - side * t).a));
        shade = max(shade, a * (1.0 - 0.7 * t));
    }
    fragColor = (wash * (1.0 - shade) + vec4(0.0, 0.0, 0.0, 1.0) * shade * strength) * qt_Opacity;
}
