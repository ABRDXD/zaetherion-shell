#version 440
// Counter windows (view/shell/TitleCounters.qml, Overdrive only; atlas #43): the enclosed counters of the room
// title's glyphs are windows, and through them is what the room holds out of view. `mask` is the counters found in
// the drawn type (alpha 1 inside a counter); `content` is the room's content one fold away, laid over the title's
// frame. The title is set at an angle, the content is not: `ax`, `ay` and `b` take a point of this item (in px) to
// the content's texture, so the view through the windows stays level while the glyphs lean.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec2 ax;
    vec2 ay;
    vec2 b;
    // The paper behind the content, and the glass's tint (premultiplied, its alpha the strength).
    vec4 ground;
    vec4 tint;
};
layout(binding = 1) uniform sampler2D mask;
layout(binding = 2) uniform sampler2D content;

void main() {
    float m = texture(mask, qt_TexCoord0).a;
    vec2 p = qt_TexCoord0 * size;
    vec2 uv = ax * p.x + ay * p.y + b;
    vec4 c = (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) ? vec4(0.0) : texture(content, uv);
    vec4 seen = c + ground * (1.0 - c.a);
    seen.rgb = mix(seen.rgb, tint.rgb / max(tint.a, 0.001), tint.a);
    fragColor = seen * m * qt_Opacity;
}
